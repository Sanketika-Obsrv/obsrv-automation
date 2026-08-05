"""Query Benchmark Agent -- latency distribution and sustainable QPS.

Nine query classes, each timed over `queries.iterations` runs after a warmup.
Warmups are discarded rather than averaged in: the first execution of a query
pays for Druid's segment mapping and the broker's result-level cache being
cold, and including it makes p99 a measurement of cache state rather than of
query cost.

Queries/sec is measured, not extrapolated from single-query latency. Inverting
p50 assumes the system scales perfectly with concurrency, which is exactly the
assumption a capacity report should not make -- so a separate probe runs
`queries.concurrency` clients flat out for a fixed window and counts what
actually completed.
"""

import threading
import time

from ..lib import stats


def query_set(ds, sample_user=None, sample_city=None):
    """The nine classes the requirement names, as Druid SQL.

    Names are stable so two runs can be diffed; each carries the property that
    makes it interesting for a capacity report.
    """
    user = sample_user or "user-0001"
    city = sample_city or "Bengaluru"
    return [
        ("count", "Total row count",
         'SELECT COUNT(*) AS c FROM "%s"' % ds),
        ("filter", "Filtered count on a low-cardinality dimension",
         'SELECT COUNT(*) AS c FROM "%s" WHERE "eid" = \'SEARCH\'' % ds),
        ("latest_events", "Most recent events (ordered scan)",
         'SELECT __time, "mid", "eid", "actor.id" FROM "%s" '
         'ORDER BY __time DESC LIMIT 100' % ds),
        ("group_by", "Group by a high-cardinality dimension",
         'SELECT "actor.id" AS actor, COUNT(*) AS events FROM "%s" '
         'GROUP BY 1 ORDER BY events DESC LIMIT 50' % ds),
        ("time_series", "Per-minute time series",
         'SELECT TIME_FLOOR(__time, \'PT1M\') AS minute, COUNT(*) AS events '
         'FROM "%s" GROUP BY 1 ORDER BY 1' % ds),
        ("top_n", "TopN over a dimension",
         'SELECT "eid", COUNT(*) AS events FROM "%s" GROUP BY 1 '
         'ORDER BY events DESC LIMIT 10' % ds),
        ("aggregation", "Multi-aggregate rollup",
         'SELECT COUNT(*) AS events, AVG("edata.size") AS avg_size, '
         'MAX("edata.size") AS max_size, COUNT(DISTINCT "actor.id") AS actors '
         'FROM "%s"' % ds),
        ("user_lookup", "Point lookup by user",
         'SELECT COUNT(*) AS events FROM "%s" WHERE "actor.id" = \'%s\'' % (ds, user)),
        ("city_lookup", "Lookup on a denormalized attribute",
         'SELECT COUNT(*) AS events FROM "%s" WHERE "user.city" = \'%s\'' % (ds, city)),
    ]


def run(ctx):
    cfg, log = ctx.cfg, ctx.log
    log.phase("Query Benchmark Agent", "latency distribution and QPS")
    res = ctx.results.setdefault("queries", {})
    q = cfg["queries"]
    tele = cfg["datasets"]["telemetry_id"]
    ds = ctx.druid.datasource(tele)

    sample_user = ctx.users[0]["id"] if getattr(ctx, "users", None) else None
    sample_city = ctx.users[0]["city"] if getattr(ctx, "users", None) else None
    cols = ctx.druid.columns(tele)
    queries = [x for x in query_set(ds, sample_user, sample_city)
               if _runnable(x[2], cols)]
    skipped = [x[0] for x in query_set(ds, sample_user, sample_city)
               if not _runnable(x[2], cols)]
    if skipped:
        log.warn("skipping %s -- the required column is not in the datasource"
                 % ", ".join(skipped))
    res["skipped"] = skipped
    res["row_count_at_test"] = ctx.druid.count(tele)

    log.step("%d query classes x %d iterations (warmup %d)"
             % (len(queries), q["iterations"], q["warmup"]))
    results = []
    for name, title, sql in queries:
        r = _time_query(ctx, name, title, sql, q)
        results.append(r)
        log.info("%-14s avg %7.1f ms  p50 %7.1f  p95 %7.1f  p99 %7.1f  max %7.1f  (%d rows)"
                 % (name, r["latency_ms"]["avg"], r["latency_ms"]["p50"],
                    r["latency_ms"]["p95"], r["latency_ms"]["p99"],
                    r["latency_ms"]["max"], r["rows"]))
    res["by_query"] = results

    allm = [ms for r in results for ms in r["samples_ms"]]
    res["overall_latency_ms"] = stats.summarize(allm, "ms")
    res["slowest"] = max(results, key=lambda r: r["latency_ms"]["p95"])["name"] if results else None
    res["fastest"] = min(results, key=lambda r: r["latency_ms"]["p95"])["name"] if results else None

    res["qps"] = _qps_probe(ctx, queries, q)
    log.info("sustained %s queries/sec (%s queries/min) at concurrency %d"
             % (stats.human_count(res["qps"]["queries_per_sec"]),
                stats.human_count(res["qps"]["queries_per_min"]),
                q["concurrency"]))
    log.table(
        ["query", "avg ms", "p50", "p95", "p99", "max", "rows"],
        [[r["name"], "%.1f" % r["latency_ms"]["avg"], "%.1f" % r["latency_ms"]["p50"],
          "%.1f" % r["latency_ms"]["p95"], "%.1f" % r["latency_ms"]["p99"],
          "%.1f" % r["latency_ms"]["max"], r["rows"]] for r in results])
    return res


