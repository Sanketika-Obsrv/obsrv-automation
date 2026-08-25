"""Druid Benchmark Agent -- indexing rate, tasks, segments, end-to-end latency.

Two different things get called "Druid throughput" and this agent keeps them
apart:

  rows indexed/sec   -- what the supervisor's tasks report processing. This is
                        Druid's own view and it leads the query view.
  rows queryable/sec -- what COUNT(*) returns over time. This is what a user
                        experiences, and it lags indexing by segment handoff.

End-to-end latency is measured per event rather than inferred from the two
curves: every row carries the event's own ets and the syncts stamped when the
extractor received it, so the difference is real per-event pipeline latency
rather than a difference of averages.
"""

import time

from ..lib import stats

# Candidate column names for the extractor's arrival timestamp. Which one
# exists depends on how the deployment flattens obsrv_meta into the datasource.
_SYNCTS_CANDIDATES = ["obsrv_meta.syncts", "obsrv_meta_syncts", "syncts"]
_PROCESSED_CANDIDATES = ["obsrv_meta.processingStartTime", "obsrv_meta_processingStartTime"]


def settle(ctx):
    """Wait for Druid to make the drained events queryable."""
    cfg, log = ctx.cfg, ctx.log
    res = ctx.results.setdefault("druid", {})
    tele = cfg["datasets"]["telemetry_id"]
    expected = ctx.results["generation"]["expected_rows_after_dedup"]
    timeout = cfg["monitor"]["druid_settle_timeout_sec"]

    log.step("waiting for Druid to make %s rows queryable (timeout %s)"
             % (f"{expected:,}", stats.human_dur(timeout)))
    t0 = time.time()
    stable_since, last = None, -1
    rows = 0
    while True:
        rows = ctx.druid.count(tele)
        el = time.time() - t0
        if rows >= expected:
            break
        # A pipeline that dropped events would otherwise sit here until the
        # timeout. Once the count stops moving for two report intervals there
        # is nothing more coming, and finishing early leaves time for the rest
        # of the benchmark.
        if rows == last and rows > 0:
            stable_since = stable_since or time.time()
            if (time.time() - stable_since) >= max(90, cfg["monitor"]["report_interval_sec"] * 2):
                log.warn("row count stable at %s (%.1f%% of expected) -- "
                         "not waiting further" % (f"{rows:,}", 100.0 * rows / expected))
                break
        else:
            stable_since = None
        last = rows
        if el >= timeout:
            log.warn("Druid settle timed out with %s / %s rows"
                     % (f"{rows:,}", f"{expected:,}"))
            break
        time.sleep(cfg["monitor"]["poll_interval_sec"])

    ctx.settle_end = time.time()
    res["settle_seconds"] = round(ctx.settle_end - t0, 2)
    res["rows_queryable"] = rows
    res["rows_expected"] = expected
    res["completeness_pct"] = round(100.0 * rows / expected, 3) if expected else None
    if rows >= expected:
        log.ok("all %s rows queryable in %s after the drain"
               % (f"{rows:,}", stats.human_dur(res["settle_seconds"])))
    return res


