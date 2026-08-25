#!/usr/bin/env python3
"""Re-render the reports from a previous run's benchmark-results.json.

Useful after changing the report templates, or to regenerate the HTML from a
run captured on another machine, without touching the deployment.
"""

import json
import os
import sys

import _common
from benchmark.lib import report as report_lib


class _Replay:
    """A context with no clients: only what the renderers actually read."""

    def __init__(self, payload, run_dir):
        self.cfg = payload["config"]
        self.results = payload["results"]
        self.started_at = payload["run"].get("started_at", 0)
        self.run_dir = run_dir
        self.sampler = _Series(payload["results"].get("series", {}))

    def dir(self, name):
        path = os.path.join(self.run_dir, name)
        os.makedirs(path, exist_ok=True)
        return path


class _Series:
    """Sample series are not stored in the JSON, so a replay renders the
    analysis and tables that come from `results` and leaves the raw CSVs
    alone rather than inventing points."""

    def __init__(self, series):
        self.kafka_samples = series.get("kafka", [])
        self.flink_samples = series.get("flink", [])
        self.druid_samples = series.get("druid", [])
        self.infra_samples = series.get("infra", [])
        self.host_samples = series.get("host", [])

    def errors(self):
        return []

    def container_series(self, role):
        return [s for s in self.infra_samples if s.get("role") == role]


def main(argv=None):
    p = _common.parser(__doc__)
    p.add_argument("results", help="path to benchmark-results.json (or its run directory)")
    p.add_argument("--no-csv", action="store_true")
    args = p.parse_args(argv)

    path = args.results
    if os.path.isdir(path):
        path = os.path.join(path, "benchmark-results.json")
    with open(path, encoding="utf-8") as fh:
        payload = json.load(fh)

    ctx = _Replay(payload, os.path.dirname(os.path.abspath(path)))
    if args.no_csv:
        ctx.cfg["report"]["csv"] = False
    for written in report_lib.write_all(ctx):
        print(written)
    return 0


if __name__ == "__main__":
    sys.exit(main())
