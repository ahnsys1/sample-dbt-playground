with customer_product_orders as (

    select
        c.customer_id,
        c.customer_name,
        p.product_sku,
        p.product_name,
        count(distinct o.order_id) as total_orders_for_product,
        sum(p.price) as total_purchase_amount_for_product,
        avg(p.price) as avg_order_amount_for_product

    from {{ ref('bronze_items') }} as oi
    left join {{ ref('bronze_orders') }} as o
        on oi.order_id = o.order_id
    left join {{ ref('bronze_customers') }} as c
        on o.customer_id = c.customer_id
    left join {{ ref('bronze_products') }} as p
        on oi.product_sku = p.product_sku

    group by
        c.customer_id,
        c.customer_name,
        p.product_sku,
        p.product_name

),

renamed as (

    select
        customer_id,
        customer_name,
        product_sku,
        product_name,
        total_orders_for_product,
        total_purchase_amount_for_product,
        avg_order_amount_for_product
    from customer_product_orders

)

select * from renamed