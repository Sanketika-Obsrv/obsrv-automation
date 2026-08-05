"""Background sampler: one thread, two cadences, four time series.

Every collector could run its own poll loop, but they would all be competing
for the same 4-core box they are trying to measure. This runs them together
and, more importantly, at two different rates:

  fast (monitor.poll_interval_sec, default 5s)
      Flink REST, Druid SQL count, cgroup reads, host metrics. All cheap HTTP
      or a file read.

  slow (monitor.report_interval_sec, default 60s)
      Kafka consumer-group lag. Every kafka-consumer-groups.sh invocation
      starts a JVM inside the broker, which costs seconds of CPU on a host
      that is deliberately saturated. Polling that every 5 seconds would
      measurably slow down the thing being measured, and "every minute" is
      the cadence the requirement asks for anyway.

The series are plain lists of dicts with a "t" key, which is all stats.py
needs to derive rates from any of them.
"""

import threading
import time

from .infra import DEFAULT_ROLES


class Sampler:
    def __init__(self, ctx, dataset_id=None, roles=None, label="run"):
        self.ctx = ctx
        self.cfg = ctx.cfg
        self.log = ctx.log
        self.dataset_id = dataset_id or ctx.cfg["datasets"]["telemetry_id"]
        # No caller passes roles, and a None here is not an empty sample -- it
        # is sample_all() raising on every cycle, which is how a run collected
        # zero container metrics and still reported a bottleneck.
        self.roles = roles if roles is not None else list(DEFAULT_ROLES)
        self.label = label

        self.kafka_samples = []
        self.flink_samples = []
        self.druid_samples = []
        self.infra_samples = []
        self.host_samples = []

        self._stop = threading.Event()
        self._thread = None
        self._t0 = None
        self._last_report = 0.0
        self._errors = []
        self.on_report = None      # optional callback(elapsed, kafka_sample)

    # --- lifecycle ---------------------------------------------------------
    def start(self):
        self._t0 = time.time()
        self._stop.clear()
        self._thread = threading.Thread(target=self._loop, name="sampler", daemon=True)
        self._thread.start()
        return self

    def stop(self, join_timeout=90):
        self._stop.set()
        if self._thread:
            self._thread.join(timeout=join_timeout)
        return self

    @property
    def elapsed(self):
        return (time.time() - self._t0) if self._t0 else 0.0

    # --- the loop ----------------------------------------------------------
    def _loop(self):
        fast = max(1, int(self.cfg["monitor"]["poll_interval_sec"]))
        slow = max(fast, int(self.cfg["monitor"]["report_interval_sec"]))
        # Take the first Kafka sample immediately: without a t=0 point there is
        # no baseline to difference the first minute's throughput against.
        self._sample_kafka()
        next_slow = time.time() + slow
        while not self._stop.is_set():
            cycle_start = time.time()
            self._sample_fast()
            if time.time() >= next_slow:
                self._sample_kafka()
                next_slow = time.time() + slow
            # Sleep the remainder of the interval rather than a fixed amount,
            # so a slow cycle does not shift every later sample.
            time.sleep(max(0.0, fast - (time.time() - cycle_start)))
        # A final pair, so the last interval before stop() is not lost.
        self._sample_fast()
        self._sample_kafka()

    def _guard(self, what, fn):
        try:
            return fn()
        except Exception as exc:               # a sampler must never kill a run
            self._errors.append("%s: %s" % (what, exc))
            self.log.event("sampler_error", what=what, error=str(exc))
            return None

    def _sample_fast(self):
        now = time.time()
        el = now - self._t0

        fs = self._guard("flink", self.ctx.pipeline.snapshot)
        if fs:
            fs["elapsed"] = el
            self.flink_samples.append(fs)

        rows = self._guard("druid", lambda: self.ctx.druid.count(self.dataset_id))
        if rows is not None:
            self.druid_samples.append({"t": now, "elapsed": el, "rows": rows})

        host = self._guard("host", self.ctx.infra.host_sample)
        if host:
            host["elapsed"] = el
            self.host_samples.append(host)

        cs = self._guard("containers", lambda: self.ctx.infra.sample_all(self.roles))
        for c in cs or []:
            c["elapsed"] = el
            self.infra_samples.append(c)

    def _sample_kafka(self):
        now = time.time()
        s = self._guard("kafka", lambda: self.ctx.kafka.lag_snapshot(self.ctx.entry_topic))
        if not s:
            return
        s["t"] = now
        s["elapsed"] = now - (self._t0 or now)

        # Derive the per-minute numbers the requirement names, against the
        # previous sample rather than the whole run, so a rate reported at
        # minute 9 describes minute 9.
        prev = self.kafka_samples[-1] if self.kafka_samples else None
        if prev and s["t"] > prev["t"]:
            dt = s["t"] - prev["t"]
            consumed_delta = max(0, s["consumed"] - prev["consumed"])
            s["records_consumed_delta"] = consumed_delta
            s["events_per_sec"] = round(consumed_delta / dt, 2)
            s["events_per_min"] = round(consumed_delta / dt * 60, 1)
            s["lag_reduction"] = prev["remaining"] - s["remaining"]
            rate = consumed_delta / dt
            s["eta_sec"] = round(s["remaining"] / rate, 1) if rate > 0.01 else None
        else:
            s["records_consumed_delta"] = 0
            s["events_per_sec"] = 0.0
            s["events_per_min"] = 0.0
            s["lag_reduction"] = 0
            s["eta_sec"] = None

        self.kafka_samples.append(s)
        if self.on_report:
            self._guard("on_report", lambda: self.on_report(s["elapsed"], s))

    # --- convenience -------------------------------------------------------
    def latest_kafka(self):
        return self.kafka_samples[-1] if self.kafka_samples else None

    def latest_druid_rows(self):
        return self.druid_samples[-1]["rows"] if self.druid_samples else 0

    def errors(self):
        return list(self._errors)

    def container_series(self, role):
        return [s for s in self.infra_samples if s.get("role") == role]
