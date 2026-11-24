FROM apache/airflow:3.4.0-python3.12

USER root
RUN apt-get update \
    && apt-get install -y --no-install-recommends git \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt/project
COPY --chown=airflow:0 pyproject.toml uv.lock README.md /opt/project/
COPY --chown=airflow:0 src /opt/project/src

RUN python -m pip install --no-cache-dir "uv>=0.8,<1" \
    && uv pip install --system --no-cache -e /opt/project

USER airflow
