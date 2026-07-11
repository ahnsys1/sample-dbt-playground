select
    o.order_id,
    o.customer_id,
    c.customer_name,
    o.store_id,
    s.store_name,
    o.ordered_at,
    cast(o.ordered_at as date) as order_date,
    o.subtotal,
    o.tax_paid,
    o.order_total,
    row_number() over (
        partition by o.customer_id
        order by o.ordered_at, o.order_id
    ) as customer_order_number,
    sum(o.order_total) over (
        partition by o.customer_id
        order by o.ordered_at, o.order_id
        rows between unbounded preceding and current row
    ) as customer_running_purchase_amount,
    lag(o.ordered_at) over (
        partition by o.customer_id
        order by o.ordered_at, o.order_id
    ) as previous_order_at
from {{ ref('bronze_orders') }} as o
left join {{ ref('bronze_customers') }} as c
    on o.customer_id = c.customer_id
left join {{ ref('bronze_stores') }} as s
    on o.store_id = s.store_id