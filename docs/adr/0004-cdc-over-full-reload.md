# ADR 0004 — CDC incremental loads over full reload

- **Status:** Accepted
- **Date:** 2026-05-09

## Context

The original pipeline rebuilt the entire fact table from staging on every
load. At 3.5M rows this works but the hybrid version (on-prem ↔ Fabric over a
gateway) makes it untenable: the Copy Activity moves the same data every run.

## Decision

Enable SQL Server CDC on `dbo.Flights_2024` and switch the on-prem-to-Fabric
data movement to LSN-windowed incremental pulls.

- `sys.sp_cdc_enable_table` on the staging table.
- Retention bumped to 7 days (default 3).
- `etl.cdc_watermark` tracks the last-seen LSN per table.
- `etl.usp_GetFlightsCDCWindow` returns rows between watermark and
  `sys.fn_cdc_get_max_lsn()`, advances watermark atomically.
- Fabric notebooks MERGE on `FlightHK` so re-runs are idempotent.

## Consequences

**Positive**
- Bandwidth scales with change volume, not table size.
- Late-arriving data is captured naturally (CDC sees the insert whenever it
  happens).
- Production-shaped pattern.

**Negative**
- SQL Server Agent dependency (capture and cleanup jobs).
- 7-day retention means an outage longer than 7 days requires a full reload
  fallback. Documented in the runbook.

## Alternatives considered

- **Triggers writing to a custom audit table** — works but reinvents what
  CDC already provides, and triggers slow inserts.
- **Timestamp-based watermark** — fails for updates that don't bump a
  timestamp column; CDC catches every operation.
