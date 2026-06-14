# Poc4GoldenGate — Oracle CDC with Debezium

A self-contained proof-of-concept for capturing Oracle database changes in real-time using **Debezium** (open-source CDC), **Apache Kafka**, and a Python consumer. This is an open-source alternative / complement to Oracle GoldenGate.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│  Oracle 21c XE (XEPDB1)                                         │
│  ┌─────────────┐  ┌──────────┐  ┌────────────┐                 │
│  │ CUSTOMERS   │  │ ORDERS   │  │ ORDER_ITEMS│  ← app_user     │
│  └─────────────┘  └──────────┘  └────────────┘                 │
│         │ Redo Logs (LogMiner)                                   │
└─────────┼───────────────────────────────────────────────────────┘
          │
          ▼
┌─────────────────────┐
│ Kafka Connect        │
│ Debezium Oracle      │  (LogMiner adapter)
│ Connector            │
└──────────┬──────────┘
           │  Avro + Schema Registry
           ▼
┌──────────────────────────────────────────────┐
│ Apache Kafka                                  │
│  oracle.XEPDB1.APP_USER.CUSTOMERS            │
│  oracle.XEPDB1.APP_USER.ORDERS               │
│  oracle.XEPDB1.APP_USER.ORDER_ITEMS          │
└──────────────┬───────────────────────────────┘
               │
        ┌──────┴──────┐
        ▼             ▼
  Python Consumer   Kafka UI
  (stdout)          :8080
```

## Prerequisites

| Requirement | Version |
|---|---|
| Docker + Docker Compose | 24+ |
| Oracle Container Registry login | free account |
| Oracle JDBC driver (`ojdbc11.jar`) | download separately |
| `jq` | for scripts |

### 1 — Oracle Container Registry login

Oracle's Docker images require a free account:

```bash
docker login container-registry.oracle.com
# use your oracle.com credentials
```

### 2 — Oracle JDBC driver

Debezium's Oracle connector requires the JDBC driver, which Oracle does not allow to be bundled in open-source images.

```bash
# Download ojdbc11.jar from:
# https://www.oracle.com/database/technologies/appdev/jdbc-downloads.html
# (Oracle Database 21c → ojdbc11.jar)

cp ~/Downloads/ojdbc11.jar kafka-connect/ojdbc11.jar
```

## Quick Start

```bash
# 1. Clone / enter the project
cd Poc4GoldenGate

# 2. Place ojdbc11.jar (see above)

# 3. Start all services (Oracle takes ~2 min to initialize)
docker compose up -d --build

# 4. Run Oracle setup (wait until oracle-db is healthy first)
./scripts/setup-oracle.sh

# 5. Register the Debezium connector
./scripts/register-connector.sh

# 6. Watch CDC events in the consumer
docker logs -f oracle-cdc-consumer

# 7. In a new terminal, fire some DML changes
./scripts/simulate-changes.sh
```

## Service Endpoints

| Service | URL |
|---|---|
| Kafka Connect REST API | http://localhost:8083 |
| Schema Registry | http://localhost:8081 |
| Kafka UI | http://localhost:8080 |
| Oracle SQL*Plus | `sqlplus app_user/app_password@//localhost:1521/XEPDB1` |

## Connector Configuration Highlights

| Setting | Value | Notes |
|---|---|---|
| `connection.adapter` | `logminer` | Uses Oracle LogMiner (no XStream license needed) |
| `snapshot.mode` | `initial` | Full snapshot on first start, then streaming |
| `log.mining.strategy` | `online_catalog` | Reads from online redo logs; use `redo_log_catalog` for high-volume |
| `transforms.unwrap` | `ExtractNewRecordState` | Flattens the Debezium envelope to a plain record |
| `decimal.handling.mode` | `double` | Converts Oracle NUMBER to JSON double |

Full config: [`kafka-connect/oracle-connector.json`](kafka-connect/oracle-connector.json)

## Kafka Topic Schema

Each topic carries flattened Avro records with these added metadata fields:

| Field | Description |
|---|---|
| `__op` | `c` insert · `u` update · `d` delete · `r` snapshot |
| `__table` | Source table name |
| `__ts_ms` | Event timestamp (epoch ms) |
| `is_deleted` | `true` on soft-delete rewrite |

## Project Layout

```
.
├── docker-compose.yml
├── oracle/
│   ├── 01_cdc_setup.sql       # LogMiner user, supplemental logging
│   ├── 02_schema.sql          # App tables (CUSTOMERS, ORDERS, ORDER_ITEMS)
│   ├── 03_seed_data.sql       # Initial rows
│   └── 04_dml_simulation.sql  # INSERT/UPDATE/DELETE for demo
├── kafka-connect/
│   ├── Dockerfile             # cp-kafka-connect + Debezium Oracle plugin
│   └── oracle-connector.json  # Connector registration payload
├── consumer/
│   ├── consumer.py            # Python Kafka consumer (confluent-kafka)
│   ├── requirements.txt
│   └── Dockerfile
└── scripts/
    ├── setup-oracle.sh        # One-shot Oracle init
    ├── register-connector.sh  # Register/update connector via REST
    └── simulate-changes.sh    # Fire DML to generate events
```

## Troubleshooting

**Oracle takes too long to start**
Oracle XE needs ~2–3 min on first launch. Run `docker logs oracle-db` and wait for `DATABASE IS READY TO USE!`.

**`ORA-65096` when creating c##dbzuser**
You are connected to the PDB, not the CDB root. Connect to `XE` (not `XEPDB1`) as sysdba.

**Connector status is `FAILED`**
Check connector logs:
```bash
curl -s http://localhost:8083/connectors/oracle-cdc-connector/status | jq .
docker logs kafka-connect
```
Common causes: missing `ojdbc11.jar`, Oracle not yet in ARCHIVELOG mode, or wrong credentials.

**No events after connector starts**
- Verify `SELECT LOG_MODE FROM V$DATABASE;` returns `ARCHIVELOG`.
- Verify supplemental logging: `SELECT SUPPLEMENTAL_LOG_DATA_MIN FROM V$DATABASE;` should be `YES`.
- Run `./scripts/simulate-changes.sh` to generate fresh DML.

## Key Differences vs Oracle GoldenGate

| Feature | Debezium | Oracle GoldenGate |
|---|---|---|
| License | Open-source (Apache 2.0) | Commercial |
| Protocol | LogMiner (included in Oracle) | LogMiner or XStream (additional license) |
| Latency | ~1–5 s | Sub-second (XStream) |
| DDL replication | Limited | Full |
| Transformations | Kafka SMTs | GoldenGate trail files |
| Ecosystem | Kafka-native | Broad (JMS, files, etc.) |
