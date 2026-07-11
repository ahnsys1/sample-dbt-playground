with

source as (

    select
        oi.item_id,
        oi.order_id,
        c.customer_id,
        c.customer_name,
        o.ordered_at,
        oi.product_sku,
        p.product_name,
        p.price as product_price,
        p.product_description
    from {{ ref('bronze_customers') }} as c
    left join {{ ref('bronze_orders') }} as o using (customer_id)
    left join {{ ref('bronze_items') }} as oi using (order_id)
    left join {{ ref('bronze_products') }} as p using (product_sku)
),

renamed as (

    select

        ----------  ids
        item_id as order_item_id,
        order_id,
        customer_id,
        product_sku,
        customer_name,
        ordered_at,
        product_name,
        product_price,
        product_description

    from source

)

select * from renamed

