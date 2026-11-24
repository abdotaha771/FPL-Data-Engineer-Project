# Apache Airflow Setup

This folder runs the complete FPL pipeline in Airflow:

1. Download and merge changed Premier League CSV files.
2. Upload the four season files to a Databricks Volume.
3. Run dbt to build Bronze, Silver, and Gold models and tests.

## DAG overview

![Airflow DAG](../../../docs/airflow%20dag.png)

## Prerequisites

- Docker Desktop
- A Databricks workspace and SQL warehouse
- A Databricks token with access to the target catalog and Volume

## Create the environment file

The `.env` file belongs in this directory:

```text
src/fpl_data_engineer_project/airflow/.env
```

Create it from the example:

```powershell
Copy-Item .env.example .env
```

Fill in the Databricks host, token, warehouse HTTP path, Volume path, Airflow
password, and secrets in `.env`. Never commit this file or put credentials in
the DAG.

Generate a Fernet key if needed:

```powershell
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

## Start Airflow

```powershell
cd src/fpl_data_engineer_project/airflow
docker compose build
docker compose up -d
```

Open `http://localhost:8080` and use the Airflow username and password from
`.env`.

The `fpl_complete_pipeline` DAG runs at 12:00 AM Egypt time (22:00 UTC) each day. It does not
backfill missed dates.

## Run a full refresh

Open the DAG, select **Trigger DAG w/ config**, and use:

```json
{"full_refresh": true}
```

A normal run uses incremental loading. A full refresh downloads all source
files and rebuilds dbt data from the start.

## Stop Airflow

```powershell
docker compose down
```

To remove Airflow's PostgreSQL data too:

```powershell
docker compose down -v
```
