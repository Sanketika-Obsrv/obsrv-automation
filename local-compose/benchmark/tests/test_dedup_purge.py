#!/usr/bin/env python3
"""Dropping a dataset has to clear its dedup keys. Needs a live local stack.

    python3 benchmark/tests/test_dedup_purge.py

Why this exists. The preprocessor's duplicate store keys on the dataset *name*:

    bench_telemetry:probe-0-0001    ->  (ttl 3600)

The name is stable across a drop-and-recreate, and the TTL is an hour, so the
keys outlive the dataset they belong to. The probe corpus is generated from a
fixed seed on purpose -- same seed, same corpus, comparable runs -- which means
run N+1 republishes run N's exact mids. Inside that hour every one of them is a
duplicate.

That is not a hypothetical. It reported as:

    unified_pipeline_processing  FAIL  0 of 100 probe events reached ... in 7m05s

with every component healthy, the supervisor running, and 223 messages on the
`failed` topic all reading ERR_PP_1010 Duplicate event found. A benchmark that
only produces valid numbers on a stack idle for an hour is not reproducible.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(
    os.path.abspath(__file__)))))

from benchmark.agents.dataset_engineering import (                     # noqa: E402
    _dedup_keys, _purge_dedup)
from benchmark.lib import config as config_lib                         # noqa: E402
from benchmark.lib.context import Context                              # noqa: E402

DS = "benchpurge_probe_ds"
OTHER = "benchpurge_other_ds"


def main():
    ctx = Context(config_lib.load(os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "benchmark-config.yaml")))

    # Seed both namespaces the way the preprocessor would.
    for db in (0, 2):
        for i in range(3):
            ctx.docker.exec("valkey_dedup", [
                "valkey-cli", "-n", str(db), "SET",
                "%s:probe-0-%04d" % (DS, i), "1", "EX", "3600"], check=False)
    ctx.docker.exec("valkey_dedup", [
        "valkey-cli", "-n", "2", "SET", "%s:probe-0-0001" % OTHER, "1",
        "EX", "3600"], check=False)

    before = _dedup_keys(ctx, DS)
    print("seeded %d key(s) for %s: %s" % (len(before), DS, before[:4]))
    assert len(before) >= 6, "seeding failed -- cannot test the purge"

    removed = _purge_dedup(ctx, DS)
    after = _dedup_keys(ctx, DS)
    survivor = _dedup_keys(ctx, OTHER)

    print("purge removed %d, %d left for %s, %d left for %s"
          % (removed, len(after), DS, len(survivor), OTHER))

    failures = []
    if after:
        failures.append("keys survived the purge: %s" % after[:5])
    if not survivor:
        failures.append("the purge deleted another dataset's keys -- too broad")

    # Leave nothing behind.
    _purge_dedup(ctx, OTHER)

    if failures:
        for f in failures:
            print("FAIL %s" % f)
        return 1
    print("PASS dedup keys are removed for the dataset and only that dataset")
    return 0


if __name__ == "__main__":
    sys.exit(main())
