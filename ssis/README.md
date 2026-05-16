# SSIS — Flights_ETL

Source-controlled copy of the SSIS solution that loads BTS monthly CSVs into
`FlightData_Staging.dbo.Flights_2024` on the on-prem SQL Server.

## Files

```
ssis/
├── Flights_Migration_Lab.sln       # VS solution file
├── Flights_ETL/
│   ├── Flights_ETL.dtproj          # SSIS project (project deployment model)
│   ├── Flights_ETL.database        # SSDT project database file
│   ├── Load_Flights_2024.dtsx      # the package (Flat File → Derived Col → Data Conv → OLE DB)
│   └── Project.params              # project-level parameters
├── package_review.md               # optimisation review with prioritised fixes
└── .gitignore                      # excludes bin/, obj/, *.user, *.ispac
```

## Live dev workspace

The dev copy used in Visual Studio lives at:
`C:\Users\Mario\source\repos\Flights_Migration_Lab\`

Edits made there must be copied back here before commit. The two copies will
drift if you forget — pick one as the source of truth and keep the other read-only.
**Recommendation:** make this repo copy the source of truth; have VS open the
project from here directly via `File → Open → Project/Solution`.

## Pipeline shape

```
Foreach Loop (User::FileName)
  └─ DF_Load_Flights
       ├─ Flat File Source (CM_FlatFile_Flights)
       ├─ Derived Column (TRIM, null handling, cancel-aware nulling for ArrTime/ArrDelay)
       ├─ Data Conversion (str→i4/i8/dbDate/wstr/bool)
       └─ OLE DB Destination → dbo.Flights_2024 (fast-load, TABLOCK,CHECK_CONSTRAINTS)
```

CSV source folder: `C:\Users\Mario\python projects\fabric project\raw csv\`
Destination: `Data Source=localhost; Catalog=FlightData_Staging; Integrated Security=SSPI`

See `package_review.md` for the optimisation list.
