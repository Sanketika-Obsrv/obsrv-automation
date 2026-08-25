#!/usr/bin/env bash
# Run the Locust query load test against both targets, one after the other.
#
# Sequential on purpose: the load generator shares a machine with the stack it
# measures, so running api and druid concurrently makes each one's numbers a
# function of the other's load.
#
# Usage: ./run.sh [duration] [users]
set -euo pipefail
cd "$(dirname "$0")"

DURATION="${1:-3m}"
USERS="${2:-4}"
# Locust is gevent-based and therefore single-threaded: without --processes,
# every virtual user shares one CPU core and the generator saturates long
# before the stack does. Measured against Druid: 70.9 req/s single-process vs
# 175.9 with --processes 4, p50 31ms vs 15ms -- the slow number was Locust.
#
# But 4 is too many on a 4-core box that also hosts the stack. At --processes 4
# for 3 minutes the generator starved the Flink TaskManager past its 50s
# heartbeat deadline; the JobManager declared it dead, the pipeline restarted
# from checkpoint, and Druid throughput collapsed from 175 req/s to 0.1 while
# competing with the recovery. A 60s run at the same setting looked fine only
# because it finished before the timeout could trip. Default to half the cores
# so the generator cannot take down what it is measuring; raise it only when
# the generator runs on a separate host.
PROCESSES="${3:-2}"
LOCUST=".venv/bin/locust"

if [ ! -x "$LOCUST" ]; then
  echo "creating venv and installing locust..."
  python3 -m venv .venv
  .venv/bin/pip install --quiet --upgrade pip
  .venv/bin/pip install --quiet locust
fi

mkdir -p results
for target in druid api; do
  echo "=== $target -- $USERS users, $PROCESSES processes, for $DURATION"
  OBSRV_TARGET="$target" "$LOCUST" -f locustfile.py --headless \
    -u "$USERS" -r "$USERS" -t "$DURATION" --only-summary \
    --processes "$PROCESSES" \
    --csv "results/$target" --html "results/$target.html"
done

echo
echo "reports: results/druid.html  results/api.html"
