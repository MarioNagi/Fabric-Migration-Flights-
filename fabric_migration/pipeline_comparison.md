# Pipeline comparison — on-prem vs Fabric

| Aspect              | On-prem (legacy)                       | Fabric (target)                            |
| ------------------- | -------------------------------------- | ------------------------------------------ |
| Ingestion           | SSIS package, scheduled by Agent       | Fabric Data Pipeline, scheduled or event   |
| Storage             | SQL Server MDF/LDF                     | OneLake Delta Parquet                      |
| Surrogate keys      | INT IDENTITY (race condition risk)     | SHA-256 hash (deterministic)               |
| Incremental load    | Full reload                            | CDC LSN-window pull → MERGE                |
| Modelling layer     | SSAS Tabular (compat 1600)             | Fabric semantic model (Direct Lake)        |
| Reporting           | Power BI Live → SSAS                   | Power BI → Direct Lake                     |
| Scaling             | Hardware-bound (single VM)             | Capacity-based (F-SKU)                     |
| Observability       | Custom — added in this rebuild         | `etl.run_log` shared across both           |
| Data quality        | None originally — added here           | `dq.expectations` shared across both       |
| Reconciliation      | None originally — added here           | `dq.vw_pipeline_reconciliation`            |
| Cutover risk        | High without parallel run              | Mitigated by 30-day parallel + recon view  |
| Cost model          | CapEx (server, licences)               | OpEx (capacity reservation)                |
| Backup / DR         | SQL backups, tape rotation             | OneLake versioning + capacity geo-pairing  |
