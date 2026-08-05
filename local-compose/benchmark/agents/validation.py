"""Validation Agent -- the eight functional checks, each with its evidence.

Every check records the query it ran and the rows it got back, so the report
does not just assert "deduplication works"; it shows the two published events,
the one stored row, and the mid they share.

This phase runs before the load phase on purpose. A performance number from a
pipeline that is silently dropping transformations is worse than no number,
and finding that out costs 200 events here instead of a million later.
"""

import json
import random
import time

from ..lib import stats
from . import dataset_engineering, telemetry_generation as gen

# The requirement's worked example: pid "search-service" in env "search" must
# come out of the JSONata transformation as "search-service-search".
# The preprocessor's code for "this mid is already in the datasource". The one
# dead-letter reason that is not data loss.
_DEDUP_CODE = "ERR_PP_1010"

PROBE_PID = "search-service"
PROBE_ENV = "search"
PROBE_PIPELINE = "search-service-search"


def run(ctx):
    cfg, log = ctx.cfg, ctx.log
    log.phase("Validation Agent", "functional checks with evidence")
    res = ctx.results.setdefault("validation", {})
    checks = []
    res["checks"] = checks

    tele = cfg["datasets"]["telemetry_id"]
    master = cfg["datasets"]["master_id"]
    ds = ctx.druid.datasource(tele)
    out_field = cfg["datasets"]["denorm_out_field"]

    # --- 1. datasets published ---------------------------------------------
    checks.append(_dataset_published(ctx, master, "master"))
    checks.append(_dataset_published(ctx, tele, "telemetry"))
    checks.append(_master_cached(ctx, master))

    # Baseline the dead-letter topics before a single probe event goes out.
    # Nothing used to write this key, so _no_failures read a missing baseline
    # as zero and compared this run's probes against every rejection the broker
    # had ever seen -- "failed +343" on a run that published 225 events. These
    # topics are never truncated, so on any stack that has rejected anything
    # the check could not pass.
    ctx.results["baseline_failed"] = ctx.kafka.failed_offsets()

    # --- publish the probe events ------------------------------------------
    events, dup_mids = _probe_events(ctx)
    unique_mids = sorted({e["mid"] for e in events})
    res["probe"] = {
        "events_published": len(events),
        "unique_mids": len(unique_mids),
        "duplicate_mids": len(dup_mids),
        "expected_rows": len(unique_mids),
    }

    before = ctx.kafka.total_end_offset(ctx.entry_topic)
    lines = [json.dumps({"dataset": tele, "event": e}, separators=(",", ":"))
             for e in events]
    log.step("publishing %d probe events (%d duplicates) to %s"
             % (len(lines), len(dup_mids), ctx.entry_topic))
    t_pub = time.time()
    ctx.kafka.produce_lines(ctx.entry_topic, lines)
    after = ctx.kafka.total_end_offset(ctx.entry_topic)
    checks.append(_check(
        "kafka_ingestion",
        "Events reach the Kafka entry topic",
        after - before >= len(lines),
        "topic %s end offset %d -> %d (+%d) for %d published events"
        % (ctx.entry_topic, before, after, after - before, len(lines)),
        evidence={"topic": ctx.entry_topic, "offset_before": before,
                  "offset_after": after, "published": len(lines)}))

    # --- 2. pipeline processed them ----------------------------------------
    log.step("waiting for the probe events to become queryable in Druid")
    target = len(unique_mids)
    got, waited = _wait_probe_rows(ctx, ds, unique_mids, target,
                                   cfg["validation"]["settle_timeout_sec"])
    checks.append(_check(
        "unified_pipeline_processing",
        "Unified Pipeline processes events end to end",
        got > 0,
        "%d of %d probe events reached the datasource in %s"
        % (got, target, stats.human_dur(waited)),
        evidence={"rows_found": got, "expected": target,
                  "seconds": round(waited, 1), "datasource": ds}))
    checks.append(_check(
        "druid_ingestion",
        "Druid indexes the processed events",
        got >= target,
        "%d / %d rows queryable" % (got, target),
        evidence={"rows": got, "expected": target}))

    if got == 0:
        log.error("no probe events arrived -- skipping the feature checks; see "
                  "dead-letter topics")
        res["failed_topics"] = ctx.kafka.failed_counts()
        return _finish(ctx, res)

    # --- 3. deduplication ---------------------------------------------------
    checks.append(_dedup(ctx, ds, dup_mids))

    # --- 4. transformations -------------------------------------------------
    checks.extend(_transformations(ctx, ds, unique_mids))

    # --- 5. denormalization -------------------------------------------------
    denorm = _denorm(ctx, ds, out_field)
    checks.append(denorm)

    # A jsonata_expr join that resolves nothing is a deployment-capability
    # problem, not a config error, and the flat actor_id key is always there as
    # a fallback. Rebuilding costs a couple of minutes and saves the whole run.
    #
    # The trigger is "nothing joined", not "the check failed". Those came apart
    # once: a check bug reported a fully-populated, correct join as mismatched,
    # and this rebuilt the dataset onto a different key and re-published the
    # probe set for nothing -- which then doubled the row count every later
    # check ran against. Rebuilding cannot fix wrong values anyway; it re-runs
    # the same join on a different key. Only an empty join is worth healing.
    if (_denorm_resolved_nothing(denorm)
            and ctx.results["datasets"]["telemetry"].get("denorm_strategy") == "jsonata"
            and cfg["datasets"].get("denorm_self_heal", True)):
        log.warn("the jsonata_expr join resolved nothing -- rebuilding on the flat "
                 "actor_id key and revalidating")
        dataset_engineering.rebuild_with_flat_denorm(ctx)
        events2, dups2 = _probe_events(ctx, salt=1)
        ctx.kafka.produce_lines(ctx.entry_topic, [
            json.dumps({"dataset": tele, "event": e}, separators=(",", ":"))
            for e in events2])
        mids2 = sorted({e["mid"] for e in events2})
        _wait_probe_rows(ctx, ds, mids2, len(mids2), cfg["validation"]["settle_timeout_sec"])
        retry = _denorm(ctx, ds, out_field)
        retry["name"] = "denormalization_after_rebuild"
        checks.append(retry)
        unique_mids = mids2
        dup_mids = dups2

    # --- 6. query -----------------------------------------------------------
    checks.append(_query_works(ctx, tele, ds))

    # --- 7. nothing was dropped --------------------------------------------
    checks.append(_no_failures(ctx))

    return _finish(ctx, res)


