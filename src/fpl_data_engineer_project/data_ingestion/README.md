# Data Ingestion

## Premier League incremental loader

The [`premier_league_incremental_loader.py`](./premier_league_incremental_loader.py)
pipeline loads the 2026-2027 Premier League data from the
[FPL Core Insights repository](https://github.com/olbauday/FPL-Core-Insights/tree/main/data/2026-2027/By%20Tournament/Premier%20League).

### Flow

1. Read the available gameweeks from GitHub.
2. Compare each selected CSV file SHA with the local manifest.
3. Download only new or changed files into `data/.cache/2026-2027/`.
4. Merge all cached gameweeks and remove duplicate records using the dataset keys.
5. Write the four season-level CSV files to `data/2026-2027/`.

The pipeline is incremental by default:

```powershell
uv run fpl-data-engineer-project
```

To download every source file again:

```powershell
uv run fpl-data-engineer-project --full-refresh
```

The cache is an implementation detail and is excluded from Git. The final
season directory contains only:

- `matches.csv`
- `playermatchstats.csv`
- `players.csv`
- `teams.csv`

## Databricks Volume uploader

The [`upload_season_to_databricks.py`](./upload_season_to_databricks.py)
uploader sends the four merged files to:

```text
/Volumes/fbl_db/raw/2026-2027
```

The path format is:

```text
/Volumes/<catalog>/<schema>/<volume>/<optional-folder>
```

For the configured path above:

- `fbl_db` is the catalog.
- `raw` is the schema.
- `2026-2027` is the Volume name.

The `2026-2027` Volume must already exist in Databricks before running the
uploader.

Create a `.env` file next to the uploader or in the repository root using
[`.env.example`](../../../.env.example). The uploader loads
`DATABRICKS_HOST`, `DATABRICKS_TOKEN`, and `DATABRICKS_VOLUME_PATH`
automatically. Never commit the token to the repository:

```powershell
uv run fpl-upload-season-to-databricks
```

Existing files are overwritten. To use another destination or local source:

```powershell
uv run fpl-upload-season-to-databricks `
  --volume-path "/Volumes/fbl_db/raw/2026-2027" `
  --source-dir "data/2026-2027"
```

If Databricks reports that a Volume does not exist, verify the third path
component after `/Volumes/<catalog>/<schema>/` is the actual Volume name.
