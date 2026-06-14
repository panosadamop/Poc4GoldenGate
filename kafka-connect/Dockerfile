FROM confluentinc/cp-kafka-connect:7.6.0

# Install Debezium Oracle connector plugin
# debezium-connector-oracle includes the LogMiner adapter
ARG DEBEZIUM_VERSION=2.6.2.Final

RUN confluent-hub install --no-prompt \
    debezium/debezium-connector-oracle:${DEBEZIUM_VERSION}

# The Oracle JDBC driver (ojdbc8.jar / ojdbc11.jar) cannot be
# bundled here due to Oracle's license. Place ojdbc11.jar in
# kafka-connect/ and it will be copied automatically, OR mount
# it at runtime via a volume. See README.md for instructions.
COPY ojdbc11.jar* /usr/share/confluent-hub-components/debezium-debezium-connector-oracle/lib/

# Confluent Avro converters are included in the base image.
# Add SMT (Single Message Transforms) jar for optional routing.
