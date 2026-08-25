"""Infrastructure Metrics Agent -- host and per-container resource cost.

Two questions: what did the deployment consume while sustaining its measured
throughput, and which component ran out of something first.

"Cost per 1000 events" is derived here because it is the only resource number
that transfers to a differently-sized deployment. Absolute CPU percentages
describe this 4-core VM and nothing else; CPU-seconds per 1000 events is a
property of the pipeline and can be multiplied out.
"""

from ..lib import stats


def analyze(ctx):
    cfg, log = ctx.cfg, ctx.log
    log.phase("Infrastructure Metrics Agent", "host and container resources")
    res = ctx.results.setdefault("infrastructure", {})

    lo = getattr(ctx, "drain_start", 0)
    hi = getattr(ctx, "settle_end", None) or getattr(ctx, "drain_end", None)

    def window(series):
        return [s for s in series
                if s.get("t", 0) >= lo and (hi is None or s.get("t", 0) <= hi + 5)]

    host = window(ctx.sampler.host_samples)
    res["host"] = _host(host, ctx)
    res["cores"] = ctx.infra.cores()

    containers = {}
    for role in sorted({s.get("role") for s in ctx.sampler.infra_samples if s.get("role")}):
        series = window(ctx.sampler.container_series(role))
        if not series:
            continue
        containers[role] = _container(series)
    res["containers"] = containers

    events = ctx.results.get("kafka", {}).get("events_drained") or 0
    res["cost_per_1000_events"] = _cost(containers, events, lo, hi)
    res["events_measured"] = events

    res["saturation"] = _saturation(cfg, res)
    res["correlation"] = _correlate(ctx, host)

    rows = []
    for role, c in sorted(containers.items(),
                          key=lambda kv: -(kv[1].get("cpu_pct_avg") or 0)):
        rows.append([role,
                     "%.1f" % (c.get("cpu_pct_avg") or 0),
                     "%.1f" % (c.get("cpu_pct_p95") or 0),
                     stats.human_bytes(c.get("mem_anon_avg")),
                     stats.human_bytes(c.get("mem_anon_peak")),
                     "%.1f" % (c.get("mem_pct_of_limit_peak") or 0)
                     if c.get("mem_pct_of_limit_peak") is not None else "-"])
    if rows:
        log.table(["container", "cpu% avg", "cpu% p95", "mem avg", "mem peak", "%limit"], rows)

    h = res["host"]
    if h.get("cpu_pct_avg") is not None:
        log.info("host: CPU avg %.1f%% / peak %.1f%%, memory peak %.1f%%, load1 peak %.2f"
                 % (h.get("cpu_pct_avg") or 0, h.get("cpu_pct_p95") or 0,
                    h.get("mem_pct_peak") or 0, h.get("load1_peak") or 0))
    for note in res["saturation"]["notes"]:
        log.info("  " + note)
    return res


def csv_rows(ctx):
    rows = []
    for s in ctx.sampler.infra_samples:
        rows.append({
            "elapsed_sec": round(s.get("elapsed", 0), 2),
            "role": s.get("role"),
            "container": s.get("container"),
            "state": s.get("state"),
            "cpu_pct": s.get("cpu_pct"),
            "cpu_cores_used": s.get("cpu_cores_used"),
            "mem_anon_bytes": s.get("mem_anon_bytes"),
            "mem_cache_bytes": s.get("mem_cache_bytes"),
            "mem_limit_bytes": s.get("mem_limit_bytes"),
            "mem_pct_of_limit": s.get("mem_pct_of_limit"),
        })
    return rows


def host_csv_rows(ctx):
    rows = []
    for s in ctx.sampler.host_samples:
        rows.append({
            "elapsed_sec": round(s.get("elapsed", 0), 2),
            "cpu_pct": s.get("cpu_pct"),
            "cpu_iowait_pct": s.get("cpu_iowait_pct"),
            "mem_pct": s.get("mem_pct"),
            "mem_used_bytes": s.get("mem_used_bytes"),
            "load1": s.get("load1"),
            "disk_read_bps": s.get("disk_read_bps"),
            "disk_write_bps": s.get("disk_write_bps"),
            "disk_io_util": s.get("disk_io_util"),
            "disk_pct": s.get("disk_pct"),
            "net_rx_bps": s.get("net_rx_bps"),
            "net_tx_bps": s.get("net_tx_bps"),
        })
    return rows


