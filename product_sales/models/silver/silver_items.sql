select
    i.item_id,
    i.order_id,
    o.customer_id,
    c.customer_name,
    o.ordered_at,
    i.product_sku,
    p.product_name,
    p.product_type,
    p.price as item_price,
    row_number() over (
        partition by i.order_id
        order by i.item_id
    ) as item_number_in_order,
    count(*) over (partition by i.order_id) as items_in_order
from {{ ref('bronze_items') }} as i
left join {{ ref('bronze_orders') }} as o
    on i.order_id = o.order_id
left join {{ ref('bronze_customers') }} as c
    on o.customer_id = c.customer_id
left join {{ ref('bronze_products') }} as p
    on i.product_sku = p.product_sku