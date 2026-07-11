select
    product_sku,
    product_name,
    md5(coalesce(product_type, 'unknown')) as product_type_id,
    price,
    product_description,
    total_items_sold,
    total_item_revenue,
    supply_count,
    total_supply_cost,
    revenue_rank_in_product_type
from {{ ref('silver_products') }}