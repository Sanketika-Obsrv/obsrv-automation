# DHI-hardened spark + apache livy (re-model of the bitnami image).
# bitnami/spark:3.5.1 -> DHI apache spark 3.5.8 (Apache layout /opt/spark, Java 17, nonroot 65532).
# DHI spark is distroless: has bash + spark-submit + sbin master/worker scripts, but NO python3
# and NO curl/unzip. So: fetch livy+jars in a builder, install python deps in a python-dev builder,
# and inject the python3 runtime from dhi.io/python:3.12-debian13 (same debian13 glibc as DHI spark).
# Bitnami SPARK_MODE master/worker + livy behaviour is replicated by docker-entrypoint-dhi.sh.

# ---------- fetch livy + jars (needs curl/unzip) ----------
FROM public.ecr.aws/docker/library/eclipse-temurin:17-jdk AS fetch
RUN apt-get update && apt-get install -y --no-install-recommends curl unzip ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN mkdir -p /jars \
    && curl -fsSL "https://archive.apache.org/dist/incubator/livy/0.8.0-incubating/apache-livy-0.8.0-incubating_2.12-bin.zip" -o /tmp/livy.zip \
    && unzip -q /tmp/livy.zip -d /tmp \
    && mv /tmp/apache-livy-0.8.0-incubating_2.12-bin /opt/livy \
    && mkdir -p /opt/livy/logs \
    && curl -fsSL -o /jars/postgresql-42.3.1.jar https://repo1.maven.org/maven2/org/postgresql/postgresql/42.3.1/postgresql-42.3.1.jar \
    && curl -fsSL -o /jars/guava-19.0.jar https://repo1.maven.org/maven2/com/google/guava/guava/19.0/guava-19.0.jar \
    && curl -fsSL -o /jars/hadoop-aws-3.4.2.jar https://repo1.maven.org/maven2/org/apache/hadoop/hadoop-aws/3.4.2/hadoop-aws-3.4.2.jar \
    && curl -fsSL -o /jars/bundle-2.29.52.jar https://repo1.maven.org/maven2/software/amazon/awssdk/bundle/2.29.52/bundle-2.29.52.jar

# ---------- python deps (obsrv batch connectors) ----------
FROM dhi.io/python:3.12-debian13-dev AS pybuild
USER 0
COPY ./connectors /data/connectors-init
# DHI python-dev has NO git, so install obsrv-python-sdk from the GitHub tarball (pinned commit)
# instead of git+https. Install into a relocatable target dir copied to the runtime image.
# NOTE: the sdk's package metadata name is `obsrv` (with a `batch` extra = pyspark), so install it
# directly from the tarball with the extra. This is the same `obsrv` the bitnami image got from git.
# Pinned to a commit (repo has no tags) instead of main, so the 2.2.0 image is reproducible -
# a rebuild no longer silently picks up whatever has since landed on the SDK's default branch.
RUN pip install --no-cache-dir --target=/pydeps -r /data/connectors-init/requirements.txt \
    && pip install --no-cache-dir --target=/pydeps \
       "obsrv[batch] @ https://github.com/Sanketika-Obsrv/obsrv-python-sdk/archive/44a0898d94877046a9bb065be391143d661c34bb.tar.gz"

# ---------- runtime ----------
FROM dhi.io/spark:3.5
USER 0
ENV LIVY_HOME=/opt/livy \
    SPARK_HOME=/opt/spark \
    PYTHONPATH=/opt/spark/python:/opt/spark/python/lib/py4j-0.10.9.7-src.zip:/opt/python-deps \
    PYSPARK_PYTHON=/usr/bin/python3.12 \
    PYSPARK_DRIVER_PYTHON=/usr/bin/python3.12 \
    LD_LIBRARY_PATH=/opt/pylib \
    PATH="/opt/spark/bin:/opt/spark/sbin:/opt/livy/bin:/usr/local/bin:${PATH}"

