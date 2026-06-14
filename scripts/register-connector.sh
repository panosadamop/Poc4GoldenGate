#!/usr/bin/env bash
# Register (or update) the Debezium Oracle connector via the Kafka Connect REST API.
set -euo pipefail

CONNECT_URL="${CONNECT_URL:-http://localhost:8083}"
CONNECTOR_CONFIG="$(dirname "$0")/../kafka-connect/oracle-connector.json"

echo "=> Waiting for Kafka Connect to be ready…"
until curl -sf "${CONNECT_URL}/connectors" > /dev/null; do
  printf '.'
  sleep 3
done
echo

CONNECTOR_NAME=$(jq -r '.name' "$CONNECTOR_CONFIG")

# Check if connector already exists
STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${CONNECT_URL}/connectors/${CONNECTOR_NAME}")

if [[ "$STATUS" == "200" ]]; then
  echo "=> Connector '${CONNECTOR_NAME}' exists — updating config…"
  curl -sf -X PUT \
    -H "Content-Type: application/json" \
    --data "$(jq '.config' "$CONNECTOR_CONFIG")" \
    "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/config" | jq .
else
  echo "=> Registering new connector '${CONNECTOR_NAME}'…"
  curl -sf -X POST \
    -H "Content-Type: application/json" \
    --data @"$CONNECTOR_CONFIG" \
    "${CONNECT_URL}/connectors" | jq .
fi

echo
echo "=> Connector status:"
sleep 3
curl -sf "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" | jq .
