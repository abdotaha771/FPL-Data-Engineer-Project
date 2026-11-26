
{{ config(materialized='table', file_format='delta') }}

select
    explode(sequence(1, 38)) as gameweek;
