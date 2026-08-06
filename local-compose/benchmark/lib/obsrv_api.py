"""Obsrv dataset-api v2 client: token, envelope, create/publish/read/delete.

Two things about this API are easy to get wrong and both are handled here:

1. Every v2 body must be wrapped in {id, ver, ts, params, request}. A bare
   request body fails with "#required must have required property 'id'".
2. The create schema is additionalProperties:false at every level, and
   narrower than the docs suggest -- dataset_config takes only
   file_upload_path, dataset_tz, indexing_config and keys_config, and
   entry_topic is derived rather than accepted.
"""

import time

from . import httpc


class ObsrvApi:
    def __init__(self, cfg, log):
        self.cfg, self.log = cfg, log
        self.base = cfg["endpoints"]["dataset_api"].rstrip("/")
        self.kc = cfg["endpoints"]["keycloak"].rstrip("/")
        self.auth = cfg["auth"]
        self._token = None
        self._token_at = 0

    # --- auth --------------------------------------------------------------
    def token(self, force=False):
        """Password-grant token, cached for 4 minutes.

        Keycloak's default access token lifespan is 5 minutes and a load phase
        easily outlives that, so this refreshes rather than failing halfway
        through with a 401 that looks like a permissions problem.
        """
        if self._token and not force and (time.time() - self._token_at) < 240:
            return self._token
        url = "%s/realms/%s/protocol/openid-connect/token" % (self.kc, self.auth["realm"])
        res = httpc.form_post(url, {
            "grant_type": "password",
            "client_id": self.auth["client_id"],
            "username": self.auth["username"],
            "password": self.auth["password"],
        })
        tok = (res or {}).get("access_token")
        if not tok:
            raise RuntimeError("no access_token from %s -- is keycloak up? got: %r" % (url, res))
        self._token, self._token_at = tok, time.time()
        return tok

    # --- envelope ----------------------------------------------------------
    @staticmethod
    def envelope(api_id, request):
        return {
            "id": api_id,
            "ver": "v2",
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
            "params": {"msgid": "obsrv-benchmark"},
            "request": request,
        }

    def call(self, api_id, request, path=None, method="POST", raise_on_error=True):
        """POST an enveloped request; return the parsed response envelope."""
        sub = path if path is not None else api_id.split("api.datasets.", 1)[-1]
        url = "%s/v2/datasets/%s" % (self.base, sub)
        try:
            _, res, _ = httpc.request(
                url, method, body=self.envelope(api_id, request),
                bearer=self.token(), timeout=120,
            )
        except httpc.HttpError as e:
            body = _try_json(e.body)
            if raise_on_error:
                raise RuntimeError("%s failed (HTTP %s): %s" % (api_id, e.code, _err_text(body)))
            return body if isinstance(body, dict) else {"params": {"status": "FAILED"},
                                                        "error": {"message": str(e)}}
        if raise_on_error and (res or {}).get("params", {}).get("status") != "SUCCESS":
            raise RuntimeError("%s failed: %s" % (api_id, _err_text(res)))
        return res

    # --- dataset lifecycle -------------------------------------------------
    def create(self, request):
        return self.call("api.datasets.create", request)

    def read(self, dataset_id, fields=None, mode="live"):
        """GET /v2/datasets/read/<id>. mode=live reads the published copy."""
        qs = "?mode=%s" % mode
        if fields:
            qs += "&fields=%s" % ",".join(fields)
        url = "%s/v2/datasets/read/%s%s" % (self.base, dataset_id, qs)
        try:
            _, res, _ = httpc.request(url, bearer=self.token(), timeout=60)
            return (res or {}).get("result")
        except httpc.HttpError:
            return None

    def exists(self, dataset_id):
        return self.read(dataset_id, fields=["dataset_id", "status"], mode="edit") is not None

    def status_transition(self, dataset_id, status):
        return self.call("api.datasets.status-transition",
                         {"dataset_id": dataset_id, "status": status})

    def publish(self, dataset_id, wait_live_sec=120):
        """Draft -> ReadyToPublish -> Live.

        Live is the transition that matters: it generates the Druid ingestion
        spec for event datasets and hands the dataset to the running Flink job
        for both types.
        """
        for want in ("ReadyToPublish", "Live"):
            self.status_transition(dataset_id, want)
            self.log.dim("  %s -> %s" % (dataset_id, want))
        deadline = time.time() + wait_live_sec
        while time.time() < deadline:
            ds = self.read(dataset_id, fields=["dataset_id", "status"])
            if (ds or {}).get("status") == "Live":
                return True
            time.sleep(2)
        return False

    def retire(self, dataset_id):
        """Retire is the only delete that also tears down the Druid supervisor."""
        return self.call("api.datasets.status-transition",
                         {"dataset_id": dataset_id, "status": "Retire"},
                         raise_on_error=False)

    def delete(self, dataset_id):
        """Hard-delete the draft row. Retire first for a Live dataset.

        There is no DELETE route on this API -- /v2/datasets/delete/<id>
        answers 404 ROUTE_NOT_FOUND. Removal is a status transition, and
        Delete is accepted from Draft and ReadyToPublish only, so a Live
        dataset has to be retired first: that leaves the draft in Draft and
        this then removes it. Retire alone leaves both rows in place.
        """
        return self.call("api.datasets.status-transition",
                         {"dataset_id": dataset_id, "status": "Delete"},
                         raise_on_error=False)

    def datasources(self):
        """The live datasources table, as the API reports it.

        Not routed through `call`, which is hardwired to /v2/datasets/.
        """
        try:
            _, res, _ = httpc.request(
                "%s/v2/datasources/list" % self.base, "POST",
                body=self.envelope("api.datasources.list", {}),
                bearer=self.token(), timeout=60)
        except httpc.HttpError:
            return []
        return ((res or {}).get("result") or {}).get("data") or []

    def datasource_key(self, dataset_id):
        """The path segment /v2/data/query/<key> will actually resolve.

        The route names its parameter `dataset_id`, but the lookup behind it
        matches `datasources.datasource` or `datasources.id` and never
        `datasources.dataset_id` -- so passing the dataset id can only ever
        404. Resolving through the list API rather than reconstructing the
        name keeps this correct if the derivation changes.
        """
        for row in self.datasources():
            if row.get("dataset_id") == dataset_id:
                return row.get("datasource") or row.get("id")
        return dataset_id

    def query(self, dataset_id, query, timeout=120):
        """Query through the API's own data-out path.

        `query` is either a SQL string or a native Druid query object; the
        controller dispatches on the type. Note the envelope: unlike every
        /v2/datasets route, data-out validates `query` at the *top level* and
        has no `request` property at all, so the usual wrapper fails schema
        validation with "must have required property 'query'".
        """
        url = "%s/v2/data/query/%s" % (self.base, self.datasource_key(dataset_id))
        body = {
            "id": "api.data.out",
            "ver": "v2",
            "ts": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
            "params": {"msgid": "obsrv-benchmark"},
            "query": query,
        }
        _, res, elapsed = httpc.request(url, "POST", body=body,
                                        bearer=self.token(), timeout=timeout)
        return res, elapsed

    def ingest(self, dataset_id, events, timeout=120):
        """POST events through the API rather than straight to Kafka.

        Used only by the functional-validation phase, where going through the
        real front door is the point. The load phase writes to Kafka directly
        -- pushing hundreds of thousands of events through an HTTP endpoint
        would benchmark the API, not the pipeline.
        """
        url = "%s/v2/data/in/%s" % (self.base, dataset_id)
        body = self.envelope("api.data.in", {"data": events})
        _, res, elapsed = httpc.request(url, "POST", body=body, bearer=self.token(),
                                        timeout=timeout)
        return res, elapsed

    def health(self, dataset_id):
        try:
            return self.call("api.dataset.health",
                             {"dataset_id": dataset_id, "categories": ["infra", "processing"]},
                             path="health", raise_on_error=False)
        except Exception:
            return None


def _try_json(text):
    import json
    try:
        return json.loads(text)
    except Exception:
        return {"raw": text}


def _err_text(res):
    if not isinstance(res, dict):
        return str(res)
    err = res.get("error") or {}
    msg = err.get("message") or res.get("message") or ""
    code = err.get("code") or (res.get("params") or {}).get("errmsg") or ""
    return ("%s %s" % (code, msg)).strip() or str(res)[:500]
