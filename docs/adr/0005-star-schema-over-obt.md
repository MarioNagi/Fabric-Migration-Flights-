# ADR 0005 — Star schema over One Big Table

- **Status:** Accepted
- **Date:** 2026-05-09

## Context

The original curated database held both a star schema (`DimCarrier`,
`DimAirport`, `DimDate`, `FactFlight`) **and** a flat denormalised table
(`dbo.Flights`) with the same 3.46M rows. Both were populated from staging,
neither referenced the other, any divergence was a silent bug.

OBT (One Big Table / "wide table") is a legitimate pattern — common in
Lakehouse-style analytics. So the choice between star and OBT needed an
explicit decision.

## Decision

Standardise on the star schema as the source of truth in curated. The
flat-table view, where needed, is provided as `dbo.vw_Flights` — a view over
the star.

Reasons:

- SSAS Tabular consumes star natively; OBT requires column-level role-playing
  setup that complicates the model.
- Disk footprint: storing both shapes doubles storage with zero analytical
  value.
- Consistency: a star + view has one writer, one source of truth. OBT +
  star has two, which drift.
- Future SCD: SCD Type 2 in a star is straightforward; in OBT every fact
  row would need versioned dim columns inline.

## Consequences

**Positive**
- Single source of truth.
- SSAS model is canonical-shaped.
- View provides the flat shape on demand for ad-hoc exploration.

**Negative**
- Joins at view-evaluation time. Acceptable for the row counts at this scale;
  if it became a bottleneck, the view could be materialised as an indexed view.

## Alternatives considered

- **OBT only** — would have meant deleting the dim tables. Rejected because
  SSAS Tabular and Power BI Direct Lake both prefer star.
- **Both, with the flat table populated by a stored proc** — keeps the dual
  storage problem. Rejected.
