{{ config(unique_key='order_id') }}

select
    cast(id as varchar) as order_id,
    cast(customer as varchar) as customer_id,
    cast(ordered_at as timestamp) as ordered_at,
    cast(store_id as varchar) as store_id,
    cast(subtotal as numeric) as subtotal,
    cast(tax_paid as numeric) as tax_paid,
    cast(order_total as numeric) as order_total,
    current_timestamp as bronze_loaded_at
from {{ ref('raw_orders') }}