select
    md5(coalesce(supply_id, '') || '|' || coalesce(product_sku, '')) as supply_key,
    supply_id,
    product_sku,
    supply_name,
    cost,
    is_perishable,
    product_name,
    product_type,
    total_supply_cost_for_product,
    supply_count_for_product,
    supply_cost_rank_for_product
from {{ ref('silver_supplies') }}