/* Test that the unique key constraint is working correctly for the silver_teams table */

select
    team_id,
    season_id
from {{ ref('silver_teams') }}
group by team_id, season_id
having count(*) > 1