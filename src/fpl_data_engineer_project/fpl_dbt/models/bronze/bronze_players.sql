{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['player_id', 'season_id'],
    file_format='delta'
) }}

{{ read_raw_csv('players.csv', reference_columns('players')) }}
