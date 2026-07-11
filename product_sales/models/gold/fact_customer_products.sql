select 
    customer_id,
    product_sku,
    total_orders_for_product,
    total_purchase_amount_for_product,
    avg_order_amount_for_product
from {{ ref('silver_customers_products') }}
