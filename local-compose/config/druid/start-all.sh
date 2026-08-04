#!/bin/bash
# Runs all 5 Druid roles in one container. The image is distroless (no
# python), so bin/start-druid -- Druid's own multi-service launcher -- can't
# run here; this backgrounds bin/run-druid (plain bash) once per role instead.
# All config is static, read-only files under config/druid/local-single-conf
# (mounted at /opt/druid/local-single-conf), one subdirectory per role plus
# _common -- the same layout bin/run-druid expects for any single service, so
# no per-role env-var passing or temp-file rendering is needed.
set -euo pipefail

CONF_DIR=/opt/druid/local-single-conf
PIDS=()

trap 'kill "${PIDS[@]}" 2>/dev/null; wait' TERM INT

for role in coordinator-overlord broker historical indexer router; do
  echo "Starting $role ..."
  /opt/druid/bin/run-druid "$role" "$CONF_DIR" &
  PIDS+=("$!")
done

wait -n
# If any role exits, bring the container down so `docker compose ps` surfaces
# the failure instead of silently running degraded.
kill "${PIDS[@]}" 2>/dev/null || true
wait
