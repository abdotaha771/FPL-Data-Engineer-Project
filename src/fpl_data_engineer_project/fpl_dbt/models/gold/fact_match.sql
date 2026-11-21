{{ config(
    materialized='incremental',
    incremental_strategy='merge',
    unique_key=['match_id'],
    file_format='delta'
) }}

select
    matches.match_id,
    matches.season_key,
    cast(replace(cast(date(matches.kickoff_time) as string), '-', '') as int) as date_key,
    matches.kickoff_time,
    matches.gameweek,
    matches.finished,
    home_team.team_key as home_team_key,
    away_team.team_key as away_team_key,
    matches.home_score,
    matches.away_score,
    case
        when coalesce(matches.finished, false) = false then null
        else matches.home_score - matches.away_score
    end as goal_difference,
    coalesce(matches.home_score, 0) + coalesce(matches.away_score, 0) as total_goals,
    case
        when coalesce(matches.finished, false) = false then 'NOT_FINISHED'
        when matches.home_score > matches.away_score then 'HOME_WIN'
        when matches.home_score < matches.away_score then 'AWAY_WIN'
        else 'DRAW'
    end as match_result,
    matches.home_possession,
    matches.away_possession,
    matches.home_expected_goals_xg,
    matches.away_expected_goals_xg,
    matches.home_total_shots,
    matches.away_total_shots,
    matches.home_shots_on_target,
    matches.away_shots_on_target,
    matches.home_accurate_passes_pct,
    matches.away_accurate_passes_pct,
    matches.home_fouls_committed,
    matches.away_fouls_committed,
    matches.home_corners,
    matches.away_corners,
    matches.home_blocked_shots,
    matches.away_blocked_shots,
    matches.home_hit_woodwork,
    matches.away_hit_woodwork,
    matches.home_shots_inside_box,
    matches.away_shots_inside_box,
    matches.home_shots_outside_box,
    matches.away_shots_outside_box,
    matches.home_passes,
    matches.away_passes,
    matches.home_own_half_passes,
    matches.away_own_half_passes,
    matches.home_opposition_half_passes,
    matches.away_opposition_half_passes,
    matches.home_accurate_long_balls_pct,
    matches.away_accurate_long_balls_pct,
    matches.home_accurate_crosses_pct,
    matches.away_accurate_crosses_pct,
    matches.home_touches_in_opposition_box,
    matches.away_touches_in_opposition_box,
    matches.home_offsides,
    matches.away_offsides,
    matches.home_yellow_cards,
    matches.away_yellow_cards,
    matches.home_red_cards,
    matches.away_red_cards,
    matches.home_interceptions,
    matches.away_interceptions,
    matches.home_blocks,
    matches.away_blocks,
    matches.home_keeper_saves,
    matches.away_keeper_saves,
    matches.home_ground_duels_won_pct,
    matches.away_ground_duels_won_pct,
    matches.home_aerial_duels_won_pct,
    matches.away_aerial_duels_won_pct,
    matches.home_successful_dribbles,
    matches.away_successful_dribbles,
    matches.home_successful_dribbles_pct,
    matches.away_successful_dribbles_pct
from {{ ref('silver_matches') }} as matches
inner join {{ ref('dim_team') }} as home_team
    on matches.home_team_id = home_team.team_id
   and matches.season_key = home_team.season_key
inner join {{ ref('dim_team') }} as away_team
    on matches.away_team_id = away_team.team_id
   and matches.season_key = away_team.season_key

{% if is_incremental() %}
where matches.season_id = '2026-2027'
{% endif %}
