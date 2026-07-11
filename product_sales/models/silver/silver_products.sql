with product_sales as (

    select
        i.product_sku,
        count(i.item_id) as total_items_sold,
        sum(p.price) as total_item_revenue
    from {{ ref('bronze_items') }} as i
    left join {{ ref('bronze_products') }} as p
        on i.product_sku = p.product_sku
    group by i.product_sku

),

product_supplies as (

    select
        product_sku,
        count(supply_id) as supply_count,
        sum(cost) as total_supply_cost
    from {{ ref('bronze_supplies') }}
    group by product_sku

),

products as (

    select
        p.product_sku,
        p.product_name,
        p.product_type,
        p.price,
        p.product_description,
        coalesce(s.total_items_sold, 0) as total_items_sold,
        coalesce(s.total_item_revenue, 0) as total_item_revenue,
        coalesce(sp.supply_count, 0) as supply_count,
        coalesce(sp.total_supply_cost, 0) as total_supply_cost
    from {{ ref('bronze_products') }} as p
    left join product_sales as s
        on p.product_sku = s.product_sku
    left join product_supplies as sp
        on p.product_sku = sp.product_sku

)

select
    product_sku,
    product_name,
    product_type,
    price,
    product_description,
    total_items_sold,
    total_item_revenue,
    supply_count,
    total_supply_cost,
    avg(price) over (partition by product_type) as avg_price_in_product_type,
    dense_rank() over (
        partition by product_type
        order by total_item_revenue desc
    ) as revenue_rank_in_product_type
from products