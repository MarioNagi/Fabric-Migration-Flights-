# pbi/

Two Power BI files, identical visuals, two backends.

| File                       | Backend                                | Use during              |
| -------------------------- | -------------------------------------- | ----------------------- |
| `flights_onprem.pbix`      | Live Connection → SSAS Tabular         | Pre-cutover + month 1   |
| `flights_fabric.pbix`      | Direct Lake → Fabric semantic model    | Month 2 onwards         |

Same measures (defined in `docs/measures.dax`), same slicers, same chart
types. Only the connection string differs.

## Pages

1. **Executive summary** — total flights, cancelled %, on-time KPI, YoY
2. **Geographic** — airport map, delays by state, top routes
3. **Carrier comparison** — performance leaderboard
4. **Time analysis** — heatmap of delays by hour × weekday
5. **Pipeline health** — `dq.vw_pipeline_reconciliation` + `etl.run_log`

## Theme

Custom theme JSON at `pbi/theme.json` — keeps visuals consistent across both
files.

## Note on the .pbix files

`.pbix` files are binary and not committed in source form. The narrative
artefacts in this repo are the screenshots in `pbi/screenshots/` and the
shared DAX in `docs/measures.dax`.
