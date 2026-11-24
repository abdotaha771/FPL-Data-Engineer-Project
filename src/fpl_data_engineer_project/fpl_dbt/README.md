# FPL dbt project

This dbt project transforms Premier League data from CSV files in Databricks
Volumes into a clean, tested Gold galaxy schema composed of related star schemas.

It covers three seasons:

- `2024-2025`
- `2025-2026`
- `2026-2027`

## Design Notes

- [Player Dimension Design Decision](#player-dimension-design-decision)

## Project structure

```text
models/
  bronze/   Raw tables loaded from Databricks CSV Volumes
  silver/   Cast, standardized, and validated tables
  gold/     Dimensions and facts used for analysis

macros/     Databricks CSV readers and reusable SQL logic
tests/      Custom data quality tests
```

## Data architecture

### Bronze

The Bronze models read the four source CSV datasets from Databricks Volumes:

```text
/Volumes/fpl_db/raw/2024-2025/<file>.csv
/Volumes/fpl_db/raw/2025-2026/<file>.csv
/Volumes/fpl_db/raw/2026-2027/<file>.csv
```

The supported datasets are:

- `matches.csv`
- `playermatchstats.csv`
- `players.csv`
- `teams.csv`

Bronze tables are incremental. A first build or `dbt run --full-refresh` loads
all three seasons, while normal dbt runs merge only `2026-2027` into the
existing tables.

The four Volume files are declared for each season in
`models/bronze/sources.yml`: 12 dbt source nodes total, four files across three
seasons. Source paths follow
`/Volumes/fpl_db/raw/<season>/<file>.csv` and are read in Bronze with
Databricks `read_files`.

The `source()` calls in `read_raw_csv.sql` register those Volume files as dbt
lineage dependencies. They are documentation and dependency nodes; the SQL
physically reads the CSV files with `read_files()` because the Volume files are
not Databricks tables.

On a first build or `--full-refresh`, each Bronze table combines the three seasons
using `UNION ALL`. Normal incremental runs read only `2026-2027` and merge changed
rows into the existing Bronze tables, preserving all historical seasons.
The Bronze models add:

- `season_id`: the source season.
- `data_upload`: the timestamp of the dbt run.
- `source`: the source file metadata path.

The Bronze layer preserves the source values as strings and keeps a complete
historical record across all seasons.

### Silver

The Silver models clean and standardize the Bronze data:

- Convert numeric fields to integers or floats.
- Convert timestamps and season keys to consistent types.
- Standardize text values.
- Remove or preserve nullable values according to the source grain.
- Provide the stable IDs used by downstream models.

The main Silver tables are:

| Table | Grain | Incremental key |
|---|---|---|
| `silver_matches` | One match | `match_id` |
| `silver_playermatchstats` | One player in one match | `player_id`, `match_id` |
| `silver_players` | One player in one season | `player_id`, `season_id` |
| `silver_teams` | One team in one season | `team_id`, `season_id` |

### Gold galaxy schema

The Gold layer contains multiple fact tables connected through shared
dimensions. Each fact and its dimensions form a star schema; together, the
related stars form a galaxy schema for reporting and analysis.

Dimensions:

- `dim_season`: season data.
- `dim_date`: calendar data generated from match kickoff dates.
- `dim_team`: team data scoped by season.
- `dim_team_home`: home-team view of `dim_team`.
- `dim_team_away`: away-team view of `dim_team`.
- `dim_player`: player data scoped by season and linked to a team.

### Player Dimension Design Decision


> **Important:** In `dim_player`, `team_key` represents the last club the player officially registered with during the season, rather than every team they played for during the season.

The following are all Premier League players with transfers between two clubs in the 2024-2025 and 2025-2026 seasons. Every other player in the data played for only one team during the season.

#### Deal Type Breakdown (2024-2025 & 2025-2026)

| Season | Player | Move (From -> To) | Deal Type |
|---|---|---|---|
| 2024-2025 | [Marcus Rashford](https://www.google.com/search?kgmid=%2Fg%2F11bwy_0408&q=all+was+trasnfers+or+they+include+loan+marcus+rashford) | Manchester United -> Aston Villa | **Loan** |
| 2024-2025 | [Axel Disasi](https://www.google.com/search?kgmid=%2Fg%2F11cm_pwmy2&q=all+was+trasnfers+or+they+include+loan+axel+disasi) | Chelsea -> Aston Villa | **Loan** |
| 2024-2025 | [Jaden Philogene](https://www.google.com/search?kgmid=%2Fg%2F11fklr7rm1&q=all+was+trasnfers+or+they+include+loan+jaden+philogene) | Aston Villa -> Ipswich Town | **Permanent Transfer** |
| 2025-2026 | [Antoine Semenyo](https://www.google.com/search?kgmid=%2Fg%2F11f6157b5z&q=all+was+trasnfers+or+they+include+loan+antoine+semenyo) | Bournemouth -> Manchester City | **Permanent Transfer** |
| 2025-2026 | [Marc Guéhi](https://www.google.com/search?kgmid=%2Fg%2F11gs72njpv&q=all+was+trasnfers+or+they+include+loan+marc+gu%C3%A9hi) | Crystal Palace -> Manchester City | **Permanent Transfer** |
| 2025-2026 | [Brennan Johnson](https://www.google.com/search?kgmid=%2Fg%2F11fmrqjvkc&q=all+was+trasnfers+or+they+include+loan+brennan+johnson) | Tottenham Hotspur -> Crystal Palace | **Permanent Transfer** |
| 2025-2026 | [Oscar Bobb](https://www.google.com/search?kgmid=%2Fg%2F11h555nqyt&q=all+was+trasnfers+or+they+include+loan+oscar+bobb) | Manchester City -> Fulham | **Permanent Transfer** |
| 2025-2026 | [Adama Traoré](https://www.google.com/search?kgmid=%2Fm%2F0y7vwwf&q=all+was+trasnfers+or+they+include+loan+adama+traor%C3%A9) | Fulham -> West Ham United | **Permanent Transfer** |
| 2025-2026 | [James Ward-Prowse](https://www.google.com/search?kgmid=%2Fm%2F0hgp0nh&q=all+was+trasnfers+or+they+include+loan+james+ward-prowse) | West Ham United -> Burnley | **Loan** |
| 2025-2026 | [Tyrique George](https://www.google.com/search?kgmid=%2Fg%2F11pzvxbdzh&q=all+was+trasnfers+or+they+include+loan+tyrique+george) | Chelsea -> Everton | **Loan** *(made permanent in July 2026)* |



| Fact table | Grain | Star-schema dimensions |
|---|---|---|
| `fact_match` | One row per match | `dim_season`, `dim_date`, `dim_team_home`, `dim_team_away` |
| `fact_team_match` | One home or away team row per match | `dim_season`, `dim_date`, `dim_team` (team and opponent roles) |
| `fact_player_match` | One player performance row per match | `dim_season`, `dim_date`, `dim_player`, `dim_team` |

The galaxy schema and its star-schema relationships are documented in
[`gold_layer.dbml`](../../../gold_layer.dbml).

## Incremental behavior

Several Gold and Silver models are incremental. New and changed rows are merged
for the current season instead of rebuilding all historical data.

Unfinished matches remain visible with `null` result measures. Gold team facts
return `null` for `is_win`, `is_draw`, `is_loss`, `goal_difference`, and
`points` until `finished` is true.

## Prerequisites

- Python 3.12
- `uv`
- A Databricks workspace
- dbt with the Databricks adapter
- Access to the source Unity Catalog Volume

Install project dependencies from the repository root:

```powershell
uv sync
```

Configure the dbt profile before running the project. The dbt profile normally
uses Databricks host, HTTP path, schema, and authentication settings.

## Running the project

Compile all models:

```powershell
uv run dbt compile --project-dir src/fpl_data_engineer_project/fpl_dbt
```

Build the Bronze layer:

```powershell
uv run dbt run --project-dir src/fpl_data_engineer_project/fpl_dbt --select bronze
```

Build the Silver layer:

```powershell
uv run dbt run --project-dir src/fpl_data_engineer_project/fpl_dbt --select silver
```

Build the Gold layer:

```powershell
uv run dbt run --project-dir src/fpl_data_engineer_project/fpl_dbt --select gold
```

Build and test the complete project:

```powershell
uv run dbt build --project-dir src/fpl_data_engineer_project/fpl_dbt
```

Run only the Gold tests:

```powershell
uv run dbt test --project-dir src/fpl_data_engineer_project/fpl_dbt --select gold
```

## Raw Volume override

The default raw Volume root is `/Volumes/fpl_db/raw`. Override it for another
catalog or schema:

```powershell
uv run dbt run --project-dir src/fpl_data_engineer_project/fpl_dbt `
  --select bronze `
  --vars '{"raw_volume_root": "/Volumes/<catalog>/<schema>"}'
```

The season folder names must remain:

```text
2024-2025
2025-2026
2026-2027
```

## Data quality

Tests validate:

- Required values are not null.
- Primary keys are unique.
- Foreign keys exist in the referenced dimension.
- Silver natural keys are consistent across seasons.

Run all tests with:

```powershell
uv run dbt test --project-dir src/fpl_data_engineer_project/fpl_dbt
```

## Generated documentation

Generate and serve dbt documentation locally:

```powershell
uv run dbt docs generate --project-dir src/fpl_data_engineer_project/fpl_dbt
uv run dbt docs serve --project-dir src/fpl_data_engineer_project/fpl_dbt
```
