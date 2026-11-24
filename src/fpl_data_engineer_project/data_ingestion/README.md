# Data Ingestion

This directory contains the two Python jobs responsible for moving
`2026-2027` Premier League data into Databricks:

1. [Premier League incremental loader](./premier_league_incremental_loader.py)
   downloads and merges upstream CSV files.
2. [Databricks Volume uploader](./upload_season_to_databricks.py)
   uploads the merged files to a Unity Catalog Volume.

## 1. Premier League incremental loader

The loader reads the
[FPL Core Insights repository](https://github.com/olbauday/FPL-Core-Insights/tree/main/data/2026-2027/By%20Tournament/Premier%20League),
discovers every available Premier League gameweek, and produces four files:

- `matches.csv`
- `playermatchstats.csv`
- `players.csv`
- `teams.csv`

The command must be run from the repository root because the loader uses
repository-relative paths such as `data/2026-2027`.

```powershell
# From F:\FPL-Data-Engineer-project
uv sync
uv run fpl-data-engineer-project
```

The installed command is registered in `pyproject.toml` and points to:

```text
fpl_data_engineer_project.data_ingestion.premier_league_incremental_loader:main
```

You can also run the Python module directly:

```powershell
uv run python -m fpl_data_engineer_project.data_ingestion.premier_league_incremental_loader
```

Both commands implement the same loader. The project script is the shorter
recommended interface.

### What happens during a normal run

1. The GitHub repository tree is queried.
2. Available gameweek folders are identified.
3. The Git SHA of every required CSV is compared with
   `data/.cache/2026-2027/premier-league/manifest.json`.
4. New or changed files are downloaded into
   `data/.cache/2026-2027/premier-league/GWXX/`.
5. The cached gameweeks are merged into one season-level file per dataset.
6. Duplicate records are removed using the source natural keys.
7. Four merged files are written to `data/2026-2027/`.

The cache is excluded from Git. A normal run downloads only changed files.

### Merge keys

| Source file | Grain | Deduplication key |
|---|---|---|
| `matches.csv` | One match | `match_id` |
| `playermatchstats.csv` | One player in one match | `player_id`, `match_id` |
| `players.csv` | One player | `player_id` |
| `teams.csv` | One team | `id` |

When multiple cached gameweeks contain the same key, the value read later
wins. This allows corrected upstream rows to replace stale rows.

### Full refresh

Use `--full-refresh` when the cache or manifest should be ignored and every
weekly file should be downloaded again:

```powershell
uv run fpl-data-engineer-project --full-refresh
```

The full-refresh option does not delete the cache. It changes the loader
behavior so no existing SHA comparison is used.

### Successful output

A successful run prints a summary similar to:

```text
Merged 38 gameweeks into 4 files; downloaded 37 changed files.
```

The exact gameweek and download counts change as the upstream season evolves.

### Troubleshooting the loader

**`Failed to spawn: fpl-data-engineer-project`**

Run `uv sync` from the repository root, then retry. This error means the
project's executable entry point has not been installed in the uv environment.

**`No gameweek directories were found upstream`**

This usually means that GitHub could not be reached or that its repository
tree layout changed. The loader validates the upstream response and will not
produce partial merged output.

**A gameweek is missing a required CSV**

The loader stops if one gameweek does not contain all four required files.
This prevents a complete season file from being generated from incomplete
source data.

**The wrong working directory is used**

The loader uses relative paths. If it reports missing files or writes files
under an unexpected location, change to the repository root first:

```powershell
cd F:\FPL-Data-Engineer-project
```

## 2. Databricks Volume uploader

The uploader validates and uploads the four merged `2026-2027` files to a
Unity Catalog Volume.

```text
/Volumes/fpl_db/raw/2026-2027
```

The default path represents:

| Part | Value |
|---|---|
| Catalog | `fpl_db` |
| Schema | `raw` |
| Volume | `2026-2027` |

The `2026-2027` Volume must already exist. Existing files are overwritten
with `overwrite=True`.

### Configure credentials

Copy [`.env.example`](../../../.env.example) to `.env` in the repository root:

```powershell
Copy-Item .env.example .env
```

Set the local values:

```text
DATABRICKS_HOST=https://<workspace-url>
DATABRICKS_TOKEN=<personal-access-token>
DATABRICKS_VOLUME_PATH=/Volumes/fpl_db/raw/2026-2027
```

Never commit `.env` or Databricks credentials.

The uploader loads environment variables from a `.env` next to the Python
module and from the repository root.

### Run the uploader

```powershell
uv sync
uv run fpl-upload-season-to-databricks
```

You can also run the module directly:

```powershell
uv run python -m fpl_data_engineer_project.data_ingestion.upload_season_to_databricks
```

The command uploads exactly these files:

```text
matches.csv
playermatchstats.csv
players.csv
teams.csv
```

### Override the destination

Use another Volume or local source directory:

```powershell
uv run fpl-upload-season-to-databricks `
  --volume-path "/Volumes/fpl_db/raw/2026-2027" `
  --source-dir "data/2026-2027"
```

### Troubleshooting the uploader

**`DATABRICKS_HOST is not configured`**

Create the `.env` file or set `DATABRICKS_HOST` in the current environment.

**`DATABRICKS_TOKEN is not configured`**

Create a valid Databricks token and add it to `DATABRICKS_TOKEN`.

**`volume_path must be a Unity Catalog path starting with /Volumes/`**

The destination must begin with `/Volumes/`. Relative or plain folder paths
are rejected.

**The Volume does not exist**

Verify this structure:

```text
/Volumes/<catalog>/<schema>/<volume>/<optional-folder>
```

The third path component after `/Volumes/` must be an existing Unity Catalog
Volume name.

**A source CSV is missing**

Run the incremental loader first, or pass a valid `--source-dir` containing
all four required CSV files.
