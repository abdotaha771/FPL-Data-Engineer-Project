
from datetime import datetime, timedelta, timezone
import os
import subprocess

from airflow.sdk import dag, get_current_context, task


@dag(
    dag_id="fpl_complete_pipeline",
    description="Sync FPL CSV files, upload them to Databricks, and build dbt models.",
    schedule="0 22 * * *",
    start_date=datetime(2026, 1, 1, tzinfo=timezone.utc),
    catchup=False,
    is_paused_upon_creation=False,
    tags=["fpl", "databricks", "dbt"],
    default_args={
        "owner": "fpl-data-engineer",
        "retries": 2,
        "retry_delay": timedelta(minutes=5),
        "retry_exponential_backoff": True,
    },
    params={"full_refresh": False},
)
def fpl_complete_pipeline():
    def python_environment():
        environment = os.environ.copy()
        environment["PYTHONPATH"] = "/opt/project/src"
        return environment

    @task(retries=2, execution_timeout=timedelta(minutes=30))
    def sync_season() -> str:
        full_refresh = bool(get_current_context()["params"]["full_refresh"])
        command = [
            "/usr/python/bin/python",
            "-m",
            "fpl_data_engineer_project.data_ingestion.premier_league_incremental_loader",
        ]
        if full_refresh:
            command.append("--full-refresh")
        subprocess.run(
            command,
            cwd="/opt/project",
            env=python_environment(),
            check=True,
        )
        return "season synced"

    @task(retries=2, execution_timeout=timedelta(minutes=30))
    def upload_season(previous_result: str) -> str:
        subprocess.run(
            [
                "/usr/python/bin/python",
                "-m",
                "fpl_data_engineer_project.data_ingestion.upload_season_to_databricks",
            ],
            cwd="/opt/project",
            env=python_environment(),
            check=True,
        )
        return "season uploaded"

    @task(retries=2, execution_timeout=timedelta(hours=2))
    def dbt_build(previous_result: str) -> str:
        full_refresh = bool(get_current_context()["params"]["full_refresh"])
        command = [
            "dbt",
            "build",
            "--project-dir",
            "/opt/project/src/fpl_data_engineer_project/fpl_dbt",
            "--profiles-dir",
            "/opt/airflow/dbt-profiles",
        ]
        if full_refresh:
            command.append("--full-refresh")
        subprocess.run(
            command,
            cwd="/opt/project",
            env=python_environment(),
            check=True,
        )
        return "dbt build completed"

    synced = sync_season()
    uploaded = upload_season(synced)
    dbt_build(uploaded)


fpl_complete_pipeline()
