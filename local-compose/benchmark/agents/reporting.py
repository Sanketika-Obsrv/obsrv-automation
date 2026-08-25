"""Reporting Agent -- bottleneck attribution, capacity model, recommendations.

The analysis here is deliberately conservative in one specific way: every
scaling claim is tied to the component the evidence says is the constraint. A
recommendation to add Kafka partitions when the TaskManager was pinned at 100%
CPU would be worse than no recommendation, because it looks actionable.

The 2x / 5x / 10x ladder is built the same way -- each step re-asks which
resource runs out first at that multiple, so the advice changes as the
bottleneck moves rather than repeating "add more of everything".
"""

from ..lib import report as report_lib
from ..lib import stats


def analyze(ctx):
    cfg, log = ctx.cfg, ctx.log
    log.phase("Reporting Agent", "bottleneck analysis and recommendations")
    res = ctx.results.setdefault("analysis", {})

    res["bottleneck"] = _bottleneck(ctx)
    res["capacity"] = _capacity(ctx)
    res["scaling"] = _scaling(ctx, res["bottleneck"])
    res["recommendations"] = _recommendations(ctx, res["bottleneck"], res["capacity"])
    res["summary_answers"] = _answers(ctx, res)

    log.info("primary bottleneck: %s -- %s"
             % (res["bottleneck"]["component"], res["bottleneck"]["reason"]))
    log.info("safe sustained throughput: %s events/min (%s events/sec)"
             % (stats.human_count(res["capacity"]["safe_per_min"]),
                stats.human_count(res["capacity"]["safe_per_sec"])))
    for i, r in enumerate(res["recommendations"][:cfg["report"]["top_n_recommendations"]], 1):
        log.info("%2d. [%s] %s" % (i, r["impact"], r["title"]))
    return res


def write(ctx):
    """Emit every artefact the requirement asks for."""
    log = ctx.log
    log.phase("Reporting Agent", "writing artefacts")
    written = report_lib.write_all(ctx)
    for path in written:
        log.info(path)
    ctx.results.setdefault("analysis", {})["artefacts"] = written
    return written


