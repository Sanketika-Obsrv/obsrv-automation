#!/usr/bin/env python3
"""Create the benchmark datasets (master + telemetry) without publishing them."""

import sys

import _common
from benchmark.agents import dataset_engineering


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("--which", choices=["master", "telemetry", "both"], default="both")
    p.add_argument("--print-only", action="store_true",
                   help="print the request bodies instead of calling the API")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)
    cfg = ctx.cfg

    bodies = {}
    if args.which in ("master", "both"):
        bodies["master"] = dataset_engineering.master_request(cfg)
    if args.which in ("telemetry", "both"):
        bodies["telemetry"] = dataset_engineering.telemetry_request(
            cfg, cfg["datasets"].get("denorm_strategy", "jsonata"))

    if args.print_only:
        _common.dump(bodies)
        return 0
    for kind, body in bodies.items():
        ds = body["dataset_id"]
        if ctx.api.exists(ds):
            print("%s: %s already exists" % (kind, ds))
            continue
        ctx.api.create(body)
        print("%s: created %s" % (kind, ds))
    return 0


if __name__ == "__main__":
    sys.exit(main())
