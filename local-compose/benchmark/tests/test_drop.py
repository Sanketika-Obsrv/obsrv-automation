#!/usr/bin/env python3
"""Does _drop actually remove a dataset? Run against a live local stack.

    python3 benchmark/tests/test_drop.py

The contract _drop has to satisfy, and the reason each half exists:

  * No row survives in datasets_draft. The draft row is what `read?mode=edit`
    sees, so a surviving draft is what made cleanup warn.
  * No row survives in datasets. checkDatasetExists (DatasetService.ts:71)
    queries the live table with no status filter, so a Retired tombstone is
    still "exists" and the next run's create gets a 409.
  * The id can be created again afterwards. That is the only property the
    benchmark actually needs -- the two row checks above are how it fails.

The Retired case is the one that matters and it cannot be built cheaply: a
dataset only reaches Retired by going Live first, which means a real Druid
supervisor. So that case runs against whatever Retired leftovers the
deployment already has, and skips when there are none.
"""

import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from benchmark.agents import dataset_engineering                      # noqa: E402
from benchmark.lib import config as config_lib                        # noqa: E402
from benchmark.lib.context import Context                             # noqa: E402
from benchmark.lib.log import Log                                     # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def make_ctx():
    cfg = config_lib.load(os.path.join(ROOT, "benchmark-config.yaml"), {})
    cfg["run"]["id"] = "test-drop"
    return Context(cfg, log=Log(None, quiet=True), with_sampler=False)


# --- probes -------------------------------------------------------------------
def live_rows(ctx, ds):
    return int(ctx.docker.psql_one(
        "SELECT count(*) FROM datasets WHERE id='%s';" % ds, "0"))


def draft_rows(ctx, ds):
    return int(ctx.docker.psql_one(
        "SELECT count(*) FROM datasets_draft WHERE dataset_id='%s';" % ds, "0"))


def create_minimal(ctx, ds):
    """The smallest master dataset the create schema accepts."""
    req = dataset_engineering.master_request(ctx.cfg)
    req["dataset_id"] = req["name"] = ds
    return ctx.api.create(req)


def retired_leftover(ctx):
    rows = ctx.docker.psql("SELECT id FROM datasets WHERE status='Retired' ORDER BY id;")
    return rows[0] if rows else None


# --- cases --------------------------------------------------------------------
def test_drop_removes_a_draft(ctx):
    """A never-published dataset must leave nothing behind."""
    ds = "droptest_draft_%d" % int(time.time())
    create_minimal(ctx, ds)
    assert draft_rows(ctx, ds) == 1, "fixture did not create a draft row"

    dataset_engineering._drop(ctx, ds)

    assert draft_rows(ctx, ds) == 0, "draft row survived _drop"
    assert live_rows(ctx, ds) == 0, "live row survived _drop"


def test_drop_frees_the_id_for_reuse(ctx):
    """The property the benchmark depends on: the same id can be created again."""
    ds = "droptest_reuse_%d" % int(time.time())
    create_minimal(ctx, ds)
    dataset_engineering._drop(ctx, ds)

    res = create_minimal(ctx, ds)          # raises RuntimeError on 409 DATASET_EXISTS
    assert (res or {}).get("params", {}).get("status") == "SUCCESS", \
        "re-create did not succeed: %r" % res
    dataset_engineering._drop(ctx, ds)


def test_drop_removes_a_retired_dataset(ctx):
    """The real bug: Retire leaves a live tombstone that blocks the next run."""
    ds = retired_leftover(ctx)
    if not ds:
        print("    SKIP test_drop_removes_a_retired_dataset -- no Retired dataset present")
        return
    print("    (using leftover %s)" % ds)

    dataset_engineering._drop(ctx, ds)

    assert live_rows(ctx, ds) == 0, "Retired live row survived _drop -- create will 409"
    assert draft_rows(ctx, ds) == 0, "draft row survived _drop"


CASES = [test_drop_removes_a_draft,
         test_drop_frees_the_id_for_reuse,
         test_drop_removes_a_retired_dataset]


def main():
    ctx = make_ctx()
    failed = 0
    for case in CASES:
        print("--> %s" % case.__name__)
        try:
            case(ctx)
            print("    PASS")
        except AssertionError as exc:
            failed += 1
            print("    FAIL %s" % exc)
        except Exception as exc:                                    # noqa: BLE001
            failed += 1
            print("    ERROR %s: %s" % (type(exc).__name__, exc))
    print("\n%d/%d passed" % (len(CASES) - failed, len(CASES)))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
