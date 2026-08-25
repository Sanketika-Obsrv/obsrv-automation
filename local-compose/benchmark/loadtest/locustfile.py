"""Locust load test for Obsrv query serving.

Two targets, chosen with OBSRV_TARGET:

    api     the Obsrv data-out API  (POST /v2/data/query/<datasource>)
    druid   Druid SQL directly      (POST /druid/v2/sql)
    both    both, weighted evenly   (default)

`api` is what an application actually calls -- it carries Keycloak auth, RBAC,
query-rule validation and a table-name rewrite on top of Druid. `druid` is the
floor: the same nine queries with none of that. Running both in one report is
the point, because the difference between the two columns is what the API layer
costs you.

Everything defaults to the local docker-compose stack, so the common case is:

    locust -f locustfile.py --headless -u 4 -r 4 -t 1m

Self-contained on purpose -- no import from the benchmark package -- so it can
be handed to someone who only has this file.
"""

import os
import threading
import time

from locust import HttpUser, between, events, task

# --- configuration -----------------------------------------------------------
DATASET = os.getenv("OBSRV_DATASET", "bench_telemetry")
TARGET = os.getenv("OBSRV_TARGET", "both").lower()

DATASET_API = os.getenv("OBSRV_DATASET_API", "http://localhost:3000")
DRUID = os.getenv("OBSRV_DRUID", "http://localhost:8888")
KEYCLOAK = os.getenv("OBSRV_KEYCLOAK", "http://localhost:8080/auth")

REALM = os.getenv("OBSRV_REALM", "obsrv")
CLIENT_ID = os.getenv("OBSRV_CLIENT_ID", "obsrv-console")
USERNAME = os.getenv("OBSRV_USERNAME", "obsrv_admin")
PASSWORD = os.getenv("OBSRV_PASSWORD", "enDoPvTAxFSd")
DRUID_AUTH = (os.getenv("OBSRV_DRUID_USER", "admin"),
              os.getenv("OBSRV_DRUID_PASSWORD", "admin123"))

SAMPLE_USER = os.getenv("OBSRV_SAMPLE_USER", "user-0001")
SAMPLE_CITY = os.getenv("OBSRV_SAMPLE_CITY", "Bengaluru")


def queries(table):
    """The nine query classes, parameterised by table name.

    The table differs per target and that is not cosmetic: the data-out API
    rewrites the dataset id in your SQL to the datasource_ref before forwarding
    it, so SQL sent to the API must name the *dataset* (`bench_telemetry`)
    while SQL sent to Druid must name the *datasource* (`bench_telemetry_events`).
    Send the datasource to the API and the rewrite fires on the substring,
    producing `bench_telemetry_events_events` and a 400.
    """
    return [
        ("count",
         'SELECT COUNT(*) AS c FROM "%s"' % table),
        ("filter",
         'SELECT COUNT(*) AS c FROM "%s" WHERE "eid" = \'SEARCH\'' % table),
        ("latest_events",
         'SELECT __time, "mid", "eid", "actor.id" FROM "%s" '
         'ORDER BY __time DESC LIMIT 100' % table),
        ("group_by",
         'SELECT "actor.id" AS actor, COUNT(*) AS events FROM "%s" '
         'GROUP BY 1 ORDER BY events DESC LIMIT 50' % table),
        # "minute" is quoted because MINUTE is a reserved time-unit keyword in
        # Druid's SQL parser; bare `AS minute` is a parse error, not a query.
        ("time_series",
         'SELECT TIME_FLOOR(__time, \'PT1M\') AS "minute", COUNT(*) AS events '
         'FROM "%s" GROUP BY 1 ORDER BY 1' % table),
        ("top_n",
         'SELECT "eid", COUNT(*) AS events FROM "%s" GROUP BY 1 '
         'ORDER BY events DESC LIMIT 10' % table),
        ("aggregation",
         'SELECT COUNT(*) AS events, AVG("edata.size") AS avg_size, '
         'MAX("edata.size") AS max_size, COUNT(DISTINCT "actor.id") AS actors '
         'FROM "%s"' % table),
        ("user_lookup",
         'SELECT COUNT(*) AS events FROM "%s" WHERE "actor.id" = \'%s\''
         % (table, SAMPLE_USER)),
        ("city_lookup",
         'SELECT COUNT(*) AS events FROM "%s" WHERE "user.city" = \'%s\''
         % (table, SAMPLE_CITY)),
    ]


