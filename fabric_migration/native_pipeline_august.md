# Native pipeline — August 2024 (Fabric-only, no on-prem)

## Scenario

August onwards, the on-prem SQL Server is decommissioned. New CSVs land
directly in the Fabric Lakehouse via a Data Pipeline. Same gold table, same
hash keys, no IDENTITY anywhere.

## Flow

```
SFTP / blob → Lakehouse Files/raw_csv/
        ↓
notebook 01_bronze_ingest    (Delta, partitioned by Year/Month)
        ↓
notebook 02_silver_clean     (typed, de-duped, quarantine)
        ↓
notebook 03_gold_dimensions  (hash-keyed dims, SCD2 carrier)
        ↓
notebook 04_gold_fact        (MERGE on FlightHK — idempotent)
```

## The "max ID" problem — solved

In the on-prem version, `FactFlightId BIGINT IDENTITY` worked because the
database assigned the next ID atomically. Fabric notebooks running in parallel
have no such coordination — `MAX(id) + row_number()` is a race condition.

Hash keys make the question moot. `FlightHK = SHA2_256(natural_key)` is
**deterministic** — same inputs, same hash, anywhere. The same flight loaded
twice produces the same `FlightHK`, so the MERGE deduplicates naturally.

This is documented in `docs/adr/0001-hash-keys-over-identity.md`.

## Orchestration

A single Fabric Data Pipeline runs the four notebooks in order:

1. Bronze ingest — wait until new files arrive
2. Silver clean — depends on bronze success
3. Gold dimensions — depends on silver success
4. Gold fact — depends on dimensions success

Each activity writes to `etl.run_log` (in the on-prem SQL Server during the
overlap month, then in a Fabric Warehouse table after decommission) for
end-to-end observability.

## Reconciliation in the cutover month

For one month the pipeline runs in both shapes (CDC-from-onprem and
Fabric-native) and `dq.vw_pipeline_reconciliation` shows zero variance. That
is the proof the migration is lossless. Then the on-prem stack is shut down.
