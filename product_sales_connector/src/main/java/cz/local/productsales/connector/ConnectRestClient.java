package cz.local.productsales.connector;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.file.Path;
import java.time.Duration;

final class ConnectRestClient {
    private final URI connectUrl;
    private final HttpClient httpClient;
    private final ObjectMapper objectMapper;

    ConnectRestClient(String connectUrl, ObjectMapper objectMapper) {
        this.connectUrl = URI.create(connectUrl.endsWith("/") ? connectUrl.substring(0, connectUrl.length() - 1) : connectUrl);
        this.httpClient = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();
        this.objectMapper = objectMapper;
    }

    JsonNode readConnectorDefinition(Path configFile) throws IOException {
        return objectMapper.readTree(configFile.toFile());
    }

    void deleteConnector(String name) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(connectUrl.resolve("/connectors/" + name))
                .timeout(Duration.ofSeconds(30))
                .DELETE()
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200 && response.statusCode() != 204 && response.statusCode() != 404) {
            throw new IOException("Failed to delete connector " + name + ": HTTP " + response.statusCode() + " " + response.body());
        }
    }

    void createConnector(JsonNode connectorDefinition) throws IOException, InterruptedException {
        String payload = objectMapper.writerWithDefaultPrettyPrinter().writeValueAsString(connectorDefinition);
        HttpRequest request = HttpRequest.newBuilder(connectUrl.resolve("/connectors"))
                .timeout(Duration.ofSeconds(30))
                .header("Content-Type", "application/json")
                .POST(HttpRequest.BodyPublishers.ofString(payload))
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200 && response.statusCode() != 201) {
            throw new IOException("Failed to create connector: HTTP " + response.statusCode() + " " + response.body());
        }
    }

    JsonNode connectorStatus(String name) throws IOException, InterruptedException {
        HttpRequest request = HttpRequest.newBuilder(connectUrl.resolve("/connectors/" + name + "/status"))
                .timeout(Duration.ofSeconds(30))
                .GET()
                .build();

        HttpResponse<String> response = httpClient.send(request, HttpResponse.BodyHandlers.ofString());
        if (response.statusCode() != 200) {
            throw new IOException("Failed to read connector status " + name + ": HTTP " + response.statusCode() + " " + response.body());
        }
        return objectMapper.readTree(response.body());
    }
}