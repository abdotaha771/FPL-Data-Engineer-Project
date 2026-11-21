{{ config(materialized='view') }}

with team_matches as (
    select
        concat(cast(season_key as string), '|', cast(match_id as string), '|', cast(home_team_key as string)) as team_match_key,
        match_id,
        season_key,
        date_key,
        kickoff_time,
        gameweek,
        home_team_key as team_key,
        away_team_key as opponent_team_key,
        'HOME' as venue,
        home_score as team_goals,
        away_score as opponent_goals,
        case
            when coalesce(finished, false) = false then null
            else home_score - away_score
        end as goal_difference,
        home_possession as team_possession,
        away_possession as opponent_possession,
        home_expected_goals_xg as team_expected_goals_xg,
        away_expected_goals_xg as opponent_expected_goals_xg,
        home_total_shots as team_total_shots,
        away_total_shots as opponent_total_shots,
        home_shots_on_target as team_shots_on_target,
        away_shots_on_target as opponent_shots_on_target,
        home_accurate_passes_pct as team_accurate_passes_pct,
        away_accurate_passes_pct as opponent_accurate_passes_pct,
        home_fouls_committed as team_fouls_committed,
        away_fouls_committed as opponent_fouls_committed,
        home_corners as team_corners,
        away_corners as opponent_corners,
        home_blocked_shots as team_blocked_shots,
        away_blocked_shots as opponent_blocked_shots,
        home_hit_woodwork as team_hit_woodwork,
        away_hit_woodwork as opponent_hit_woodwork,
        home_shots_inside_box as team_shots_inside_box,
        away_shots_inside_box as opponent_shots_inside_box,
        home_shots_outside_box as team_shots_outside_box,
        away_shots_outside_box as opponent_shots_outside_box,
        home_passes as team_passes,
        away_passes as opponent_passes,
        home_own_half_passes as team_own_half_passes,
        away_own_half_passes as opponent_own_half_passes,
        home_opposition_half_passes as team_opposition_half_passes,
        away_opposition_half_passes as opponent_opposition_half_passes,
        home_accurate_long_balls_pct as team_accurate_long_balls_pct,
        away_accurate_long_balls_pct as opponent_accurate_long_balls_pct,
        home_accurate_crosses_pct as team_accurate_crosses_pct,
        away_accurate_crosses_pct as opponent_accurate_crosses_pct,
        home_touches_in_opposition_box as team_touches_in_opposition_box,
        away_touches_in_opposition_box as opponent_touches_in_opposition_box,
        home_offsides as team_offsides,
        away_offsides as opponent_offsides,
        home_yellow_cards as team_yellow_cards,
        away_yellow_cards as opponent_yellow_cards,
        home_red_cards as team_red_cards,
        away_red_cards as opponent_red_cards,
        home_interceptions as team_interceptions,
        away_interceptions as opponent_interceptions,
        home_blocks as team_blocks,
        away_blocks as opponent_blocks,
        home_keeper_saves as team_keeper_saves,
        away_keeper_saves as opponent_keeper_saves,
        home_ground_duels_won_pct as team_ground_duels_won_pct,
        away_ground_duels_won_pct as opponent_ground_duels_won_pct,
        home_aerial_duels_won_pct as team_aerial_duels_won_pct,
        away_aerial_duels_won_pct as opponent_aerial_duels_won_pct,
        home_successful_dribbles as team_successful_dribbles,
        away_successful_dribbles as opponent_successful_dribbles,
        home_successful_dribbles_pct as team_successful_dribbles_pct,
        away_successful_dribbles_pct as opponent_successful_dribbles_pct,
        finished,
        case
            when coalesce(finished, false) = false then null
            when home_score > away_score then true
            else false
        end as is_win,
        case
            when coalesce(finished, false) = false then null
            when home_score = away_score then true
            else false
        end as is_draw,
        case
            when coalesce(finished, false) = false then null
            when home_score < away_score then true
            else false
        end as is_loss,
        case
            when coalesce(finished, false) = false then null
            when home_score > away_score then 3
            when home_score = away_score then 1
            else 0
        end as points
    from {{ ref('fact_match') }}

    union all

    select
        concat(cast(season_key as string), '|', cast(match_id as string), '|', cast(away_team_key as string)) as team_match_key,
        match_id,
        season_key,
        date_key,
        kickoff_time,
        gameweek,
        away_team_key as team_key,
        home_team_key as opponent_team_key,
        'AWAY' as venue,
        away_score as team_goals,
        home_score as opponent_goals,
        case
            when coalesce(finished, false) = false then null
            else away_score - home_score
        end as goal_difference,
        away_possession as team_possession,
        home_possession as opponent_possession,
        away_expected_goals_xg as team_expected_goals_xg,
        home_expected_goals_xg as opponent_expected_goals_xg,
        away_total_shots as team_total_shots,
        home_total_shots as opponent_total_shots,
        away_shots_on_target as team_shots_on_target,
        home_shots_on_target as opponent_shots_on_target,
        away_accurate_passes_pct as team_accurate_passes_pct,
        home_accurate_passes_pct as opponent_accurate_passes_pct,
        away_fouls_committed as team_fouls_committed,
        home_fouls_committed as opponent_fouls_committed,
        away_corners as team_corners,
        home_corners as opponent_corners,
        away_blocked_shots as team_blocked_shots,
        home_blocked_shots as opponent_blocked_shots,
        away_hit_woodwork as team_hit_woodwork,
        home_hit_woodwork as opponent_hit_woodwork,
        away_shots_inside_box as team_shots_inside_box,
        home_shots_inside_box as opponent_shots_inside_box,
        away_shots_outside_box as team_shots_outside_box,
        home_shots_outside_box as opponent_shots_outside_box,
        away_passes as team_passes,
        home_passes as opponent_passes,
        away_own_half_passes as team_own_half_passes,
        home_own_half_passes as opponent_own_half_passes,
        away_opposition_half_passes as team_opposition_half_passes,
        home_opposition_half_passes as opponent_opposition_half_passes,
        away_accurate_long_balls_pct as team_accurate_long_balls_pct,
        home_accurate_long_balls_pct as opponent_accurate_long_balls_pct,
        away_accurate_crosses_pct as team_accurate_crosses_pct,
        home_accurate_crosses_pct as opponent_accurate_crosses_pct,
        away_touches_in_opposition_box as team_touches_in_opposition_box,
        home_touches_in_opposition_box as opponent_touches_in_opposition_box,
        away_offsides as team_offsides,
        home_offsides as opponent_offsides,
        away_yellow_cards as team_yellow_cards,
        home_yellow_cards as opponent_yellow_cards,
        away_red_cards as team_red_cards,
        home_red_cards as opponent_red_cards,
        away_interceptions as team_interceptions,
        home_interceptions as opponent_interceptions,
        away_blocks as team_blocks,
        home_blocks as opponent_blocks,
        away_keeper_saves as team_keeper_saves,
        home_keeper_saves as opponent_keeper_saves,
        away_ground_duels_won_pct as team_ground_duels_won_pct,
        home_ground_duels_won_pct as opponent_ground_duels_won_pct,
        away_aerial_duels_won_pct as team_aerial_duels_won_pct,
        home_aerial_duels_won_pct as opponent_aerial_duels_won_pct,
        away_successful_dribbles as team_successful_dribbles,
        home_successful_dribbles as opponent_successful_dribbles,
        away_successful_dribbles_pct as team_successful_dribbles_pct,
        home_successful_dribbles_pct as opponent_successful_dribbles_pct,
        finished,
        case
            when coalesce(finished, false) = false then null
            when away_score > home_score then true
            else false
        end as is_win,
        case
            when coalesce(finished, false) = false then null
            when away_score = home_score then true
            else false
        end as is_draw,
        case
            when coalesce(finished, false) = false then null
            when away_score < home_score then true
            else false
        end as is_loss,
        case
            when coalesce(finished, false) = false then null
            when away_score > home_score then 3
            when away_score = home_score then 1
            else 0
        end as points
    from {{ ref('fact_match') }}
)

select *
from team_matches
