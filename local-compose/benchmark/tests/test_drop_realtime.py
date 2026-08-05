"""Dropping a datasource must remove rows held open by a realtime task.

Live-stack test. Needs the compose stack up and `bench_telemetry` holding
rows from a previous run -- which is exactly the state a re-run starts in.

The bug this pins: terminating a Kafka supervisor leaves its indexing tasks
running, and a running task serves its rows itself rather than from a
published segment. Every segment-level remedy therefore reports success and
changes nothing:

    markUnused  -> {"numChangedSegments": 0, "segmentStateChanged": false}
    SELECT COUNT(*) -> 19800

The count is what the benchmark's functional checks measure, so a drop that
leaves those rows makes the next run report its predecessor's data. One run
claimed "all 39,602 rows queryable" for 19,802 events.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))

from benchmark.lib import config as config_lib                 # noqa: E402
from benchmark.lib.context import Context                      # noqa: E402
from benchmark.lib.log import Log                              # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def main():
    cfg = config_lib.load(os.path.join(ROOT, "benchmark-config.yaml"), {})
    cfg["run"]["id"] = "test-drop-realtime"
    ctx = Context(cfg, log=Log(None, quiet=True), with_sampler=False)
    ds_id = cfg["datasets"]["telemetry_id"]
    druid = ctx.druid

    before = druid.count(ds_id)
    tasks = druid.running_tasks(ds_id)
    print("rows before:      %s" % f"{before:,}")
    print("running task(s):  %s" % (", ".join(t[:60] for t in tasks) or "none"))

    if not before:
        print("SKIP no rows in %s -- run a benchmark first, then re-run this"
              % druid.datasource(ds_id))
        return 0

    ok = druid.drop_datasource(ds_id)
    after = druid.count(ds_id)
    still = druid.running_tasks(ds_id)
    print("drop returned:    %s" % ok)
    print("rows after:       %s" % f"{after:,}")
    print("running task(s):  %s" % (", ".join(t[:60] for t in still) or "none"))

    if after == 0 and ok and not still:
        print("PASS the datasource is empty and no indexing task survives")
        return 0
    print("FAIL %s row(s) and %d task(s) survived the drop" % (after, len(still)))
    return 1


if __name__ == "__main__":
    sys.exit(main())
