FROM confluentinc/cp-kafka-connect:7.6.0

ARG DEBEZIUM_VERSION=2.6.2.Final
ARG JDBC_VERSION=10.7.6

# Debezium Oracle connector — not on Confluent Hub, download from Maven Central
RUN curl -fSL "https://repo1.maven.org/maven2/io/debezium/debezium-connector-oracle/${DEBEZIUM_VERSION}/debezium-connector-oracle-${DEBEZIUM_VERSION}-plugin.tar.gz" \
    -o /tmp/debezium-oracle-plugin.tar.gz && \
    tar -xzf /tmp/debezium-oracle-plugin.tar.gz -C /usr/share/confluent-hub-components/ && \
    rm /tmp/debezium-oracle-plugin.tar.gz

# Confluent JDBC connector — writes change events to the target DB
RUN confluent-hub install --no-prompt \
    confluentinc/kafka-connect-jdbc:${JDBC_VERSION}

# Oracle JDBC driver (ojdbc17 for Oracle 21c / JDK 17)
# Plugin lib dirs — picked up by the connector's isolated classloader
COPY ojdbc17.jar /usr/share/confluent-hub-components/debezium-connector-oracle/lib/
COPY ojdbc17.jar /usr/share/confluent-hub-components/confluentinc-kafka-connect-jdbc/lib/
# Kafka system classpath — required so DriverManager.getConnection() can find the Oracle driver
COPY ojdbc17.jar /usr/share/java/kafka/