def analyze(ctx):
    cfg, log = ctx.cfg, ctx.log
    log.phase("Druid Benchmark Agent", "indexing throughput and latency")
    res = ctx.results.setdefault("druid", {})
    tele = cfg["datasets"]["telemetry_id"]
    res["datasource"] = ctx.druid.datasource(tele)

    # --- queryable-rows rate ------------------------------------------------
    series = [s for s in ctx.sampler.druid_samples
              if s.get("t", 0) >= getattr(ctx, "drain_start", 0)]
    res["samples"] = len(series)
    res["queryable_rate"] = stats.rate_summary(series, "rows") if len(series) > 1 else {}
    res["rows_per_sec_sustained"] = res["queryable_rate"].get("sustained_per_sec")
    res["rows_per_sec_peak"] = res["queryable_rate"].get("peak_per_sec")

    # --- Druid's own indexing view -----------------------------------------
    res["supervisor"] = _supervisor(ctx, tele)
    res["tasks"] = _tasks(ctx)
    res["segments"] = ctx.druid.segments(tele)
    if res["segments"].get("segments"):
        res["segments"]["avg_rows_per_segment"] = int(
            res["segments"]["rows"] / res["segments"]["segments"])
        res["segments"]["avg_bytes_per_segment"] = int(
            res["segments"]["bytes"] / res["segments"]["segments"])

    # --- per-event latency --------------------------------------------------
    res["latency"] = _latency(ctx, tele)

    # --- resource cost ------------------------------------------------------
    dr = ctx.sampler.container_series("druid")
    if dr:
        res["container"] = {
            "cpu_pct": stats.summarize([s.get("cpu_pct") for s in dr], "%"),
            "mem_anon_bytes": stats.summarize([s.get("mem_anon_bytes") for s in dr], "bytes"),
            "mem_limit_bytes": dr[-1].get("mem_limit_bytes"),
        }

    log.info("queryable rows: sustained %s rows/s, peak %s rows/s; %d segment(s), %s"
             % (stats.human_count(res["rows_per_sec_sustained"]),
                stats.human_count(res["rows_per_sec_peak"]),
                res["segments"].get("segments", 0),
                stats.human_bytes(res["segments"].get("bytes", 0))))
    if res["supervisor"].get("rows_processed_1m") is not None:
        log.info("supervisor moving averages: %s rows/s (1m), %s rows/s (5m)"
                 % (stats.human_count(res["supervisor"]["rows_processed_1m"]),
                    stats.human_count(res["supervisor"]["rows_processed_5m"])))
    lat = res["latency"]
    if lat.get("pipeline_ms", {}).get("count"):
        p = lat["pipeline_ms"]
        log.info("event->pipeline latency: p50 %.0f ms, p95 %.0f ms, p99 %.0f ms"
                 % (p["p50"], p["p95"], p["p99"]))
    if lat.get("end_to_end_sec") is not None:
        log.info("end-to-end (first event produced -> last row queryable): %s"
                 % stats.human_dur(lat["end_to_end_sec"]))
    return res


def csv_rows(ctx):
    rows = []
    prev = None
    for s in ctx.sampler.druid_samples:
        rate = None
        if prev and s["t"] > prev["t"]:
            rate = round(max(0, s["rows"] - prev["rows"]) / (s["t"] - prev["t"]), 2)
        rows.append({
            "elapsed_sec": round(s.get("elapsed", 0), 2),
            "rows_queryable": s.get("rows"),
            "rows_per_sec": rate,
        })
        prev = s
    return rows


# --- helpers -----------------------------------------------------------------
def _supervisor(ctx, dataset_id):
    out = {"state": None}
    st = ctx.druid.supervisor_status(dataset_id)
    payload = (st or {}).get("payload") or {}
    out["state"] = payload.get("state")
    out["detailed_state"] = payload.get("detailedState")
    out["healthy"] = payload.get("healthy")
    out["active_tasks"] = len(payload.get("activeTasks") or [])
    out["publishing_tasks"] = len(payload.get("publishingTasks") or [])
    out["aggregate_lag"] = payload.get("aggregateLag")

    stat = ctx.druid.supervisor_stats(dataset_id) or {}
    # {taskGroupId: {taskId: {"movingAverages": {"buildSegments": {"1m": {...}}}}}}
    totals = {"1m": [], "5m": [], "15m": []}
    processed = errors = thrown = 0
    for group in stat.values():
        if not isinstance(group, dict):
            continue
        for task in group.values():
            if not isinstance(task, dict):
                continue
            mav = ((task.get("movingAverages") or {}).get("buildSegments") or {})
            for win in totals:
                v = (mav.get(win) or {}).get("processed")
                if isinstance(v, (int, float)):
                    totals[win].append(v)
            tot = (task.get("totals") or {}).get("buildSegments") or {}
            processed += tot.get("processed") or 0
            errors += tot.get("processedWithError") or 0
            thrown += tot.get("thrownAway") or 0
    out["rows_processed_1m"] = round(sum(totals["1m"]), 2) if totals["1m"] else None
    out["rows_processed_5m"] = round(sum(totals["5m"]), 2) if totals["5m"] else None
    out["rows_processed_15m"] = round(sum(totals["15m"]), 2) if totals["15m"] else None
    out["rows_processed_total"] = processed
    out["rows_with_error"] = errors
    out["rows_thrown_away"] = thrown
    return out


