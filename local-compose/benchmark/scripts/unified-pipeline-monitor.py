#!/usr/bin/env python3
"""Watch the unified pipeline: throughput, backpressure, JVM, checkpoints.

Also the pause/resume control surface. Pausing stops the TaskManager rather
than cancelling the job: cancelling discards committed offsets, and the fresh
source then falls back to LATEST and skips the whole backlog while reporting
a perfect drain.
"""

import sys
import time

import _common
from benchmark.lib import stats


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("-i", "--interval", type=int, default=5)
    p.add_argument("-n", "--count", type=int, default=0)
    p.add_argument("--pause", action="store_true", help="stop the TaskManager and exit")
    p.add_argument("--resume", action="store_true", help="start the TaskManager and exit")
    p.add_argument("--restart", action="store_true", help="restart the job and exit")
    p.add_argument("--which", choices=["unified", "cache_indexer"], default="unified")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)
    fl = ctx.pipeline if args.which == "unified" else ctx.cache_indexer
    if fl is None:
        print("cache-indexer is not running")
        return 1

    if args.pause:
        return 0 if fl.pause() else 1
    if args.resume:
        return 0 if fl.resume(timeout_sec=ctx.cfg["pipeline"]["resume_timeout_sec"]) else 1
    if args.restart:
        return 0 if fl.restart_job(timeout_sec=ctx.cfg["pipeline"]["resume_timeout_sec"]) else 1

    print("%-8s %-9s %10s %10s %12s %8s %8s"
          % ("elapsed", "state", "in/s", "out/s", "heap", "busy", "bp"))
    t0, prev, taken = time.time(), None, 0
    try:
        while True:
            s = fl.snapshot()
            now = s.get("t", time.time())
            rin = rout = 0.0
            if prev and now > prev.get("t", 0):
                dt = now - prev["t"]
                rin = max(0, (s.get("records_in") or 0) - (prev.get("records_in") or 0)) / dt
                rout = max(0, (s.get("records_out") or 0) - (prev.get("records_out") or 0)) / dt
            vs = s.get("vertices") or []
            busy = max([v.get("busy") or 0 for v in vs], default=0)
            bp = max([v.get("backpressured") or 0 for v in vs], default=0)
            print("%-8s %-9s %10s %10s %12s %7.0f%% %7.0f%%"
                  % (stats.human_dur(now - t0), s.get("state"), stats.human_count(rin),
                     stats.human_count(rout), stats.human_bytes(s.get("jvm_heap_used")),
                     100 * busy, 100 * bp))
            prev, taken = s, taken + 1
            if args.count and taken >= args.count:
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
