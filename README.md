# FPL Data Engineering Platform

An end-to-end data engineering project that collects Premier League match
data, loads it into Databricks, transforms it with dbt, and prepares it for
analytics through a tested Gold galaxy schema of related star schemas.

## Overview

The platform processes three Premier League seasons:

- `2024-2025`
- `2025-2026`
- `2026-2027`

It includes incremental ingestion, Databricks Unity Catalog Volume storage,
dbt Bronze/Silver/Gold layers, Apache Airflow orchestration, and data quality
tests for keys and relationships.

## Data view

The project uses these source files:

| File | Description |
|---|---|
| `matches.csv` | Match details, scores, fixtures, and team statistics |
| `playermatchstats.csv` | Player performance for each match |
| `players.csv` | Player identity and team information |
| `teams.csv` | Team identity and names |

Source:
[FPL Core Insights](https://github.com/olbauday/FPL-Core-Insights/tree/main/data/2026-2027/By%20Tournament/Premier%20League)

Data moves through the pipeline as follows:

1. The ingestion service discovers available gameweeks from the upstream
   repository.
2. It compares each file's Git SHA with a local manifest.
3. Only new or changed files are downloaded.
4. Weekly files are merged into four season-level CSV files.
5. The files are uploaded to a Databricks Volume.
6. dbt reads the CSV files and builds the analytical layers.
7. Airflow runs the complete workflow on a daily schedule.

## Project structure

```text
.
├── data/
│   ├── 2026-2027/
│   └── previous seasons/
├── docs/
│   ├── airflow dag.png
│   ├── dbt flow.png
│   ├── gold layer.png
│   └── project architecture.gif
├── gold_layer.dbml
├── pyproject.toml
└── src/fpl_data_engineer_project/
    ├── airflow/
    │   ├── dags/
    │   ├── profiles/
    │   ├── Dockerfile
    │   └── docker-compose.yaml
    ├── data_ingestion/
    │   ├── premier_league_incremental_loader.py
    │   └── upload_season_to_databricks.py
    └── fpl_dbt/
        ├── models/
        │   ├── bronze/
        │   ├── silver/
        │   └── gold/
        ├── macros/
        └── tests/
```

## Architecture

![Project workflow](docs/project%20architecture.gif)

The pipeline is orchestrated by Airflow and moves data from FPL Core Insights
through the incremental Python loader and Databricks Volume into dbt:

```text
FPL Core Insights
        |
        v
Incremental Python Loader
        |
        v
Databricks Unity Catalog Volume
        |
        v
dbt Bronze -> Silver -> Gold
        ^
        |
Apache Airflow orchestration
```

## Airflow

![Airflow DAG](docs/airflow%20dag.png)

For Airflow setup and running the scheduled end-to-end pipeline, see the
[Airflow guide](src/fpl_data_engineer_project/airflow/README.md).

## dbt

![dbt flow](docs/dbt%20flow.png)

### Bronze

The Bronze layer reads the raw CSV files with Databricks `read_files()`.
Source values are preserved as strings and enriched with:

- `season_id`
- `data_upload`
- Source file metadata

### Silver

The Silver layer:

- Casts columns to suitable data types
- Standardizes text and timestamps
- Creates season keys
- Defines stable natural keys
- Handles nullable and incomplete match data

### Gold galaxy schema

![Gold layer](docs/gold%20layer.png)

The Gold layer uses a season-aware galaxy schema: each fact table forms a
star-schema view, and shared dimensions connect the stars.

**Dimensions**

- `dim_season`
- `dim_date`
- `dim_team`
- `dim_team_home`
- `dim_team_away`
- `dim_player`
- `dim_gameweek`

| Fact table | Grain | Star-schema dimensions |
|---|---|---|
| `fact_match` | One row per match | `dim_season`, `dim_date`,`dim_gameweek`, `dim_team_home`, `dim_team_away` |
| `fact_team_match` | One row per team per match | `dim_season`, `dim_date`,`dim_gameweek`, `dim_team` (team and opponent roles) |
| `fact_player_match` | One row per player per match | `dim_season`, `dim_date`,`dim_gameweek`, `dim_player`, `dim_team` |



## Other

### Quick start

#### Requirements

- Python 3.12
- [uv](https://docs.astral.sh/uv/)
- Docker Desktop for Airflow
- A Databricks workspace and access to a Unity Catalog Volume

Install the project dependencies from the repository root:

```powershell
uv sync
```

### Technology stack

- **Python 3.12** - ingestion and Databricks upload utilities
- **uv** - Python dependency and environment management
- **Databricks** - cloud storage and SQL processing
- **dbt** - SQL transformations, documentation, and testing
- **Delta tables** - incremental analytical storage
- **Apache Airflow** - workflow orchestration
- **Docker Compose** - local Airflow environment

### Documentation

- [Data ingestion guide](src/fpl_data_engineer_project/data_ingestion/README.md)
- [dbt guide](src/fpl_data_engineer_project/fpl_dbt/README.md)
- [Airflow guide](src/fpl_data_engineer_project/airflow/README.md)
- [Gold galaxy schema](gold_layer.dbml)
