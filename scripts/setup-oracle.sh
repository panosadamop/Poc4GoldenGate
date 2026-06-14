#!/usr/bin/env bash
# Run Oracle setup scripts inside the oracle-db container.
# Must be called after the container is healthy.
set -euo pipefail

CONTAINER="${ORACLE_CONTAINER:-oracle-db}"
SYS_PWD="${SYS_PWD:-Oracle_1234}"
APP_PWD="${APP_PWD:-app_password}"

run_sql() {
  local script="$1"
  local user="$2"
  local connect_str="$3"
  echo "=> Running ${script} as ${user}…"
  docker exec -i "$CONTAINER" sqlplus -S "${user}/${connect_str}" <<< "@/docker-entrypoint-initdb.d/${script}"
}

echo "=== Waiting for Oracle to be healthy ==="
until docker exec "$CONTAINER" sqlplus -S "sys/${SYS_PWD}@//localhost:1521/XE as sysdba" <<< "SELECT 1 FROM DUAL;" &>/dev/null; do
  printf '.'
  sleep 5
done
echo

echo "=== Running CDC setup (sysdba) ==="
docker exec -i "$CONTAINER" sqlplus "sys/${SYS_PWD}@//localhost:1521/XE as sysdba" < "$(dirname "$0")/../oracle/01_cdc_setup.sql"

echo "=== Creating schema (app_user) ==="
docker exec -i "$CONTAINER" sqlplus "app_user/${APP_PWD}@//localhost:1521/XEPDB1" < "$(dirname "$0")/../oracle/02_schema.sql"

echo "=== Loading seed data (app_user) ==="
docker exec -i "$CONTAINER" sqlplus "app_user/${APP_PWD}@//localhost:1521/XEPDB1" < "$(dirname "$0")/../oracle/03_seed_data.sql"

echo "=== Oracle setup complete ==="
