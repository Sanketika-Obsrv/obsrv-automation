"""Report rendering: JSON, CSV, Markdown, HTML.

Three audiences, one dataset. benchmark-results.json is the complete record and
is what another agent should parse. benchmark-summary.md is the one-screen
answer. benchmark-report.md is the full narrative with the evidence attached.
The HTML is the same content as the report with a stylesheet, so a browser is
never required to read the results.
"""

import html as html_mod
import json
import os
import time

from . import stats


def write_all(ctx):
    out = []
    out.append(write_json(ctx))
    if ctx.cfg["report"].get("csv", True):
        out.extend(write_csvs(ctx))
    out.append(write_summary(ctx))
    out.append(write_report(ctx))
    if ctx.cfg["report"].get("html", True):
        out.append(write_html(ctx))
    return out


# --- json ---------------------------------------------------------------------
def write_json(ctx):
    path = os.path.join(ctx.run_dir, "benchmark-results.json")
    payload = {
        "run": {
            "id": ctx.cfg["run"]["id"],
            "profile": ctx.cfg["run"]["profile"],
            "started_at": ctx.started_at,
            "finished_at": time.time(),
            "duration_sec": round(time.time() - ctx.started_at, 2),
            "config_path": ctx.cfg["run"].get("config_path"),
        },
        "config": ctx.cfg,
        "results": ctx.results,
    }
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(payload, fh, indent=2, default=str, sort_keys=False)
    return path


# --- csv ----------------------------------------------------------------------
def write_csvs(ctx):
    from ..agents import (druid_benchmark, infrastructure_metrics, kafka_benchmark,
                          query_benchmark, unified_pipeline_benchmark)
    d = ctx.dir("csv")
    written = []
    for name, rows in (
        ("kafka.csv", kafka_benchmark.csv_rows(ctx)),
        ("throughput.csv", _throughput_rows(ctx)),
        ("flink.csv", unified_pipeline_benchmark.csv_rows(ctx)),
        ("druid.csv", druid_benchmark.csv_rows(ctx)),
        ("query.csv", query_benchmark.csv_rows(ctx)),
        ("infrastructure.csv", infrastructure_metrics.csv_rows(ctx)),
        ("host.csv", infrastructure_metrics.host_csv_rows(ctx)),
    ):
        if rows:
            written.append(stats.write_csv(os.path.join(d, name), rows))
    return written


