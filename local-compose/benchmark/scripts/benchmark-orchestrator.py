#!/usr/bin/env python3
"""Run the complete eighteen-step benchmark. This is `benchmark run`."""

import sys

import _common
from benchmark import orchestrator


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("--profile", choices=["smoke", "standard", "heavy"],
                   help="shortcut for --set run.profile=...")
    p.add_argument("--events", type=int, help="shortcut for --set load.events=...")
    p.add_argument("--cleanup", action="store_true",
                   help="drop the benchmark datasets when the run finishes")
    p.add_argument("--no-queries", action="store_true",
                   help="ingest pipeline only -- skip the query benchmark (steps 11-12)")
    args = p.parse_args(argv)
    if args.no_queries:
        args.sets.append("run.skip_queries=true")
    if args.profile:
        args.sets.append("run.profile=%s" % args.profile)
    if args.events:
        args.sets.append("load.events=%d" % args.events)
    if args.cleanup:
        args.sets.append("run.cleanup=true")
    return orchestrator.run(_common.load_cfg(args))


if __name__ == "__main__":
    sys.exit(main())
