#!/usr/bin/env python3
"""Generate the telemetry corpus as NDJSON, wrapped for the ingest topic."""

import os
import sys

import _common
from benchmark.agents import telemetry_generation


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("-n", "--events", type=int, help="number of events")
    p.add_argument("-o", "--out", default="telemetry.ndjson")
    p.add_argument("--users", help="users NDJSON to draw actor.id from "
                                   "(default: regenerate from the config seed)")
    args = p.parse_args(argv)
    cfg = _common.load_cfg(args)
    if args.events:
        cfg["load"]["events"] = args.events

    if args.users:
        import json
        with open(args.users, encoding="utf-8") as fh:
            users = [json.loads(l) for l in fh if l.strip()]
    else:
        users = telemetry_generation.generate_users(cfg["users"]["count"],
                                                    cfg["users"]["seed"])
    manifest = telemetry_generation.generate_telemetry(
        os.path.abspath(args.out), cfg["datasets"]["telemetry_id"],
        cfg["load"]["events"], users, cfg)
    _common.dump(manifest)
    return 0


if __name__ == "__main__":
    sys.exit(main())
