/* dbt test to check for duplicate rows in the silver_playermatchstats table
 based on the composite key of player_id and match_id */

select
    player_id,
    match_id
from {{ ref('silver_playermatchstats') }}
group by
    match_id,
    player_id
having count(*) > 1
