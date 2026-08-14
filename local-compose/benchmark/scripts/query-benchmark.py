#!/usr/bin/env python3
"""Benchmark the nine query classes and probe sustainable QPS."""

import sys

import _common
from benchmark.agents import query_benchmark, telemetry_generation


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("--iterations", type=int)
    p.add_argument("--concurrency", type=int)
    p.add_argument("--json", action="store_true")
    p.add_argument("--list", action="store_true", help="print the SQL and exit")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)
    if args.iterations:
        ctx.cfg["queries"]["iterations"] = args.iterations
    if args.concurrency:
        ctx.cfg["queries"]["concurrency"] = args.concurrency

    ds = ctx.druid.datasource(ctx.cfg["datasets"]["telemetry_id"])
    if args.list:
        for name, title, sql in query_benchmark.query_set(ds):
            print("\n-- %s: %s\n%s" % (name, title, sql))
        return 0

    ctx.users = telemetry_generation.generate_users(ctx.cfg["users"]["count"],
                                                    ctx.cfg["users"]["seed"])
    res = query_benchmark.run(ctx)
    if args.json:
        _common.dump(res)
    return 0


if __name__ == "__main__":
    sys.exit(main())
