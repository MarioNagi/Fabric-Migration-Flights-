# ADR 0007 — Clustered columnstore on FactFlight

- **Status:** Accepted
- **Date:** 2026-05-09

## Context

`FactFlight` is an analytics fact: 3.5M rows, mostly read by aggregations,
loaded in monthly batches. The default rowstore + nonclustered indexes shape
is correct for OLTP, wrong for analytics.

## Decision

Build `FactFlight` with a **clustered columnstore index** plus supporting
nonclustered btree indexes on each dim foreign-key column.

```sql
CREATE CLUSTERED COLUMNSTORE INDEX CCI_FactFlight ON fact.FactFlight;
CREATE NONCLUSTERED INDEX IX_FactFlight_DateKey   ON fact.FactFlight (DateKey);
CREATE NONCLUSTERED INDEX IX_FactFlight_CarrierHK ON fact.FactFlight (CarrierHK);
CREATE NONCLUSTERED INDEX IX_FactFlight_OriginHK  ON fact.FactFlight (OriginHK);
CREATE NONCLUSTERED INDEX IX_FactFlight_DestHK    ON fact.FactFlight (DestHK);
```

## Consequences

**Positive**
- 5–10× compression vs rowstore.
- Aggregation scans are faster (segment elimination, batch-mode execution).
- SSAS processing benefits — fewer pages to read.

**Negative**
- Single-row lookups are slower than a btree (still acceptable; supporting
  NCIs cover dim joins).
- INSERT performance is lower than rowstore at small batch sizes; OK because
  loads are batched.
- Trickle inserts go to a delta store and need periodic reorganisation —
  scheduled via a SQL Agent job.

## Alternatives considered

- **Rowstore + heavy indexing** — worse compression, slower scans on a
  3.5M-row table.
- **Nonclustered columnstore on a rowstore base** — dual-shape, harder to
  reason about. Rejected.
