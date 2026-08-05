#!/usr/bin/env python3
"""Watch Druid indexing: queryable rows, rows/sec, supervisor lag, tasks, segments."""

import sys
import time

import _common
from benchmark.lib import stats


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("-i", "--interval", type=int, default=10)
    p.add_argument("-n", "--count", type=int, default=0)
    p.add_argument("-d", "--dataset", help="default: the telemetry dataset")
    p.add_argument("--until", type=int, help="stop once this row count is queryable")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)
    ds = args.dataset or ctx.cfg["datasets"]["telemetry_id"]

    print("datasource: %s" % ctx.druid.datasource(ds))
    print("%-9s %12s %10s %10s %8s %9s %s"
          % ("elapsed", "rows", "rows/s", "sup.lag", "tasks", "segments", "state"))
    t0, prev, taken = time.time(), None, 0
    try:
        while True:
            now = time.time()
            rows = ctx.druid.count(ds)
            sup = ctx.druid.supervisor_status(ds) or {}
            payload = sup.get("payload") or {}
            tc = ctx.druid.task_counts()
            seg = ctx.druid.segments(ds)
            rate = ((rows - prev[1]) / (now - prev[0])) if prev and now > prev[0] else 0.0
            print("%-9s %12s %10s %10s %8s %9s %s"
                  % (stats.human_dur(now - t0), f"{rows:,}", stats.human_count(rate),
                     payload.get("aggregateLag", "-"),
                     "%s/%s" % (tc.get("running", 0), tc.get("pending", 0)),
                     seg.get("segments", "-"), payload.get("detailedState", "-")))
            prev, taken = (now, rows), taken + 1
            if args.until and rows >= args.until:
                break
            if args.count and taken >= args.count:
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
