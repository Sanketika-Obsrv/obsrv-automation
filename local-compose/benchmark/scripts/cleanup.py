#!/usr/bin/env python3
"""Remove benchmark datasets, their Druid datasources and their supervisors.

Retire -> delete through the API, then terminate the supervisor and drop the
datasource: deleting the dataset alone leaves the supervisor running and the
segments queryable, so the next run's row counts start above zero.
"""

import sys

import _common
from benchmark.agents import dataset_engineering


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("datasets", nargs="*",
                   help="dataset ids (default: the two from the config)")
    p.add_argument("--all-probes", action="store_true",
                   help="also remove anything whose id starts with probe_ or demo_")
    p.add_argument("--yes", action="store_true", help="do not prompt")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)

    targets = list(args.datasets) or [ctx.cfg["datasets"]["telemetry_id"],
                                      ctx.cfg["datasets"]["master_id"]]
    if args.all_probes:
        for row in ctx.docker.psql(
                "SELECT dataset_id FROM datasets WHERE dataset_id LIKE 'probe%' "
                "OR dataset_id LIKE 'demo%';"):
            if row not in targets:
                targets.append(row)

    print("will remove: %s" % ", ".join(targets))
    if not args.yes:
        if input("proceed? [y/N] ").strip().lower() not in ("y", "yes"):
            return 1
    for ds in targets:
        try:
            dataset_engineering._drop(ctx, ds)
            print("removed %s" % ds)
        except Exception as exc:                                # noqa: BLE001
            print("could not remove %s: %s" % (ds, exc))
    return 0


if __name__ == "__main__":
    sys.exit(main())
