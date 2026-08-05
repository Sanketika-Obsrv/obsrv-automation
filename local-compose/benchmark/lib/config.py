"""Config loading: YAML file, deep-merged onto defaults, then env overrides.

The defaults here are the whole point of "changing the benchmark should only
require modifying the YAML file" -- a config file that omits everything but
`load.events` still runs, and the file that ships is a fully-commented
version of exactly these values.
"""

import copy
import os
import time

from . import miniyaml

DEFAULTS = {
    "run": {
        "id": None,                     # None -> generated as bench-YYYYmmdd-HHMMSS
        "output_dir": "results",
        "profile": "standard",          # smoke | standard | heavy -- see PROFILES
        "keep_going": True,             # a failed validation does not abort the run
        "cleanup": False,               # drop datasets/datasources at the end
        "cleanup_on_failure": False,
        "skip_queries": False,          # measure ingest only; leave steps 11-12 out
    },
    "endpoints": {
        "dataset_api": "http://localhost:3000",
        "keycloak": "http://localhost:8080/auth",
        "druid_router": "http://localhost:8888",
        "druid_coordinator": "http://localhost:8081",
        "flink_unified": "http://localhost:8181",
        "flink_cache_indexer": "http://localhost:8182",
        "prometheus": "http://localhost:9090",
        "node_exporter": "http://localhost:9100",
    },
    "auth": {
        "realm": "obsrv",
        "client_id": "obsrv-console",
        "username": "obsrv_admin",
        "password": "enDoPvTAxFSd",
        "druid_user": "admin",
        "druid_password": "admin123",
    },
    "docker": {
        "compose_dir": None,            # None -> the local-compose dir above this one
        "compose_file": "docker-compose.yaml",
        "container_prefix": "obsrv",
        "containers": {},               # role -> container name overrides
        "kafka_bin": "/opt/kafka/bin",
    },
    "kafka": {
        "bootstrap_internal": "localhost:9092",   # as seen from inside the broker
        "ingest_topic": "ingest",
        "consumer_group": "unified-pipeline-group",
        "masterdata_consumer_group": "masterdata-pipeline-group",
        "failed_topics": [
            "failed", "extractor.failed", "transform.failed",
            "denorm.failed", "masterdata.failed",
        ],
    },
    "datasets": {
        "master_id": "bench_users",
        "telemetry_id": "bench_telemetry",
        "denorm_out_field": "user",
        "recreate": True,               # drop and rebuild if they already exist
    },
    "users": {
        "count": 100,
        "seed": 20260804,
    },
    "load": {
        "events": 20000,
        "producer_rate": 0,             # events/sec, 0 = as fast as the broker takes
        "batch_size": 5000,             # lines per producer flush
        "concurrent_producers": 2,
        "event_size_bytes": [400, 4000],   # payload padding range, for size variety
        "large_event_fraction": 0.25,   # share with edata.size > 100000
        "duplicate_fraction": 0.02,     # share re-emitted with the same mid
        "timestamp_spread_minutes": 30,
        "seed": 20260804,
    },
    "pipeline": {
        "pause_before_load": True,      # build the backlog with the job stopped
        "pause_target": "up_taskmanager",
        "resume_timeout_sec": 300,
        "drain_timeout_sec": 1800,
        "drain_idle_sec": 60,           # lag 0 held this long = drained
    },
    "monitor": {
        "poll_interval_sec": 5,         # kafka/flink/druid/infra sampling
        "report_interval_sec": 60,      # per-minute console rollup
        "druid_settle_timeout_sec": 900,
    },
    "queries": {
        "warmup": 3,
        "iterations": 12,
        "concurrency": 4,
        "timeout_sec": 60,
        "qps_probe_seconds": 20,        # saturation probe for the QPS estimate
    },
    "validation": {
        "functional_events": 200,       # small, deterministic set for the feature checks
        "dedup_probe_events": 25,
        "settle_timeout_sec": 420,
    },
    "capacity": {
        # Targets the executive summary answers yes/no against.
        "targets_per_min": [10000, 100000],
        "safe_headroom": 0.7,           # recommend 70% of sustained as production-safe
        "cpu_saturation_pct": 85.0,
        "mem_saturation_pct": 90.0,
    },
    "report": {
        "html": True,
        "csv": True,
        "top_n_recommendations": 12,
    },
}

# Named presets, applied under the YAML but over DEFAULTS. Nothing here is
# reachable except through run.profile, so a config file that sets values
# explicitly always wins.
PROFILES = {
    "smoke": {
        "users": {"count": 25},
        "load": {"events": 2000, "concurrent_producers": 1},
        "queries": {"iterations": 5, "concurrency": 2, "qps_probe_seconds": 10},
        "validation": {"functional_events": 100},
    },
    "standard": {},
    "heavy": {
        "load": {"events": 500000, "concurrent_producers": 4, "batch_size": 20000},
        "queries": {"iterations": 25, "concurrency": 8, "qps_probe_seconds": 45},
        "pipeline": {"drain_timeout_sec": 5400},
        "monitor": {"druid_settle_timeout_sec": 2700},
    },
}

# Environment overrides, for the cases where editing the YAML is the wrong
# move -- a CI job varying only the volume, or a secret that should not be in
# a file. OBSRV_BENCH_<PATH_WITH_UNDERSCORES>.
ENV_PREFIX = "OBSRV_BENCH_"


