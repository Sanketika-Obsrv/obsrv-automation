#!/usr/bin/env python3
"""Watch consumer lag: consumed, remaining, lag reduction, events/sec, ETA.

Defaults to one sample a minute. Each sample runs kafka-consumer-groups.sh,
which starts a JVM inside the broker -- polling every few seconds on a
saturated host measurably slows down the pipeline being measured.
"""

import sys
import time

import _common
from benchmark.lib import stats


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("-i", "--interval", type=int, default=60, help="seconds between samples")
    p.add_argument("-n", "--count", type=int, default=0, help="samples to take, 0 = forever")
    p.add_argument("-t", "--topic")
    p.add_argument("-g", "--group")
    p.add_argument("--until-drained", action="store_true", help="stop when lag hits zero")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)
    topic = args.topic or ctx.cfg["kafka"]["ingest_topic"]

    print("%-9s %12s %12s %12s %10s %12s %s"
          % ("elapsed", "consumed", "remaining", "reduction", "ev/s", "ev/min", "eta"))
    t0, prev, taken = time.time(), None, 0
    try:
        while True:
            s = ctx.kafka.lag_snapshot(topic, args.group)
            s["t"] = time.time()
            if prev and s["t"] > prev["t"]:
                dt = s["t"] - prev["t"]
                delta = max(0, s["consumed"] - prev["consumed"])
                rate = delta / dt
                eta = s["remaining"] / rate if rate > 0.01 else None
                red = prev["remaining"] - s["remaining"]
            else:
                rate, eta, red = 0.0, None, 0
            print("%-9s %12s %12s %12s %10s %12s %s"
                  % (stats.human_dur(s["t"] - t0), f"{s['consumed']:,}",
                     f"{s['remaining']:,}", f"{red:,}", stats.human_count(rate),
                     stats.human_count(rate * 60), stats.human_dur(eta)))
            prev, taken = s, taken + 1
            if args.until_drained and s["remaining"] <= 0 and taken > 1:
                break
            if args.count and taken >= args.count:
                break
            time.sleep(args.interval)
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
