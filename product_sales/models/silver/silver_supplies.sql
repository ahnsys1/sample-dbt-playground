select
    s.supply_id,
    s.supply_name,
    s.cost,
    s.is_perishable,
    s.product_sku,
    p.product_name,
    p.product_type,
    sum(s.cost) over (partition by s.product_sku) as total_supply_cost_for_product,
    count(*) over (partition by s.product_sku) as supply_count_for_product,
    dense_rank() over (
        partition by s.product_sku
        order by s.cost desc, s.supply_id
    ) as supply_cost_rank_for_product
from {{ ref('bronze_supplies') }} as s
left join {{ ref('bronze_products') }} as p
    on s.product_sku = p.product_sku