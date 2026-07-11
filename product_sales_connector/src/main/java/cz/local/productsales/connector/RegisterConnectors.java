package cz.local.productsales.connector;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Comparator;
import java.util.List;
import java.util.Map;
import java.util.stream.Stream;

public final class RegisterConnectors {
    private RegisterConnectors() {
    }

    public static void main(String[] args) throws Exception {
        Map<String, String> options = CliOptions.parse(args);
        Path connectorsDir = Path.of(options.getOrDefault("connectors-dir", "connectors"));
        String connectUrl = options.getOrDefault("connect-url", "http://localhost:8082");
        boolean deleteFirst = !options.containsKey("no-delete-first");

        ObjectMapper objectMapper = new ObjectMapper();
        ConnectRestClient client = new ConnectRestClient(connectUrl, objectMapper);
        List<Path> connectorFiles = connectorFiles(connectorsDir);

        for (Path connectorFile : connectorFiles) {
            JsonNode connectorDefinition = client.readConnectorDefinition(connectorFile);
            String name = connectorDefinition.path("name").asText();
            if (name.isBlank()) {
                throw new IllegalArgumentException("Connector file has no name: " + connectorFile);
            }

            if (deleteFirst) {
                client.deleteConnector(name);
            }
            client.createConnector(connectorDefinition);
            JsonNode status = client.connectorStatus(name);
            System.out.printf("%s -> %s%n", name, status.path("connector").path("state").asText("UNKNOWN"));
        }
    }

    private static List<Path> connectorFiles(Path connectorsDir) throws IOException {
        if (!Files.isDirectory(connectorsDir)) {
            throw new IllegalArgumentException("Connectors directory does not exist: " + connectorsDir.toAbsolutePath());
        }

        try (Stream<Path> paths = Files.list(connectorsDir)) {
            return paths
                    .filter(path -> path.getFileName().toString().endsWith(".json"))
                    .sorted(Comparator.comparing(path -> path.getFileName().toString()))
                    .toList();
        }
    }
}