def _throughput_rows(ctx):
    """One row per reporting interval: the headline series, joined.

    Kafka is sampled once a minute and everything else every few seconds, so
    each Kafka sample picks up the nearest reading from the other series rather
    than being interpolated -- an invented midpoint in a capacity report is
    indistinguishable from a measurement.
    """
    rows = []
    flink = ctx.sampler.flink_samples
    druid = ctx.sampler.druid_samples
    host = ctx.sampler.host_samples
    for s in ctx.sampler.kafka_samples:
        f = _nearest(flink, s["t"])
        dr = _nearest(druid, s["t"])
        h = _nearest(host, s["t"])
        rows.append({
            "elapsed_sec": round(s.get("elapsed", 0), 2),
            "minute": int(s.get("elapsed", 0) // 60),
            "consumed": s.get("consumed"),
            "remaining": s.get("remaining"),
            "events_per_sec": s.get("events_per_sec"),
            "events_per_min": s.get("events_per_min"),
            "lag_reduction": s.get("lag_reduction"),
            "eta_sec": s.get("eta_sec"),
            "flink_records_out": (f or {}).get("records_out"),
            "flink_heap_used": (f or {}).get("jvm_heap_used"),
            "druid_rows": (dr or {}).get("rows"),
            "host_cpu_pct": (h or {}).get("cpu_pct"),
            "host_mem_pct": (h or {}).get("mem_pct"),
        })
    return rows


def _nearest(series, t, max_gap=45):
    if not series:
        return None
    best = min(series, key=lambda s: abs(s.get("t", 0) - t))
    return best if abs(best.get("t", 0) - t) <= max_gap else None


# --- markdown -----------------------------------------------------------------
def write_summary(ctx):
    path = os.path.join(ctx.run_dir, "benchmark-summary.md")
    r = ctx.results
    a = r.get("analysis", {})
    cap = a.get("capacity", {})
    v = r.get("validation", {})
    k = r.get("kafka", {})
    q = r.get("queries", {})
    L = []
    L.append("# Obsrv Benchmark Summary")
    L.append("")
    L.append("`%s` | profile `%s` | %s"
             % (ctx.cfg["run"]["id"], ctx.cfg["run"]["profile"],
                time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(ctx.started_at))))
    L.append("")
    L.append("| | |")
    L.append("|---|---|")
    L.append("| Events processed | %s |" % f"{k.get('events_drained', 0):,}")
    L.append("| Sustained throughput | **%s events/sec** (%s events/min) |"
             % (stats.human_count(cap.get("sustained_per_sec")),
                stats.human_count(cap.get("sustained_per_min"))))
    L.append("| Peak throughput | %s events/sec |" % stats.human_count(cap.get("peak_per_sec")))
    L.append("| Backlog drain | %s | " % stats.human_dur(k.get("drain_seconds")))
    L.append("| Query p95 | %s ms |"
             % stats.human_count((q.get("overall_latency_ms") or {}).get("p95")))
    L.append("| Queries/sec | %s at concurrency %s |"
             % (stats.human_count((q.get("qps") or {}).get("queries_per_sec")),
                (q.get("qps") or {}).get("concurrency")))
    L.append("| Functional checks | %s%d/%d passed |"
             % ("" if v.get("all_passed") else "**", v.get("passed", 0), v.get("total", 0)))
    L.append("| Bottleneck | %s |" % a.get("bottleneck", {}).get("component", "-"))
    L.append("| Recommended safe rate | **%s events/min** |"
             % stats.human_count(cap.get("safe_per_min")))
    L.append("")
    L.append("## Bottleneck")
    L.append("")
    L.append("**%s** -- %s" % (a.get("bottleneck", {}).get("component", "-"),
                               a.get("bottleneck", {}).get("reason", "-")))
    L.append("")
    L.append("## Top recommendations")
    L.append("")
    for i, rec in enumerate(a.get("recommendations", [])[:5], 1):
        L.append("%d. **%s** (%s) -- %s" % (i, rec["title"], rec["impact"], rec["detail"]))
    L.append("")
    L.append("Full report: `benchmark-report.md` | Raw data: `benchmark-results.json`")
    L.append("")
    return _write(path, "\n".join(L))


def write_report(ctx):
    path = os.path.join(ctx.run_dir, "benchmark-report.md")
    return _write(path, "\n".join(_report_lines(ctx)))


