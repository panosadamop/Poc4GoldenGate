"""
Oracle CDC consumer — reads Debezium change events from Kafka and
prints a structured summary of each INSERT / UPDATE / DELETE.
"""

import json
import logging
import os
import signal
import sys
from datetime import datetime, timezone

from confluent_kafka import Consumer, KafkaError
from confluent_kafka.schema_registry import SchemaRegistryClient
from confluent_kafka.schema_registry.avro import AvroDeserializer
from confluent_kafka.serialization import SerializationContext, MessageField

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s  %(levelname)-8s  %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger(__name__)

BOOTSTRAP_SERVERS = os.getenv("KAFKA_BOOTSTRAP_SERVERS", "localhost:29092")
SCHEMA_REGISTRY_URL = os.getenv("SCHEMA_REGISTRY_URL", "http://localhost:8081")
TOPICS = os.getenv(
    "TOPICS",
    "oracle.XEPDB1.APP_USER.CUSTOMERS,oracle.XEPDB1.APP_USER.ORDERS,oracle.XEPDB1.APP_USER.ORDER_ITEMS",
).split(",")

OP_LABELS = {
    "c": ("INSERT", "\033[32m"),   # green
    "u": ("UPDATE", "\033[33m"),   # yellow
    "d": ("DELETE", "\033[31m"),   # red
    "r": ("SNAPSHOT", "\033[36m"), # cyan
}
RESET = "\033[0m"


def _ts_ms_to_str(ts_ms: int | None) -> str:
    if ts_ms is None:
        return "—"
    return datetime.fromtimestamp(ts_ms / 1000, tz=timezone.utc).isoformat()


def _table_name(topic: str) -> str:
    # topic format: oracle.XEPDB1.APP_USER.CUSTOMERS
    parts = topic.split(".")
    return ".".join(parts[-2:]) if len(parts) >= 2 else topic


def handle_event(topic: str, key, value) -> None:
    if value is None:
        log.debug("Tombstone on %s (key=%s)", topic, key)
        return

    op = value.get("__op") or value.get("op", "?")
    label, color = OP_LABELS.get(op, (op.upper(), ""))
    ts_str = _ts_ms_to_str(value.get("__ts_ms") or value.get("ts_ms"))
    table = value.get("__table") or _table_name(topic)
    is_deleted = value.get("is_deleted", False)

    # Remove internal Debezium metadata fields before printing payload
    payload = {
        k: v
        for k, v in value.items()
        if not k.startswith("__") and k not in ("op", "ts_ms", "is_deleted", "source", "transaction")
    }

    print(
        f"\n{color}{'─' * 60}\n"
        f"  {label:<10}  table={table}  ts={ts_str}"
        + (f"  [DELETED]" if is_deleted else "")
        + f"\n{'─' * 60}{RESET}"
    )
    for field, val in payload.items():
        print(f"  {field:<20} = {val!r}")


def main() -> None:
    schema_registry = SchemaRegistryClient({"url": SCHEMA_REGISTRY_URL})
    avro_deserializer = AvroDeserializer(schema_registry)

    consumer = Consumer(
        {
            "bootstrap.servers": BOOTSTRAP_SERVERS,
            "group.id": "oracle-cdc-demo-consumer",
            "auto.offset.reset": "earliest",
            "enable.auto.commit": True,
        }
    )
    consumer.subscribe(TOPICS)

    running = True

    def _shutdown(sig, frame):
        nonlocal running
        log.info("Shutting down…")
        running = False

    signal.signal(signal.SIGINT, _shutdown)
    signal.signal(signal.SIGTERM, _shutdown)

    log.info("Subscribed to topics: %s", TOPICS)
    log.info("Waiting for change events… (Ctrl+C to stop)")

    while running:
        msg = consumer.poll(timeout=1.0)
        if msg is None:
            continue
        if msg.error():
            if msg.error().code() == KafkaError._PARTITION_EOF:
                continue
            log.error("Kafka error: %s", msg.error())
            continue

        try:
            key = (
                avro_deserializer(msg.key(), SerializationContext(msg.topic(), MessageField.KEY))
                if msg.key()
                else None
            )
            value = (
                avro_deserializer(msg.value(), SerializationContext(msg.topic(), MessageField.VALUE))
                if msg.value()
                else None
            )
            handle_event(msg.topic(), key, value)
        except Exception as exc:
            log.exception("Failed to deserialize message on %s: %s", msg.topic(), exc)

    consumer.close()
    log.info("Consumer closed.")


if __name__ == "__main__":
    sys.exit(main())
