{{ config(materialized='table', file_format='delta') }}

with match_dates as (
    select distinct date(kickoff_time) as calendar_date
    from {{ ref('silver_matches') }}
    where kickoff_time is not null
),
date_bounds as (
    select
        min(calendar_date) as min_date,
        max(calendar_date) as max_date
    from match_dates
),
calendar as (
    select explode(sequence(
        (select min_date from date_bounds),
        (select max_date from date_bounds),
        interval 1 day
    )) as calendar_date
)

select
    cast(replace(cast(calendar_date as string), '-', '') as int) as date_key,
    calendar_date,
    year(calendar_date) as year,
    quarter(calendar_date) as quarter,
    month(calendar_date) as month,
    date_format(calendar_date, 'MMMM') as month_name,
    weekofyear(calendar_date) as week_of_year,
    dayofmonth(calendar_date) as day_of_month,
    dayofweek(calendar_date) as day_of_week,
    date_format(calendar_date, 'EEEE') as day_name,
    case
        when dayofweek(calendar_date) in (1, 7) then true
        else false
    end as is_weekend
from calendar
