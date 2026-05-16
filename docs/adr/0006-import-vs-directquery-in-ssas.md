# ADR 0006 — Import mode in SSAS Tabular (DirectQuery documented as the
production path)

- **Status:** Accepted
- **Date:** 2026-05-09

## Context

SSAS Tabular supports Import (data cached in the model) and DirectQuery
(queries pushed to the source). Each has trade-offs.

## Decision

Use **Import** mode for this project.

Reasons:

- Faster for the demo and screenshots (no query latency).
- Compression is excellent at 3.5M rows.
- No network dependency between Power BI and SQL Server during a live
  presentation.

DirectQuery is documented as the production path for cases where:

- Data volume exceeds Tabular's in-memory budget.
- Latency requirements demand queries hit the warehouse directly.
- Row-level security must be enforced at the source.

## Consequences

**Positive**
- Cold-start performance is fine.
- Processing strategy is straightforward: full process daily, partition
  process for the active month after CDC pulls.

**Negative**
- Memory footprint grows with data — would need a re-evaluation past 50M+
  rows.
- Refresh latency means data is "current as of last process," not real-time.

## Alternatives considered

- **DirectQuery** — chosen for production-scale rebuilds, not for portfolio
  scope.
- **Composite (mixed)** — adds complexity disproportionate to the project's
  scope.
