# dhi.io/eclipse-temurin:jre-17-alpine3.24 does not exist (404) despite the tag name - DHI ships
# this line as debian13 regardless; the actually-buildable/pushed reference is the jdk-17-dev
# debian13 variant (confirmed via `docker inspect` labels on the already-published hms:2.2.0 image)
FROM dhi.io/eclipse-temurin:17-jdk-debian13-dev

# see https://hadoop.apache.org/releases.html
# 3.3.4 only exists on archive.apache.org, which throttles this file to ~50-100KB/s (confirmed
# from multiple networks incl. GitHub Actions runners) - a ~700MB download that never finishes
# in practice. 3.3.6 is the same 3.3.x line (no API/wire-compat break) and is still on the fast
# CDN mirror (dlcdn.apache.org, confirmed 12MB/s+) since it hasn't been superseded off it yet.
ARG HADOOP_VERSION=3.3.6
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
# Hadoop 3.3.6 ships netty 4.1.89.Final (plus a leftover netty 3.10.6.Final, see below) - both
# carry dozens of CVEs. Bumping within the 4.1.x line only (Netty's own compat policy: binary
# compatible across 4.1.x patches) - latest as of writing.
ARG NETTY_VERSION=4.1.137.Final
# bundled jackson-databind/core range from 2.4.0 to 2.12.7 depending on which lib dir - bumping
# to the latest 2.x line (Jackson maintains ObjectMapper API compat across minor versions) -
# latest as of writing.
ARG JACKSON_VERSION=2.22.2
# jackson-annotations uses its own version scheme (major.minor only, no patch digit) - latest
# as of writing.
ARG JACKSON_ANNOTATIONS_VERSION=2.22

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

# dlcdn.apache.org is the fast CDN mirror for current (non-archived) releases - confirmed
# 12MB/s+, vs. archive.apache.org's ~50-100KB/s throttle on old releases. Keep the resumable
# retry loop anyway as defense-in-depth for ordinary transient network blips.
RUN echo "Download the Hadoop binary package" && \
    for i in 1 2 3 4 5 6 7 8; do \
      curl -sS -C - --connect-timeout 30 --max-time 300 \
        -o /tmp/hadoop.tar.gz \
        https://dlcdn.apache.org/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz \
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

RUN echo "Remove hadoop-client fat jars, the YARN app-catalog webapp war, and the YARN \
timelineservice lib dir - confirmed via 'hadoop classpath'/'hadoop jar' (what run.sh actually \
invokes) that none of these are ever on the metastore classpath (classpath only includes \
yarn/lib and yarn/*, not the nested yarn/timelineservice/lib); they only carry their own \
shaded/vendored copies of old netty/avro/zookeeper/jackson-mapper-asl/jackson-databind \
(CVE-2019-20444, CVE-2024-47561, CVE-2023-44981, CVE-2019-10202, etc - htrace-core alone in \
timelineservice/lib carries 52 CVE-instances via its bundled jackson 2.4.0)" && \
    rm -rf /opt/hadoop-$HADOOP_VERSION/share/hadoop/client && \
    rm -rf /opt/hadoop-$HADOOP_VERSION/share/hadoop/yarn/timelineservice && \
    rm -f /opt/hadoop-$HADOOP_VERSION/share/hadoop/yarn/hadoop-yarn-applications-catalog-webapp-*.war

RUN echo "Remove unused zookeeper (run.sh sets no ZK/HA config; verified via boot-test that its \
absence doesn't affect metastore startup) and ancient jackson-mapper-asl (EOL, no upstream fix \
exists) - fixes CVE-2023-44981, CVE-2024-23944, CVE-2019-10202, CVE-2019-10172" && \
    rm -f /opt/hadoop-$HADOOP_VERSION/share/hadoop/common/lib/zookeeper-*.jar \
          /opt/hadoop-$HADOOP_VERSION/share/hadoop/hdfs/lib/zookeeper-*.jar \
          /opt/hadoop-$HADOOP_VERSION/share/hadoop/common/lib/jackson-mapper-asl-*.jar \
          /opt/hadoop-$HADOOP_VERSION/share/hadoop/hdfs/lib/jackson-mapper-asl-*.jar

