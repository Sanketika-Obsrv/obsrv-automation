#!/bin/bash
# DHI spark bitnami-compat entrypoint: replicates the bitnami SPARK_MODE behavior
# (standalone master/worker + livy) on the Apache spark (DHI) base at /opt/spark.
set -euo pipefail

export SPARK_HOME="${SPARK_HOME:-/opt/spark}"
export LIVY_HOME="${LIVY_HOME:-/opt/livy}"
export PATH="$SPARK_HOME/bin:$SPARK_HOME/sbin:$LIVY_HOME/bin:$PATH"

# custom-init: spark-metadata dirs (event logs / livy / spark-log)
mkdir -p "$SPARK_HOME/spark-metadata/spark-events" \
         "$SPARK_HOME/spark-metadata/livy" \
         "$SPARK_HOME/spark-metadata/spark-log" 2>/dev/null || true

# use the mounted config dir if present (deployment mounts a configMap at /data/conf)
if [ -d /data/conf ]; then export SPARK_CONF_DIR=/data/conf; fi

start_livy() {
  if [ -x "$LIVY_HOME/bin/livy-server" ]; then
    mkdir -p "$LIVY_HOME/logs" 2>/dev/null || true
    "$LIVY_HOME/bin/livy-server" start || echo "WARN: livy-server start returned non-zero"
  fi
}

case "${SPARK_MODE:-}" in
  master)
    start_livy
    # DHI spark base has NO `hostname` binary; fall back to HOSTNAME env / /etc/hostname / 0.0.0.0
    exec "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.master.Master \
      --host "${SPARK_MASTER_HOST:-${HOSTNAME:-$(cat /etc/hostname 2>/dev/null || echo 0.0.0.0)}}" \
      --port "${SPARK_MASTER_PORT:-7077}" \
      --webui-port "${SPARK_MASTER_WEBUI_PORT:-8080}"
    ;;
  worker)
    exec "$SPARK_HOME/bin/spark-class" org.apache.spark.deploy.worker.Worker \
      "${SPARK_MASTER_URL:?SPARK_MASTER_URL required for worker}" \
      --cores "${SPARK_WORKER_CORES:-2}" \
      --webui-port "${SPARK_WORKER_WEBUI_PORT:-8080}" \
      --work-dir "${SPARK_WORKER_DIR:-/tmp}"
    ;;
  *)
    # no SPARK_MODE -> pass through (e.g. spark-submit / help)
    exec "$@"
    ;;
esac