def _finish(ctx, res):
    checks = res["checks"]
    res["passed"] = sum(1 for c in checks if c["passed"])
    res["failed"] = sum(1 for c in checks if not c["passed"])
    res["total"] = len(checks)
    res["all_passed"] = res["failed"] == 0
    ctx.log.table(
        ["check", "result", "detail"],
        [[c["name"], "PASS" if c["passed"] else "FAIL", c["detail"][:88]] for c in checks])
    if res["all_passed"]:
        ctx.log.ok("all %d functional checks passed" % res["total"])
    else:
        ctx.log.error("%d of %d functional checks failed" % (res["failed"], res["total"]))
    return res


# --- individual checks --------------------------------------------------------
def _check(name, title, passed, detail, evidence=None):
    return {"name": name, "title": title, "passed": bool(passed),
            "detail": detail, "evidence": evidence or {}}


def _dataset_published(ctx, dataset_id, kind):
    row = ctx.docker.psql_one(
        "SELECT status FROM datasets WHERE dataset_id='%s';" % dataset_id)
    live = ctx.api.read(dataset_id, fields=["dataset_id", "status", "type"])
    ok = row == "Live" and (live or {}).get("status") == "Live"
    return _check(
        "dataset_published_%s" % kind,
        "%s dataset is published and Live" % kind.title(),
        ok,
        "%s status=%s (metadata store), api reports %s"
        % (dataset_id, row, (live or {}).get("status")),
        evidence={"dataset_id": dataset_id, "db_status": row, "api": live})


def _master_cached(ctx, master_id):
    db = ctx.docker.psql_one(
        "SELECT dataset_config->'cache_config'->>'redis_db' FROM datasets "
        "WHERE dataset_id='%s';" % master_id) or "0"
    rc, o, _ = ctx.docker.exec("valkey_denorm", ["valkey-cli", "-n", db, "DBSIZE"],
                               check=False, timeout=20)
    try:
        size = int(o.strip())
    except ValueError:
        size = 0
    want = len(ctx.users)
    sample_key = ctx.users[0]["id"]
    rc2, val, _ = ctx.docker.exec("valkey_denorm", ["valkey-cli", "-n", db, "GET", sample_key],
                                  check=False, timeout=20)
    return _check(
        "master_data_cached",
        "Master dataset records are cached and joinable",
        size >= want and bool(val.strip()),
        "%d/%d records in Valkey db %s; GET %s returns %d bytes"
        % (size, want, db, sample_key, len(val.strip())),
        evidence={"redis_db": db, "dbsize": size, "expected": want,
                  "sample_key": sample_key, "sample_value": val.strip()[:400]})


