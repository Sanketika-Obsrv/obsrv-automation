#!/usr/bin/env python3
"""Publish a dataset (Draft -> ReadyToPublish -> Live) and wait for Live.

Publishing a telemetry dataset also restarts the unified pipeline, because
the Flink job reads transformations_config once at job startup: a dataset
published into a running job gets its Druid columns but every transformed
value is null, with nothing on transform.failed to explain it.
"""

import sys

import _common


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("dataset_id", nargs="?", help="default: the telemetry dataset")
    p.add_argument("--no-restart", action="store_true",
                   help="skip the unified-pipeline restart")
    args = p.parse_args(argv)
    ctx = _common.context(args, with_sampler=False)

    ds = args.dataset_id or ctx.cfg["datasets"]["telemetry_id"]
    if not ctx.api.exists(ds):
        print("dataset %s does not exist" % ds)
        return 1
    if not ctx.api.publish(ds):
        print("%s did not reach Live" % ds)
        return 1
    print("%s is Live" % ds)

    if not args.no_restart and ds != ctx.cfg["datasets"]["master_id"]:
        print("restarting unified-pipeline so it loads the transformations...")
        ok = ctx.pipeline.restart_job(timeout_sec=ctx.cfg["pipeline"]["resume_timeout_sec"])
        print("unified-pipeline %s" % ("RUNNING" if ok else "did NOT return to RUNNING"))
        return 0 if ok else 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