# --- shared Keycloak token ---------------------------------------------------
class _Token:
    """One token shared by every virtual user, refreshed before it expires.

    Keycloak's default access-token lifespan is 5 minutes and a load test
    outlives that easily. Refreshing per request would measure Keycloak; not
    refreshing at all turns a 10-minute run into a wall of 401s halfway
    through, which reads as the query API failing under load.
    """

    def __init__(self):
        self._lock = threading.Lock()
        self._value = None
        self._at = 0.0

    def get(self, session):
        with self._lock:
            if self._value and (time.time() - self._at) < 240:
                return self._value
            res = session.post(
                "%s/realms/%s/protocol/openid-connect/token" % (KEYCLOAK, REALM),
                data={"grant_type": "password", "client_id": CLIENT_ID,
                      "username": USERNAME, "password": PASSWORD},
                name="[auth] keycloak token", timeout=30)
            res.raise_for_status()
            self._value = res.json()["access_token"]
            self._at = time.time()
            return self._value


TOKEN = _Token()
_DATASOURCE_KEY = {"value": None}


def datasource_key(session):
    """The path segment /v2/data/query/<key> will actually resolve.

    The route calls its parameter `dataset_id`, but the lookup behind it
    matches `datasources.datasource` or `datasources.id` and never
    `datasources.dataset_id` -- so passing the dataset id always 404s.
    Resolved once through the list API rather than reconstructing the name.
    """
    if _DATASOURCE_KEY["value"]:
        return _DATASOURCE_KEY["value"]
    res = session.post(
        "%s/v2/datasources/list" % DATASET_API,
        json={"id": "api.datasources.list", "ver": "v2",
              "ts": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
              "params": {"msgid": "locust"}, "request": {}},
        headers={"Authorization": "Bearer %s" % TOKEN.get(session)},
        name="[setup] datasources/list", timeout=30)
    rows = (res.json().get("result") or {}).get("data") or []
    for row in rows:
        if row.get("dataset_id") == DATASET:
            _DATASOURCE_KEY["value"] = row.get("datasource") or row.get("id")
            break
    else:
        _DATASOURCE_KEY["value"] = DATASET
    return _DATASOURCE_KEY["value"]


# --- users -------------------------------------------------------------------
class ObsrvApiUser(HttpUser):
    """Queries through the Obsrv data-out API, the way an application would."""

    host = DATASET_API
    weight = 1 if TARGET in ("api", "both") else 0
    wait_time = between(0, 0)

    def on_start(self):
        self.queries = queries(DATASET)
        self.key = datasource_key(self.client)
        self.i = 0

    @task
    def run_query(self):
        name, sql = self.queries[self.i % len(self.queries)]
        self.i += 1
        with self.client.post(
            "/v2/data/query/%s" % self.key,
            json={"id": "api.data.out", "ver": "v2",
                  "ts": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
                  "params": {"msgid": "locust"}, "query": sql},
            headers={"Authorization": "Bearer %s" % TOKEN.get(self.client)},
            name="api: %s" % name, catch_response=True, timeout=60,
        ) as res:
            # A 200 whose envelope says FAILED is still a failed query. Locust
            # would otherwise score it as a fast success and flatter the report.
            if res.status_code == 200:
                status = (res.json().get("params") or {}).get("status")
                if status == "SUCCESS":
                    res.success()
                else:
                    res.failure("envelope status=%s" % status)
            else:
                res.failure("HTTP %s" % res.status_code)


class DruidSqlUser(HttpUser):
    """Queries Druid SQL directly -- the floor, with no API layer in the path."""

    host = DRUID
    weight = 1 if TARGET in ("druid", "both") else 0
    wait_time = between(0, 0)

    def on_start(self):
        # Druid is queried by datasource, which is the dataset id plus _events.
        self.queries = queries(os.getenv("OBSRV_DATASOURCE",
                                         "%s_events" % DATASET))
        self.i = 0

    @task
    def run_query(self):
        name, sql = self.queries[self.i % len(self.queries)]
        self.i += 1
        with self.client.post(
            "/druid/v2/sql",
            json={"query": sql, "resultFormat": "object", "header": False},
            auth=DRUID_AUTH, name="druid: %s" % name,
            catch_response=True, timeout=60,
        ) as res:
            if res.status_code == 200:
                res.success()
            else:
                res.failure("HTTP %s" % res.status_code)


@events.test_start.add_listener
def _announce(environment, **_kw):
    print("target=%s dataset=%s api=%s druid=%s"
          % (TARGET, DATASET, DATASET_API, DRUID))
