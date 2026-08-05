"""Unified Pipeline Benchmark Agent -- Flink throughput, latency, health.

Answers, from the drain window only: how fast did the job move records, which
operator was the constraint, what did the JVM cost, and did checkpointing or a
restart interrupt anything.

Operator attribution is the part worth explaining. Flink reports two ratios per
vertex: busy and backpressured. An operator that is backpressured is waiting on
something downstream, so it is a victim, not a cause. The bottleneck is the
operator that is busy and NOT backpressured -- it has work queued behind it and
nothing ahead of it holding it up.
"""

from ..lib import stats


def analyze(ctx):
    cfg, log = ctx.cfg, ctx.log
    log.phase("Unified Pipeline Benchmark Agent", "Flink throughput and health")
    res = ctx.results.setdefault("pipeline", {})
    samples = _window(ctx, ctx.sampler.flink_samples)
    res["samples"] = len(samples)

    if len(samples) < 2:
        log.warn("not enough Flink samples to derive a rate")
        res["throughput"] = {"samples": len(samples)}
        return res

    first, last = samples[0], samples[-1]
    res["job_id"] = last.get("job_id")
    res["state"] = last.get("state")
    res["parallelism"] = max((v.get("parallelism") or 0)
                             for v in (last.get("vertices") or [{}]))
    res["slots_total"] = last.get("slots_total")

    res["throughput_in"] = stats.rate_summary(samples, "records_in")
    res["throughput_out"] = stats.rate_summary(samples, "records_out")
    res["sustained_per_sec"] = res["throughput_out"].get("sustained_per_sec")
    res["peak_per_sec"] = res["throughput_out"].get("peak_per_sec")
    res["records_in_total"] = (last.get("records_in") or 0) - (first.get("records_in") or 0)
    res["records_out_total"] = (last.get("records_out") or 0) - (first.get("records_out") or 0)

    res["vertices"] = _vertex_analysis(samples)
    res["bottleneck_operator"] = _bottleneck(res["vertices"])

    res["jvm"] = {
        "heap_used": stats.summarize([s.get("jvm_heap_used") for s in samples], "bytes"),
        "heap_max": last.get("jvm_heap_max"),
        "heap_pct_peak": round(
            100.0 * (stats.pct([s.get("jvm_heap_used") for s in samples], 95) or 0)
            / last["jvm_heap_max"], 1) if last.get("jvm_heap_max") else None,
        "nonheap_used": stats.summarize([s.get("jvm_nonheap_used") for s in samples], "bytes"),
        "cpu_load": stats.summarize([s.get("jvm_cpu_load") for s in samples], "ratio"),
        "threads": last.get("jvm_threads"),
        # GC counters are cumulative, so the run's cost is the difference, and
        # the share of wall clock spent in GC is what actually matters.
        "gc_young_ms": _delta(first, last, "gc_young_ms"),
        "gc_old_ms": _delta(first, last, "gc_old_ms"),
    }
    window = (last.get("t") or 0) - (first.get("t") or 0)
    gc_ms = (res["jvm"]["gc_young_ms"] or 0) + (res["jvm"]["gc_old_ms"] or 0)
    res["jvm"]["gc_pct_of_wall"] = round(100.0 * gc_ms / (window * 1000.0), 2) if window else None

    res["checkpoints"] = {
        "completed": _delta(first, last, "checkpoint_count"),
        "failed": last.get("checkpoint_failed"),
        "duration_ms": stats.summarize(
            [s.get("checkpoint_last_ms") for s in samples], "ms"),
        "avg_ms_reported": last.get("checkpoint_avg_ms"),
    }

    tm = ctx.sampler.container_series("up_taskmanager")
    res["taskmanager"] = _container_summary(tm)
    jm = ctx.sampler.container_series("up_jobmanager")
    res["jobmanager"] = _container_summary(jm)

    # A job that restarted mid-drain invalidates the latency numbers -- the
    # source rewinds to the last checkpoint and reprocesses -- so it is called
    # out rather than averaged away.
    states = {s.get("state") for s in samples}
    res["states_seen"] = sorted(x for x in states if x)
    res["restarted_mid_run"] = len(states - {"RUNNING", None}) > 0
    if res["restarted_mid_run"]:
        log.warn("job state changed during the drain (%s) -- throughput and latency "
                 "cover a run that was interrupted" % ", ".join(res["states_seen"]))

    log.info("pipeline out: sustained %s rec/s, peak %s rec/s (%s records over %s)"
             % (stats.human_count(res["sustained_per_sec"]),
                stats.human_count(res["peak_per_sec"]),
                f"{res['records_out_total']:,}", stats.human_dur(window)))
    if res["jvm"]["heap_pct_peak"] is not None:
        log.info("taskmanager JVM heap peak %.0f%% of max, %.2f%% of wall clock in GC"
                 % (res["jvm"]["heap_pct_peak"], res["jvm"]["gc_pct_of_wall"] or 0))
    if res["bottleneck_operator"]:
        b = res["bottleneck_operator"]
        log.info("busiest operator: %s (busy %.0f%%, backpressured %.0f%%)"
                 % (b["name"], 100 * (b["busy_avg"] or 0), 100 * (b["backpressured_avg"] or 0)))

    if res["vertices"]:
        log.table(
            ["operator", "par", "busy%", "bp%", "rec/s out"],
            [[v["name"][:44], v["parallelism"],
              "%.0f" % (100 * (v["busy_avg"] or 0)),
              "%.0f" % (100 * (v["backpressured_avg"] or 0)),
              stats.human_count(v["out_per_sec"])] for v in res["vertices"]],
        )
    return res