def deep_merge(base, over):
    out = copy.deepcopy(base)
    for k, v in (over or {}).items():
        if isinstance(v, dict) and isinstance(out.get(k), dict):
            out[k] = deep_merge(out[k], v)
        else:
            out[k] = copy.deepcopy(v)
    return out


def _coerce(old, raw):
    if isinstance(old, bool):
        return raw.strip().lower() in ("1", "true", "yes", "on")
    if isinstance(old, int) and not isinstance(old, bool):
        return int(raw)
    if isinstance(old, float):
        return float(raw)
    if isinstance(old, list):
        return [x.strip() for x in raw.split(",") if x.strip()]
    return raw


def apply_env(cfg):
    """OBSRV_BENCH_LOAD_EVENTS=1000000 -> cfg['load']['events'] = 1000000."""
    flat = {}

    def walk(node, path):
        for k, v in node.items():
            p = path + [k]
            if isinstance(v, dict):
                walk(v, p)
            else:
                flat["_".join(p).upper()] = (p, v)

    walk(cfg, [])
    for env_key, val in os.environ.items():
        if not env_key.startswith(ENV_PREFIX):
            continue
        target = env_key[len(ENV_PREFIX):]
        if target not in flat:
            continue
        path, old = flat[target]
        node = cfg
        for k in path[:-1]:
            node = node[k]
        try:
            node[path[-1]] = _coerce(old, val)
        except ValueError:
            node[path[-1]] = val
    return cfg


def _pick_profile(file_cfg, overrides):
    """Which PROFILES entry to merge in.

    The profile selects one of the dicts being merged, so it has to be known
    before the merge runs -- which means it cannot come out of the merged
    config the way every other key does. It reads the same precedence chain by
    hand instead: env, then --set, then the file, then the default. Reading
    only the file here is what made `--profile smoke` silently run 20k events.
    """
    profile = (os.environ.get(ENV_PREFIX + "RUN_PROFILE")
               or ((overrides or {}).get("run") or {}).get("profile")
               or (file_cfg.get("run") or {}).get("profile")
               or DEFAULTS["run"]["profile"])
    if profile not in PROFILES:
        raise ValueError("unknown run.profile %r (have: %s)"
                         % (profile, ", ".join(sorted(PROFILES))))
    return profile


def load(path=None, overrides=None):
    """Build the effective config. `overrides` is a dict of CLI --set values."""
    file_cfg = {}
    if path:
        if not os.path.exists(path):
            raise FileNotFoundError("config file not found: %s" % path)
        file_cfg = miniyaml.load_file(path) or {}

    profile = _pick_profile(file_cfg, overrides)
    cfg = deep_merge(DEFAULTS, PROFILES[profile])
    cfg = deep_merge(cfg, file_cfg)
    cfg = deep_merge(cfg, overrides or {})
    cfg = apply_env(cfg)

    if not cfg["run"].get("id"):
        cfg["run"]["id"] = "bench-" + time.strftime("%Y%m%d-%H%M%S")
    if cfg["docker"].get("compose_dir") is None:
        cfg["docker"]["compose_dir"] = os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", ".."))
    cfg["run"]["config_path"] = os.path.abspath(path) if path else None
    cfg["run"]["profile"] = profile
    validate(cfg)
    return cfg


def validate(cfg):
    """Fail on the mistakes that would otherwise surface as a bad report."""
    problems = []
    if cfg["load"]["events"] < 1:
        problems.append("load.events must be >= 1")
    if cfg["load"]["concurrent_producers"] < 1:
        problems.append("load.concurrent_producers must be >= 1")
    if not 0 <= cfg["load"]["duplicate_fraction"] < 1:
        problems.append("load.duplicate_fraction must be in [0, 1)")
    if not 0 <= cfg["load"]["large_event_fraction"] <= 1:
        problems.append("load.large_event_fraction must be in [0, 1]")
    lo, hi = cfg["load"]["event_size_bytes"][:2]
    if lo > hi:
        problems.append("load.event_size_bytes must be [min, max]")
    if cfg["users"]["count"] < 1:
        problems.append("users.count must be >= 1")
    if cfg["queries"]["concurrency"] < 1:
        problems.append("queries.concurrency must be >= 1")
    if cfg["monitor"]["poll_interval_sec"] < 1:
        problems.append("monitor.poll_interval_sec must be >= 1")
    if cfg["datasets"]["master_id"] == cfg["datasets"]["telemetry_id"]:
        problems.append("datasets.master_id and datasets.telemetry_id must differ")
    if problems:
        raise ValueError("invalid config:\n  - " + "\n  - ".join(problems))
    return cfg


def parse_set(pairs):
    """--set load.events=50000 -> {"load": {"events": "50000"}} (typed later)."""
    out = {}
    for pair in pairs or []:
        if "=" not in pair:
            raise ValueError("--set expects key.path=value, got %r" % pair)
        key, _, val = pair.partition("=")
        node = out
        parts = [p for p in key.strip().split(".") if p]
        if not parts:
            raise ValueError("--set expects key.path=value, got %r" % pair)
        for p in parts[:-1]:
            node = node.setdefault(p, {})
        # Reuse the YAML scalar rules so --set load.events=50000 is an int and
        # --set run.cleanup=true is a bool.
        node[parts[-1]] = miniyaml.loads("v: " + val.strip())["v"]
    return out


def run_dir(cfg):
    base = cfg["run"]["output_dir"]
    if not os.path.isabs(base):
        base = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), base)
    return os.path.join(base, cfg["run"]["id"])
