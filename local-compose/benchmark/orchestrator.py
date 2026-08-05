"""Benchmark orchestrator -- the whole run, unattended.

The eighteen steps the requirement lists, in order, with no manual
intervention between any two of them:

   1 create datasets            10 monitor Druid indexing
   2 publish datasets           11 execute the query benchmark
   3 validate configuration     12 measure query latency
   4 generate users             13 collect infrastructure metrics
   5 generate telemetry         14 analyze throughput
   6 stop the unified pipeline  15 detect bottlenecks
   7 load Kafka                 16 generate reports
   8 start the unified pipeline 17 produce recommendations
   9 monitor Kafka consumption  18 clean up (optional)

Steps 6-8 are inside the Kafka agent's load(), because pausing, producing and
resuming is one atomic operation -- a run that pauses the pipeline and then
dies has left the deployment broken, so the resume has to live in the same
try block as the produce.

Two rules govern failure handling:

  * A phase that cannot produce meaningful numbers raises Fatal and stops the
    run. Everything measured so far is still written -- a partial report with
    honest scope beats a traceback.
  * A functional check that fails does not stop anything (unless
    run.keep_going is false). Knowing that denormalization is broken *and*
    what the throughput is, is more useful than knowing only the former.
"""

import time
import traceback

from .agents import (dataset_engineering, druid_benchmark, infrastructure_metrics,
                     kafka_benchmark, query_benchmark, reporting, telemetry_generation,
                     unified_pipeline_benchmark, validation)
from .lib import stats
from .lib.context import Context
from .lib.log import Fatal

# Everything that must be up before the first API call. The dataset API will
# happily accept a create while Kafka is down and the run will then fail three
# phases later with an unrelated symptom, so the check happens here instead.
REQUIRED_ROLES = ["postgres", "kafka", "druid", "dataset_api", "command_api",
                  "up_jobmanager", "up_taskmanager", "valkey_dedup", "valkey_denorm"]


def run(cfg, log=None):
    ctx = Context(cfg, log=log)
    log = ctx.log
    log.phase("Obsrv Benchmark", "%s | profile %s | %s events"
              % (cfg["run"]["id"], cfg["run"]["profile"], f"{cfg['load']['events']:,}"))
    log.info("output: %s" % ctx.run_dir)
    log.event("run_start", config=cfg)

    failure = None
    try:
        preflight(ctx)                                          # 3 (part 1)
        dataset_engineering_phase(ctx)                          # 1, 2
        telemetry_generation.run(ctx)                           # 4, 5
        validation_phase(ctx)                                   # 3 (part 2)
        load_and_drain(ctx)                                     # 6, 7, 8, 9
        druid_benchmark.settle(ctx)                             # 10
        analysis_phase(ctx)                                     # 13, 14
        if cfg["run"]["skip_queries"]:
            log.info("skipping the query benchmark (run.skip_queries) -- the report "
                     "covers ingest only")
        else:
            query_benchmark.run(ctx)                            # 11, 12
        reporting.analyze(ctx)                                  # 15, 17
    except Fatal as exc:
        failure = str(exc)
        log.error(str(exc))
        log.event("run_fatal", error=str(exc))
    except KeyboardInterrupt:
        failure = "interrupted"
        log.warn("interrupted -- writing a report from what was measured so far")
    except Exception as exc:                                    # noqa: BLE001
        failure = "%s: %s" % (type(exc).__name__, exc)
        log.error(failure)
        log.event("run_error", error=failure, traceback=traceback.format_exc())
    finally:
        if ctx.sampler:
            ctx.sampler.stop()

    ctx.results["run_failure"] = failure
    written = []
    try:
        written = reporting.write(ctx)                          # 16
    except Exception as exc:                                    # noqa: BLE001
        log.error("report generation failed: %s" % exc)
        log.event("report_error", error=str(exc), traceback=traceback.format_exc())

    if cfg["run"]["cleanup"] and (failure is None or cfg["run"]["cleanup_on_failure"]):
        cleanup(ctx)                                            # 18

    _final_summary(ctx, written, failure)
    ctx.log.close()
    return 0 if (failure is None and _functional_ok(ctx, cfg)) else 1


