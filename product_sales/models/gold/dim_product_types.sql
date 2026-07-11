select distinct
    md5(coalesce(product_type, 'unknown')) as product_type_id,
    coalesce(product_type, 'unknown') as product_type,
    avg_price_in_product_type
from {{ ref('silver_products') }}