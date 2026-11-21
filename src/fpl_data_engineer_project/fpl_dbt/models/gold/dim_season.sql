{{ config(materialized='table', file_format='delta') }}

with seasons as (
    select distinct season_id
    from {{ ref('silver_matches') }}
)

select
    cast(split_part(season_id, '-', 1) as int) as season_key,
    season_id,
    season_id as season_name
from seasons
