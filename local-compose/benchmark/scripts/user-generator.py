#!/usr/bin/env python3
"""Generate the user master dataset as NDJSON (bare records, ready to produce)."""

import os
import sys

import _common
from benchmark.agents import telemetry_generation


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("-n", "--count", type=int, help="number of profiles")
    p.add_argument("-o", "--out", default="users.ndjson")
    p.add_argument("--seed", type=int)
    args = p.parse_args(argv)
    cfg = _common.load_cfg(args)

    count = args.count or cfg["users"]["count"]
    seed = args.seed if args.seed is not None else cfg["users"]["seed"]
    users = telemetry_generation.generate_users(count, seed)
    path = telemetry_generation.write_users_ndjson(users, os.path.abspath(args.out))
    print("%d user profiles -> %s" % (len(users), path))
    print("sample: %s" % users[0])
    return 0


if __name__ == "__main__":
    sys.exit(main())
