# Runbook

What to do when things break. Ordered by likelihood.

## Pipeline failed overnight

1. Check `etl.run_log` for the most recent failed row:
   ```sql
   SELECT TOP 5 * FROM FlightData_Curated_v2.etl.run_log
   ORDER BY StartedAt DESC;
   ```
2. Read `ErrorMessage`. Common causes below.

## CDC pull returns 0 rows when it shouldn't

1. Is SQL Server Agent running?
   ```sql
   SELECT servicename, status_desc FROM sys.dm_server_services;
   ```
   If `SQL Server Agent (MSSQLSERVER)` is not `Running`, start it:
   ```powershell
   Start-Service SQLSERVERAGENT
   ```
2. Is the capture job alive?
   ```sql
   EXEC sys.sp_cdc_help_jobs;
   ```
3. Is the watermark stuck in the future?
   ```sql
   SELECT * FROM FlightData_Staging.etl.cdc_watermark;
   ```
   If `LastLSN > sys.fn_cdc_get_max_lsn()` it means the capture lost data
   (e.g., a long Agent outage). Reset by setting `LastLSN = NULL` and the
   next pull will start from the minimum available LSN. **Document the
   gap in `etl.run_log` with a manual entry.**

## Reconciliation view shows DRIFT

```sql
SELECT * FROM dq.vw_pipeline_reconciliation WHERE [Status] = 'DRIFT';
```

Possible causes:

| Variance pattern                          | Cause                              |
| ----------------------------------------- | ---------------------------------- |
| Staging > Curated for a single month      | Last load was partial — re-run     |
| Curated > Staging for any month           | Duplicate insert into fact         |
| Staging > Curated for every month equally | Curated was truncated; reload all  |

## Fact load duplicates rows

Cannot happen with hash keys + the `WHERE NOT EXISTS` guard in
`05_load_fact.sql`. If it does, check that the load was run against
`FlightData_Curated_v2` and not the legacy `FlightData_Curated`.

## SSAS process job fails

1. Check the job history in SSMS → Object Explorer → SSAS instance →
   `FlightAnalytics` database → Process History.
2. Most common cause: a new airport code in fact has no row in `DimAirport`.
   Run the dim load again before processing fact partitions.
3. Re-process:
   ```powershell
   .\ssas\deploy.ps1   # re-deploys + processes
   ```

## DQ rule fires repeatedly

```sql
SELECT * FROM dq.expectation_results
WHERE Passed = 0
ORDER BY EvaluatedAt DESC;
```

If the rule is genuinely wrong (false positive), set `IsActive = 0` in
`dq.expectations` and document the change in the commit message.

If the rule is right and the data is wrong, the bad rows are in
`dq.quarantine_flights`. Triage and fix at source.

## Fabric notebook fails

Notebooks log to `etl.run_log` (via the on-prem proc, called from the
Fabric pipeline activity). Check there first.

If a notebook is non-idempotent (it isn't, by design — every write uses
overwrite or MERGE), re-running is safe.

## Total rebuild from scratch

```powershell
sqlcmd -S localhost -E -C -Q "DROP DATABASE FlightData_Curated_v2"
.\tasks.ps1 setup
.\tasks.ps1 load
.\tasks.ps1 verify
```
