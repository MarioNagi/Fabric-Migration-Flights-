# ADR 0001 — Hash surrogate keys over INT IDENTITY

- **Status:** Accepted
- **Date:** 2026-05-09

## Context

The on-prem version used `INT IDENTITY` surrogate keys (`CarrierKey`,
`AirportKey`, `FactFlightId`). When the August data load moved to a
Fabric-native pipeline, two problems appeared:

1. **No coordination.** Spark notebooks running in parallel cannot agree on
   "the next ID" without a centralised sequence the on-prem database used to
   provide for free.
2. **No portability.** A row inserted on-prem and re-loaded into Fabric got a
   different surrogate, so MERGE-by-SK was not idempotent.

`MAX(SK) + ROW_NUMBER()` is a known anti-pattern in distributed loads — it
races, and a retry produces different keys.

## Decision

Use `BINARY(32)` SHA-256 hash keys derived from the natural key:

```
CarrierHK = HASHBYTES('SHA2_256', UPPER(LTRIM(RTRIM(CarrierCode))))
```

Same on-prem T-SQL, same Spark `sha2(..., 256)`, same input → same output.

## Consequences

**Positive**
- Deterministic across systems — on-prem and Fabric agree.
- MERGE on hash key is naturally idempotent.
- No "max id" lookup, no race condition, no central sequence.
- Surrogate is decoupled from insert order.

**Negative**
- 32 bytes vs 4 — fact storage is larger.
- Hash keys do not order naturally (`<`, `>` are meaningless).
- Joins are still fast (clustered columnstore handles it) but slower than INT
  joins on a heap.

**Mitigations**
- Clustered columnstore on the fact compresses repeated hash values heavily.
- Where ordering is needed (audit displays), join to dim and use the natural
  key.

## Alternatives considered

- **Sequence table** — atomic counter both sides update. Fragile across the
  on-prem ↔ Fabric gateway, single point of contention, and the round-trip
  cost is unacceptable for million-row loads.
- **GUID** — deterministic only via UUID v5 (similar to a hash); no advantage
  over SHA-256 and harder to debug.
- **Compound natural key everywhere** — works but couples every fact to every
  dim's natural-key shape; a dim rename ripples through all facts.
