#!/usr/bin/env python3
"""Run the functional validation suite: dedup, transformation, denorm, queries.

Sends its own small deterministic probe set, so it can be run against a
deployment that has never seen a benchmark.
"""

import sys

import _common
from benchmark.agents import dataset_engineering, telemetry_generation, validation


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("--json", action="store_true", help="print the evidence as JSON")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)

    ctx.users = telemetry_generation.generate_users(ctx.cfg["users"]["count"],
                                                    ctx.cfg["users"]["seed"])
    ctx.entry_topic = ctx.docker.psql_one(
        "SELECT entry_topic FROM datasets WHERE dataset_id='%s';"
        % ctx.cfg["datasets"]["telemetry_id"]) or ctx.cfg["kafka"]["ingest_topic"]
    ctx.results["datasets"] = {
        "master": {"dataset_id": ctx.cfg["datasets"]["master_id"],
                   "redis_db": dataset_engineering._redis_db(
                       ctx, ctx.cfg["datasets"]["master_id"])},
        "telemetry": {"dataset_id": ctx.cfg["datasets"]["telemetry_id"]},
    }

    res = validation.run(ctx)
    if args.json:
        _common.dump(res)
    return 0 if res.get("all_passed") else 1


if __name__ == "__main__":
    sys.exit(main())
