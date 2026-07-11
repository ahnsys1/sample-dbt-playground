with customer_orders_table as (

    select
        customer_id,
        count(order_id) as total_orders,
        sum(order_total) as total_purchase_amount,
        avg(order_total) as avg_order_amount,
        min(ordered_at) as first_order_at,
        max(ordered_at) as last_order_at
    from {{ ref('bronze_orders') }}
    group by customer_id

),

customers as (

    select
        c.customer_id,
        c.customer_name,
        coalesce(o.total_orders, 0) as total_orders,
        coalesce(o.total_purchase_amount, 0) as total_purchase_amount,
        coalesce(o.avg_order_amount, 0) as avg_order_amount,
        o.first_order_at,
        o.last_order_at
    from {{ ref('bronze_customers') }} as c
    left join customer_orders_table as o
        on c.customer_id = o.customer_id

)

select
    customer_id,
    customer_name,
    total_orders,
    total_purchase_amount,
    avg_order_amount,
    first_order_at,
    last_order_at,
    dense_rank() over (order by total_purchase_amount desc) as customer_value_rank,
    case
        when total_purchase_amount >= 5000 then 'high_value'
        when total_purchase_amount > 0 then 'active'
        else 'no_orders'
    end as customer_segment
from customers