def csv_rows(ctx):
    rows = []
    for s in ctx.sampler.flink_samples:
        rows.append({
            "elapsed_sec": round(s.get("elapsed", 0), 2),
            "state": s.get("state"),
            "records_in": s.get("records_in"),
            "records_out": s.get("records_out"),
            "slots_total": s.get("slots_total"),
            "slots_free": s.get("slots_free"),
            "jvm_heap_used": s.get("jvm_heap_used"),
            "jvm_heap_max": s.get("jvm_heap_max"),
            "jvm_cpu_load": s.get("jvm_cpu_load"),
            "jvm_threads": s.get("jvm_threads"),
            "gc_young_ms": s.get("gc_young_ms"),
            "gc_old_ms": s.get("gc_old_ms"),
            "checkpoint_count": s.get("checkpoint_count"),
            "checkpoint_last_ms": s.get("checkpoint_last_ms"),
            "max_busy_ratio": max([v.get("busy_ratio") or 0
                                   for v in s.get("vertices") or []] or [0]),
            "max_backpressured_ratio": max([v.get("backpressured_ratio") or 0
                                            for v in s.get("vertices") or []] or [0]),
        })
    return rows


# --- helpers -----------------------------------------------------------------
def _window(ctx, samples):
    """Restrict a series to the drain window.

    Samples taken while the TaskManager was down, or after the backlog was
    gone, would drag every rate toward zero and make a saturated pipeline look
    half idle.
    """
    lo = getattr(ctx, "drain_start", None)
    hi = getattr(ctx, "drain_end", None)
    if lo is None:
        return list(samples)
    return [s for s in samples
            if s.get("t", 0) >= lo and (hi is None or s.get("t", 0) <= hi + 5)]


def _delta(first, last, key):
    a, b = first.get(key), last.get(key)
    if a is None or b is None:
        return None
    return max(0, b - a)


def _vertex_analysis(samples):
    """Per-operator averages across the window, keyed by operator id."""
    acc = {}
    for s in samples:
        for v in s.get("vertices") or []:
            e = acc.setdefault(v.get("id") or v.get("name"), {
                "name": v.get("name", "?"), "parallelism": v.get("parallelism"),
                "busy": [], "bp": [], "series": [],
            })
            if v.get("busy_ratio") is not None:
                e["busy"].append(v["busy_ratio"])
            if v.get("backpressured_ratio") is not None:
                e["bp"].append(v["backpressured_ratio"])
            e["series"].append({"t": s["t"], "out": v.get("records_out") or 0})
    out = []
    for e in acc.values():
        rate = stats.rate_summary(e["series"], "out")
        out.append({
            "name": e["name"],
            "parallelism": e["parallelism"],
            "busy_avg": round(sum(e["busy"]) / len(e["busy"]), 4) if e["busy"] else None,
            "busy_p95": stats.pct(e["busy"], 95),
            "backpressured_avg": round(sum(e["bp"]) / len(e["bp"]), 4) if e["bp"] else None,
            "out_per_sec": rate.get("sustained_per_sec"),
            "out_total": rate.get("total"),
        })
    return out


def _bottleneck(vertices):
    """Busiest operator that is not itself waiting on a downstream one."""
    candidates = [v for v in vertices if v.get("busy_avg") is not None]
    if not candidates:
        return None
    scored = sorted(candidates,
                    key=lambda v: (v["busy_avg"] - (v.get("backpressured_avg") or 0)),
                    reverse=True)
    top = scored[0]
    return top if (top.get("busy_avg") or 0) > 0.05 else None


def _container_summary(series):
    if not series:
        return {}
    return {
        "cpu_pct": stats.summarize([s.get("cpu_pct") for s in series], "%"),
        "mem_anon_bytes": stats.summarize([s.get("mem_anon_bytes") for s in series], "bytes"),
        "mem_limit_bytes": series[-1].get("mem_limit_bytes"),
        "mem_pct_of_limit_peak": stats.pct(
            [s.get("mem_pct_of_limit") for s in series], 95),
    }