# --- phases -------------------------------------------------------------------
def preflight(ctx):
    """Step 3a: the deployment is actually able to run a benchmark."""
    log = ctx.log
    log.phase("Preflight", "deployment health")
    missing = []
    rows = []
    for role in REQUIRED_ROLES:
        state, health = ctx.docker.state(role)
        rows.append([role, ctx.docker.c(role), state, health])
        if state != "running" or health == "unhealthy":
            missing.append(role)
    log.table(["role", "container", "state", "health"], rows)
    if missing:
        raise Fatal("not running: %s -- start the stack first "
                    "(cd local-compose && docker compose up -d)" % ", ".join(missing))

    checks = [
        ("dataset-api", lambda: ctx.api.token() is not None),
        ("druid", lambda: bool(ctx.druid.datasources()) or True),
        ("flink unified-pipeline", lambda: ctx.pipeline.job_state() == "RUNNING"),
        ("kafka", lambda: ctx.kafka.topic_exists(ctx.cfg["kafka"]["ingest_topic"])),
    ]
    for name, probe in checks:
        try:
            ok = probe()
        except Exception as exc:                                # noqa: BLE001
            raise Fatal("%s is not reachable: %s" % (name, exc))
        if not ok:
            raise Fatal("%s did not pass its preflight check" % name)
        log.ok("%s reachable" % name)

    ctx.results["preflight"] = {
        "containers": {r[0]: {"state": r[2], "health": r[3]} for r in rows},
        "cores": ctx.infra.cores(),
        "cache_indexer": ctx.cache_indexer is not None,
        "prometheus": ctx.infra.prometheus_up(),
    }
    log.info("host: %s cores, metrics from %s"
             % (ctx.infra.cores(),
                "prometheus" if ctx.infra.prometheus_up() else "/proc via a container"))


def dataset_engineering_phase(ctx):
    """Steps 1-2. Users are generated first: the master load needs them."""
    if not ctx.users:
        ctx.users = telemetry_generation.generate_users(
            ctx.cfg["users"]["count"], ctx.cfg["users"]["seed"])
        ctx.users_file = telemetry_generation.write_users_ndjson(
            ctx.users, "%s/users.ndjson" % ctx.dir("data"))
    dataset_engineering.run(ctx)


def validation_phase(ctx):
    """Step 3b: prove every advertised feature works before measuring speed.

    Order matters. Benchmarking a pipeline whose denormalization silently
    drops every join measures a pipeline nobody would deploy, and the report
    would look excellent.
    """
    res = validation.run(ctx)
    if not res.get("all_passed") and not ctx.cfg["run"]["keep_going"]:
        raise Fatal("%d functional check(s) failed and run.keep_going is false"
                    % res.get("failed", 0))
    if not res.get("all_passed"):
        ctx.log.warn("%d functional check(s) failed -- continuing to the performance "
                     "run; the report records both" % res.get("failed", 0))


def load_and_drain(ctx):
    """Steps 6-9: pause, produce the backlog, resume, watch it drain."""
    ctx.results["baseline_failed"] = ctx.results.get("kafka", {}).get(
        "failed_before") or ctx.kafka.failed_counts()
    kafka_benchmark.load(ctx)
    ctx.sampler.start()
    ctx.log.info("sampling every %ds, Kafka rollup every %ds"
                 % (ctx.cfg["monitor"]["poll_interval_sec"],
                    ctx.cfg["monitor"]["report_interval_sec"]))
    kafka_benchmark.drain(ctx)


def analysis_phase(ctx):
    """Steps 13-14. The sampler stops here: everything after this reads series.

    Query benchmarking happens after the sampler is stopped so the query load
    does not contaminate the throughput window it would otherwise overlap.
    """
    ctx.sampler.stop()
    kafka_benchmark.analyze(ctx)
    unified_pipeline_benchmark.analyze(ctx)
    druid_benchmark.analyze(ctx)
    infrastructure_metrics.analyze(ctx)


def cleanup(ctx):
    """Step 18: put the deployment back the way it was found."""
    log = ctx.log
    log.phase("Cleanup", "removing benchmark datasets")
    removed = []
    for ds in (ctx.cfg["datasets"]["telemetry_id"], ctx.cfg["datasets"]["master_id"]):
        try:
            dataset_engineering._drop(ctx, ds)
            removed.append(ds)
            log.ok("removed %s" % ds)
        except Exception as exc:                                # noqa: BLE001
            log.warn("could not remove %s: %s" % (ds, exc))
    ctx.results["cleanup"] = {"removed": removed}


# --- reporting-out ------------------------------------------------------------
def _functional_ok(ctx, cfg):
    v = ctx.results.get("validation") or {}
    return bool(v.get("all_passed", False)) if v else False


def _final_summary(ctx, written, failure):
    log = ctx.log
    r = ctx.results
    cap = (r.get("analysis") or {}).get("capacity") or {}
    v = r.get("validation") or {}
    log.phase("Done", stats.human_dur(time.time() - ctx.started_at))
    if failure:
        log.error("run ended early: %s" % failure)
    log.info("functional: %s/%s checks passed" % (v.get("passed", 0), v.get("total", 0)))
    log.info("sustained:  %s events/sec (%s events/min)"
             % (stats.human_count(cap.get("sustained_per_sec")),
                stats.human_count(cap.get("sustained_per_min"))))
    log.info("safe rate:  %s events/min recommended for production"
             % stats.human_count(cap.get("safe_per_min")))
    log.info("bottleneck: %s"
             % ((r.get("analysis") or {}).get("bottleneck", {}).get("component", "-")))
    for path in written:
        log.info("wrote %s" % ctx.rel(path))
    errs = ctx.sampler.errors() if ctx.sampler else []
    if errs:
        log.warn("%d sampler error(s) -- see run.jsonl" % len(errs))
    log.event("run_end", failure=failure, written=written)
