package cz.local.productsales.connector;

import java.util.LinkedHashMap;
import java.util.Map;

final class CliOptions {
    private CliOptions() {
    }

    static Map<String, String> parse(String[] args) {
        Map<String, String> options = new LinkedHashMap<>();
        for (String arg : args) {
            if (!arg.startsWith("--")) {
                throw new IllegalArgumentException("Unsupported argument: " + arg);
            }

            String option = arg.substring(2);
            int separator = option.indexOf('=');
            if (separator < 0) {
                options.put(option, "true");
            } else {
                options.put(option.substring(0, separator), option.substring(separator + 1));
            }
        }
        return options;
    }
}