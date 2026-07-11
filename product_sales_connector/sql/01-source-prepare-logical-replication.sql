-- Run on the source PostgreSQL instance on localhost:5431 as a superuser.
-- wal_level changes require a PostgreSQL restart before Debezium can start streaming.
ALTER SYSTEM SET wal_level = logical;
ALTER SYSTEM SET max_replication_slots = 10;
ALTER SYSTEM SET max_wal_senders = 10;
ALTER ROLE postgres WITH REPLICATION;

CREATE SCHEMA IF NOT EXISTS product_sales_bronze;

DO $$
BEGIN
    IF to_regclass('product_sales_bronze.bronze_customers') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bronze_customers_pk') THEN
        ALTER TABLE product_sales_bronze.bronze_customers ADD CONSTRAINT bronze_customers_pk PRIMARY KEY (customer_id);
    END IF;
END $$;

DO $$
BEGIN
    IF to_regclass('product_sales_bronze.bronze_items') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bronze_items_pk') THEN
        ALTER TABLE product_sales_bronze.bronze_items ADD CONSTRAINT bronze_items_pk PRIMARY KEY (item_id);
    END IF;
END $$;

DO $$
BEGIN
    IF to_regclass('product_sales_bronze.bronze_orders') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bronze_orders_pk') THEN
        ALTER TABLE product_sales_bronze.bronze_orders ADD CONSTRAINT bronze_orders_pk PRIMARY KEY (order_id);
    END IF;
END $$;

DO $$
BEGIN
    IF to_regclass('product_sales_bronze.bronze_products') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bronze_products_pk') THEN
        ALTER TABLE product_sales_bronze.bronze_products ADD CONSTRAINT bronze_products_pk PRIMARY KEY (product_sku);
    END IF;
END $$;

DO $$
BEGIN
    IF to_regclass('product_sales_bronze.bronze_stores') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bronze_stores_pk') THEN
        ALTER TABLE product_sales_bronze.bronze_stores ADD CONSTRAINT bronze_stores_pk PRIMARY KEY (store_id);
    END IF;
END $$;

DO $$
BEGIN
    IF to_regclass('product_sales_bronze.bronze_supplies') IS NOT NULL
       AND NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'bronze_supplies_pk') THEN
        ALTER TABLE product_sales_bronze.bronze_supplies ADD CONSTRAINT bronze_supplies_pk PRIMARY KEY (supply_id, product_sku);
    END IF;
END $$;

SELECT pg_reload_conf();