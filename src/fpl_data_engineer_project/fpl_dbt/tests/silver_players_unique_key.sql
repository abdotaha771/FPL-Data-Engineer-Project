/* Test for unique key on silver_players */
select 
player_id,
season_id
from {{ ref('silver_players') }}
group by player_id, season_id
having count(*) > 1