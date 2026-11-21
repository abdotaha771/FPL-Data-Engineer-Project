# FPL data engineer project

This project incrementally loads the four Premier League CSV datasets for the
2026-2027 season from the
[FPL Core Insights source](https://github.com/olbauday/FPL-Core-Insights/tree/main/data/2026-2027/By%20Tournament/Premier%20League):

- `matches.csv`
- `playermatchstats.csv`
- `players.csv`
- `teams.csv`

The loader implementation and detailed flow are documented in
[`src/fpl_data_engineer_project/data_ingestion/README.md`](src/fpl_data_engineer_project/data_ingestion/README.md).

Run the incremental pipeline from the repository root:

```powershell
uv run fpl-data-engineer-project
```

The pipeline checks the upstream GitHub SHA for every available gameweek,
downloads only new or changed files, and rewrites the four merged files in
`data/2026-2027`. Weekly source files and the manifest are cached in
`data/.cache/2026-2027`; this keeps the season directory limited to the four
output CSV files. Use `--full-refresh` to download all weekly files again.

In dbt, the Bronze tables are incremental: first builds and
`dbt run --full-refresh` load all three historical seasons, while normal runs
merge only `2026-2027` into the existing Bronze tables.