def _dedup(ctx, ds, dup_mids):
    if not dup_mids:
        return _check("deduplication", "Duplicate events are dropped", False,
                      "no duplicate probe events were generated")
    quoted = ",".join("'%s'" % m for m in dup_mids)
    rows, _ = ctx.druid.sql(
        'SELECT "mid", COUNT(*) AS copies FROM "%s" WHERE "mid" IN (%s) '
        'GROUP BY "mid" ORDER BY copies DESC' % (ds, quoted))
    found = {r["mid"]: int(r["copies"]) for r in rows}
    extra = {m: c for m, c in found.items() if c > 1}
    ok = bool(found) and not extra
    return _check(
        "deduplication",
        "Republishing an event with the same mid stores one row",
        ok,
        "%d mids published twice, %d stored once, %d stored more than once"
        % (len(dup_mids), sum(1 for c in found.values() if c == 1), len(extra)),
        evidence={"duplicate_mids_published": dup_mids[:10],
                  "rows_per_mid": dict(list(found.items())[:10]),
                  "violations": extra,
                  "query": 'SELECT "mid", COUNT(*) FROM "%s" WHERE "mid" IN (...) '
                           'GROUP BY "mid"' % ds})


def _transformations(ctx, ds, mids):
    cols = ctx.druid.columns(ds.replace("_events", ""))
    out = []

    have_pipeline = "pipeline" in cols
    rows, _ = ctx.druid.sql(
        'SELECT "pipeline", COUNT(*) AS c FROM "%s" WHERE "context.pdata.pid" = \'%s\' '
        'GROUP BY "pipeline" ORDER BY c DESC LIMIT 5' % (ds, PROBE_PID)) \
        if have_pipeline and "context.pdata.pid" in cols else ([], 0)
    if not rows and have_pipeline:
        rows, _ = ctx.druid.sql(
            'SELECT "pipeline", COUNT(*) AS c FROM "%s" GROUP BY "pipeline" '
            'ORDER BY c DESC LIMIT 5' % ds)
    values = {(r.get("pipeline") or "null"): int(r.get("c") or 0) for r in rows}
    ok = PROBE_PIPELINE in values
    out.append(_check(
        "transformation_pipeline",
        'JSONata: context.pdata.pid & "-" & context.env',
        ok,
        "expected %r; datasource holds %s" % (PROBE_PIPELINE, values or "no pipeline column"),
        evidence={"expected": PROBE_PIPELINE, "observed": values,
                  "column_present": have_pipeline}))

    # isLargeEvent lands as a BIGINT 1/0, not a JSON boolean -- Druid has no
    # boolean storage type here, so the check compares against the numeric form.
    have_large = "isLargeEvent" in cols
    if have_large:
        rows2, _ = ctx.druid.sql(
            'SELECT "isLargeEvent" AS flag, MIN("edata.size") AS min_size, '
            'MAX("edata.size") AS max_size, COUNT(*) AS c FROM "%s" '
            'GROUP BY "isLargeEvent"' % ds)
        by_flag = {str(r.get("flag")): r for r in rows2}
        consistent = all(
            (float(r.get("min_size") or 0) > 100000) == (str(r.get("flag")) in ("1", "true"))
            for r in rows2 if r.get("flag") is not None and r.get("min_size") is not None)
        ok2 = bool(rows2) and any(r.get("flag") is not None for r in rows2) and consistent
        detail = "; ".join(
            "flag=%s size %s..%s (%s rows)"
            % (r.get("flag"), r.get("min_size"), r.get("max_size"), r.get("c"))
            for r in rows2)
    else:
        by_flag, ok2, detail = {}, False, "no isLargeEvent column in the datasource"
    out.append(_check(
        "transformation_is_large_event",
        "JSONata: edata.size > 100000",
        ok2, detail,
        evidence={"by_flag": {k: {kk: vv for kk, vv in v.items()} for k, v in by_flag.items()},
                  "note": "Druid stores the boolean as BIGINT 1/0"}))
    return out


