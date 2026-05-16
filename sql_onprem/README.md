# sql_onprem

T-SQL scripts for the on-prem side of the migration. Run in numeric order.

## Schema setup

| Script                            | Purpose                                |
| --------------------------------- | -------------------------------------- |
| `01_create_databases.sql`         | Creates Staging + Curated_v2           |
| `02_create_staging.sql`           | `dbo.Flights_2024` shape               |
| `03_create_star_schema.sql`       | Hash-keyed dims + fact + view          |
| `04_load_dimensions.sql`          | Populates DimDate/Carrier/Airport      |
| `05_load_fact.sql`                | Populates FactFlight from staging      |
| `06_drop_legacy_flat_table.sql`   | Removes the duplicate `dbo.Flights`    |

## CDC

| Script                            | Purpose                                |
| --------------------------------- | -------------------------------------- |
| `10_enable_cdc.sql`               | DB + table-level CDC, 7-day retention  |
| `11_cdc_window_function.sql`      | LSN-windowed extraction TVF            |
| `12_watermark_table.sql`          | Watermark + helper proc                |

## Observability and DQ

| Script                            | Purpose                                |
| --------------------------------- | -------------------------------------- |
| `20_etl_runlog.sql`               | Cross-system run log + helper procs    |
| `21_dq_framework.sql`             | Expectations, results, quarantine      |
| `22_reconciliation_view.sql`      | Per-month staging vs curated drift     |

## Notes

- Every script is idempotent — safe to re-run.
- `IF OBJECT_ID(...) IS NULL` guards mean re-running creates no duplicates.
- Every load sets `RunId` so rows can be traced back to `etl.run_log`.
