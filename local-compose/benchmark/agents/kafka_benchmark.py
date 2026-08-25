"""Kafka Benchmark Agent -- backlog generation, drain measurement, analysis.

The measurement strategy is deliberately backlog-based rather than
steady-rate. Pushing events at a fixed rate and watching them keep up tells
you the deployment can handle that rate; it does not tell you what it can
handle. Stopping the consumer, building a known backlog, then starting the
consumer and timing the drain measures the pipeline's actual ceiling, because
throughout the drain there is always more work available than the pipeline
can take. Every throughput number in the report comes from that window.
"""

import time

from ..lib import stats
from ..lib.log import Fatal


def load(ctx):
    """Pause the pipeline, build the backlog, restart the pipeline."""
    cfg, log = ctx.cfg, ctx.log
    log.phase("Kafka Benchmark Agent", "backlog generation")
    res = ctx.results.setdefault("kafka", {})

    res["failed_before"] = ctx.kafka.failed_counts()
    topic = ctx.entry_topic
    before = ctx.kafka.total_end_offset(topic)
    res["topic"] = topic
    res["partitions"] = ctx.kafka.partitions(topic)
    res["end_offset_before"] = before

    paused = False
    if cfg["pipeline"]["pause_before_load"]:
        paused = ctx.pipeline.pause()
        res["paused_for_load"] = paused
        if not paused:
            log.warn("could not pause the pipeline; the backlog will drain while "
                     "it is being built, so peak throughput will be understated")
    else:
        res["paused_for_load"] = False

    n = ctx.results["generation"]["lines"]
    rate = cfg["load"]["producer_rate"]
    workers = cfg["load"]["concurrent_producers"]
    log.step("producing %s events to %s (%d producer%s, rate=%s)"
             % (f"{n:,}", topic, workers, "" if workers == 1 else "s",
                "unthrottled" if rate <= 0 else "%d/s" % rate))

    t0 = time.time()
    prod = ctx.kafka.produce_file(
        topic, ctx.load_file, workers=workers, rate=rate,
        batch_size=cfg["load"]["batch_size"],
        on_progress=lambda el: log.event("produce_progress", elapsed=round(el, 1)),
    )
    log.info("produced %s events in %s (%s events/sec into the broker)"
             % (f"{prod['events']:,}", stats.human_dur(prod["seconds"]),
                stats.human_count(prod["rate_per_sec"])))

    after = ctx.kafka.total_end_offset(topic)
    backlog = after - before
    res["end_offset_after"] = after
    res["backlog_events"] = backlog
    res["producer"] = prod
    res["producer_throughput_per_sec"] = prod["rate_per_sec"]
    res["producer_throughput_per_min"] = round(prod["rate_per_sec"] * 60, 1)
    res["producer_bytes_per_sec"] = round(
        ctx.results["generation"]["bytes"] / prod["seconds"], 1) if prod["seconds"] else 0

    if backlog < n * 0.99:
        log.warn("only %s of %s events reached the topic (offset delta) -- some "
                 "producer batches may have failed" % (f"{backlog:,}", f"{n:,}"))
    else:
        log.ok("backlog of %s events built on %s" % (f"{backlog:,}", topic))

    if paused:
        if not ctx.pipeline.resume(timeout_sec=cfg["pipeline"]["resume_timeout_sec"]):
            raise Fatal("unified-pipeline did not resume; the backlog cannot drain")
    ctx.drain_start = time.time()
    res["drain_started_at"] = ctx.drain_start
    return res


def drain(ctx):
    """Watch the consumer group work through the backlog.

    Done when the group's lag has been zero for pipeline.drain_idle_sec --
    a single zero reading is not enough, because the group briefly reports
    zero lag between a producer batch landing and the consumer noticing it.
    """
    cfg, log = ctx.cfg, ctx.log
    res = ctx.results.setdefault("kafka", {})
    timeout = cfg["pipeline"]["drain_timeout_sec"]
    idle_needed = cfg["pipeline"]["drain_idle_sec"]

    log.step("draining the backlog (timeout %s)" % stats.human_dur(timeout))
    ctx.sampler.on_report = _progress_line(ctx)

    t0 = time.time()
    zero_since = None
    while True:
        elapsed = time.time() - t0
        s = ctx.sampler.latest_kafka()
        if s is not None:
            if s["remaining"] <= 0:
                zero_since = zero_since or time.time()
                if (time.time() - zero_since) >= idle_needed:
                    break
            else:
                zero_since = None
        if elapsed >= timeout:
            log.warn("drain timed out after %s with %s events still queued"
                     % (stats.human_dur(elapsed),
                        f"{(s or {}).get('remaining', 0):,}"))
            res["drain_timed_out"] = True
            break
        time.sleep(2)

    ctx.drain_end = time.time()
    res.setdefault("drain_timed_out", False)
    res["drain_seconds"] = round(ctx.drain_end - ctx.drain_start, 2)
    ctx.sampler.on_report = None

    consumed = _consumed_during_drain(ctx)
    res["events_drained"] = consumed
    if res["drain_seconds"] > 0:
        res["drain_throughput_per_sec"] = round(consumed / res["drain_seconds"], 2)
        res["drain_throughput_per_min"] = round(consumed / res["drain_seconds"] * 60, 1)
    log.ok("drained %s events in %s (%s events/sec)"
           % (f"{consumed:,}", stats.human_dur(res["drain_seconds"]),
              stats.human_count(res.get("drain_throughput_per_sec"))))
    return res