def _denorm_resolved_nothing(denorm):
    """Did the join produce no joined data at all?

    Two shapes count: the datasource grew no out_field columns, or it grew them
    and every row left them null. Anything else -- including a populated join
    whose values look wrong -- is a result to report, not one to rebuild.
    """
    ev = denorm.get("evidence") or {}
    if not ev.get("columns"):
        return True
    return int(ev.get("rows_joined") or 0) == 0


def _denorm_name_col(joined):
    """The joined column the correctness comparison is made on."""
    return next((c for c in joined if c.endswith(".userName")), None)


def _denorm_select_cols(joined, limit=8):
    """Which joined columns to pull into the sample.

    Bounded, because the sample is recorded verbatim as evidence and a master
    with forty attributes would bury the report. But the bound has to make room
    for the column the check actually compares on: the columns arrive sorted,
    `user.userName` sorts last of ten, and truncating to the first eight meant
    the comparison read None out of every row and declared a 100%-joined
    datasource mismatched.
    """
    cols = list(joined[:limit])
    name_col = _denorm_name_col(joined)
    if name_col and name_col not in cols:
        cols.append(name_col)
    return cols


def _denorm(ctx, ds, out_field):
    dataset_id = ds.replace("_events", "")
    cols = ctx.druid.columns(dataset_id)
    joined = sorted(c for c in cols if c.startswith(out_field + "."))
    if not joined:
        return _check(
            "denormalization",
            "Telemetry rows carry the joined user attributes",
            False,
            "no %s.* columns in the datasource (columns: %s)"
            % (out_field, ", ".join(sorted(cols)[:12])),
            evidence={"columns": sorted(cols)})

    select = ", ".join('"%s"' % c for c in _denorm_select_cols(joined))
    rows, _ = ctx.druid.sql(
        'SELECT "actor.id" AS actor_id, %s FROM "%s" WHERE "%s" IS NOT NULL LIMIT 5'
        % (select, ds, joined[0]))
    total, _ = ctx.druid.sql('SELECT COUNT(*) AS c FROM "%s"' % ds)
    filled, _ = ctx.druid.sql(
        'SELECT COUNT(*) AS c FROM "%s" WHERE "%s" IS NOT NULL' % (ds, joined[0]))
    n_total = int((total or [{}])[0].get("c") or 0)
    n_filled = int((filled or [{}])[0].get("c") or 0)
    pct = round(100.0 * n_filled / n_total, 2) if n_total else 0

    # Verify the join is correct, not merely populated: the joined userName has
    # to be the one the master holds for that actor.id.
    correct = None
    if rows:
        by_id = {u["id"]: u for u in ctx.users}
        name_col = _denorm_name_col(joined)
        if name_col:
            correct = all(
                (by_id.get(r.get("actor_id")) or {}).get("userName") == r.get(name_col)
                for r in rows if r.get("actor_id") in by_id)
    ok = n_filled > 0 and (correct is not False)
    return _check(
        "denormalization",
        "Telemetry rows carry the joined user attributes",
        ok,
        "%d/%d rows joined (%.1f%%) on %d columns%s"
        % (n_filled, n_total, pct, len(joined),
           "" if correct is None else (", values match the master"
                                       if correct else ", values DO NOT match the master")),
        evidence={"columns": joined, "rows_joined": n_filled, "rows_total": n_total,
                  "pct": pct, "sample": rows[:3], "values_match_master": correct})


def _query_works(ctx, dataset_id, ds):
    rows, elapsed = ctx.druid.sql(
        'SELECT "actor.id" AS actor_id, COUNT(*) AS events FROM "%s" '
        'GROUP BY 1 ORDER BY events DESC LIMIT 5' % ds)
    api_ok, api_err = False, None
    try:
        res, _ = ctx.api.query(dataset_id, {
            "context": {"dataset": dataset_id},
            "query": {"queryType": "timeseries", "dataSource": ds,
                      "intervals": ["1000-01-01/3000-01-01"],
                      "granularity": "all",
                      "aggregations": [{"type": "count", "name": "count"}]},
        })
        api_ok = (res or {}).get("params", {}).get("status") == "SUCCESS"
    except Exception as exc:
        api_err = str(exc)[:200]
    return _check(
        "druid_query",
        "The datasource answers analytical queries",
        bool(rows),
        "group-by returned %d rows in %.0f ms; dataset-api query %s"
        % (len(rows), elapsed * 1000, "succeeded" if api_ok else "failed"),
        evidence={"sample": rows, "sql_ms": round(elapsed * 1000, 1),
                  "api_query_ok": api_ok, "api_error": api_err})


