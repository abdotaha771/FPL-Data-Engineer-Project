{{ config(
    materialized='table',
    file_format='delta'
)}}

with silver_teams as (
    select
        try_cast(try_cast(code as float) as int) as team_id,
        cast(trim(name) as string) as team_name,
        cast(trim(short_name) as string) as team_short_name,
        cast(trim(season_id) as string) as season_id,
        try_cast(split_part(season_id, '-', 1) as int) as season_key,
        current_timestamp() as data_upload,
        'bronze_layers' as source
    from {{ ref('bronze_teams') }}
)

select
    team_id,
    team_name,
    team_short_name,
    season_id,
    season_key,
    data_upload,
    source
from silver_teams