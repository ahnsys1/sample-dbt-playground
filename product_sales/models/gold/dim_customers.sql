select
    customer_id,
    customer_name,
    total_orders,
    total_purchase_amount,
    avg_order_amount,
    first_order_at,
    last_order_at,
    customer_value_rank,
    customer_segment
from {{ ref('silver_customers') }}