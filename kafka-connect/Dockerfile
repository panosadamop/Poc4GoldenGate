FROM confluentinc/cp-kafka-connect:7.6.0

ARG DEBEZIUM_VERSION=2.6.2.Final
ARG JDBC_VERSION=10.7.6

# Debezium Oracle connector — downloaded from Maven Central (not on Confluent Hub)
# The archive already bundles ojdbc8-21.11.0.0.jar (Oracle 21c driver, Java 8+)
RUN curl -fSL "https://repo1.maven.org/maven2/io/debezium/debezium-connector-oracle/${DEBEZIUM_VERSION}/debezium-connector-oracle-${DEBEZIUM_VERSION}-plugin.tar.gz" \
    -o /tmp/debezium-oracle-plugin.tar.gz && \
    tar -xzf /tmp/debezium-oracle-plugin.tar.gz -C /usr/share/confluent-hub-components/ && \
    rm /tmp/debezium-oracle-plugin.tar.gz

# Confluent JDBC connector — writes change events to the target DB
RUN confluent-hub install --no-prompt \
    confluentinc/kafka-connect-jdbc:${JDBC_VERSION}

# This image runs JDK 11; ojdbc17 (JDK 17+) would fail to load.
# Reuse the bundled ojdbc8 (compatible with JDK 8-17 and Oracle 12c-21c) for:
#   - JDBC sink connector plugin classpath
#   - Kafka system classpath (required so DriverManager.getConnection() can find the driver)
RUN OJDBC=$(ls /usr/share/confluent-hub-components/debezium-connector-oracle/ojdbc*.jar | head -1) && \
    cp "$OJDBC" /usr/share/confluent-hub-components/confluentinc-kafka-connect-jdbc/lib/ && \
    rm -f /usr/share/confluent-hub-components/confluentinc-kafka-connect-jdbc/lib/ojdbc17.jar && \
    cp "$OJDBC" /usr/share/java/kafka/ && \
    cp "$OJDBC" /etc/kafka-connect/jars/
