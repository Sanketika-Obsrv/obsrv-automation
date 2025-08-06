FROM flink:1.20-scala_2.12-java11

ENV FLINK_VERSION=1.20.0
ENV FLINK_HOME=/opt/flink

RUN if [ -f "$FLINK_HOME/conf/flink-conf.yaml" ]; then \
      chmod 777 "$FLINK_HOME/conf/flink-conf.yaml"; \
    fi

# Create plugin directories
RUN mkdir -p "$FLINK_HOME/plugins/s3-fs-presto" \
    && mkdir -p "$FLINK_HOME/plugins/gs-fs-hadoop"

RUN curl -fL "https://repo1.maven.org/maven2/org/apache/flink/flink-gs-fs-hadoop/${FLINK_VERSION}/flink-gs-fs-hadoop-${FLINK_VERSION}.jar" \
    -o "$FLINK_HOME/plugins/gs-fs-hadoop/flink-gs-fs-hadoop-${FLINK_VERSION}.jar"

# Azure connector (save to lib)
RUN curl -fL "https://repo1.maven.org/maven2/org/apache/flink/flink-azure-fs-hadoop/${FLINK_VERSION}/flink-azure-fs-hadoop-${FLINK_VERSION}.jar" \
    -o "$FLINK_HOME/lib/flink-azure-fs-hadoop-${FLINK_VERSION}.jar"

# S3 plugin
RUN curl -fL "https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-presto/${FLINK_VERSION}/flink-s3-fs-presto-${FLINK_VERSION}.jar" \
    -o "$FLINK_HOME/plugins/s3-fs-presto/flink-s3-fs-presto-${FLINK_VERSION}.jar"
