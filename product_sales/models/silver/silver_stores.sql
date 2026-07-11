with store_orders as (

    select
        store_id,
        count(order_id) as total_orders,
        sum(order_total) as total_sales_amount,
        avg(order_total) as avg_order_amount,
        min(ordered_at) as first_order_at,
        max(ordered_at) as last_order_at
    from {{ ref('bronze_orders') }}
    group by store_id

),

stores as (

    select
        s.store_id,
        s.store_name,
        s.opened_at,
        s.tax_rate,
        coalesce(o.total_orders, 0) as total_orders,
        coalesce(o.total_sales_amount, 0) as total_sales_amount,
        coalesce(o.avg_order_amount, 0) as avg_order_amount,
        o.first_order_at,
        o.last_order_at
    from {{ ref('bronze_stores') }} as s
    left join store_orders as o
        on s.store_id = o.store_id

)

select
    store_id,
    store_name,
    opened_at,
    tax_rate,
    total_orders,
    total_sales_amount,
    avg_order_amount,
    first_order_at,
    last_order_at,
    dense_rank() over (order by total_sales_amount desc) as store_sales_rank
from stores