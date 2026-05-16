# Security model

## Accounts and least privilege

| Component             | Account                            | Permissions                                       |
| --------------------- | ---------------------------------- | ------------------------------------------------- |
| SSIS package run      | `svc_ssis_loader` (domain account) | `db_datawriter` on `FlightData_Staging` only      |
| Fact load proc        | `svc_curated_loader`               | `db_datawriter` on `FlightData_Curated_v2` only   |
| Power BI gateway      | `svc_pbi_gateway`                  | `db_datareader` on `FlightData_Curated_v2`        |
| SSAS service          | `MSSQLServerOLAPService` (default) | `db_datareader` on `FlightData_Curated_v2`        |
| Developer (you)       | local admin                        | full — for development only                       |

The dev environment uses Windows integrated security. Production would use
managed identities (Fabric) and Entra ID service principals (gateway).

## Secrets

- No connection strings, passwords, or tokens are committed to this repo.
- Local development uses Windows authentication exclusively.
- The Fabric gateway credential is configured in the Power BI Service, not
  in any file in this repo.
- A `.env.example` file (in this repo) shows the shape; the real `.env` is
  in `.gitignore`.

## Row-Level Security

Defined in `ssas/FlightAnalytics/Model.bim`:

- `Analyst` — read all
- `EastCoastAnalysts` — filter `DimAirport[State] IN ('NY','NJ','PA','MA',
  'CT','RI','VT','NH','ME')`

Roles map to Active Directory / Entra ID groups; the model definition
includes the filter expressions but role membership is configured at the SSAS
server level.

## PII assessment

BTS flight data contains no personal information — no passenger records, no
crew details, no payment data. The data is publicly downloadable. No
regulatory regime (HIPAA, PCI, GDPR) applies.

If the project were extended to include passenger data, the framework would
be:

1. Tag PII columns in `dq.expectations` metadata.
2. Apply Dynamic Data Masking on the SQL Server side.
3. Apply column-level security in Fabric Warehouse (`GRANT SELECT ON ...
   (allowed_cols)`).
4. Update SSAS roles to deny PII columns by default.

## Audit trail

Every curated row carries:

- `LoadedAt` — when it entered the table
- `UpdatedAt` — when it was last MERGEd
- `RecordSource` — which system produced it
- `RunId` — links to `etl.run_log`
- `StagingFlightID` — links back to the source row in staging

`etl.run_log` is the single ledger of pipeline activity; combined with the
lineage columns above, every row in gold can be traced back to a source CSV
file.
