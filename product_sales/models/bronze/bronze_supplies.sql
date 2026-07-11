{{ config(unique_key=['supply_id', 'product_sku']) }}

select
    cast(id as varchar) as supply_id,
    cast(name as varchar) as supply_name,
    cast(cost as numeric) as cost,
    cast(perishable as boolean) as is_perishable,
    cast(sku as varchar) as product_sku,
    current_timestamp as bronze_loaded_at
from {{ ref('raw_supplies') }}

{% if is_incremental() %}
where updated_at > (
    select coalesce(max(updated_at), '1900-01-01')
    from {{ this }}
)
{% endif %}