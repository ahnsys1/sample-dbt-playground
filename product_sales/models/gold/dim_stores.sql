select
    store_id,
    store_name,
    cast(opened_at as date) as opened_date,
    cast(to_char(cast(opened_at as date), 'YYYYMMDD') as integer) as opened_date_id,
    tax_rate,
    total_orders,
    total_sales_amount,
    avg_order_amount,
    first_order_at,
    last_order_at,
    store_sales_rank
from {{ ref('silver_stores') }}