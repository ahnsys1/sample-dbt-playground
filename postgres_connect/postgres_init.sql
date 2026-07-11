{
  "name": "postgres-orders-sink",
  "config": {
    "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
    "topics": "orders",
    "connection.url": "jdbc:postgresql://localhost:5432/postgres",
    "connection.user": "postgres",
    "connection.password": "password",
    "insert.mode": "insert",
    "auto.create": "true",
    "pk.mode": "record_key",
    "pk.fields": "order_id"
  }
}