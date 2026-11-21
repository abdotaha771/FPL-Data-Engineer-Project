{% macro read_raw_csv(file_name, columns) %}
{% set bronze_seasons = ['2026-2027'] if is_incremental() else ['2024-2025', '2025-2026', '2026-2027'] %}
{% for season_id in bronze_seasons %}
{% set source_name = 'raw_' ~ season_id.replace('-', '_') %}
{% set source_table = file_name.replace('.csv', '') %}
-- dbt source: {{ source(source_name, source_table) }}
select
{% for column in columns %}
    {{ column }},
{% endfor %}
    '{{ season_id }}' as season_id,
    current_timestamp() as data_upload,
    _metadata.file_path as source
from read_files(
    '{{ var("raw_volume_root", "/Volumes/fpl_db/raw") }}/{{ season_id }}',
    format => 'csv',
    header => true,
    fileNamePattern => '{{ file_name }}',
    schema => '{{ columns | join(" STRING, ") }} STRING'
)
{% if not loop.last %}

union all
{% endif %}
{% endfor %}
{% endmacro %}
