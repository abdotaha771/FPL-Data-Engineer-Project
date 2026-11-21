{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['id', 'season_id'],
    file_format='delta'
) }}

{{ read_raw_csv('teams.csv', reference_columns('teams')) }}
