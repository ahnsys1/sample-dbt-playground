package cz.local.productsales.connector;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.stream.Stream;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ConnectorConfigTest {
    private static final ObjectMapper OBJECT_MAPPER = new ObjectMapper();
    private static final Path CONNECTORS_DIR = Path.of("connectors");
    private static final String TABLES = String.join(",",
            "product_sales_bronze.bronze_customers",
            "product_sales_bronze.bronze_items",
            "product_sales_bronze.bronze_orders",
            "product_sales_bronze.bronze_products",
            "product_sales_bronze.bronze_stores",
            "product_sales_bronze.bronze_supplies");

    @Test
    void sourceConnectorSnapshotsAndStreamsOnlyRequestedTables() throws IOException {
        JsonNode config = config("product-sales-postgres-source.json");

        assertEquals("io.debezium.connector.postgresql.PostgresConnector", value(config, "connector.class"));
        assertEquals("5431", value(config, "database.port"));
        assertEquals("initial", value(config, "snapshot.mode"));
        assertEquals("product_sales_bronze", value(config, "schema.include.list"));
        assertEquals(TABLES, value(config, "table.include.list"));
        assertEquals("product_sales", value(config, "topic.prefix"));
        assertEquals("product_sales\\.([^.]+\\.[^.]+)", value(config, "transforms.route.topic.regex"));
        assertEquals("$1", value(config, "transforms.route.topic.replacement"));
    }

    @Test
    void eachRequestedTopicHasDebeziumJdbcSinkWithPrimaryKey() throws IOException {
        Map<String, String> expectedPrimaryKeys = Map.of(
                "product_sales_bronze.bronze_customers", "customer_id",
                "product_sales_bronze.bronze_items", "item_id",
                "product_sales_bronze.bronze_orders", "order_id",
                "product_sales_bronze.bronze_products", "product_sku",
                "product_sales_bronze.bronze_stores", "store_id",
                "product_sales_bronze.bronze_supplies", "supply_id,product_sku");

        Map<String, String> actualPrimaryKeys = new HashMap<>();
        try (Stream<Path> paths = Files.list(CONNECTORS_DIR)) {
            for (Path path : paths.filter(file -> file.getFileName().toString().startsWith("sink-")).toList()) {
                JsonNode config = config(path.getFileName().toString());
                String topic = value(config, "topics");

                assertEquals("io.debezium.connector.jdbc.JdbcSinkConnector", value(config, "connector.class"));
                assertEquals("jdbc:postgresql://host.docker.internal:5432/postgres", value(config, "connection.url"));
                assertEquals(topic, value(config, "collection.name.format"));
                assertEquals("upsert", value(config, "insert.mode"));
                assertEquals("true", value(config, "delete.enabled"));
                assertEquals("record_key", value(config, "primary.key.mode"));

                actualPrimaryKeys.put(topic, value(config, "primary.key.fields"));
            }
        }

        assertEquals(expectedPrimaryKeys, actualPrimaryKeys);
    }

    @Test
    void allConnectorFilesHaveNameAndConfig() throws IOException {
        try (Stream<Path> paths = Files.list(CONNECTORS_DIR)) {
            for (Path path : paths.filter(file -> file.getFileName().toString().endsWith(".json")).toList()) {
                JsonNode connector = OBJECT_MAPPER.readTree(path.toFile());

                assertFalse(connector.path("name").asText().isBlank(), path + " is missing name");
                assertTrue(connector.path("config").isObject(), path + " is missing config");
            }
        }
    }

    @Test
    void topicsMatchRequestedTableNames() throws IOException {
        Set<String> expectedTopics = Set.of(TABLES.split(","));
        Set<String> actualTopics;
        try (Stream<Path> paths = Files.list(CONNECTORS_DIR)) {
            actualTopics = paths
                    .filter(file -> file.getFileName().toString().startsWith("sink-"))
                    .map(file -> {
                        try {
                            return value(config(file.getFileName().toString()), "topics");
                        } catch (IOException exception) {
                            throw new IllegalStateException(exception);
                        }
                    })
                    .collect(java.util.stream.Collectors.toSet());
        }

        assertEquals(expectedTopics, actualTopics);
    }

    private static JsonNode config(String fileName) throws IOException {
        return OBJECT_MAPPER.readTree(CONNECTORS_DIR.resolve(fileName).toFile()).path("config");
    }

    private static String value(JsonNode config, String key) {
        return config.path(key).asText();
    }
}