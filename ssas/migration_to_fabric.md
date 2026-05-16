# SSAS Tabular → Fabric semantic model — migration plan

> Source: `ssas/FlightAnalytics/Model.bim` (Tabular, compat level 1600)
> Target: Fabric workspace, **Direct Lake** semantic model over the Gold layer

## TL;DR

Your `Model.bim` is already 95% portable. Compat level 1600 is the same level
Fabric uses for Power BI semantic models. The 5% that needs reworking is:
**partition expressions** (Import mode pointing at `localhost`) and **role
membership** (Windows-account-based DAX security). The measures, hierarchies,
relationships, and KPI go across as-is.

The right migration is **rebuild as Direct Lake** against the Fabric Lakehouse
gold tables, not lift-and-shift the Import-mode model. Direct Lake is the
whole point of Fabric — querying Parquet at OneLake speed without an import
refresh.

## What's in `Model.bim` today

```
FlightAnalytics  (compat 1600)
├── DataSource: tds → localhost.FlightData_Curated_v2   ← won't work from Fabric
├── Tables (4)
│   ├── DimDate         (10 cols, M expression, Calendar hierarchy)
│   ├── DimCarrier      (6 cols, IsCurrent filter in M, binary CarrierHK)
│   ├── DimAirport      (9 cols, Geography hierarchy)
│   └── FactFlight      (11 cols, 11 measures incl. KPI)
├── Relationships (4)   ← Origin = active, Dest = inactive (USERELATIONSHIP)
└── Roles (2)
    ├── EastCoastAnalysts — row-level filter on DimAirport.State
    └── Analyst — read-only
```

The hash keys in the model (`CarrierHK`, `AirportHK`, `FlightHK` as `binary`)
already match the curated SQL schema we just deployed. **That's the bit that
makes Direct Lake possible without rework** — same keys, same join cardinality.

## Two valid target shapes in Fabric

### Option A — Direct Lake over Lakehouse (recommended)

```
On-prem SQL  →  Fabric Pipeline (Copy → Lakehouse Files /bronze/)
              →  Notebook (silver, validated parquet)
              →  Notebook (gold dim/fact, partitioned by Year)
              →  Lakehouse SQL endpoint
              →  Default semantic model  OR  Custom semantic model
              →  Power BI report
```

- No import, no refresh schedule. Reports read directly from Parquet in OneLake.
- Falls back to DirectQuery on the SQL endpoint if a query is too large for in-memory framing.
- Required: data lives in **Delta** tables in a Lakehouse (or shortcut to one).
- Best for the medallion shape we already designed.

### Option B — Import semantic model with M scripted refresh

```
Fabric Warehouse (gold)  →  Semantic model (Import mode, M expressions)
                         →  Refresh schedule
```

- Closer to what you have on SSAS today (paths just change from `localhost` to the Fabric warehouse).
- Loses the Direct Lake advantage.
- Only choose this if you have measures or DAX that Direct Lake doesn't support yet (rare — TIME INTELLIGENCE works fine).

**Recommendation:** Option A. It's what a Fabric interview will ask you to defend.

## Migration steps (Option A)

### Phase 1 — Extract the model (TMSL)
Get a TMSL representation of the SSAS model. Two ways:

```powershell
# from Tabular Editor 2 / 3
File → Save As → JSON  →  outputs the same shape as Model.bim
```
or
```powershell
# SSMS → connect to SSAS Tabular → right-click DB → Script → CREATE
# yields a TMSL script with createOrReplace
```

Save as `ssas/FlightAnalytics/tmsl_export.json`. This is your portable artefact.

### Phase 2 — Build the gold Lakehouse tables to match the model

The semantic model expects 4 tables with exact column names. You need to
materialise them in the Lakehouse with the same names:

```
LH_FlightAnalytics_Gold
├── DimDate           (DateKey, DateValue, Year, Quarter, Month, MonthName, ...)
├── DimCarrier        (CarrierHK, CarrierCode, CarrierName, CarrierType, Country, IsCurrent)
├── DimAirport        (AirportHK, AirportCode, AirportName, CityName, State, Country, Lat, Lon, IsHub)
└── FactFlight        (FlightHK, DateKey, CarrierHK, OriginHK, DestHK, DepDelayMin, ArrDelayMin,
                       Cancelled, Diverted, DistanceMiles, IsOnTime)
```

This is what the `fabric_migration/notebooks/` series is for. Two important
adjustments for Direct Lake:

1. **Binary types.** Direct Lake supports `binary` but the semantic-model UI
   prefers it `isHidden`. Already hidden in your BIM — good.
2. **`DimCarrier[IsCurrent]` filter.** Your M expression in BIM is
   `Table.SelectRows(dim, each [IsCurrent] = true)`. In Direct Lake there is
   no M — the filter has to be **baked into the Delta table** (write only
   `IsCurrent=1` rows to `LH_Gold.DimCarrier_Current`) or expressed as a
   semantic-model **calculation group / table filter**. Bake it into the
   table — that's the Fabric-idiomatic way and it's faster.

