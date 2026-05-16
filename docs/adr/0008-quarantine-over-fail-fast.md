# ADR 0008 — Quarantine bad rows instead of failing the batch

- **Status:** Accepted
- **Date:** 2026-05-09

## Context

A batch of 600k rows hits a single `OriginCode IS NULL` row. Two choices:

1. **Fail fast** — abort the batch, fix the source, re-run.
2. **Quarantine** — divert the bad row to `dq.quarantine_flights`, continue
   loading the rest, surface the failure in `etl.run_log` and the
   reconciliation view.

## Decision

Use the **quarantine** pattern. Hard-rule failures (NOT NULL, lookup
violation) divert. Soft-rule failures (range warnings) load with a flag.

## Consequences

**Positive**
- One bad row never blocks an entire month's load.
- Failures are loud (`run_log` status, reconciliation drift) without being
  destructive.
- Quarantine table is the queue for human triage.

**Negative**
- Pipeline can succeed with bad data quarantined. Mitigated by surfacing
  quarantine row count in the dashboard tile — invisible failures are the
  real risk, not visible ones.

## Alternatives considered

- **Fail fast everywhere** — high operational cost; one source-system glitch
  pages the on-call.
- **Silent drop** — never. Bad rows must go somewhere reviewable.
