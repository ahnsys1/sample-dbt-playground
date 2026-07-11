#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONNECT_URL="${CONNECT_URL:-http://localhost:8082}"

cd "$PROJECT_DIR"
mvn -q -DskipTests package
java -jar target/product-sales-connector-1.0.0.jar \
  --connect-url="$CONNECT_URL" \
  --connectors-dir="$PROJECT_DIR/connectors"