# Known limitations

This project is deliberately scoped to a portfolio piece. The list below is
what it does **not** do, and what real production work would add on top.

## Out of scope

| Limitation                                | Production extension                                        |
| ----------------------------------------- | ----------------------------------------------------------- |
| Single fact table (`FactFlight`)          | Add `FactDelaysByCause`, `FactAirportCapacity`              |
| SCD2 only on `DimCarrier`                 | Extend SCD2 to `DimAirport` for airport rebrands            |
| One source system (BTS CSVs)              | Multi-source ingestion (weather, fleet, fuel)               |
| Batch CDC, not streaming                  | Event Hub / Kafka into Fabric Eventstream                   |
| No DR strategy                            | Geo-replicated Fabric capacity, on-prem AG                  |
| No cost / capacity right-sizing           | Workload monitoring, F-SKU sizing, slot reservation         |
| No machine learning                       | Delay prediction model in Fabric Data Science               |
| No real users with real RLS               | LDAP / Entra ID group mapping to SSAS roles                 |

## Things that exist but are minimal

- DQ rules are 8, not 50. Adding more is straightforward — drop into
  `dq.expectations`.
- Hub airports (`DimAirport.IsHub`) are hard-coded to a list of 20 codes,
  not derived from BTS reference data.
- `DimCarrier` is seeded from the 15 codes in staging — a real environment
  would source from `L_UNIQUE_CARRIERS.csv` and refresh quarterly.
- The runbook covers the common failure modes; production runbooks need
  pager rotation, escalation, and post-incident templates.

## Why these are limitations, not bugs

A portfolio project that boiled the ocean would never ship. The choices
above keep the scope under "two evenings to clone, run, and explore" while
still demonstrating the production-shaped decisions the project would make at
scale.
