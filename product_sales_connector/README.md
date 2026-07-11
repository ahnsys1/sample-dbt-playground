# product_sales_connector

Maven project for streaming `product_sales_bronze` tables from a source PostgreSQL database on `localhost:5431` into a target PostgreSQL database on `localhost:5432` through Kafka Connect.

The pipeline uses:

- Debezium PostgreSQL source connector for the initial snapshot and CDC events.
- Debezium JDBC sink connector for upsert and delete propagation into the target database.
- One Kafka topic per table, named exactly like the table, for example `product_sales_bronze.bronze_orders`.
- A small Java CLI that registers all connector JSON files against the Kafka Connect REST API.

## Tables

| Source table | Kafka topic | Primary key used by sink |
| --- | --- | --- |
| `product_sales_bronze.bronze_customers` | `product_sales_bronze.bronze_customers` | `customer_id` |
| `product_sales_bronze.bronze_items` | `product_sales_bronze.bronze_items` | `item_id` |
| `product_sales_bronze.bronze_orders` | `product_sales_bronze.bronze_orders` | `order_id` |
| `product_sales_bronze.bronze_products` | `product_sales_bronze.bronze_products` | `product_sku` |
| `product_sales_bronze.bronze_stores` | `product_sales_bronze.bronze_stores` | `store_id` |
| `product_sales_bronze.bronze_supplies` | `product_sales_bronze.bronze_supplies` | `supply_id, product_sku` |

## Prerequisites

- Java 17+
- Maven 3.9+
- Docker Compose
- Source PostgreSQL reachable on `localhost:5431`
- Target PostgreSQL reachable on `localhost:5432`
- PostgreSQL user/password currently configured as `postgres` / `password` in `connectors/*.json`

## Prepare PostgreSQL

Run source preparation on port `5431`:

```bash
psql -h localhost -p 5431 -U postgres -d postgres -f sql/01-source-prepare-logical-replication.sql
```

Restart the source PostgreSQL server after changing `wal_level` to `logical`.

Run target preparation on port `5432`:

```bash
psql -h localhost -p 5432 -U postgres -d postgres -f sql/02-target-prepare-schema.sql
```

## Start Kafka and Kafka Connect

```bash
docker compose up -d
```

Kafka Connect REST API is exposed on `http://localhost:8082`.

## Register connectors

```bash
bash scripts/register-connectors.sh
```

The source connector uses `snapshot.mode=initial`, so the first run snapshots the selected tables and then continues with `INSERT`, `UPDATE`, and `DELETE` changes from the replication slot `product_sales_connector`.

## Useful commands

Check connector status:

```bash
curl -s http://localhost:8082/connectors/product-sales-postgres-source/status
curl -s http://localhost:8082/connectors/sink-bronze-orders/status
```

List topics:

```bash
docker compose exec kafka-client /opt/kafka/bin/kafka-topics.sh --bootstrap-server kafka:9093 --list
```

Consume one bronze topic from the beginning:

```bash
docker compose exec kafka-client /opt/kafka/bin/kafka-console-consumer.sh \
	--bootstrap-server kafka:9093 \
	--topic product_sales_bronze.bronze_orders \
	--from-beginning
```

Remove connectors:

```bash
bash scripts/delete-connectors.sh
```

Run project validation:

```bash
mvn test
```

## Notes

`UPDATE` and `DELETE` streaming depends on primary keys. The SQL preparation file adds primary key constraints that match the dbt `unique_key` configuration for the bronze models. If any table contains duplicate keys, fix those duplicates before adding the constraint and starting CDC.