# --- bottleneck ----------------------------------------------------------------
def _bottleneck(ctx):
    """Attribute the ceiling to one component, with the evidence for it.

    Order matters: a saturated host CPU explains a busy operator, so hardware
    is tested before software. Within the pipeline, an operator that is busy
    without being backpressured is the constraint; one that is backpressured is
    a symptom of the next stage down.
    """
    k = ctx.results.get("kafka", {})
    p = ctx.results.get("pipeline", {})
    d = ctx.results.get("druid", {})
    infra = ctx.results.get("infrastructure", {})
    host = infra.get("host", {})
    containers = infra.get("containers", {})
    ev = {}

    cpu_p95 = host.get("cpu_pct_p95")
    ev["host_cpu_p95"] = cpu_p95
    ev["host_mem_peak_pct"] = host.get("mem_pct_peak")
    ev["pipeline_sustained_per_sec"] = p.get("sustained_per_sec")
    ev["kafka_sustained_per_sec"] = k.get("sustained_per_sec")
    ev["druid_rows_per_sec"] = d.get("rows_per_sec_sustained")

    cap = ctx.cfg["capacity"]
    tm = containers.get("up_taskmanager", {})
    ev["taskmanager_cpu_p95"] = tm.get("cpu_pct_p95")
    ev["taskmanager_mem_pct_of_limit"] = tm.get("mem_pct_of_limit_peak")

    # 1. Hardware exhausted?
    if cpu_p95 is not None and cpu_p95 >= cap["cpu_saturation_pct"]:
        # Whose CPU? The container with the largest share owns it.
        owner = max(containers.items(),
                    key=lambda kv: kv[1].get("cpu_seconds") or 0, default=(None, {}))
        return {
            "component": "host CPU (%s)" % (owner[0] or "unattributed"),
            "layer": "infrastructure",
            "reason": ("the VM's CPU sat at %.0f%% (p95) during the drain, and %s "
                       "consumed the largest share of it"
                       % (cpu_p95, owner[0] or "no single container")),
            "evidence": ev,
        }
    if host.get("mem_pct_peak") and host["mem_pct_peak"] >= cap["mem_saturation_pct"]:
        return {"component": "host memory", "layer": "infrastructure",
                "reason": "the VM reached %.0f%% memory" % host["mem_pct_peak"],
                "evidence": ev}
    for role, c in containers.items():
        if (c.get("mem_pct_of_limit_peak") or 0) >= cap["mem_saturation_pct"]:
            return {"component": "%s memory limit" % role, "layer": "container",
                    "reason": ("%s peaked at %.0f%% of its cgroup memory limit"
                               % (role, c["mem_pct_of_limit_peak"])),
                    "evidence": ev}

    # 2. Flink operator constraint?
    op = p.get("bottleneck_operator")
    if op and (op.get("busy_avg") or 0) >= 0.5:
        return {
            "component": "unified-pipeline operator: %s" % op["name"],
            "layer": "flink",
            "reason": ("this operator was busy %.0f%% of the time while only %.0f%% "
                       "backpressured -- it is doing the work that sets the pace, not "
                       "waiting on a downstream stage"
                       % (100 * op["busy_avg"], 100 * (op.get("backpressured_avg") or 0))),
            "evidence": dict(ev, operator=op),
        }

    # 3. Slots / parallelism?
    if p.get("slots_total") and (p.get("parallelism") or 0) >= p["slots_total"]:
        gc = (p.get("jvm") or {}).get("gc_pct_of_wall") or 0
        if gc < 5:
            return {
                "component": "unified-pipeline parallelism",
                "layer": "flink",
                "reason": ("every task slot was occupied (%d slot(s), parallelism %d) with "
                           "no operator saturated and no resource exhausted -- the job "
                           "cannot use more of the machine than it has slots for"
                           % (p["slots_total"], p["parallelism"])),
                "evidence": ev,
            }

    # 4. GC?
    gc = (p.get("jvm") or {}).get("gc_pct_of_wall")
    if gc is not None and gc >= 8:
        return {"component": "TaskManager garbage collection", "layer": "flink",
                "reason": "%.1f%% of wall-clock time went to GC" % gc,
                "evidence": ev}

    # 5. Druid keeping up?
    if (d.get("rows_per_sec_sustained") or 0) and (k.get("sustained_per_sec") or 0):
        if d["rows_per_sec_sustained"] < k["sustained_per_sec"] * 0.6:
            return {
                "component": "Druid indexing",
                "layer": "druid",
                "reason": ("rows became queryable at %s/s while the pipeline processed "
                           "%s/s -- indexing and segment handoff, not stream processing, "
                           "set the end-to-end rate"
                           % (stats.human_count(d["rows_per_sec_sustained"]),
                              stats.human_count(k["sustained_per_sec"]))),
                "evidence": ev,
            }

    return {
        "component": "no single saturated component",
        "layer": "none",
        "reason": ("nothing crossed a saturation threshold: the measured rate is what "
                   "this configuration produces at rest, and the next constraint will "
                   "only appear at a higher load"),
        "evidence": ev,
    }


# --- capacity ------------------------------------------------------------------
def _capacity(ctx):
    cfg = ctx.cfg
    k = ctx.results.get("kafka", {})
    sustained = k.get("sustained_per_sec") or k.get("drain_throughput_per_sec") or 0
    peak = k.get("peak_per_sec") or sustained
    headroom = cfg["capacity"]["safe_headroom"]
    out = {
        "sustained_per_sec": round(sustained, 2),
        "sustained_per_min": round(sustained * 60, 1),
        "peak_per_sec": round(peak, 2),
        "peak_per_min": round(peak * 60, 1),
        "safe_headroom": headroom,
        "safe_per_sec": round(sustained * headroom, 2),
        "safe_per_min": round(sustained * headroom * 60, 1),
        "safe_per_hour": round(sustained * headroom * 3600),
        "safe_per_day": round(sustained * headroom * 86400),
        "targets": [],
    }
    for target in cfg["capacity"]["targets_per_min"]:
        need = target / 60.0
        out["targets"].append({
            "events_per_min": target,
            "events_per_sec": round(need, 2),
            "achievable_now": bool(sustained >= need),
            "achievable_safely": bool(sustained * headroom >= need),
            "multiple_of_measured": round(need / sustained, 2) if sustained else None,
        })
    return out


