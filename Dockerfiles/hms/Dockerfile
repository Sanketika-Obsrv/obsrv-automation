# dhi.io/eclipse-temurin:jre-17-alpine3.24 does not exist (404) despite the tag name - DHI ships
# this line as debian13 regardless; the actually-buildable/pushed reference is the jdk-17-dev
# debian13 variant (confirmed via `docker inspect` labels on the already-published hms:2.2.0 image)
FROM dhi.io/eclipse-temurin:17-jdk-debian13-dev

# see https://hadoop.apache.org/releases.html
ARG HADOOP_VERSION=3.3.4
# see https://downloads.apache.org/hive/
ARG HIVE_METASTORE_VERSION=3.0.0
# see https://jdbc.postgresql.org/download.html#current
# bumped from 42.2.18 to fix CVE-2024-1597 (SQL injection), CVE-2022-21724 and later
# CVE-2025-49146 / CVE-2026-42198 / CVE-2026-54291 (fixed 42.7.7/42.7.11/42.7.12) - latest as of writing
ARG POSTGRES_CONNECTOR_VERSION=42.7.13
# see https://logging.apache.org/log4j/2.x/security.html
# bundled hive-metastore ships log4j 2.8.2 (Log4Shell CVE-2021-44228 + others); bumped in place.
# 2.25.4 still carries CVE-2026-49844 (fixed 2.25.5/2.26.1) - latest as of writing
ARG LOG4J_VERSION=2.26.1

ENV HADOOP_HOME="/opt/hadoop"
ENV PATH="/opt/spark/bin:/opt/hadoop/bin:${PATH}"
ENV DATABASE_DRIVER=org.postgresql.Driver
ENV DATABASE_TYPE=postgres
ENV DATABASE_TYPE_JDBC=postgresql
ENV DATABASE_PORT=5432

WORKDIR /app

# Split into separate RUN layers (each one caches independently) so a transient network
# failure on a later step doesn't force re-downloading the ~900MB Hadoop tarball again on
# retry. curl --retry adds resilience against flaky connections within a single step too.

RUN apt-get update -y && \
  apt-get install -y --no-install-recommends curl net-tools gzip && \
  rm -rf /var/lib/apt/lists/*

# archive.apache.org drops long-lived connections mid-transfer on this (900MB+) file; piping
# straight into tar meant a mid-stream drop threw away all progress. Download to a file with
# `-C -` (resume) in a retry loop instead - a dropped connection continues from its last byte.
RUN echo "Download the Hadoop binary package" && \
    for i in 1 2 3 4 5 6 7 8; do \
      curl -sS -C - --connect-timeout 30 --max-time 900 \
        -o /tmp/hadoop.tar.gz \
        https://archive.apache.org/dist/hadoop/core/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
      && break; \
      echo "download attempt $i failed/interrupted, resuming..."; sleep 5; \
    done && \
    echo "Extract the Hadoop binary package" && \
    tar xzf /tmp/hadoop.tar.gz -C /opt/ && \
    rm /tmp/hadoop.tar.gz && \
    ln -s /opt/hadoop-$HADOOP_VERSION /opt/hadoop && \
    rm -r /opt/hadoop/share/doc

RUN echo "Add S3a jars to the classpath" && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/hadoop-aws* /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/hadoop/share/hadoop/tools/lib/aws-java-sdk* /opt/hadoop/share/hadoop/common/lib/

RUN echo "Remove hadoop-client fat jars and the YARN app-catalog webapp war - confirmed via \
'hadoop classpath'/'hadoop jar' (what run.sh actually invokes) that neither is ever on the \
metastore classpath; they only carry their own shaded/vendored copies of old netty/avro/zookeeper/ \
jackson-mapper-asl (CVE-2019-20444, CVE-2024-47561, CVE-2023-44981, CVE-2019-10202, etc)" && \
    rm -rf /opt/hadoop-$HADOOP_VERSION/share/hadoop/client && \
    rm -f /opt/hadoop-$HADOOP_VERSION/share/hadoop/yarn/hadoop-yarn-applications-catalog-webapp-*.war

RUN echo "Download the standalone metastore binary" && \
    for i in 1 2 3 4 5 6 7 8; do \
      curl -sS -C - --connect-timeout 30 --max-time 900 \
        -o /tmp/hive-metastore.tar.gz \
        https://downloads.apache.org/hive/hive-standalone-metastore-$HIVE_METASTORE_VERSION/hive-standalone-metastore-$HIVE_METASTORE_VERSION-bin.tar.gz \
      && break; \
      echo "download attempt $i failed/interrupted, resuming..."; sleep 5; \
    done && \
    echo "Extract the standalone metastore binary" && \
    tar xzf /tmp/hive-metastore.tar.gz -C /opt/ && \
    rm /tmp/hive-metastore.tar.gz && \
    ln -s /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin /opt/hive-metastore

RUN echo "Fix guava conflict (HIVE-22915)" && \
    rm /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/guava-19.0.jar && \
    cp /opt/hadoop-$HADOOP_VERSION/share/hadoop/hdfs/lib/guava-27.0-jre.jar /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/

RUN echo "Remove unused embedded DB driver jars - only postgres is used (see run.sh DATABASE_TYPE) - fixes CVE-2015-1832 (derby XXE), CVE-2022-41853 (hsqldb RCE)" && \
    rm -f /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/derby-*.jar && \
    rm -f /opt/hadoop-$HADOOP_VERSION/share/hadoop/mapreduce/lib-examples/hsqldb-*.jar

RUN echo "Patch bundled log4j to fix Log4Shell (CVE-2021-44228) and related CVEs" && \
    rm -f /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/log4j-core-*.jar \
          /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/log4j-api-*.jar \
          /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/log4j-1.2-api-*.jar \
          /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/log4j-slf4j-impl-*.jar && \
    for jar in log4j-core log4j-api log4j-1.2-api log4j-slf4j-impl; do \
      curl -sL --retry 3 --retry-delay 2 --fail \
        https://repo1.maven.org/maven2/org/apache/logging/log4j/$jar/$LOG4J_VERSION/$jar-$LOG4J_VERSION.jar \
        --output /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib/$jar-$LOG4J_VERSION.jar; \
    done

RUN echo "Download and install the PostgreSQL connector" && \
    curl -sL --retry 3 --retry-delay 2 --fail \
      https://jdbc.postgresql.org/download/postgresql-$POSTGRES_CONNECTOR_VERSION.jar --output /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar && \
    ln -s /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar /opt/hadoop/share/hadoop/common/lib/ && \
    ln -s /opt/postgresql-$POSTGRES_CONNECTOR_VERSION.jar /opt/hive-metastore/lib/

COPY run.sh run.sh

CMD [ "./run.sh" ]
HEALTHCHECK CMD [ "sh", "-c", "netstat -ln | grep 9083" ]
