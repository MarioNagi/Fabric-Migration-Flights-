# fabric_migration

Fabric notebooks and pipeline flow documentation.

## Notebooks

| Notebook                                | Purpose                                |
| --------------------------------------- | -------------------------------------- |
| `notebooks/01_bronze_ingest.py`         | Lands raw CSVs as Delta, partitioned   |
| `notebooks/02_silver_clean.py`          | Typing, de-dup, quarantine             |
| `notebooks/03_gold_dimensions.py`       | Hash-keyed dims (SCD2 carrier)         |
| `notebooks/04_gold_fact.py`             | Hash-keyed fact, MERGE-idempotent      |

## Flow docs

| Doc                                     | Scenario                               |
| --------------------------------------- | -------------------------------------- |
| `cdc_to_gold_july.md`                   | July: on-prem → Fabric incremental     |
| `native_pipeline_august.md`             | August: Fabric-only, no on-prem        |
| `pipeline_comparison.md`                | Side-by-side comparison table          |

## How to run in Fabric

1. Upload the four `.py` files as notebooks into a Lakehouse.
2. Attach to a Lakehouse called `FlightDataLakehouse`.
3. Create a Warehouse called `FlightDataWarehouse`.
4. Build a Data Pipeline that runs the notebooks in order with `On Success`
   dependencies.
5. Schedule the pipeline daily (or trigger from the on-prem CDC pull).

The notebooks reference the Lakehouse / Warehouse names as constants at the
top of each file. Change those constants if your workspace uses different
names.
