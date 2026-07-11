#!/usr/bin/env bash
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8082}"
CONNECTORS=(
  product-sales-postgres-source
  sink-bronze-customers
  sink-bronze-items
  sink-bronze-orders
  sink-bronze-products
  sink-bronze-stores
  sink-bronze-supplies
)

for connector in "${CONNECTORS[@]}"; do
  curl -sS -X DELETE "$CONNECT_URL/connectors/$connector" >/dev/null || true
  echo "deleted $connector"
done