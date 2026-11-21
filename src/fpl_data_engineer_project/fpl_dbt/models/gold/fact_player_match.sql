{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['player_match_key'],
    file_format='delta'
) }}

select
    concat(stats.season_id, '|', stats.match_id, '|', cast(stats.player_id as string)) as player_match_key,
    player_dim.player_key,
    stats.match_id,
    stats.season_key,
    cast(replace(cast(date(matches.kickoff_time) as string), '-', '') as int) as date_key,
    player_dim.team_key,
    matches.gameweek,
    matches.kickoff_time,
    stats.minutes_played,
    coalesce(stats.goals, 0) as goals,
    coalesce(stats.assists, 0) as assists,
    coalesce(stats.goals, 0) + coalesce(stats.assists, 0) as goal_involvement,
    stats.total_shots,
    stats.xg,
    stats.xa,
    stats.xgot,
    stats.shots_on_target,
    stats.successful_dribbles,
    stats.big_chances_missed,
    stats.touches_opposition_box,
    stats.chances_created,
    stats.final_third_passes,
    stats.accurate_crosses,
    stats.accurate_long_balls,
    stats.tackles_won,
    stats.touches,
    stats.accurate_passes,
    stats.tackles,
    stats.interceptions,
    stats.recoveries,
    stats.blocks,
    stats.clearances,
    stats.headed_clearances,
    stats.dribbled_past,
    stats.duels_won,
    stats.duels_lost,
    stats.ground_duels_won,
    stats.aerial_duels_won,
    stats.was_fouled,
    stats.fouls_committed,
    stats.saves,
    stats.goals_conceded,
    stats.xgot_faced,
    stats.goals_prevented,
    stats.sweeper_actions,
    stats.gk_accurate_passes,
    stats.gk_accurate_long_balls,
    stats.offsides,
    stats.high_claim,
    stats.accurate_passes_percent,
    stats.accurate_crosses_percent,
    stats.accurate_long_balls_percent,
    stats.ground_duels_won_percent,
    stats.aerial_duels_won_percent,
    stats.successful_dribbles_percent,
    stats.tackles_won_percent,
    stats.start_min,
    stats.finish_min,
    stats.team_goals_conceded,
    stats.penalties_scored,
    stats.penalties_missed
from {{ ref('silver_playermatchstats') }} stats
left join {{ ref('silver_matches') }} matches
  on stats.match_id = matches.match_id
inner join {{ ref('dim_player') }} as player_dim
  on stats.player_id = player_dim.player_id
 and stats.season_key = player_dim.season_key
{% if is_incremental() %}
where stats.season_id = '2026-2027'
{% endif %}