# --- helpers -----------------------------------------------------------------
def _host(series, ctx):
    if not series:
        return {"samples": 0}
    def col(k):
        return [s.get(k) for s in series if s.get(k) is not None]
    last = series[-1]
    out = {
        "samples": len(series),
        "source": "prometheus/node-exporter" if ctx.infra.prometheus_up() else "/proc",
        "cpu_pct_avg": _avg(col("cpu_pct")),
        "cpu_pct_p95": stats.pct(col("cpu_pct"), 95),
        "cpu_pct_max": max(col("cpu_pct")) if col("cpu_pct") else None,
        "cpu_iowait_pct_avg": _avg(col("cpu_iowait_pct")),
        "mem_pct_avg": _avg(col("mem_pct")),
        "mem_pct_peak": max(col("mem_pct")) if col("mem_pct") else None,
        "mem_total_bytes": last.get("mem_total_bytes"),
        "mem_used_peak_bytes": max(col("mem_used_bytes")) if col("mem_used_bytes") else None,
        "load1_avg": _avg(col("load1")),
        "load1_peak": max(col("load1")) if col("load1") else None,
        "disk_read_bps_peak": max(col("disk_read_bps")) if col("disk_read_bps") else None,
        "disk_write_bps_peak": max(col("disk_write_bps")) if col("disk_write_bps") else None,
        "disk_io_util_peak": max(col("disk_io_util")) if col("disk_io_util") else None,
        "disk_pct": last.get("disk_pct"),
        "net_rx_bps_peak": max(col("net_rx_bps")) if col("net_rx_bps") else None,
        "net_tx_bps_peak": max(col("net_tx_bps")) if col("net_tx_bps") else None,
    }
    return out


def _container(series):
    cpu = [s.get("cpu_pct") for s in series if s.get("cpu_pct") is not None]
    mem = [s.get("mem_anon_bytes") for s in series if s.get("mem_anon_bytes")]
    first_cpu = next((s.get("cpu_usage_sec") for s in series
                      if s.get("cpu_usage_sec") is not None), None)
    last_cpu = next((s.get("cpu_usage_sec") for s in reversed(series)
                     if s.get("cpu_usage_sec") is not None), None)
    return {
        "samples": len(series),
        "state": series[-1].get("state"),
        "cpu_pct_avg": round(_avg(cpu), 2) if cpu else None,
        "cpu_pct_p95": stats.pct(cpu, 95),
        "cpu_pct_max": max(cpu) if cpu else None,
        # Total CPU-seconds consumed over the window: the input to cost/1000.
        "cpu_seconds": round(last_cpu - first_cpu, 2)
        if (first_cpu is not None and last_cpu is not None) else None,
        "mem_anon_avg": int(_avg(mem)) if mem else None,
        "mem_anon_peak": max(mem) if mem else None,
        "mem_limit_bytes": series[-1].get("mem_limit_bytes"),
        "mem_pct_of_limit_peak": stats.pct(
            [s.get("mem_pct_of_limit") for s in series], 95),
    }


def _cost(containers, events, lo, hi):
    """CPU-seconds and peak memory per 1000 events, for the pipeline path."""
    if not events:
        return {}
    per = {}
    total = 0.0
    for role, c in containers.items():
        secs = c.get("cpu_seconds")
        if secs is None:
            continue
        per[role] = round(1000.0 * secs / events, 4)
        total += secs
    return {
        "cpu_seconds_total": round(total, 2),
        "cpu_seconds_per_1000": round(1000.0 * total / events, 4),
        "by_container": dict(sorted(per.items(), key=lambda kv: -kv[1])),
        "window_sec": round((hi or lo) - lo, 2) if hi else None,
    }


