#!/usr/bin/env bash
# Inject DML changes into Oracle to generate CDC events.
set -euo pipefail

CONTAINER="${ORACLE_CONTAINER:-oracle-db}"
APP_PWD="${APP_PWD:-app_password}"

echo "=> Injecting DML changes into XEPDB1…"
docker exec -i "$CONTAINER" sqlplus "app_user/${APP_PWD}@//localhost:1521/XEPDB1" \
  < "$(dirname "$0")/../oracle/04_dml_simulation.sql"

echo "=> Done. Watch the consumer logs:"
echo "   docker logs -f oracle-cdc-consumer"