def _report_lines(ctx):
    r, cfg = ctx.results, ctx.cfg
    a = r.get("analysis", {})
    L = []
    add = L.append

    add("# Obsrv Mini Deployment -- Benchmark Report")
    add("")
    add("- **Run** `%s` (profile `%s`)" % (cfg["run"]["id"], cfg["run"]["profile"]))
    add("- **Started** %s" % time.strftime("%Y-%m-%d %H:%M:%S", time.localtime(ctx.started_at)))
    add("- **Duration** %s" % stats.human_dur(time.time() - ctx.started_at))
    add("- **Load** %s events, %s users, %s duplicates, avg %s per event"
        % (f"{r.get('generation', {}).get('lines', 0):,}",
           f"{r.get('generation', {}).get('users', 0):,}",
           f"{r.get('generation', {}).get('duplicate_events', 0):,}",
           stats.human_bytes(r.get("generation", {}).get("avg_event_bytes"))))
    add("")

    # --- executive summary ---
    add("## 1. Executive summary")
    add("")
    add("| Question | Answer |")
    add("|---|---|")
    for qa in a.get("summary_answers", []):
        add("| %s | %s |" % (_esc(qa["question"]), _esc(qa["answer"])))
    add("")

    # --- functional ---
    v = r.get("validation", {})
    add("## 2. Functional validation")
    add("")
    add("%d of %d checks passed." % (v.get("passed", 0), v.get("total", 0)))
    add("")
    add("| Check | Result | Detail |")
    add("|---|---|---|")
    for c in v.get("checks", []):
        add("| %s | %s | %s |" % (_esc(c["title"]), "PASS" if c["passed"] else "**FAIL**",
                                  _esc(c["detail"])))
    add("")
    add("<details><summary>Evidence</summary>")
    add("")
    for c in v.get("checks", []):
        add("**%s** (`%s`)" % (c["title"], c["name"]))
        add("")
        add("```json")
        add(json.dumps(c.get("evidence", {}), indent=2, default=str)[:4000])
        add("```")
        add("")
    add("</details>")
    add("")

    # --- datasets ---
    ds = r.get("datasets", {})
    add("## 3. Datasets under test")
    add("")
    add("| | Master | Telemetry |")
    add("|---|---|---|")
    add("| Dataset id | `%s` | `%s` |" % (ds.get("master", {}).get("dataset_id", "-"),
                                          ds.get("telemetry", {}).get("dataset_id", "-")))
    add("| Records / entry topic | %s cached in Valkey db %s | `%s` (%s partitions) |"
        % (ds.get("master", {}).get("records", "-"), ds.get("master", {}).get("redis_db", "-"),
           ds.get("telemetry", {}).get("entry_topic", "-"),
           ds.get("telemetry", {}).get("partitions", "-")))
    add("| Datasource | (cache only) | `%s` |" % ds.get("telemetry", {}).get("datasource", "-"))
    add("| Dedup key | - | `%s` |" % ds.get("telemetry", {}).get("dedup_key", "-"))
    add("| Transformations | - | %s |"
        % ", ".join("`%s`" % t for t in ds.get("telemetry", {}).get("transformations", [])))
    add("| Denormalization | - | `%s` via %s |"
        % (ds.get("telemetry", {}).get("denorm_out_field", "-"),
           ds.get("telemetry", {}).get("denorm_strategy", "-")))
    add("")

    # --- kafka ---
    k = r.get("kafka", {})
    add("## 4. Kafka ingestion and backlog drain")
    add("")
    add("| Metric | Value |")
    add("|---|---|")
    add("| Topic | `%s` (%s partitions) |" % (k.get("topic"), k.get("partitions")))
    add("| Backlog built | %s events |" % f"{k.get('backlog_events', 0):,}")
    add("| Producer throughput | %s events/sec (%s) |"
        % (stats.human_count(k.get("producer_throughput_per_sec")),
           stats.human_bytes(k.get("producer_bytes_per_sec")) + "/s"))
    add("| Pipeline paused during load | %s |" % k.get("paused_for_load"))
    add("| Drain time | %s |" % stats.human_dur(k.get("drain_seconds")))
    add("| Events drained | %s |" % f"{k.get('events_drained', 0):,}")
    add("| Sustained consumption | %s events/sec (%s events/min) |"
        % (stats.human_count(k.get("sustained_per_sec")),
           stats.human_count(k.get("sustained_per_min"))))
    add("| Peak consumption | %s events/sec |" % stats.human_count(k.get("peak_per_sec")))
    add("| Dead-letter events | %s |" % f"{k.get('events_failed', 0):,}")
    add("")
    samples = ctx.sampler.kafka_samples
    if samples:
        add("### Per-minute progress")
        add("")
        add("| Minute | Consumed | Remaining | Events/sec | Events/min | Lag reduction | ETA |")
        add("|---:|---:|---:|---:|---:|---:|---|")
        for s in samples:
            add("| %d | %s | %s | %s | %s | %s | %s |"
                % (int(s.get("elapsed", 0) // 60), f"{s.get('consumed', 0):,}",
                   f"{s.get('remaining', 0):,}", stats.human_count(s.get("events_per_sec")),
                   stats.human_count(s.get("events_per_min")),
                   f"{s.get('lag_reduction', 0):,}", stats.human_dur(s.get("eta_sec"))))
        add("")

    # --- pipeline ---
    p = r.get("pipeline", {})
    add("## 5. Unified Pipeline (Flink)")
    add("")
    add("| Metric | Value |")
    add("|---|---|")
    add("| Job state | %s (%s) |" % (p.get("state"), ", ".join(p.get("states_seen", []) or [])))
    add("| Slots / parallelism | %s / %s |" % (p.get("slots_total"), p.get("parallelism")))
    add("| Records out | %s (%s/sec sustained, %s/sec peak) |"
        % (f"{p.get('records_out_total', 0):,}", stats.human_count(p.get("sustained_per_sec")),
           stats.human_count(p.get("peak_per_sec"))))
    jvm = p.get("jvm", {})
    add("| JVM heap | peak %s%% of %s |"
        % (jvm.get("heap_pct_peak"), stats.human_bytes(jvm.get("heap_max"))))
    add("| GC | %s ms young + %s ms old = %s%% of wall clock |"
        % (jvm.get("gc_young_ms"), jvm.get("gc_old_ms"), jvm.get("gc_pct_of_wall")))
    cp = p.get("checkpoints", {})
    add("| Checkpoints | %s completed, %s failed, p95 %s ms |"
        % (cp.get("completed"), cp.get("failed"),
           stats.human_count((cp.get("duration_ms") or {}).get("p95"))))
    tm = p.get("taskmanager", {})
    add("| TaskManager CPU | avg %s%%, p95 %s%% |"
        % (stats.human_count((tm.get("cpu_pct") or {}).get("avg")),
           stats.human_count((tm.get("cpu_pct") or {}).get("p95"))))
    add("")
    if p.get("vertices"):
        add("### Operators")
        add("")
        add("| Operator | Parallelism | Busy | Backpressured | Records out/sec |")
        add("|---|---:|---:|---:|---:|")
        for vtx in p["vertices"]:
            add("| %s | %s | %s%% | %s%% | %s |"
                % (_esc(vtx["name"]), vtx.get("parallelism"),
                   "%.0f" % (100 * (vtx.get("busy_avg") or 0)),
                   "%.0f" % (100 * (vtx.get("backpressured_avg") or 0)),
                   stats.human_count(vtx.get("out_per_sec"))))
        add("")

    # --- druid ---
    d = r.get("druid", {})
    add("## 6. Druid indexing and query surface")
    add("")
    add("| Metric | Value |")
    add("|---|---|")
    add("| Datasource | `%s` |" % d.get("datasource"))
    add("| Rows queryable | %s of %s expected (%s%%) |"
        % (f"{d.get('rows_queryable', 0):,}", f"{d.get('rows_expected', 0):,}",
           d.get("completeness_pct")))
    add("| Settle time after drain | %s |" % stats.human_dur(d.get("settle_seconds")))
    add("| Queryable rows/sec | %s sustained, %s peak |"
        % (stats.human_count(d.get("rows_per_sec_sustained")),
           stats.human_count(d.get("rows_per_sec_peak"))))
    sup = d.get("supervisor", {})
    add("| Supervisor | %s (%s), %s active task(s), lag %s |"
        % (sup.get("state"), sup.get("detailed_state"), sup.get("active_tasks"),
           sup.get("aggregate_lag")))
    add("| Supervisor rows processed | %s (1m avg), %s total |"
        % (stats.human_count(sup.get("rows_processed_1m")),
           f"{sup.get('rows_processed_total', 0):,}"))
    seg = d.get("segments", {})
    add("| Segments | %s covering %s, avg %s rows each |"
        % (seg.get("segments"), stats.human_bytes(seg.get("bytes")),
           f"{seg.get('avg_rows_per_segment', 0):,}"))
    t = d.get("tasks", {})
    add("| Indexing tasks | %s running, %s pending, %s waiting; duration p95 %s s |"
        % (t.get("running"), t.get("pending"), t.get("waiting"),
           stats.human_count((t.get("duration_sec") or {}).get("p95"))))
    lat = (d.get("latency") or {}).get("pipeline_ms") or {}
    add("| Per-event pipeline latency | p50 %s ms, p95 %s ms, p99 %s ms, max %s ms |"
        % (stats.human_count(lat.get("p50")), stats.human_count(lat.get("p95")),
           stats.human_count(lat.get("p99")), stats.human_count(lat.get("max"))))
    add("")

    # --- queries ---
    q = r.get("queries", {})
    add("## 7. Query benchmark")
    add("")
    add("Measured against %s rows. %d iterations per class after %d warmups, "
        "then a %ss saturation probe at concurrency %d."
        % (f"{q.get('row_count_at_test', 0):,}", cfg["queries"]["iterations"],
           cfg["queries"]["warmup"], cfg["queries"]["qps_probe_seconds"],
           cfg["queries"]["concurrency"]))
    add("")
    add("| Query | Avg ms | P50 | P95 | P99 | Max | Rows | Errors |")
    add("|---|---:|---:|---:|---:|---:|---:|---:|")
    for qr in q.get("by_query", []):
        l = qr["latency_ms"]
        add("| %s | %.1f | %.1f | %.1f | %.1f | %.1f | %s | %s |"
            % (qr["name"], l["avg"], l["p50"], l["p95"], l["p99"], l["max"],
               qr["rows"], qr["errors"]))
    add("")
    qps = q.get("qps", {})
    add("Under %s concurrent clients the deployment completed **%s queries/sec** "
        "(%s/min) with p95 %s ms."
        % (qps.get("concurrency"), stats.human_count(qps.get("queries_per_sec")),
           stats.human_count(qps.get("queries_per_min")),
           stats.human_count((qps.get("latency_under_load_ms") or {}).get("p95"))))
    add("")

    # --- infrastructure ---
    infra = r.get("infrastructure", {})
    host = infra.get("host", {})
    add("## 8. Infrastructure")
    add("")
    add("Host (%s cores, %s RAM, metrics from %s):"
        % (infra.get("cores"), stats.human_bytes(host.get("mem_total_bytes")),
           host.get("source")))
    add("")
    add("| Metric | Average | Peak |")
    add("|---|---:|---:|")
    add("| CPU | %s%% | %s%% |" % (stats.human_count(host.get("cpu_pct_avg")),
                                   stats.human_count(host.get("cpu_pct_max"))))
    add("| Memory | %s%% | %s%% |" % (stats.human_count(host.get("mem_pct_avg")),
                                      stats.human_count(host.get("mem_pct_peak"))))
    add("| Load (1m) | %s | %s |" % (stats.human_count(host.get("load1_avg")),
                                     stats.human_count(host.get("load1_peak"))))
    add("| Disk read | - | %s/s |" % stats.human_bytes(host.get("disk_read_bps_peak")))
    add("| Disk write | - | %s/s |" % stats.human_bytes(host.get("disk_write_bps_peak")))
    add("| Network rx/tx | - | %s/s / %s/s |"
        % (stats.human_bytes(host.get("net_rx_bps_peak")),
           stats.human_bytes(host.get("net_tx_bps_peak"))))
    add("")
    add("| Container | CPU avg % | CPU p95 % | Mem avg | Mem peak | % of limit | CPU-sec |")
    add("|---|---:|---:|---:|---:|---:|---:|")
    for role, c in sorted((infra.get("containers") or {}).items(),
                          key=lambda kv: -(kv[1].get("cpu_seconds") or 0)):
        add("| %s | %s | %s | %s | %s | %s | %s |"
            % (role, c.get("cpu_pct_avg"), c.get("cpu_pct_p95"),
               stats.human_bytes(c.get("mem_anon_avg")),
               stats.human_bytes(c.get("mem_anon_peak")),
               c.get("mem_pct_of_limit_peak"), c.get("cpu_seconds")))
    add("")
    cost = infra.get("cost_per_1000_events", {})
    if cost:
        add("Resource cost: **%s CPU-seconds per 1,000 events** across all containers "
            "(%s CPU-seconds total over the measured window)."
            % (cost.get("cpu_seconds_per_1000"), cost.get("cpu_seconds_total")))
        add("")
    corr = infra.get("correlation", {})
    if corr.get("cpu_vs_throughput_r") is not None:
        add("CPU/throughput correlation r = %s -- %s"
            % (corr["cpu_vs_throughput_r"], corr.get("interpretation")))
        add("")

    # --- bottleneck & recs ---
    add("## 9. Bottleneck analysis")
    add("")
    b = a.get("bottleneck", {})
    add("**%s** (%s layer)" % (b.get("component", "-"), b.get("layer", "-")))
    add("")
    add(b.get("reason", ""))
    add("")
    add("```json")
    add(json.dumps(b.get("evidence", {}), indent=2, default=str)[:3000])
    add("```")
    add("")
    for note in (infra.get("saturation") or {}).get("notes", []):
        add("- %s" % note)
    add("")

    add("## 10. Capacity")
    add("")
    cap = a.get("capacity", {})
    add("| | events/sec | events/min | events/day |")
    add("|---|---:|---:|---:|")
    add("| Measured sustained | %s | %s | %s |"
        % (stats.human_count(cap.get("sustained_per_sec")),
           stats.human_count(cap.get("sustained_per_min")),
           stats.human_count((cap.get("sustained_per_sec") or 0) * 86400)))
    add("| Measured peak | %s | %s | - |"
        % (stats.human_count(cap.get("peak_per_sec")),
           stats.human_count(cap.get("peak_per_min"))))
    add("| **Recommended safe** | **%s** | **%s** | **%s** |"
        % (stats.human_count(cap.get("safe_per_sec")),
           stats.human_count(cap.get("safe_per_min")),
           stats.human_count(cap.get("safe_per_day"))))
    add("")
    for t in cap.get("targets", []):
        add("- %s events/min: **%s** (%sx the measured sustained rate)"
            % (f"{t['events_per_min']:,}",
               "achievable with headroom" if t["achievable_safely"]
               else ("achievable with no headroom" if t["achievable_now"] else "not achievable"),
               t["multiple_of_measured"]))
    add("")

    add("## 11. Scaling to 2x / 5x / 10x")
    add("")
    for step in a.get("scaling", []):
        add("### %dx (%s events/sec, projected host CPU %s%%)"
            % (step["multiple"], stats.human_count(step["target_per_sec"]),
               step["projected_host_cpu_pct"]))
        add("")
        for s in step["steps"]:
            add("- %s" % s)
        add("")

    add("## 12. Recommendations")
    add("")
    for i, rec in enumerate(a.get("recommendations", []), 1):
        add("%d. **%s** _(%s impact)_" % (i, rec["title"], rec["impact"]))
        add("")
        add("   %s" % rec["detail"])
        add("")

    add("## 13. Reproducing this run")
    add("")
    add("```bash")
    add("cd local-compose/benchmark")
    add("./benchmark run %s" % (cfg["run"].get("config_path") or "benchmark-config.yaml"))
    add("```")
    add("")
    add("Same seeds (`users.seed=%s`, `load.seed=%s`) produce the same corpus, so two "
        "runs are directly comparable." % (cfg["users"]["seed"], cfg["load"]["seed"]))
    add("")
    errs = ctx.sampler.errors() if getattr(ctx, "sampler", None) else []
    if errs:
        add("### Sampler warnings")
        add("")
        for e in errs[:20]:
            add("- `%s`" % _esc(e))
        add("")
    return L


# --- html ---------------------------------------------------------------------
def write_html(ctx):
    path = os.path.join(ctx.run_dir, "benchmark.html")
    body = _md_to_html("\n".join(_report_lines(ctx)))
    doc = _HTML_SHELL % {"title": "Obsrv Benchmark %s" % ctx.cfg["run"]["id"], "body": body}
    return _write(path, doc)


def _md_to_html(md):
    """Minimal Markdown renderer -- headings, tables, lists, code, bold.

    Deliberately not a full implementation: the input is this module's own
    output, so the subset is known, and a dependency-free HTML report is worth
    more than complete CommonMark support.
    """
    out, in_code, in_table, in_list = [], False, False, False

    def close_blocks():
        nonlocal in_table, in_list
        if in_table:
            out.append("</tbody></table>")
            in_table = False
        if in_list:
            out.append("</ul>")
            in_list = False

    for line in md.splitlines():
        if line.startswith("```"):
            close_blocks()
            out.append("</pre>" if in_code else "<pre>")
            in_code = not in_code
            continue
        if in_code:
            out.append(html_mod.escape(line))
            continue
        s = line.rstrip()
        if not s:
            close_blocks()
            continue
        if s.startswith("<details") or s.startswith("</details") or s.startswith("<summary"):
            close_blocks()
            out.append(s)
            continue
        if s.startswith("#"):
            close_blocks()
            level = len(s) - len(s.lstrip("#"))
            out.append("<h%d>%s</h%d>" % (level, _inline(s[level:].strip()), level))
            continue
        if s.startswith("|"):
            cells = [c.strip() for c in s.strip("|").split("|")]
            if all(set(c) <= set("-: ") and c for c in cells):
                continue                      # the alignment row
            if not in_table:
                out.append("<table><thead><tr>%s</tr></thead><tbody>"
                           % "".join("<th>%s</th>" % _inline(c) for c in cells))
                in_table = True
            else:
                out.append("<tr>%s</tr>" % "".join("<td>%s</td>" % _inline(c) for c in cells))
            continue
        close_blocks() if in_table else None
        if s.lstrip().startswith("- "):
            if not in_list:
                out.append("<ul>")
                in_list = True
            out.append("<li>%s</li>" % _inline(s.lstrip()[2:]))
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        out.append("<p>%s</p>" % _inline(s))
    close_blocks()
    if in_code:
        out.append("</pre>")
    return "\n".join(out)


def _inline(text):
    t = html_mod.escape(text)
    # Order matters: bold before code, so **`x`** renders both.
    while "**" in t:
        t = t.replace("**", "<strong>", 1)
        if "**" in t:
            t = t.replace("**", "</strong>", 1)
        else:
            t = t.replace("<strong>", "**", 1)
            break
    while t.count("`") >= 2:
        t = t.replace("`", "<code>", 1).replace("`", "</code>", 1)
    return t


_HTML_SHELL = """<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>%(title)s</title>
<style>
:root { color-scheme: light dark; --fg:#1b1f23; --bg:#fff; --mut:#57606a; --line:#d0d7de;
        --accent:#0969da; --code:#f6f8fa; }
@media (prefers-color-scheme: dark) {
  :root { --fg:#e6edf3; --bg:#0d1117; --mut:#9198a1; --line:#30363d; --accent:#4493f8;
          --code:#161b22; } }
body { margin:0 auto; max-width:1100px; padding:2rem 1.25rem 6rem; background:var(--bg);
       color:var(--fg); font:15px/1.6 -apple-system,BlinkMacSystemFont,"Segoe UI",
       Roboto,Helvetica,Arial,sans-serif; }
h1 { font-size:1.9rem; border-bottom:2px solid var(--line); padding-bottom:.4rem; }
h2 { font-size:1.35rem; margin-top:2.5rem; border-bottom:1px solid var(--line);
     padding-bottom:.3rem; }
h3 { font-size:1.1rem; margin-top:1.75rem; color:var(--mut); }
table { border-collapse:collapse; width:100%%; margin:1rem 0; display:block;
        overflow-x:auto; font-size:.92rem; }
th,td { border:1px solid var(--line); padding:.4rem .6rem; text-align:left;
        vertical-align:top; }
th { background:var(--code); font-weight:600; }
tr:nth-child(even) td { background:color-mix(in srgb, var(--code) 45%%, transparent); }
pre { background:var(--code); padding:.85rem 1rem; overflow-x:auto; border-radius:6px;
      font-size:.85rem; line-height:1.45; }
code { background:var(--code); padding:.1rem .3rem; border-radius:4px; font-size:.88em; }
pre code { background:none; padding:0; }
strong { font-weight:650; }
ul { padding-left:1.3rem; }
details { margin:1rem 0; border:1px solid var(--line); border-radius:6px; padding:.6rem .9rem; }
summary { cursor:pointer; font-weight:600; color:var(--accent); }
</style></head><body>
%(body)s
</body></html>
"""


# --- shared -------------------------------------------------------------------
def _esc(text):
    return str(text).replace("|", "\\|").replace("\n", " ")


def _write(path, text):
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        fh.write(text)
    return path