# inject python3 runtime (debian13 glibc-compatible with DHI spark).
# The distroless python image uses /usr/bin + /usr/lib (NOT /usr/local); mirror that layout so
# python's default sys.prefix (/usr) finds the stdlib. Shared-lib deps are staged in /opt/pylib
# (on LD_LIBRARY_PATH) since the spark base ships none of them (no libssl/libffi/libz/etc).
COPY --from=dhi.io/python:3.12-debian13 /usr/bin/python3.12 /usr/bin/python3.12
COPY --from=dhi.io/python:3.12-debian13 /usr/lib/python3.12 /usr/lib/python3.12
# Debian multiarch: libs live under /usr/lib/<arch>-linux-gnu (x86_64 on amd64, aarch64 on arm64).
# Glob the arch dir with *-linux-gnu (matches the single arch dir present) + a directory dest so
# the filename is preserved — makes these COPYs arch-agnostic for multi-arch builds.
COPY --from=dhi.io/python:3.12-debian13 /usr/lib/*-linux-gnu/libpython3.12.so.1.0 /opt/pylib/
COPY --from=dhi.io/python:3.12-debian13 /usr/lib/*-linux-gnu/libssl.so.3          /opt/pylib/
COPY --from=dhi.io/python:3.12-debian13 /usr/lib/*-linux-gnu/libcrypto.so.3       /opt/pylib/
COPY --from=dhi.io/python:3.12-debian13 /usr/lib/*-linux-gnu/libffi.so.8          /opt/pylib/
COPY --from=dhi.io/python:3.12-debian13 /usr/lib/*-linux-gnu/libbz2.so.1.0        /opt/pylib/
COPY --from=dhi.io/python:3.12-debian13 /usr/lib/*-linux-gnu/liblzma.so.5         /opt/pylib/
COPY --from=dhi.io/python:3.12-debian13 /usr/lib/*-linux-gnu/libzstd.so.1         /opt/pylib/
COPY --from=dhi.io/python:3.12-debian13 /usr/lib/*-linux-gnu/libz.so.1            /opt/pylib/
RUN mkdir -p /usr/local/bin \
    && ln -sf /usr/bin/python3.12 /usr/local/bin/python3 \
    && ln -sf /usr/bin/python3.12 /usr/local/bin/python

# livy + python deps + jars
COPY --from=fetch /opt/livy /opt/livy
COPY --from=pybuild /pydeps /opt/python-deps
COPY --from=fetch /jars/postgresql-42.3.1.jar /opt/spark/jars/postgresql-42.3.1.jar
COPY --from=fetch /jars/guava-19.0.jar /opt/spark/jars/guava-19.0.jar
COPY --from=fetch /jars/hadoop-aws-3.4.2.jar /opt/spark/jars/hadoop-aws-3.4.2.jar
COPY --from=fetch /jars/bundle-2.29.52.jar /opt/spark/jars/bundle-2.29.52.jar
# drop the stock guava (WFS needs 19) — name/version may differ on 3.5.8; remove any guava-1x
RUN sh -c 'rm -f /opt/spark/jars/guava-1[0-8].*.jar' || true

# obsrv config + scripts + connectors
COPY ./conf/ /opt/livy/conf/
COPY ./log4j.properties /opt/spark/conf/log4j.properties
COPY ./custom-init.sh /opt/spark/conf/custom-init.sh
COPY ./connectors /data/connectors-init
COPY ./docker-entrypoint-dhi.sh /opt/docker-entrypoint-dhi.sh
# livy-env.sh + log4j.properties hardcode the bitnami layout (/opt/bitnami/spark);
# rewrite both to the DHI apache layout (/opt/spark).
RUN sed -i 's#/opt/bitnami/spark#/opt/spark#g' /opt/livy/conf/livy-env.sh /opt/spark/conf/log4j.properties /opt/spark/conf/custom-init.sh
# The DHI base has no `ps`; livy-server's start daemon-check uses `ps -p <pid> -o comm=`.
# Provide a minimal /proc-backed shim so livy-server reports success and manages its pid file.
RUN printf '%s\n' '#!/usr/bin/bash' \
    'pid=""' \
    'while [ $# -gt 0 ]; do case "$1" in -p) pid="$2"; shift 2;; -o) shift 2;; *) shift;; esac; done' \
    '[ -n "$pid" ] && [ -r "/proc/$pid/comm" ] && cat "/proc/$pid/comm"; exit 0' \
    > /usr/local/bin/ps && chmod +x /usr/local/bin/ps
RUN mkdir -p /tmp/spark-events "$SPARK_HOME/spark-metadata" \
    && chmod +x /opt/spark/conf/custom-init.sh /opt/docker-entrypoint-dhi.sh \
    && chown -R 65532:65532 /opt/livy /opt/python-deps /data/connectors-init /tmp/spark-events "$SPARK_HOME/spark-metadata"

USER 65532
WORKDIR /opt/spark
ENTRYPOINT ["/opt/docker-entrypoint-dhi.sh"]