RUN echo "Remove native-transport netty jars (opt-in perf jars for epoll/kqueue - NIO is \
Hadoop's default transport, these are never loaded unless explicitly configured) and the \
leftover netty 3.x jar (only used by zookeeper's optional NettyServerCnxnFactory, removed \
above) - fixes CVE-2019-20444 and removes dead weight before the real netty bump below" && \
    rm -f /opt/hadoop-$HADOOP_VERSION/share/hadoop/common/lib/netty-3.10.6.Final.jar \
          /opt/hadoop-$HADOOP_VERSION/share/hadoop/hdfs/lib/netty-3.10.6.Final.jar \
          /opt/hadoop-$HADOOP_VERSION/share/hadoop/*/lib/netty-transport-native-epoll-*.jar \
          /opt/hadoop-$HADOOP_VERSION/share/hadoop/*/lib/netty-transport-native-kqueue-*.jar \
          /opt/hadoop-$HADOOP_VERSION/share/hadoop/*/lib/netty-resolver-dns-native-macos-*.jar

RUN echo "Bump remaining netty 4.1.x jars in place (same major.minor line, binary compatible \
per Netty's own policy) - fixes dozens of CVEs incl. CVE-2026-42579/44893/33870/56817/44249. \
NB: glob is anchored on a digit right after the artifact name (\$artifact-[0-9]*.jar) because \
many netty artifact names are string-prefixes of others (netty-transport vs. \
netty-transport-classes-epoll, netty-codec vs. netty-codec-dns, etc) - a plain \$artifact-*.jar \
would also delete/miss those unrelated artifacts." && \
    for dir in common hdfs; do \
      for artifact in netty-buffer netty-codec netty-codec-dns netty-codec-haproxy \
        netty-codec-http netty-codec-http2 netty-codec-memcache netty-codec-mqtt \
        netty-codec-redis netty-codec-smtp netty-codec-socks netty-codec-stomp netty-codec-xml \
        netty-common netty-handler netty-handler-proxy netty-handler-ssl-ocsp netty-resolver \
        netty-resolver-dns netty-resolver-dns-classes-macos netty-transport \
        netty-transport-classes-epoll netty-transport-classes-kqueue \
        netty-transport-native-unix-common netty-transport-rxtx netty-transport-sctp \
        netty-transport-udt netty-all; do \
        old=$(ls /opt/hadoop-$HADOOP_VERSION/share/hadoop/$dir/lib/$artifact-[0-9]*.jar 2>/dev/null || true); \
        if [ -n "$old" ]; then \
          rm -f $old && \
          curl -sL --retry 3 --retry-delay 2 --fail \
            https://repo1.maven.org/maven2/io/netty/$artifact/$NETTY_VERSION/$artifact-$NETTY_VERSION.jar \
            --output /opt/hadoop-$HADOOP_VERSION/share/hadoop/$dir/lib/$artifact-$NETTY_VERSION.jar; \
        fi; \
      done; \
    done

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

RUN echo "Bump bundled jackson-databind/jackson-core/jackson-annotations in place (same 2.x \
API line, Jackson maintains ObjectMapper compat across minor versions) - fixes CVE-2025-52999, \
CVE-2022-42003 and dozens more. Same digit-anchored glob as the netty step - jackson-core would \
otherwise collide with nothing here, but kept consistent for safety. jackson-annotations is \
handled separately - it uses its own major.minor-only version scheme, no patch digit." && \
    for loc in /opt/hadoop-$HADOOP_VERSION/share/hadoop/common/lib \
               /opt/hadoop-$HADOOP_VERSION/share/hadoop/hdfs/lib \
               /opt/apache-hive-metastore-$HIVE_METASTORE_VERSION-bin/lib; do \
      for artifact in jackson-databind jackson-core; do \
        old=$(ls $loc/$artifact-[0-9]*.jar 2>/dev/null || true); \
        if [ -n "$old" ]; then \
          rm -f $old && \
          curl -sL --retry 3 --retry-delay 2 --fail \
            https://repo1.maven.org/maven2/com/fasterxml/jackson/core/$artifact/$JACKSON_VERSION/$artifact-$JACKSON_VERSION.jar \
            --output $loc/$artifact-$JACKSON_VERSION.jar; \
        fi; \
      done; \
      old=$(ls $loc/jackson-annotations-[0-9]*.jar 2>/dev/null || true); \
      if [ -n "$old" ]; then \
        rm -f $old && \
        curl -sL --retry 3 --retry-delay 2 --fail \
          https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/$JACKSON_ANNOTATIONS_VERSION/jackson-annotations-$JACKSON_ANNOTATIONS_VERSION.jar \
          --output $loc/jackson-annotations-$JACKSON_ANNOTATIONS_VERSION.jar; \
      fi; \
    done

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
