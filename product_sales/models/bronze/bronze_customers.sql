{{ config(unique_key='customer_id') }}

select
    cast(id as varchar) as customer_id,
    cast(name as varchar) as customer_name,
    current_timestamp as bronze_loaded_at
from {{ ref('raw_customers') }}