def csv_rows(ctx):
    rows = []
    for r in ctx.results.get("queries", {}).get("by_query", []):
        for i, ms in enumerate(r["samples_ms"]):
            rows.append({"query": r["name"], "iteration": i + 1, "latency_ms": round(ms, 3),
                         "rows_returned": r["rows"]})
    return rows


# --- helpers -----------------------------------------------------------------
def _runnable(sql, cols):
    """Drop a query that references a column the datasource does not have.

    A missing column is a Druid 400, which would otherwise be recorded as an
    enormous latency and poison the percentiles.
    """
    for col in ("user.city", "actor.id", "edata.size", "eid", "mid"):
        if '"%s"' % col in sql and col not in cols:
            return False
    return True


def _time_query(ctx, name, title, sql, q):
    for _ in range(q["warmup"]):
        try:
            ctx.druid.sql(sql, timeout=q["timeout_sec"])
        except Exception:
            break
    samples, rows, errors = [], 0, 0
    for _ in range(q["iterations"]):
        try:
            got, elapsed = ctx.druid.sql(sql, timeout=q["timeout_sec"])
            samples.append(elapsed * 1000.0)
            rows = len(got)
        except Exception:
            errors += 1
    return {
        "name": name, "title": title, "sql": sql,
        "iterations": q["iterations"], "errors": errors, "rows": rows,
        "samples_ms": [round(s, 3) for s in samples],
        "latency_ms": stats.summarize(samples, "ms") if samples
        else {"count": 0, "avg": 0, "p50": 0, "p95": 0, "p99": 0, "max": 0},
    }


def _qps_probe(ctx, queries, q):
    """Saturation probe: N clients issuing the query mix for a fixed window."""
    if not queries:
        return {"queries_per_sec": 0, "queries_per_min": 0}
    seconds = q["qps_probe_seconds"]
    conc = q["concurrency"]
    stop = time.time() + seconds
    counts = [0] * conc
    lat = [[] for _ in range(conc)]
    errs = [0] * conc

    def worker(idx):
        i = idx
        while time.time() < stop:
            _, _, sql = queries[i % len(queries)]
            try:
                _, elapsed = ctx.druid.sql(sql, timeout=q["timeout_sec"])
                lat[idx].append(elapsed * 1000.0)
                counts[idx] += 1
            except Exception:
                errs[idx] += 1
            i += 1

    ctx.log.step("QPS probe: %d concurrent clients for %ds" % (conc, seconds))
    t0 = time.time()
    threads = [threading.Thread(target=worker, args=(i,), daemon=True) for i in range(conc)]
    for t in threads:
        t.start()
    for t in threads:
        t.join(timeout=seconds + q["timeout_sec"] + 30)
    elapsed = time.time() - t0

    total = sum(counts)
    all_lat = [x for l in lat for x in l]
    return {
        "concurrency": conc,
        "window_sec": round(elapsed, 2),
        "queries_completed": total,
        "errors": sum(errs),
        "queries_per_sec": round(total / elapsed, 2) if elapsed else 0,
        "queries_per_min": round(total / elapsed * 60, 1) if elapsed else 0,
        "latency_under_load_ms": stats.summarize(all_lat, "ms"),
    }