def analyze(ctx):
    """Turn the Kafka sample series into the throughput answers."""
    log = ctx.log
    res = ctx.results.setdefault("kafka", {})
    samples = ctx.sampler.kafka_samples
    res["samples"] = len(samples)

    if len(samples) >= 2:
        rate = stats.rate_summary(samples, "consumed")
        res["throughput"] = rate
        res["sustained_per_sec"] = rate.get("sustained_per_sec")
        res["sustained_per_min"] = rate.get("sustained_per_min")
        res["peak_per_sec"] = rate.get("peak_per_sec")
        res["peak_per_min"] = rate.get("peak_per_min")
        res["max_per_sec"] = rate.get("max_per_sec")
        res["max_remaining"] = max(s["remaining"] for s in samples)
    else:
        log.warn("fewer than two Kafka samples -- the drain was shorter than one "
                 "report interval, so per-minute throughput cannot be derived; "
                 "lower monitor.report_interval_sec or raise load.events")
        res["throughput"] = {"samples": len(samples)}

    res["failed_after"] = ctx.kafka.failed_counts()
    res["failed_delta"] = {
        t: res["failed_after"].get(t, 0) - res["failed_before"].get(t, 0)
        for t in set(res["failed_after"]) | set(res["failed_before"])
    }
    dropped = sum(v for v in res["failed_delta"].values() if v > 0)
    # The corpus carries load.duplicate_fraction deliberate duplicates, and the
    # preprocessor sends every one of them to `failed` with ERR_PP_1010. Those
    # are dedup working, not input being lost, and counting them as loss made a
    # clean run warn "40 events landed on dead-letter topics" for the 40
    # duplicates it was asked to generate. Only the excess is a real drop.
    expected_dupes = int((ctx.results.get("generation") or {})
                         .get("duplicate_events") or 0)
    res["events_failed_total"] = dropped
    res["events_failed_expected_duplicates"] = min(expected_dupes, dropped)
    dropped_unexpected = max(0, dropped - expected_dupes)
    res["events_failed"] = dropped_unexpected
    detail = ", ".join("%s=%d" % (k, v)
                       for k, v in sorted(res["failed_delta"].items()) if v > 0)
    if dropped_unexpected:
        log.warn("%s unexpected event(s) landed on dead-letter topics: %s "
                 "(%s of %s were the deliberate duplicates)"
                 % (f"{dropped_unexpected:,}", detail,
                    f"{res['events_failed_expected_duplicates']:,}", f"{dropped:,}"))
    elif dropped:
        log.ok("dead-letter topics hold only the %s deliberate duplicate(s) (%s)"
               % (f"{dropped:,}", detail))
    else:
        log.ok("no events on any dead-letter topic")

    if samples:
        log.table(
            ["min", "consumed", "remaining", "events/sec", "events/min", "eta"],
            [[int(s["elapsed"] // 60), f"{s['consumed']:,}", f"{s['remaining']:,}",
              stats.human_count(s.get("events_per_sec")),
              stats.human_count(s.get("events_per_min")),
              stats.human_dur(s.get("eta_sec"))] for s in samples],
        )
    return res


def csv_rows(ctx):
    out = []
    for s in ctx.sampler.kafka_samples:
        out.append({
            "elapsed_sec": round(s.get("elapsed", 0), 2),
            "topic": s.get("topic"),
            "partitions": s.get("partitions"),
            "consumed": s.get("consumed"),
            "end_offset": s.get("end_offset"),
            "remaining": s.get("remaining"),
            "records_consumed_delta": s.get("records_consumed_delta"),
            "lag_reduction": s.get("lag_reduction"),
            "events_per_sec": s.get("events_per_sec"),
            "events_per_min": s.get("events_per_min"),
            "eta_sec": s.get("eta_sec"),
        })
    return out


# --- helpers -----------------------------------------------------------------
def _consumed_during_drain(ctx):
    samples = ctx.sampler.kafka_samples
    if len(samples) < 2:
        return ctx.results.get("kafka", {}).get("backlog_events", 0)
    return max(0, samples[-1]["consumed"] - samples[0]["consumed"])


def _progress_line(ctx):
    def report(elapsed, s):
        ctx.log.info(
            "t+%-6s consumed %-12s remaining %-12s %8s ev/s  %10s ev/min  eta %s"
            % (stats.human_dur(elapsed), f"{s['consumed']:,}", f"{s['remaining']:,}",
               stats.human_count(s.get("events_per_sec")),
               stats.human_count(s.get("events_per_min")),
               stats.human_dur(s.get("eta_sec"))))
    return report
