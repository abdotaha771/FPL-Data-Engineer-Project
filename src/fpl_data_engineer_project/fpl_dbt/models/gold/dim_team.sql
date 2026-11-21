{{ config(materialized='table', file_format='delta') }}

select
    teams.season_key * 10000 + teams.team_id as team_key,
    teams.team_id,
    teams.team_name,
    teams.team_short_name,
    teams.season_key
from {{ ref('silver_teams') }} as teams

