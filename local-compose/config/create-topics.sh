#!/usr/bin/env bash
# Creates every Kafka topic the Obsrv pipeline uses.
#
# The kafka40 chart only provisions a subset (ingest, masterdata.ingest,
# system.telemetry.events, stats, masterdata.stats, hudi.connector.in,
# obsrv-connectors-metrics, connectors.failed) and lets the rest rely on
# auto-topic-creation. We create them all explicitly so the stack does not
# depend on auto-create being enabled.
#
# Partitions/replication match the chart: numPartitions 4, replicationFactor 1.
set -euo pipefail

BOOTSTRAP="${BOOTSTRAP:-kafka:9092}"
PARTITIONS="${PARTITIONS:-4}"
REPLICATION="${REPLICATION:-1}"
KAFKA_BIN="${KAFKA_BIN:-/opt/kafka/bin}"

TOPICS=(
  # --- main pipeline (unified-pipeline) ---
  ingest
  raw
  unique
  denorm
  transform
  transform.failed
  failed
  stats
  system.events

  # --- master data (cache-indexer) ---
  masterdata.ingest
  masterdata.raw
  masterdata.unique
  masterdata.denorm
  masterdata.transform
  masterdata.transform.failed
  masterdata.failed
  masterdata.stats

  # --- other obsrv components ---
  system.telemetry.events
  hudi.connector.in
  hudi.connector.out
  obsrv-connectors-metrics
  connectors.failed
)

echo "Waiting for Kafka at ${BOOTSTRAP} ..."
until "${KAFKA_BIN}/kafka-broker-api-versions.sh" --bootstrap-server "${BOOTSTRAP}" >/dev/null 2>&1; do
  sleep 2
done
echo "Kafka is up."

for topic in "${TOPICS[@]}"; do
  "${KAFKA_BIN}/kafka-topics.sh" \
    --bootstrap-server "${BOOTSTRAP}" \
    --create --if-not-exists \
    --topic "${topic}" \
    --partitions "${PARTITIONS}" \
    --replication-factor "${REPLICATION}"
  echo "  ok: ${topic}"
done

echo
echo "Topics now present:"
"${KAFKA_BIN}/kafka-topics.sh" --bootstrap-server "${BOOTSTRAP}" --list