def _no_failures(ctx):
    """Did validation lose any data?

    Not the same question as "did anything land on a dead-letter topic". The
    probe deliberately republishes mids, and restarting the pipeline during
    setup makes Flink replay whatever was not yet checkpointed -- both arrive
    at the duplicate check and both are routed to `failed` with ERR_PP_1010.
    That code means the event's row is already in the datasource, so counting
    it as loss marks a healthy pipeline as lossy. An extractor or transform
    rejection is the opposite: that event has no row anywhere.
    """
    after = ctx.kafka.failed_offsets()
    before = ctx.results.get("baseline_failed") or {}

    dupes, lost, delta, codes = 0, {}, {}, {}
    for topic, ends in after.items():
        starts = before.get(topic) or {}
        ranges = {p: (starts.get(p, 0), end) for p, end in ends.items()
                  if end > starts.get(p, 0)}
        n = sum(e - s for s, e in ranges.values())
        if not n:
            continue
        delta[topic] = n
        by_code = ctx.kafka.classify_failed(topic, ranges)
        codes[topic] = by_code
        d = by_code.get(_DEDUP_CODE, 0)
        dupes += d
        if n - d > 0:
            lost[topic] = n - d

    if lost:
        detail = "; ".join(
            "%s +%d not duplicates (%s)"
            % (t, v, ", ".join("%s=%d" % kv for kv in sorted(codes[t].items())))
            for t, v in sorted(lost.items()))
    elif dupes:
        detail = ("%d duplicate rejection(s), no lost events -- the row for each "
                  "is already in the datasource" % dupes)
    else:
        detail = "dead-letter topics unchanged"
    return _check(
        "no_dead_letter_events",
        "No events were lost during functional validation",
        not lost, detail,
        evidence={"before": before, "after": after, "delta": delta,
                  "by_error_code": codes,
                  "duplicate_rejections": dupes, "lost": lost})


# --- probe corpus --------------------------------------------------------------
def _probe_events(ctx, salt=0):
    """A small, fully-known event set covering every feature under test.

    Fixed pid/env on a share of the events so the transformation check has a
    deterministic expected value, a controlled mix of large and small
    edata.size, and a set of events re-sent verbatim so dedup has something to
    collapse.
    """
    cfg = ctx.cfg
    n = cfg["validation"]["functional_events"]
    n_dup = min(cfg["validation"]["dedup_probe_events"], max(1, n // 4))
    rnd = random.Random(cfg["load"]["seed"] + 7919 + salt)
    now_ms = int(time.time() * 1000)

    events = []
    for i in range(n):
        large = (i % 4 == 0)
        ev = gen.make_event(rnd, ctx.users, now_ms, 60_000, large, rnd.randint(400, 1200))
        # Half the probes use the requirement's worked example verbatim.
        if i % 2 == 0:
            ev["context"]["pdata"]["pid"] = PROBE_PID
            ev["context"]["env"] = PROBE_ENV
        ev["mid"] = "probe-%d-%04d" % (salt, i)
        events.append(ev)

    # Duplicates: byte-identical re-sends of events already in the list.
    dups = [dict(events[i]) for i in range(0, n_dup)]
    dup_mids = [d["mid"] for d in dups]
    merged = []
    for i, ev in enumerate(events):
        merged.append(ev)
        if i < len(dups):
            merged.append(dups[i])
    return merged, dup_mids


def _wait_probe_rows(ctx, ds, mids, target, timeout_sec, poll=5):
    quoted = ",".join("'%s'" % m for m in mids[:500])
    t0 = time.time()
    got = 0
    while time.time() - t0 < timeout_sec:
        try:
            rows, _ = ctx.druid.sql(
                'SELECT COUNT(*) AS c FROM "%s" WHERE "mid" IN (%s)' % (ds, quoted))
            got = int((rows or [{}])[0].get("c") or 0)
        except Exception:
            got = 0
        if got >= target:
            break
        time.sleep(poll)
    return got, time.time() - t0
