#!/usr/bin/env python3
"""Watch host and per-container CPU, memory, disk and network.

Container numbers come from the cgroup files, not `docker stats`: docker's
memory figure includes page cache, which on this workload is over 100 MB of
noise, and each call costs about a second of wall clock.
"""

import sys
import time

import _common
from benchmark.lib import stats


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("-i", "--interval", type=int, default=5)
    p.add_argument("-n", "--count", type=int, default=0)
    p.add_argument("--roles", help="comma-separated container roles (default: all)")
    p.add_argument("--host-only", action="store_true")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)
    roles = [r.strip() for r in args.roles.split(",")] if args.roles else None

    t0, taken = time.time(), 0
    try:
        while True:
            h = ctx.infra.host_sample() or {}
            print("\n[%s] host  cpu %s%%  mem %s%%  load1 %s  disk r/w %s / %s  net rx/tx %s / %s"
                  % (stats.human_dur(time.time() - t0),
                     stats.human_count(h.get("cpu_pct")), stats.human_count(h.get("mem_pct")),
                     stats.human_count(h.get("load1")),
                     stats.human_bytes(h.get("disk_read_bps")),
                     stats.human_bytes(h.get("disk_write_bps")),
                     stats.human_bytes(h.get("net_rx_bps")),
                     stats.human_bytes(h.get("net_tx_bps"))))
            if not args.host_only:
                samples = sorted(ctx.infra.sample_all(roles),
                                 key=lambda s: -(s.get("cpu_pct") or 0))
                for s in samples:
                    if not s.get("cpu_pct") and not s.get("mem_anon_bytes"):
                        continue
                    print("  %-28s cpu %6s%%  mem %10s  (%s%% of limit)"
                          % (s.get("role"), stats.human_count(s.get("cpu_pct")),
                             stats.human_bytes(s.get("mem_anon_bytes")),
                             stats.human_count(s.get("mem_pct_of_limit"))))
            taken += 1
            if args.count and taken >= args.count:
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
