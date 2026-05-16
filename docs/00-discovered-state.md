# Discovered state — 2026-05-09

This document records what was actually present in the local environment
before any rebuild work began. It exists because the README claimed more than
the repository delivered, and the rebuild needed an honest baseline.

Verified against `localhost` SQL Server with `sqlcmd` and `Get-Service`.

## SQL Server

- **Edition:** Microsoft SQL Server 2022 (RTM) Developer Edition, 16.0.1000.6
- **SQL Server (MSSQLSERVER):** Running, automatic startup
- **SQL Server Agent:** Running, automatic startup — CDC capture jobs supported
- **SSAS (MSSQLServerOLAPService):** Installed (MSAS16), currently stopped
- **SSAS CEIP telemetry:** Running

## Databases relevant to this project

| Database              | Purpose                                       |
| --------------------- | --------------------------------------------- |
| `FlightData_Staging`  | SSIS landing zone for raw CSV loads           |
| `FlightData_Curated`  | Star schema (and a redundant flat copy)       |
| `CsvRaw`              | Unrelated — Northwind exports                 |

## `FlightData_Staging`

| Table             | Rows      | PK                          |
| ----------------- | --------- | --------------------------- |
| `dbo.Flights_2024`| 3,495,952 | `FlightID BIGINT IDENTITY`  |

Row distribution by month:

| Year | Month | Rows    |
| ---- | ----- | ------- |
| 2024 | 1     | 547,271 |
| 2024 | 2     | 519,221 |
| 2024 | 3     | 591,767 |
| 2024 | 4     | 582,205 |
| 2024 | 5     | 609,743 |
| 2024 | 6     | 611,132 |
| 2024 | 7     | 634,613 |

CDC: not enabled.

## `FlightData_Curated`

| Table             | Rows      | PK                              |
| ----------------- | --------- | ------------------------------- |
| `dbo.DimCarrier`  | 15        | `CarrierKey INT IDENTITY`       |
| `dbo.DimAirport`  | 343       | `AirportKey INT IDENTITY`       |
| `dbo.DimDate`     | 182       | `DateKey INT` (yyyymmdd)        |
| `dbo.FactFlight`  | 3,461,339 | `FactFlightId BIGINT IDENTITY`  |
| `dbo.Flights`     | 3,461,339 | none — flat denormalised dump   |

Foreign keys: `FK_Fact_Date`, `FK_Fact_Carrier`, `FK_Fact_Origin`,
`FK_Fact_Dest` (Origin and Dest both reference `DimAirport`).

## What the README claimed vs reality

| Claim                                           | Reality                              |
| ----------------------------------------------- | ------------------------------------ |
| "Senior Data Engineer" project                  | Author is transitioning into the role|
| Star schema in `FlightData_Staging`             | Star schema is in `FlightData_Curated`|
| `DimCarrier` has `CarrierName`                  | Only `CarrierCode`                   |
| `DimAirport` has `AirportID`, name, city        | Only `AirportCode`, `CityName`       |
| Production-shaped pipeline                      | No tests, no ADRs, no CI, no run-log |
| CDC for July                                    | Not enabled                          |
| Surrogate keys survive Fabric migration         | INT IDENTITY — they do not           |

## Gaps the rebuild closes

1. Surrogate-key strategy — IDENTITY replaced by `BINARY(32)` SHA-256 hashes
2. Dimensions enriched with the attributes a real dashboard needs
3. SCD Type 2 added to `DimCarrier` to demonstrate the pattern
4. `dbo.Flights` flat duplicate replaced by `dbo.vw_Flights` view
5. CDC enabled on `dbo.Flights_2024` with watermark + LSN-window pattern
6. `etl.run_log` for cross-system observability
7. `dq.expectations` framework with quarantine pattern
8. Reconciliation view surfaced in Power BI
9. Test suite mirroring the sibling MigrationLab project
10. SSAS Tabular model with measures, hierarchies, KPIs, RLS
11. Two Power BI reports — one Live to SSAS, one Direct Lake to Fabric gold
12. Eight ADRs documenting decisions
13. README rewrite leading with the problem, not the stack
