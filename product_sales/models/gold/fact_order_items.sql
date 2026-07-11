select
    item_id,
    order_id,
    customer_id,
    product_sku,
    cast(to_char(cast(ordered_at as date), 'YYYYMMDD') as integer) as order_date_id,
    ordered_at,
    item_number_in_order,
    items_in_order,
    1 as quantity,
    item_price,
    item_price as item_revenue
from {{ ref('silver_items') }}