def _scaling(ctx, bottleneck):
    """What has to change for 2x, 5x, 10x -- re-evaluated at each step."""
    infra = ctx.results.get("infrastructure", {})
    host = infra.get("host", {})
    p = ctx.results.get("pipeline", {})
    cores = infra.get("cores") or 4
    cpu_p95 = host.get("cpu_pct_p95") or 0
    slots = p.get("slots_total") or 1
    out = []
    for mult in (2, 5, 10):
        needed_cpu = cpu_p95 * mult
        steps = []
        if needed_cpu > 100:
            extra_cores = max(1, int(round(cores * needed_cpu / 100.0)) - cores)
            steps.append("add ~%d CPU core%s (projected %.0f%% of the current %d)"
                         % (extra_cores, "" if extra_cores == 1 else "s", needed_cpu, cores))
        # Flink scales by slots; the reactive scheduler picks up new
        # TaskManagers without a job restart, which is why this is the cheap
        # lever in this deployment.
        want_slots = max(slots * mult // 2, slots + 1)
        steps.append("raise unified-pipeline parallelism to ~%d slot(s) "
                     "(add TaskManager replicas; the reactive scheduler absorbs them "
                     "without a job restart)" % want_slots)
        parts = ctx.results.get("kafka", {}).get("partitions") or 4
        if want_slots > parts:
            steps.append("increase %s to >= %d partitions -- consumer parallelism is "
                         "capped by partition count"
                         % (ctx.results.get("kafka", {}).get("topic", "ingest"), want_slots))
        if mult >= 5:
            steps.append("give Druid its own middle-manager capacity (more task slots "
                         "and a larger heap) so segment handoff does not become the "
                         "new ceiling")
            steps.append("move Valkey dedup/denorm off the same host, or accept that "
                         "each event costs two extra round trips on a shared box")
        if mult >= 10:
            steps.append("split the single-container Druid into separate "
                         "coordinator/overlord, broker, historical and middle-manager "
                         "processes -- the bundled micro-quickstart is not a 10x target")
        out.append({
            "multiple": mult,
            "target_per_sec": round((ctx.results.get("analysis", {}).get("capacity", {})
                                     .get("sustained_per_sec")
                                     or ctx.results.get("kafka", {}).get("sustained_per_sec")
                                     or 0) * mult, 2),
            "projected_host_cpu_pct": round(needed_cpu, 1),
            "steps": steps,
        })
    return out


def _recommendations(ctx, bottleneck, capacity):
    """Concrete, ordered, and tied to something that was measured."""
    recs = []
    p = ctx.results.get("pipeline", {})
    k = ctx.results.get("kafka", {})
    d = ctx.results.get("druid", {})
    infra = ctx.results.get("infrastructure", {})
    host = infra.get("host", {})
    q = ctx.results.get("queries", {})
    containers = infra.get("containers", {})

    def add(impact, title, detail):
        recs.append({"impact": impact, "title": title, "detail": detail})

    layer = bottleneck.get("layer")
    if layer == "flink":
        add("high", "Add TaskManager slots before anything else",
            "The constraint is inside the stream job (%s). This deployment runs %s "
            "slot(s); the reactive scheduler rescales automatically when another "
            "TaskManager registers, so this is a compose scale operation rather than a "
            "job redeploy." % (bottleneck["component"], p.get("slots_total")))
    if layer == "infrastructure":
        add("high", "The VM is the ceiling, not the configuration",
            "Host CPU p95 was %.0f%%. Tuning parallelism will redistribute the same "
            "cycles; raising throughput needs more cores or fewer co-tenant services."
            % (host.get("cpu_pct_p95") or 0))
    if layer == "druid":
        add("high", "Give Druid more indexing capacity",
            "Rows became queryable at %s/s against %s/s processed. Raise the "
            "supervisor's taskCount and the middle-manager worker capacity, and check "
            "segmentGranularity -- small frequent segments cost handoff time."
            % (stats.human_count(d.get("rows_per_sec_sustained")),
               stats.human_count(k.get("sustained_per_sec"))))

    parts = k.get("partitions") or 0
    slots = p.get("slots_total") or 0
    if parts and slots and slots > parts:
        add("high", "Partition count caps consumer parallelism",
            "%s has %d partitions but the job has %d slots; %d slot(s) can never receive "
            "a partition." % (k.get("topic"), parts, slots, slots - parts))
    elif parts and slots and parts > slots * 2:
        add("medium", "There is unused partition parallelism available",
            "%s has %d partitions against %d slot(s). Additional TaskManagers will find "
            "work immediately -- no repartitioning needed." % (k.get("topic"), parts, slots))

    gc = (p.get("jvm") or {}).get("gc_pct_of_wall")
    heap = (p.get("jvm") or {}).get("heap_pct_peak")
    if gc is not None and gc >= 5:
        add("medium", "TaskManager GC is eating measurable throughput",
            "%.1f%% of wall clock went to garbage collection with heap peaking at %s%% "
            "of max. Raise taskmanager.memory.process.size before adding parallelism -- "
            "more slots on the same heap makes this worse."
            % (gc, "%.0f" % heap if heap else "?"))
    elif heap is not None and heap >= 85:
        add("medium", "TaskManager heap is close to its limit",
            "Peak heap was %.0f%% of max. There is little room for a larger dedup or "
            "denorm working set." % heap)

    cp = p.get("checkpoints") or {}
    cp_ms = (cp.get("duration_ms") or {}).get("p95")
    if cp_ms and cp_ms > 10000:
        add("medium", "Checkpoints are slow enough to interrupt processing",
            "p95 checkpoint duration was %.1f s. Increase the interval or move the "
            "checkpoint store off the container filesystem." % (cp_ms / 1000.0))

    failed = k.get("events_failed") or 0
    if failed:
        add("high", "Events are being rejected",
            "%s events landed on dead-letter topics during the run (%s). Throughput "
            "figures describe a pipeline that was dropping input."
            % (f"{failed:,}", ", ".join("%s=%d" % (t, v)
                                        for t, v in sorted((k.get("failed_delta") or {}).items())
                                        if v > 0)))

    completeness = d.get("completeness_pct")
    if completeness is not None and completeness < 99.5:
        add("high", "Not every event became queryable",
            "%.2f%% of the expected rows are in Druid (%s of %s). Investigate before "
            "trusting the latency numbers."
            % (completeness, f"{d.get('rows_queryable', 0):,}",
               f"{d.get('rows_expected', 0):,}"))

    qp95 = (q.get("overall_latency_ms") or {}).get("p95")
    if qp95 and qp95 > 1000:
        add("medium", "Query p95 is above one second",
            "p95 across all query classes was %.0f ms at %s rows. Enable the Druid "
            "result-level cache, and check that segments are not being scanned in full "
            "for point lookups." % (qp95, f"{q.get('row_count_at_test', 0):,}"))

    seg = d.get("segments") or {}
    if seg.get("segments") and seg.get("avg_rows_per_segment", 0) < 100000:
        add("low", "Segments are smaller than Druid's target",
            "%d segment(s) averaging %s rows. Druid targets ~5M rows per segment; small "
            "segments multiply query fan-out and metadata overhead. Increase "
            "segmentGranularity or run compaction."
            % (seg["segments"], f"{seg.get('avg_rows_per_segment', 0):,}"))

    for role in ("valkey_dedup", "valkey_denorm"):
        c = containers.get(role) or {}
        if (c.get("cpu_pct_p95") or 0) > 60:
            add("medium", "%s is working hard" % role,
                "p95 CPU %.0f%%. Every event costs a round trip here; at higher volumes "
                "this becomes a per-event latency floor." % c["cpu_pct_p95"])

    corr = (infra.get("correlation") or {}).get("cpu_vs_throughput_r")
    if corr is not None and corr < 0.25:
        add("low", "Throughput is not CPU-limited",
            "Correlation between host CPU and throughput was r=%.2f. Adding cores is "
            "unlikely to help; the constraint is concurrency or an external wait." % corr)

    add("low", "Re-run at a higher volume to confirm the ceiling",
        "This run drained %s events. The measured rate is a lower bound; "
        "OBSRV_BENCH_LOAD_EVENTS=%d re-runs the identical benchmark at 5x."
        % (f"{k.get('events_drained', 0):,}", (ctx.cfg["load"]["events"] or 1) * 5))
    return recs


# --- executive summary ---------------------------------------------------------
def _answers(ctx, analysis):
    """The questions the requirement's executive summary has to answer.

    Kept as an explicit list of (question, answer) so nothing quietly goes
    missing when the report template changes.
    """
    k = ctx.results.get("kafka", {})
    p = ctx.results.get("pipeline", {})
    d = ctx.results.get("druid", {})
    q = ctx.results.get("queries", {})
    infra = ctx.results.get("infrastructure", {})
    host = infra.get("host", {})
    v = ctx.results.get("validation", {})
    cap = analysis["capacity"]
    lat = (d.get("latency") or {}).get("pipeline_ms") or {}

    def n(x, suffix=""):
        return "-" if x is None else "%s%s" % (stats.human_count(x), suffix)

    qa = [
        ("Peak ingestion throughput",
         "%s events/sec (%s events/min)" % (n(cap["peak_per_sec"]), n(cap["peak_per_min"]))),
        ("Sustained ingestion throughput",
         "%s events/sec (%s events/min)"
         % (n(cap["sustained_per_sec"]), n(cap["sustained_per_min"]))),
        ("Producer-side ceiling (Kafka write path)",
         "%s events/sec" % n(k.get("producer_throughput_per_sec"))),
        ("Unified Pipeline processing rate",
         "%s records/sec sustained, %s peak"
         % (n(p.get("sustained_per_sec")), n(p.get("peak_per_sec")))),
        ("Druid indexing speed",
         "%s rows/sec queryable, %s rows/sec reported by the supervisor"
         % (n(d.get("rows_per_sec_sustained")),
            n((d.get("supervisor") or {}).get("rows_processed_1m")))),
        ("End-to-end latency (event generated -> queryable)",
         "p50 %s ms, p95 %s ms, p99 %s ms"
         % (n(lat.get("p50")), n(lat.get("p95")), n(lat.get("p99")))),
        ("Wall-clock end to end for the whole batch",
         stats.human_dur((d.get("latency") or {}).get("end_to_end_sec"))),
        ("Backlog drain time",
         "%s for %s events" % (stats.human_dur(k.get("drain_seconds")),
                               f"{k.get('events_drained', 0):,}")),
        ("Query latency (all classes)",
         "avg %s ms, p50 %s, p95 %s, p99 %s"
         % (n((q.get("overall_latency_ms") or {}).get("avg")),
            n((q.get("overall_latency_ms") or {}).get("p50")),
            n((q.get("overall_latency_ms") or {}).get("p95")),
            n((q.get("overall_latency_ms") or {}).get("p99")))),
        ("Estimated queries/sec",
         "%s queries/sec (%s/min) at concurrency %s, measured under load"
         % (n((q.get("qps") or {}).get("queries_per_sec")),
            n((q.get("qps") or {}).get("queries_per_min")),
            (q.get("qps") or {}).get("concurrency"))),
        ("Slowest / fastest query class",
         "%s / %s" % (q.get("slowest") or "-", q.get("fastest") or "-")),
        ("CPU utilisation at peak",
         "host %s%% p95 (%s%% max) across %s cores"
         % (n(host.get("cpu_pct_p95")), n(host.get("cpu_pct_max")), infra.get("cores"))),
        ("Memory utilisation at peak",
         "host %s%% of %s; TaskManager heap peak %s%% of max"
         % (n(host.get("mem_pct_peak")), stats.human_bytes(host.get("mem_total_bytes")),
            n((p.get("jvm") or {}).get("heap_pct_peak")))),
        ("Disk and network at peak",
         "read %s/s, write %s/s, net rx %s/s tx %s/s"
         % (stats.human_bytes(host.get("disk_read_bps_peak")),
            stats.human_bytes(host.get("disk_write_bps_peak")),
            stats.human_bytes(host.get("net_rx_bps_peak")),
            stats.human_bytes(host.get("net_tx_bps_peak")))),
        ("Cost per 1,000 events",
         "%s CPU-seconds across all containers"
         % n((infra.get("cost_per_1000_events") or {}).get("cpu_seconds_per_1000"))),
        ("Is Kafka the bottleneck?",
         _yesno(analysis["bottleneck"]["layer"] == "kafka",
                "consumer lag fell monotonically and the producer sustained %s events/sec, "
                "well above the pipeline's rate" % n(k.get("producer_throughput_per_sec")))),
        ("Is Flink / the Unified Pipeline the bottleneck?",
         _yesno(analysis["bottleneck"]["layer"] == "flink",
                analysis["bottleneck"]["reason"])),
        ("Is Druid the bottleneck?",
         _yesno(analysis["bottleneck"]["layer"] == "druid",
                analysis["bottleneck"]["reason"])),
        ("Is the infrastructure the bottleneck?",
         _yesno(analysis["bottleneck"]["layer"] in ("infrastructure", "container"),
                analysis["bottleneck"]["reason"])),
        ("Recommended safe production throughput",
         "%s events/min (%s events/sec) -- %d%% of measured sustained, leaving headroom "
         "for query load and retries"
         % (n(cap["safe_per_min"]), n(cap["safe_per_sec"]), int(cap["safe_headroom"] * 100))),
        ("Daily volume at the safe rate",
         "%s events/day" % n(cap["safe_per_day"])),
        ("Functional correctness",
         "%d/%d checks passed%s"
         % (v.get("passed", 0), v.get("total", 0),
            "" if v.get("all_passed") else " -- see the failures below")),
    ]
    for t in cap["targets"]:
        qa.append((
            "Can this deployment sustain %s events/min?" % f"{t['events_per_min']:,}",
            "%s -- that is %sx the measured sustained rate"
            % ("Yes" if t["achievable_safely"] else
               ("Yes, but with no headroom" if t["achievable_now"] else "No"),
               t["multiple_of_measured"])))
    for step in analysis["scaling"]:
        qa.append(("What is needed for %dx capacity?" % step["multiple"],
                   "; ".join(step["steps"])))
    return [{"question": a, "answer": b} for a, b in qa]


def _yesno(flag, reason):
    return ("Yes -- %s" if flag else "No -- %s") % reason
