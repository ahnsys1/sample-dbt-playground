select
    order_id,
    customer_id,
    store_id,
    cast(to_char(order_date, 'YYYYMMDD') as integer) as order_date_id,
    ordered_at,
    customer_order_number,
    customer_running_purchase_amount,
    previous_order_at,
    subtotal,
    tax_paid,
    order_total
from {{ ref('silver_orders') }}