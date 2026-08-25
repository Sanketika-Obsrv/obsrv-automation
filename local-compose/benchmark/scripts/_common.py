"""Shared bootstrap for the standalone scripts.

Each script under scripts/ is runnable on its own -- `python3 scripts/kafka-monitor.py`
-- which means it has to put the package root on sys.path before it can import
anything. Doing that in one place keeps the fourteen entrypoints to their
actual subject matter.
"""

import argparse
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))   # .../benchmark
if os.path.dirname(ROOT) not in sys.path:
    sys.path.insert(0, os.path.dirname(ROOT))

from benchmark.lib import config as config_lib      # noqa: E402
from benchmark.lib.context import Context           # noqa: E402
from benchmark.lib.log import Log                   # noqa: E402

DEFAULT_CONFIG = os.path.join(ROOT, "benchmark-config.yaml")


def parser(description):
    p = argparse.ArgumentParser(description=description)
    p.add_argument("-c", "--config", default=None,
                   help="YAML config (default: benchmark-config.yaml if present)")
    p.add_argument("--set", dest="sets", action="append", default=[], metavar="k.p=v",
                   help="override a config value, repeatable")
    p.add_argument("-q", "--quiet", action="store_true")
    return p


def load_cfg(args):
    path = args.config
    if path is None and os.path.exists(DEFAULT_CONFIG):
        path = DEFAULT_CONFIG
    return config_lib.load(path, config_lib.parse_set(args.sets))


def context(args, with_sampler=True, subdir=None):
    """A context whose artefacts land in the run directory, but without the
    orchestrator's phase machinery -- scripts write next to a real run's output
    so a one-off probe is comparable with the benchmark it is diagnosing."""
    cfg = load_cfg(args)
    if subdir:
        cfg["run"]["id"] = "%s-%s" % (cfg["run"]["id"], subdir)
    log = Log(os.path.join(config_lib.run_dir(cfg), "run.jsonl"), quiet=args.quiet)
    return Context(cfg, log=log, with_sampler=with_sampler)


def dump(obj):
    import json
    print(json.dumps(obj, indent=2, default=str))