### Phase 3 — Create the Fabric semantic model

```
Fabric workspace
 → +New → Semantic model → Direct Lake
 → pick LH_FlightAnalytics_Gold and the 4 tables above
 → Open in Tabular Editor (or web modeling) and apply your BIM:
    - measures (paste DAX from Model.bim 1:1 — they all port)
    - relationships (same keys, same active/inactive flags)
    - hierarchies (Calendar, Geography)
    - KPI on On-Time %
    - sort columns (MonthName by Month, DayName by DayOfWeek)
```

You can do this with a **TMSL deployment** if you want it scripted:
- Connect Tabular Editor 3 to the Fabric workspace XMLA endpoint:
  `powerbi://api.powerbi.com/v1.0/myorg/<workspace_name>`
- Open `tmsl_export.json`
- Re-point the data source from `localhost` to the Lakehouse SQL endpoint
- `Deploy` → workspace.

### Phase 4 — Re-do RLS

Your `EastCoastAnalysts` role uses Windows AD groups implicitly. In Fabric:

```
Roles tab → EastCoastAnalysts
  Filter:    DimAirport[State] IN { "NY","NJ","PA","MA","CT","RI","VT","NH","ME" }
  Members:   <Entra ID group or user UPN>
```

DAX filter stays as-is. Members move from AD to Microsoft Entra.

### Phase 5 — Connect a Power BI report

- New Power BI report in the same workspace → **Direct Lake** connection to
  the semantic model. Drag a measure. If it works, you're done.
- If you previously had a `.pbix` against the SSAS model, change the
  connection string and re-publish — measures and hierarchies are the same.

## What changes vs. SSAS

| Concept                    | SSAS Tabular 1600        | Fabric semantic model (Direct Lake) |
|----------------------------|--------------------------|--------------------------------------|
| Storage                    | Imported, in-memory      | Parquet/Delta in OneLake, framed on demand |
| Refresh                    | Process Full / Process Add | No refresh — schema-aware framing |
| Partition expressions (M)  | `Sql.Database(...)`      | Replaced by Lakehouse Delta tables |
| Hierarchies                | Same                     | Same                                 |
| Measures                   | DAX                      | DAX, identical                       |
| RLS                        | DAX filter, AD members   | DAX filter, **Entra** members        |
| KPI                        | Same                     | Same                                 |
| `IsCurrent` filter in M    | M expression             | Bake into Delta or table-level filter |
| `binary` keys              | Supported                | Supported, keep hidden               |
| Inactive relationships     | `USERELATIONSHIP` in DAX | Same                                 |
| Deployment                 | SSDT-AS / TMSL via SSMS  | TMSL via Tabular Editor over XMLA    |
| Backup/restore             | `.abf`                   | Source control the BIM; Fabric handles state |

The two destinations every interviewer will ask about:

- **"Why Direct Lake and not Import?"** — Direct Lake reads the same Parquet
  the data scientists query. There is no second copy in VertiPaq memory,
  there is no refresh schedule, there is no drift window between Lakehouse
  truth and report truth. The trade-off is large-cardinality DAX may fall
  back to DirectQuery, which is slower than VertiPaq — but for this model
  (small dims, fact ~4M rows/year) Direct Lake will frame everything.

- **"Why not DirectQuery on the SQL Warehouse?"** — DirectQuery hits T-SQL,
  which has higher latency per visual than Parquet column scans. Direct Lake
  is the in-between: Parquet speed without import constraints.

## Concrete next steps (in order)

1. **Phase 2 first.** The gold tables don't exist yet in any Lakehouse. Until
   they do, there is nothing for Direct Lake to bind to.
   - Build `LH_FlightAnalytics_Gold` in the Fabric workspace.
   - Run the four notebooks in `fabric_migration/notebooks/` (still to be
     written — they're in the HANDOFF plan, phases 2 and 3).
2. **Phase 1 in parallel.** Export TMSL from SSAS to `tmsl_export.json` so
   you have a script-only representation that survives the rebuild.
3. **Phase 3.** Create the Fabric semantic model, paste measures from BIM.
4. **Phase 4 + 5.** RLS and Power BI binding.

The hardest single step is Phase 2 (Lakehouse + medallion notebooks) — that's
the bulk of the Day 3 LinkedIn arc. Once gold is in OneLake, the semantic
model is half a day of clicking.

## What does NOT need to change

- Star schema design (hash keys, SCD2 on DimCarrier, columnstore on fact)
- DAX expressions — every one of the 11 measures ports verbatim
- Hierarchies — Calendar and Geography port verbatim
- KPI on On-Time % — ports verbatim
- Relationship topology — same active/inactive flags

The BIM is good. The work is downstream of it.
