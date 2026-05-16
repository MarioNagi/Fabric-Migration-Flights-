# ADR 0002 — Keep on-prem stack alive for one month after Fabric goes live

- **Status:** Accepted
- **Date:** 2026-05-09

## Context

The migration cuts over a working SSIS → SQL Server → SSAS → Power BI stack.
A "big bang" cutover means any silent data quality issue in Fabric is
invisible until users complain. Worse, rolling back is expensive once the
on-prem capture is decommissioned.

## Decision

Run both pipelines in parallel for **one calendar month** after Fabric goes
live. During the parallel period:

- SSIS continues to load `dbo.Flights_2024` for that month.
- CDC continues to capture changes; the Fabric Copy Activity continues to pull.
- Fabric pipelines also run in their native shape (no on-prem dependency).
- `dq.vw_pipeline_reconciliation` shows row counts on both sides per month.
- Power BI users keep pointing at SSAS until the reconciliation invariant
  holds for 30 consecutive days.

After the parallel period, the on-prem stack is decommissioned in this order:
SSAS → SQL Server CDC → SQL Server staging → SSIS package archived.

## Consequences

**Positive**
- Migration is reversible until day 30.
- Reconciliation drift surfaces loudly.
- Users experience no UX change (Power BI live connection unchanged).

**Negative**
- One month of parallel infrastructure cost.
- Two pipelines to monitor.
- Risk of "we'll keep it for one more month" indefinitely — explicit
  decommission deadline mitigates this.

## Alternatives considered

- **Big-bang cutover** — cheaper but no rollback path. Rejected.
- **Indefinite parallel run** — never realises the migration's cost benefit.
  Rejected.
