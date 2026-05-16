# ADR 0003 — SSAS Tabular and Fabric semantic model side by side

- **Status:** Accepted
- **Date:** 2026-05-09

## Context

The on-prem stack has SSAS Tabular feeding Power BI Live Connection. Fabric
has its own semantic-model layer (Direct Lake over the warehouse).

A naive migration deletes the SSAS model and forces every Power BI report
onto Fabric immediately. This is risky for the same reason as ADR 0002: any
silent regression in measure definitions is invisible until users notice.

## Decision

Maintain both semantic layers during the parallel period (ADR 0002):

- `ssas/FlightAnalytics/Model.bim` — Tabular, compat 1600, pointing at
  `FlightData_Curated_v2`.
- Fabric semantic model on `FlightDataWarehouse.fact_flight` + dims (Direct
  Lake).
- **Identical measure definitions** in both, copy-pasted from a shared DAX
  file at `docs/measures.dax`.
- Two `.pbix` files (`pbi/flights_onprem.pbix` and `pbi/flights_fabric.pbix`)
  with identical visuals; only the data source differs.

After the parallel period, the SSAS database is detached and the report
pointed exclusively at Fabric.

## Consequences

**Positive**
- Measure parity is verifiable side-by-side.
- Easy A/B comparison for stakeholders ("does the YoY tile still match?").
- Strong narrative artefact: same dashboard, two backends.

**Negative**
- Two models to keep in sync. Mitigated by the shared DAX file.

## Alternatives considered

- **DirectQuery from SSAS to Fabric Warehouse** — possible but defeats the
  point; SSAS becomes a passthrough.
- **Skip SSAS entirely** — would lose the on-prem comparison artefact and the
  CV signal of having actually built a Tabular model.
