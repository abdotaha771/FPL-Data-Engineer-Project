{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['match_id'],
    file_format='delta'
) }}

{{ read_raw_csv('matches.csv', reference_columns('matches')) }}
