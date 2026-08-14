"""Flink REST client for the unified-pipeline (and cache-indexer) jobs.

Covers the four things a throughput benchmark needs from the stream engine:
what the job is doing (state, restarts), how fast records are moving through
each operator, whether anything is backpressured, and what checkpointing is
costing. Also handles pause/resume, which for this deployment means stopping
and starting the TaskManager container rather than cancelling the job -- see
pause() for why.
"""

import time

from . import httpc


class Flink:
    def __init__(self, cfg, log, docker, which="unified"):
        self.cfg, self.log, self.d = cfg, log, docker
        self.which = which
        key = "flink_unified" if which == "unified" else "flink_cache_indexer"
        self.base = cfg["endpoints"][key].rstrip("/")
        self.tm_role = "up_taskmanager" if which == "unified" else "ci_taskmanager"
        self.jm_role = "up_jobmanager" if which == "unified" else "ci_jobmanager"

    def _get(self, path, default=None, timeout=20):
        try:
            return httpc.get_json("%s%s" % (self.base, path), timeout=timeout)
        except httpc.HttpError:
            return default

    # --- jobs --------------------------------------------------------------
    def jobs(self):
        return (self._get("/jobs/overview", {}) or {}).get("jobs", []) or []

    def job_id(self):
        js = self.jobs()
        running = [j for j in js if j.get("state") == "RUNNING"]
        pick = running[0] if running else (js[0] if js else None)
        return pick.get("jid") if pick else None

    def job_state(self):
        js = self.jobs()
        if not js:
            return "NONE"
        for j in js:
            if j.get("state") == "RUNNING":
                return "RUNNING"
        return js[0].get("state", "UNKNOWN")

    def job_detail(self, jid=None):
        jid = jid or self.job_id()
        return self._get("/jobs/%s" % jid, {}) if jid else {}

    def wait_for_running(self, timeout_sec=300, poll=5):
        deadline = time.time() + timeout_sec
        last = "NONE"
        while time.time() < deadline:
            last = self.job_state()
            if last == "RUNNING":
                # RUNNING with no registered slots means the scheduler has the
                # job but nothing is executing it, which is the exact state a
                # just-started TaskManager passes through.
                if self.slots_total() > 0:
                    return True
            time.sleep(poll)
        self.log.warn("%s job did not reach RUNNING within %ds (last: %s)"
                      % (self.which, timeout_sec, last))
        return False

    # --- taskmanagers ------------------------------------------------------
    def taskmanagers(self):
        return (self._get("/taskmanagers", {}) or {}).get("taskmanagers", []) or []

    def slots_total(self):
        return sum(tm.get("slotsNumber", 0) for tm in self.taskmanagers())

    def slots_free(self):
        return sum(tm.get("freeSlots", 0) for tm in self.taskmanagers())

    def tm_metrics(self, names):
        """Sum a set of TaskManager metrics across all TaskManagers."""
        out = {n: 0.0 for n in names}
        for tm in self.taskmanagers():
            tid = tm.get("id")
            if not tid:
                continue
            got = self._get("/taskmanagers/%s/metrics?get=%s" % (tid, ",".join(names)), [])
            for m in got or []:
                try:
                    out[m["id"]] = out.get(m["id"], 0.0) + float(m.get("value") or 0)
                except (KeyError, TypeError, ValueError):
                    continue
        return out

    # --- per-vertex throughput and backpressure ----------------------------
    def vertices(self, jid=None):
        det = self.job_detail(jid)
        return det.get("vertices", []) or []

    def vertex_metrics(self, jid, vid, names):
        got = self._get("/jobs/%s/vertices/%s/metrics?get=%s" % (jid, vid, ",".join(names)), [])
        out = {}
        for m in got or []:
            try:
                out[m["id"]] = float(m.get("value") or 0)
            except (TypeError, ValueError):
                pass
        return out

    def backpressure(self, jid, vid):
        """{status, backpressuredRatio, busyRatio, idleRatio} for one vertex.

        busyRatio is the useful one for bottleneck attribution: the operator
        with a high busy ratio and no backpressure from downstream is the one
        doing the work that limits the job.
        """
        bp = self._get("/jobs/%s/vertices/%s/backpressure" % (jid, vid), {}) or {}
        subs = bp.get("subtasks", []) or []
        def avg(k):
            vals = [s.get(k) for s in subs if isinstance(s.get(k), (int, float))]
            return round(sum(vals) / len(vals), 4) if vals else None
        return {
            "status": bp.get("status"),
            "backpressure_level": bp.get("backpressure-level"),
            "backpressured_ratio": avg("backpressuredRatio"),
            "busy_ratio": avg("busyRatio"),
            "idle_ratio": avg("idleRatio"),
            "subtasks": len(subs),
        }

    def snapshot(self):
        """One sample of everything worth a time series, in one call tree."""
        jid = self.job_id()
        det = self.job_detail(jid) if jid else {}
        verts = det.get("vertices", []) or []
        sample = {
            "t": time.time(),
            "job_id": jid,
            "state": det.get("state") or self.job_state(),
            "duration_ms": det.get("duration"),
            "slots_total": self.slots_total(),
            "slots_free": self.slots_free(),
            "records_in": 0,
            "records_out": 0,
            "vertices": [],
        }
        for v in verts:
            m = v.get("metrics", {}) or {}
            rin = m.get("read-records") or 0
            rout = m.get("write-records") or 0
            sample["records_in"] += rin
            sample["records_out"] += rout
            entry = {
                "name": v.get("name", "")[:80],
                "id": v.get("id"),
                "parallelism": v.get("parallelism"),
                "status": v.get("status"),
                "records_in": rin,
                "records_out": rout,
                "busy_ratio": None,
                "backpressured_ratio": None,
            }
            if jid and v.get("status") == "RUNNING":
                bp = self.backpressure(jid, v.get("id"))
                entry["busy_ratio"] = bp.get("busy_ratio")
                entry["backpressured_ratio"] = bp.get("backpressured_ratio")
                entry["backpressure_status"] = bp.get("status")
            sample["vertices"].append(entry)

        tm = self.tm_metrics([
            "Status.JVM.Memory.Heap.Used", "Status.JVM.Memory.Heap.Max",
            "Status.JVM.Memory.NonHeap.Used", "Status.JVM.CPU.Load",
            "Status.JVM.Threads.Count", "Status.JVM.GarbageCollector.G1_Young_Generation.Time",
            "Status.JVM.GarbageCollector.G1_Old_Generation.Time",
        ])
        sample["jvm_heap_used"] = tm.get("Status.JVM.Memory.Heap.Used")
        sample["jvm_heap_max"] = tm.get("Status.JVM.Memory.Heap.Max")
        sample["jvm_nonheap_used"] = tm.get("Status.JVM.Memory.NonHeap.Used")
        sample["jvm_cpu_load"] = tm.get("Status.JVM.CPU.Load")
        sample["jvm_threads"] = tm.get("Status.JVM.Threads.Count")
        sample["gc_young_ms"] = tm.get("Status.JVM.GarbageCollector.G1_Young_Generation.Time")
        sample["gc_old_ms"] = tm.get("Status.JVM.GarbageCollector.G1_Old_Generation.Time")

        cp = self.checkpoints(jid) if jid else {}
        sample["checkpoint_count"] = cp.get("completed")
        sample["checkpoint_failed"] = cp.get("failed")
        sample["checkpoint_last_ms"] = cp.get("last_duration_ms")
        sample["checkpoint_avg_ms"] = cp.get("avg_duration_ms")
        sample["restarts"] = det.get("status-counts", {}).get("FAILED", 0)
        return sample

    # --- checkpoints -------------------------------------------------------
    def checkpoints(self, jid=None):
        jid = jid or self.job_id()
        if not jid:
            return {}
        cp = self._get("/jobs/%s/checkpoints" % jid, {}) or {}
        counts = cp.get("counts", {}) or {}
        summary = cp.get("summary", {}) or {}
        latest = ((cp.get("latest") or {}).get("completed") or {})
        def _dur(node, key="end_to_end_duration"):
            v = (node or {}).get(key)
            if isinstance(v, dict):
                return v.get("avg")
            return v
        return {
            "completed": counts.get("completed"),
            "failed": counts.get("failed"),
            "in_progress": counts.get("in_progress"),
            "restored": counts.get("restored"),
            "last_duration_ms": latest.get("end_to_end_duration"),
            "last_state_size": latest.get("state_size"),
            "avg_duration_ms": _dur(summary),
        }

    # --- pause / resume ----------------------------------------------------
    def pause(self):
        """Stop processing so a Kafka backlog can accumulate.

        The TaskManager container is stopped rather than the job cancelled.
        Cancelling would tear down the Kafka source's committed offsets story
        and, on a fresh start, the source falls back to LATEST -- which would
        silently skip the entire backlog we just built and report a perfect
        drain of zero events. Stopping the TaskManager leaves the job in the
        scheduler waiting for slots, so when the container comes back the job
        resumes from its committed offsets and actually consumes the backlog.
        """
        self.log.step("pausing %s (stopping %s)" % (self.which, self.d.c(self.tm_role)))
        self.d.compose(["stop", _svc(self.d, self.tm_role)], timeout=180)
        deadline = time.time() + 90
        while time.time() < deadline:
            if not self.d.running(self.tm_role):
                self.log.dim("  taskmanager stopped; job state=%s slots=%d"
                             % (self.job_state(), self.slots_total()))
                return True
            time.sleep(2)
        self.log.warn("taskmanager did not stop within 90s")
        return False

    def resume(self, timeout_sec=300):
        self.log.step("resuming %s (starting %s)" % (self.which, self.d.c(self.tm_role)))
        self.d.compose(["start", _svc(self.d, self.tm_role)], timeout=300)
        ok = self.wait_for_running(timeout_sec=timeout_sec)
        if ok:
            self.log.dim("  job RUNNING with %d slot(s)" % self.slots_total())
        return ok

    def restart_job(self, timeout_sec=300):
        """Full job restart -- the only way cache-indexer picks up a new
        master dataset, because its enumerator builds the subscription list
        once at startup and runs without periodic partition discovery."""
        self.d.compose(["restart", _svc(self.d, self.jm_role), _svc(self.d, self.tm_role)],
                       timeout=300)
        return self.wait_for_running(timeout_sec=timeout_sec)


def _svc(docker, role):
    """Compose service name from the container name (strip the project prefix)."""
    name = docker.c(role)
    prefix = docker.prefix + "-"
    return name[len(prefix):] if name.startswith(prefix) else name
