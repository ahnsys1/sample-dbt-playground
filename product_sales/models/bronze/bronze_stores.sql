{{ config(unique_key='store_id') }}

select
    cast(id as varchar) as store_id,
    cast(name as varchar) as store_name,
    cast(opened_at as timestamp) as opened_at,
    cast(tax_rate as numeric) as tax_rate,
    current_timestamp as bronze_loaded_at
from {{ ref('raw_stores') }}