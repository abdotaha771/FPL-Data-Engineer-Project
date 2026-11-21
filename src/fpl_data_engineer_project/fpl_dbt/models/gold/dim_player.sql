{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['player_id', 'season_key'],
    file_format='delta'
) }}

select
    players.season_key * 100000 + players.player_id as player_key,
    players.player_id,
    players.first_name,
    players.last_name,
    concat(coalesce(players.first_name, ''), ' ', coalesce(players.last_name, '')) as full_name,
    players.web_name,
    players.position,
    teams.team_key,
    players.season_key
from {{ ref('silver_players') }} as players
inner join {{ ref('dim_team') }} as teams
    on players.team_id = teams.team_id
   and players.season_key = teams.season_key
{% if is_incremental() %}
where players.season_id = '2026-2027'
{% endif %}
