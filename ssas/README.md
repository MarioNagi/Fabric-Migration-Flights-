# SSAS Tabular — FlightAnalytics

Tabular model deployed to local SQL Server Analysis Services 16.

## What's here

- `FlightAnalytics/Model.bim` — Tabular model definition (compat 1600)
- `deploy.ps1` — TMSL deploy + full process script

## Model

Star schema over `FlightData_Curated_v2`:

- `DimDate` — Calendar hierarchy (Year → Quarter → Month → Day)
- `DimCarrier` — current rows only (SCD2 history filtered out at the M layer)
- `DimAirport` — Geography hierarchy (Country → State → Airport)
- `FactFlight` — connected to all dims, single active relationship to
  `DimAirport` via `OriginHK` (Dest is inactive, used via `USERELATIONSHIP`)

## Measures

| Measure                | DAX                                                 |
| ---------------------- | --------------------------------------------------- |
| Total Flights          | `COUNTROWS(FactFlight)`                             |
| Cancelled %            | `DIVIDE([Cancelled Flights], [Total Flights])`      |
| On-Time %              | `DIVIDE([On-Time Flights], [Total Flights])`        |
| Avg Dep Delay          | `AVERAGE(FactFlight[DepDelayMin])`                  |
| Avg Arr Delay          | `AVERAGE(FactFlight[ArrDelayMin])`                  |
| Flights YoY %          | `SAMEPERIODLASTYEAR` comparison                     |
| On-Time KPI            | Target 80%, green ≥ 80%, yellow ≥ 70%, red below    |

## Roles

- `Analyst` — read all
- `EastCoastAnalysts` — RLS to `State IN ('NY','NJ','PA','MA','CT','RI','VT','NH','ME')`

## Deploy

```powershell
.\deploy.ps1
```

Requires the `SqlServer` PowerShell module (the script installs it if missing)
and SSAS service running.

## Why this exists alongside the Fabric semantic model

The migration runs both in parallel for one month. Power BI consumers point
to `flights_onprem.pbix` (Live → SSAS) until the cutover, then switch to
`flights_fabric.pbix` (Direct Lake). Same measures, same visuals — only the
data source changes. Documented in
`docs/adr/0003-ssas-and-fabric-side-by-side.md`.