def _saturation(cfg, res):
    """Which resource, if any, was actually the limit."""
    cap = cfg["capacity"]
    notes, limits = [], []
    host = res.get("host") or {}
    cpu_peak = host.get("cpu_pct_p95")
    mem_peak = host.get("mem_pct_peak")
    if cpu_peak is not None and cpu_peak >= cap["cpu_saturation_pct"]:
        limits.append("host_cpu")
        notes.append("host CPU reached %.0f%% (>= %.0f%% threshold) -- CPU-bound"
                     % (cpu_peak, cap["cpu_saturation_pct"]))
    if mem_peak is not None and mem_peak >= cap["mem_saturation_pct"]:
        limits.append("host_memory")
        notes.append("host memory reached %.0f%% -- memory-bound" % mem_peak)
    io = host.get("disk_io_util_peak")
    if io is not None and io >= 0.85:
        limits.append("disk_io")
        notes.append("disk was busy %.0f%% of the time -- I/O-bound" % (100 * io))
    for role, c in (res.get("containers") or {}).items():
        pct = c.get("mem_pct_of_limit_peak")
        if pct is not None and pct >= cap["mem_saturation_pct"]:
            limits.append("%s_memory_limit" % role)
            notes.append("%s reached %.0f%% of its memory limit" % (role, pct))
    if not limits:
        notes.append("no resource crossed its saturation threshold -- the limit is "
                     "in the pipeline's own concurrency, not the hardware")
    return {"limits": limits, "notes": notes,
            "cpu_headroom_pct": round(100.0 - (cpu_peak or 0), 1) if cpu_peak is not None else None}


def _correlate(ctx, host_series):
    """Pearson r between host CPU and observed throughput.

    A strong positive correlation says throughput is tracking CPU, i.e. adding
    cores would help. A flat or negative one says something else -- a lock, a
    single-threaded operator, an external wait -- is setting the pace, and more
    hardware would not move the number.
    """
    kafka = ctx.sampler.kafka_samples
    if len(kafka) < 3 or len(host_series) < 3:
        return {"note": "not enough samples to correlate"}
    pairs = []
    for k in kafka[1:]:
        rate = k.get("events_per_sec")
        if not rate:
            continue
        # The host sample nearest this Kafka sample in time.
        near = min(host_series, key=lambda h: abs(h.get("t", 0) - k["t"]))
        if abs(near.get("t", 0) - k["t"]) > 30 or near.get("cpu_pct") is None:
            continue
        pairs.append((near["cpu_pct"], rate))
    if len(pairs) < 3:
        return {"note": "not enough overlapping samples to correlate"}
    r = _pearson([p[0] for p in pairs], [p[1] for p in pairs])
    return {
        "pairs": len(pairs),
        "cpu_vs_throughput_r": round(r, 3) if r is not None else None,
        "interpretation": _interpret(r),
    }


def _interpret(r):
    if r is None:
        return "undefined (no variance in one of the series)"
    if r >= 0.6:
        return ("throughput tracks CPU closely -- the workload is CPU-bound and "
                "more cores should raise the ceiling")
    if r >= 0.25:
        return "throughput partially tracks CPU -- CPU is one of several constraints"
    if r <= -0.25:
        return ("CPU rises as throughput falls -- time is going somewhere other than "
                "useful work (GC, retries, contention)")
    return ("throughput is largely independent of CPU -- the constraint is "
            "concurrency or an external wait, not processor time")


def _pearson(xs, ys):
    n = len(xs)
    mx, my = sum(xs) / n, sum(ys) / n
    num = sum((x - mx) * (y - my) for x, y in zip(xs, ys))
    dx = sum((x - mx) ** 2 for x in xs) ** 0.5
    dy = sum((y - my) ** 2 for y in ys) ** 0.5
    return num / (dx * dy) if dx and dy else None


def _avg(xs):
    return sum(xs) / float(len(xs)) if xs else None
