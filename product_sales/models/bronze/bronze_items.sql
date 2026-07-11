{{ config(unique_key='item_id') }}

select
    cast(id as varchar) as item_id,
    cast(order_id as varchar) as order_id,
    cast(sku as varchar) as product_sku,
    current_timestamp as bronze_loaded_at
from {{ ref('raw_items') }}