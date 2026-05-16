# CDC flow — July 2024 incremental load (on-prem → Fabric)

## Scenario

July CSVs land via SSIS → `FlightData_Staging.dbo.Flights_2024`. CDC captures
the inserts. A Fabric pipeline pulls the LSN window and merges into gold —
**without** rebuilding the fact.

## Flow

```
[SSIS]            [SQL Server]                           [Fabric]
CSV → Flights_2024 → cdc.dbo_Flights_2024_CT → Copy Activity → bronze_cdc
                                                              ↓
                                                   notebook 02_silver_clean
                                                              ↓
                                                       MERGE → gold.fact_flight
```

## Steps

1. **SSIS run** writes July rows to `Flights_2024`. CDC capture job (Agent)
   pushes each insert into `cdc.dbo_Flights_2024_CT`.
2. **Fabric Copy Activity** reads `etl.cdc_watermark.LastLSN`, calls
   `etl.usp_GetFlightsCDCWindow`, lands the result in
   `FlightDataLakehouse.bronze_cdc_flights`.
3. **Notebook 02_silver_clean** filters/typecasts and unions with the existing
   `silver_flights` (de-dupe on natural key, latest wins).
4. **Notebook 04_gold_fact** computes hash keys and MERGEs on `FlightHK` —
   idempotent, safe to re-run.
5. **Watermark update** is the last step inside `usp_GetFlightsCDCWindow`,
   so partial failures never advance the LSN.

## Why this is interview-grade

- Incremental, not full-reload — survives at production scale.
- LSN-windowed extraction is the canonical SQL Server CDC pattern.
- Watermark is updated atomically with the read, so failures are safe to retry.
- Hash keys make the merge deterministic — no SK lookup over the gateway.
- Quarantine + DQ runner means bad rows never silently corrupt gold.

## Failure modes covered

| Failure                                     | Outcome                                  |
| ------------------------------------------- | ---------------------------------------- |
| Agent stopped — no CDC capture              | `usp_GetFlightsCDCWindow` returns 0 rows |
| Capture lag — `from_lsn > max_lsn`          | Proc prints message, no advance          |
| Fabric pipeline crash mid-pull              | Watermark unchanged, next run re-pulls   |
| Same row pulled twice                       | MERGE on `FlightHK` is idempotent        |
| Bad row from staging                        | Quarantined in silver, never reaches gold|
