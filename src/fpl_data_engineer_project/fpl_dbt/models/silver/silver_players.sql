{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['player_id', 'season_id'],
    file_format='delta'
)}}

with silver_players as (
    select
        try_cast(try_cast(player_id as float) as int) as player_id,
        cast(trim(first_name) as string) as first_name,
        cast(trim(second_name) as string) as last_name,
        cast(trim(web_name) as string) as web_name,
        try_cast(try_cast(team_code as float) as int) as team_id,
        cast(trim(position) as string) as position,
        cast(trim(season_id) as string) as season_id,
        try_cast(split_part(season_id, '-', 1) as int) as season_key,
        current_timestamp() as data_upload,
        'bronze_players' as source
    from {{ ref('bronze_players') }}
    {% if is_incremental() %}
    where season_id = '2026-2027'
    {% endif %}
)

select
    player_id,
    first_name,
    last_name,
    web_name,
    team_id,
    position,
    season_id,
    season_key,
    data_upload,
    source
from silver_players