def _tasks(ctx):
    counts = ctx.druid.task_counts()
    durations = []
    for t in ctx.druid.tasks("complete")[:50]:
        d = t.get("duration")
        if isinstance(d, (int, float)) and d > 0:
            durations.append(d / 1000.0)
    counts["completed_sampled"] = len(durations)
    counts["duration_sec"] = stats.summarize(durations, "s")
    return counts


def _latency(ctx, dataset_id):
    """Per-event latency straight out of the datasource.

    pipeline_ms is syncts - ets: how long an event waited between being
    generated and being picked up by the extractor. Under a deliberately-built
    backlog this is dominated by queue time, which is exactly the number that
    says how far behind the pipeline fell.
    """
    out = {}
    cols = ctx.druid.columns(dataset_id)
    ds = ctx.druid.datasource(dataset_id)
    syncts = next((c for c in _SYNCTS_CANDIDATES if c in cols), None)
    out["syncts_column"] = syncts

    if syncts:
        q = ('SELECT APPROX_QUANTILE_DS(d, 0.5) AS p50, APPROX_QUANTILE_DS(d, 0.95) AS p95, '
             'APPROX_QUANTILE_DS(d, 0.99) AS p99, AVG(d) AS avg_, MIN(d) AS min_, '
             'MAX(d) AS max_, COUNT(*) AS c FROM (SELECT ("%s" - "ets") AS d FROM "%s" '
             'WHERE "%s" IS NOT NULL AND "ets" IS NOT NULL)' % (syncts, ds, syncts))
        try:
            rows, _ = ctx.druid.sql(q)
        except Exception:
            # APPROX_QUANTILE_DS needs the datasketches extension; fall back to
            # exact ordering, which is fine at benchmark row counts.
            rows = _exact_quantiles(ctx, ds, syncts)
        r = (rows or [{}])[0]
        if r.get("c"):
            out["pipeline_ms"] = {
                "count": int(r.get("c") or 0),
                "unit": "ms",
                "min": _num(r.get("min_")), "avg": _num(r.get("avg_")),
                "p50": _num(r.get("p50")), "p95": _num(r.get("p95")),
                "p99": _num(r.get("p99")), "max": _num(r.get("max_")),
            }
    else:
        out["pipeline_ms"] = {"count": 0, "note": "no syncts column in the datasource"}

    # Wall-clock end to end: the load phase started producing at drain_start
    # minus the produce time; the last row became queryable at settle_end.
    start = ctx.results.get("kafka", {}).get("drain_started_at")
    prod_sec = ctx.results.get("kafka", {}).get("producer", {}).get("seconds", 0)
    end = getattr(ctx, "settle_end", None)
    if start and end:
        out["end_to_end_sec"] = round(end - (start - prod_sec), 2)
        out["drain_to_queryable_sec"] = round(end - getattr(ctx, "drain_end", start), 2)
    return out


def _exact_quantiles(ctx, ds, syncts):
    q = ('SELECT COUNT(*) AS c, AVG(d) AS avg_, MIN(d) AS min_, MAX(d) AS max_ '
         'FROM (SELECT ("%s" - "ets") AS d FROM "%s" WHERE "%s" IS NOT NULL)'
         % (syncts, ds, syncts))
    try:
        rows, _ = ctx.druid.sql(q)
    except Exception:
        return [{}]
    base = (rows or [{}])[0]
    # Percentiles by offset: cheap enough at these row counts and exact.
    total = int(base.get("c") or 0)
    for label, p in (("p50", 0.5), ("p95", 0.95), ("p99", 0.99)):
        if total < 2:
            base[label] = base.get("avg_")
            continue
        off = min(total - 1, int(total * p))
        try:
            rows2, _ = ctx.druid.sql(
                'SELECT ("%s" - "ets") AS d FROM "%s" WHERE "%s" IS NOT NULL '
                'ORDER BY d LIMIT 1 OFFSET %d' % (syncts, ds, syncts, off))
            base[label] = (rows2 or [{}])[0].get("d")
        except Exception:
            base[label] = None
    return [base]


def _num(v):
    try:
        return round(float(v), 2)
    except (TypeError, ValueError):
        return None
