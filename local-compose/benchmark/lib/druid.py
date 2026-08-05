"""Druid client: SQL, supervisors, indexing tasks, segments.

Everything goes to the router (8888), which proxies to broker/overlord/
coordinator as needed. Basic auth because druid-basic-security is enabled in
this deployment.

One naming trap this module encapsulates: dataset `foo` becomes datasource
`foo_events`. Querying the bare dataset id returns nothing at all, with no
error -- which reads exactly like "the pipeline dropped my events".
"""

import time

from . import httpc


class Druid:
    def __init__(self, cfg, log):
        self.cfg, self.log = cfg, log
        self.router = cfg["endpoints"]["druid_router"].rstrip("/")
        self.coordinator = cfg["endpoints"]["druid_coordinator"].rstrip("/")
        self.basic = (cfg["auth"]["druid_user"], cfg["auth"]["druid_password"])

    @staticmethod
    def datasource(dataset_id):
        return "%s_events" % dataset_id

    # --- SQL ---------------------------------------------------------------
    def sql(self, query, timeout=120, context=None):
        """Return (rows, elapsed_seconds). Rows are dicts."""
        body = {"query": query, "resultFormat": "object", "header": False}
        if context:
            body["context"] = context
        _, res, elapsed = httpc.request(
            "%s/druid/v2/sql" % self.router, "POST", body=body,
            basic=self.basic, timeout=timeout)
        return (res or []), elapsed

    def scalar(self, query, default=None, timeout=120):
        rows, _ = self.sql(query, timeout=timeout)
        if not rows:
            return default
        vals = list(rows[0].values())
        return vals[0] if vals else default

    def count(self, dataset_id, where=None, timeout=120):
        ds = self.datasource(dataset_id)
        q = 'SELECT COUNT(*) AS c FROM "%s"' % ds
        if where:
            q += " WHERE " + where
        try:
            return int(self.scalar(q, default=0, timeout=timeout) or 0)
        except httpc.HttpError:
            # Before the first segment is published the datasource does not
            # exist and Druid answers 400, not an empty result.
            return 0
        except (TypeError, ValueError):
            return 0

    def columns(self, dataset_id):
        ds = self.datasource(dataset_id)
        try:
            rows, _ = self.sql(
                "SELECT COLUMN_NAME, DATA_TYPE FROM INFORMATION_SCHEMA.COLUMNS "
                "WHERE TABLE_NAME = '%s'" % ds)
            return {r["COLUMN_NAME"]: r["DATA_TYPE"] for r in rows}
        except httpc.HttpError:
            return {}

    def datasources(self):
        try:
            rows, _ = self.sql(
                "SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES "
                "WHERE TABLE_SCHEMA = 'druid'")
            return sorted(r["TABLE_NAME"] for r in rows)
        except httpc.HttpError:
            return []

    def wait_for_count(self, dataset_id, target, timeout_sec, poll=5, on_sample=None):
        """Poll until the datasource holds `target` rows.

        Returns (final_count, seconds_waited, samples). `on_sample` gets each
        (elapsed, count) so the caller can build the indexing-rate series
        without a second polling loop.
        """
        t0 = time.time()
        samples, last = [], 0
        while True:
            now = time.time()
            c = self.count(dataset_id)
            samples.append({"t": now - t0, "rows": c})
            if on_sample:
                on_sample(now - t0, c)
            last = c
            if c >= target or (now - t0) >= timeout_sec:
                return c, now - t0, samples
            time.sleep(poll)
        return last, time.time() - t0, samples

    # --- supervisors -------------------------------------------------------
    def supervisors(self):
        try:
            return httpc.get_json("%s/druid/indexer/v1/supervisor" % self.router,
                                  basic=self.basic, timeout=30) or []
        except httpc.HttpError:
            return []

    def wait_for_supervisor(self, dataset_id, timeout_sec=150, poll=3):
        want = self.datasource(dataset_id)
        deadline = time.time() + timeout_sec
        while time.time() < deadline:
            if want in self.supervisors():
                return True
            time.sleep(poll)
        return False

    def supervisor_status(self, dataset_id):
        want = self.datasource(dataset_id)
        try:
            return httpc.get_json(
                "%s/druid/indexer/v1/supervisor/%s/status" % (self.router, want),
                basic=self.basic, timeout=30) or {}
        except httpc.HttpError:
            return {}

    def supervisor_stats(self, dataset_id):
        """rowsProcessed / rowsThrownAway / errors, per task, from the overlord.

        This is the only place that reports Druid's own view of ingestion
        throughput -- 1m/5m/15m moving averages of processed rows -- which is
        what "Druid indexing throughput" means as distinct from "rows visible
        to a query", the latter lagging by segment handoff.
        """
        want = self.datasource(dataset_id)
        try:
            return httpc.get_json(
                "%s/druid/indexer/v1/supervisor/%s/stats" % (self.router, want),
                basic=self.basic, timeout=30) or {}
        except httpc.HttpError:
            return {}

    def running_tasks(self, dataset_id):
        """Ids of the indexing tasks currently holding this datasource open."""
        ds = self.datasource(dataset_id)
        return [t["id"] for t in self.tasks("running")
                if t.get("dataSource") == ds and t.get("id")]

    def shutdown_tasks(self, dataset_id, timeout=120, poll=3):
        """Kill the realtime indexing tasks and wait for them to go.

        Terminating a supervisor stops it from *scheduling* new tasks; the
        tasks already running keep going, and while one is alive its rows are
        served straight out of the task, not from a published segment. That is
        the gap this closes. Without it a drop looks inexplicable: mark-unused
        answers `numChangedSegments: 0` because there genuinely are no used
        segments, and a query against the same datasource answers 19,800 rows.
        """
        ids = self.running_tasks(dataset_id)
        for tid in ids:
            try:
                httpc.post_json("%s/druid/indexer/v1/task/%s/shutdown"
                                % (self.router, tid), {},
                                basic=self.basic, timeout=60)
            except httpc.HttpError:
                pass
        deadline = time.time() + timeout
        while self.running_tasks(dataset_id) and time.time() < deadline:
            time.sleep(poll)
        return ids

    def terminate_supervisor(self, dataset_id):
        want = self.datasource(dataset_id)
        try:
            return httpc.post_json(
                "%s/druid/indexer/v1/supervisor/%s/terminate" % (self.router, want),
                {}, basic=self.basic, timeout=60)
        except httpc.HttpError:
            return None

    # --- tasks and segments ------------------------------------------------
    def tasks(self, state=None):
        url = "%s/druid/indexer/v1/tasks" % self.router
        if state:
            url += "?state=%s" % state
        try:
            return httpc.get_json(url, basic=self.basic, timeout=30) or []
        except httpc.HttpError:
            return []

    def task_counts(self):
        """{running, pending, waiting, success, failed} -- the queue picture."""
        out = {}
        for st in ("running", "pending", "waiting"):
            out[st] = len(self.tasks(st))
        return out

    def segments(self, dataset_id):
        ds = self.datasource(dataset_id)
        try:
            rows, _ = self.sql(
                "SELECT COUNT(*) AS segments, SUM(\"size\") AS bytes, "
                "SUM(\"num_rows\") AS rows_ FROM sys.segments "
                "WHERE datasource = '%s' AND is_overshadowed = 0" % ds)
            r = rows[0] if rows else {}
            return {"segments": int(r.get("segments") or 0),
                    "bytes": int(r.get("bytes") or 0),
                    "rows": int(r.get("rows_") or 0)}
        except (httpc.HttpError, TypeError, ValueError):
            return {"segments": 0, "bytes": 0, "rows": 0}

    # Everything before this interval and everything after it; wide enough that
    # no generated timestamp can fall outside it.
    _ALL_TIME = "1000-01-01_3000-01-01"

    def drop_datasource(self, dataset_id, timeout=600, poll=5):
        """Terminate the supervisor and remove every row. Verified, not assumed.

        This used to fire two DELETEs, swallow every error, and return. It was
        not removing anything: three consecutive runs queried a datasource
        still holding the first run's segments, so "all 4,021 rows queryable"
        was reported for a run that produced 1,960, and the functional checks
        that count whole-datasource rows were measuring their predecessors.

        Order matters and each step has a reason:

          1. Terminate the supervisor, and wait for it to actually go. While it
             lives it keeps publishing, so anything dropped underneath it comes
             straight back.
          2. Shut down the indexing tasks it left running. Terminating a
             supervisor does not stop them, and a live task serves its rows
             directly -- they are not in any segment yet, so no amount of
             segment manipulation can reach them.
          3. Mark every segment unused (DELETE on the datasource). This is what
             makes the published rows stop answering queries.
          4. Issue a kill for all time, which is what reclaims the storage.

        Only step 2 is retried while polling, and step 3 is issued exactly once
        at the end. That split matters in both directions:

        Mark-unused is plain coordinator metadata -- idempotent, no task, cheap
        to repeat -- and it is the step that makes rows stop answering queries,
        so it is what the poll is waiting on. It does not commit synchronously;
        the historical keeps serving the segments until the coordinator's next
        management cycle, which on a single-node Druid sharing four cores can
        take minutes. Hence a generous timeout rather than a tight one.

        A kill, by contrast, spawns a real indexing task, and it only removes
        segments that are *already* unused. An earlier version of this fired
        one on every poll iteration: 110 kill tasks piled up on the one indexer,
        competing for the slots that ingestion and the mark-unused cycle needed,
        and made the very timeout they were supposed to beat more likely. It is
        storage reclamation, not visibility -- once at the end is enough.

        Returns True when the datasource is gone or empty. A False here is worth
        failing a run over -- every row count after it is contaminated.
        """
        ds = self.datasource(dataset_id)
        self.terminate_supervisor(dataset_id)
        self._await_supervisor_gone(ds, timeout=min(60, timeout))
        self.shutdown_tasks(dataset_id, timeout=min(120, timeout))

        errors = []
        deadline = time.time() + timeout
        gone = False
        while True:
            self._mark_unused(ds, errors)
            if self.count(dataset_id, timeout=30) == 0:
                gone = True
                break
            if time.time() >= deadline:
                break
            time.sleep(poll)

        self._kill(ds, errors)
        if not gone:
            left = self.count(dataset_id, timeout=30)
            if left:
                self.log.warn(
                    "%s still holds %s row(s) %.0fs after the drop%s -- every "
                    "whole-datasource count this run reports includes them"
                    % (ds, f"{left:,}", timeout,
                       ("; " + "; ".join(errors[:2])) if errors else ""))
            return left == 0
        return True

    def _mark_unused(self, ds, errors):
        """Stop the segments answering queries. Metadata only, no task."""
        self._delete("%s/druid/coordinator/v1/datasources/%s"
                     % (self.coordinator, ds), errors)

    def _kill(self, ds, errors):
        """Reclaim the storage. Spawns an indexing task -- issue sparingly."""
        for url in (
            "%s/druid/coordinator/v1/datasources/%s/intervals/%s"
            % (self.coordinator, ds, self._ALL_TIME),
            # The pre-0.22 spelling. Harmless where the one above worked, and
            # the only one that lands on an older coordinator.
            "%s/druid/coordinator/v1/datasources/%s?kill=true&interval=%s"
            % (self.coordinator, ds, self._ALL_TIME),
        ):
            self._delete(url, errors)

    def _delete(self, url, errors):
        try:
            httpc.request(url, "DELETE", basic=self.basic, timeout=60)
        except httpc.HttpError as exc:
            # A 404 means there is nothing to drop, which is the goal.
            if getattr(exc, "code", None) != 404:
                errors.append("%s: %s" % (url.split("/v1/")[-1], exc))

    def _await_supervisor_gone(self, ds, timeout=60, poll=3):
        deadline = time.time() + timeout
        while time.time() < deadline:
            try:
                if ds not in (httpc.get_json(
                        "%s/druid/indexer/v1/supervisor" % self.router,
                        basic=self.basic, timeout=30) or []):
                    return True
            except httpc.HttpError:
                return True
            time.sleep(poll)
        return False
