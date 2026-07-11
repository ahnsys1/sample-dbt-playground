{{ config(unique_key='product_sku') }}

select
    cast(sku as varchar) as product_sku,
    cast(name as varchar) as product_name,
    cast(type as varchar) as product_type,
    cast(price as numeric) as price,
    cast(description as varchar) as product_description,
    current_timestamp as bronze_loaded_at
from {{ ref('raw_products') }}