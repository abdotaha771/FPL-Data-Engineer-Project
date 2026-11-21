{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['player_id', 'match_id'],
    file_format='delta'
) }}

{{ read_raw_csv('playermatchstats.csv', reference_columns('playermatchstats')) }}
