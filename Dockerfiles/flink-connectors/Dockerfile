# DHI-hardened flink-connectors (Flink 1.20 base + fs plugins + python connectors).
# flink dist + fs plugins assembled from the official flink 1.20 image (has curl),
# then run on the DHI debian/glibc eclipse-temurin 11 base (glibc for snappy;
# debian ships bash). python3 added for the connector scripts. flink uid 9999.
FROM flink:1.20.5-scala_2.12-java11 AS flink-dist
USER root
# log4j 2.25.5 replaces whatever version ships in the flink base image
ARG LOG4J_VERSION=2.25.5
RUN set -eux; \
    mkdir -p "$FLINK_HOME/plugins/s3-fs-presto" "$FLINK_HOME/plugins/gs-fs-hadoop"; \
    curl -fsSL -o "$FLINK_HOME/lib/flink-azure-fs-hadoop-1.20.0.jar" https://repo1.maven.org/maven2/org/apache/flink/flink-azure-fs-hadoop/1.20.0/flink-azure-fs-hadoop-1.20.0.jar; \
    curl -fsSL -o "$FLINK_HOME/plugins/s3-fs-presto/flink-s3-fs-presto-1.20.0.jar" https://repo1.maven.org/maven2/org/apache/flink/flink-s3-fs-presto/1.20.0/flink-s3-fs-presto-1.20.0.jar; \
    curl -fsSL -o "$FLINK_HOME/plugins/gs-fs-hadoop/flink-gs-fs-hadoop-1.20.0.jar" https://repo1.maven.org/maven2/org/apache/flink/flink-gs-fs-hadoop/1.20.0/flink-gs-fs-hadoop-1.20.0.jar; \
    chmod 644 "$FLINK_HOME/conf/config.yaml"; \
    cd "$FLINK_HOME/lib"; \
    rm -f log4j-1.2-api-*.jar log4j-api-*.jar log4j-core-*.jar log4j-slf4j-impl-*.jar; \
    for a in log4j-1.2-api log4j-api log4j-core log4j-slf4j-impl; do \
      curl -fsSL -o "$a-${LOG4J_VERSION}.jar" "https://repo1.maven.org/maven2/org/apache/logging/log4j/$a/${LOG4J_VERSION}/$a-${LOG4J_VERSION}.jar"; \
    done; \
    chown -R 9999:9999 "$FLINK_HOME"

FROM dhi.io/eclipse-temurin:11-jdk-debian13-dev
ENV FLINK_HOME=/opt/flink
ENV PATH="${FLINK_HOME}/bin:${PATH}"
USER 0
# python3 + pip for the connector scripts.
# gettext-base provides `envsubst`, which the official docker-entrypoint.sh runs every
# FLINK_PROPERTIES value through. If it is missing, each `$(echo $value | envsubst)`
# captures an empty string, wiping all FLINK_PROPERTIES (including
# jobmanager/taskmanager.memory.flink.size) to empty in config.yaml -> the JobManager
# then fails with "Cannot read memory size from config option 'jobmanager.memory.flink.size'".
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip gettext-base \
    && rm -rf /var/lib/apt/lists/*
COPY --from=flink-dist --chown=9999:9999 /opt/flink /opt/flink
COPY --chown=9999:9999 ./connectors /data/connectors-init
RUN pip3 install --no-cache-dir --break-system-packages -r /data/connectors-init/requirements.txt
# Official Flink docker-entrypoint (resolves `jobmanager`/`taskmanager`/`standalone-job`
# args the connector deployments pass as command). Non-root (9999) so its gosu drop is
# a no-op, but copy gosu too so the script never errors on a missing binary.
COPY --from=flink-dist /docker-entrypoint.sh /docker-entrypoint.sh
COPY --from=flink-dist /usr/local/bin/gosu /usr/local/bin/gosu
RUN printf 'flink:x:9999:9999:flink:/opt/flink:/bin/bash\n' >> /etc/passwd \
    && printf 'flink:x:9999:\n' >> /etc/group \
    && chmod +x /docker-entrypoint.sh /usr/local/bin/gosu
USER 9999:9999
WORKDIR ${FLINK_HOME}
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["help"]
