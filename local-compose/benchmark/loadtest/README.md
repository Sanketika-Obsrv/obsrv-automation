# Query load testing with Locust

Load-tests Obsrv's query serving with [Locust](https://locust.io) — a standard,
recognisable tool, so this can be handed to anyone rather than only run by the
person who wrote it.

`locustfile.py` is deliberately self-contained: it imports nothing from the
`benchmark` package and every setting has a default matching the local
docker-compose stack. Copy that one file anywhere and it runs.

---

## Why Locust and not JMeter or Gatling

The stack under test is a 4-CPU / 11.7 GB Docker VM where the pipeline already
drives the Flink TaskManager to ~96% CPU. **The load generator runs on the same
machine as the thing it is measuring**, so its own footprint is a measurement
error, not just an inconvenience. A JVM generator competes for exactly the CPU
we are trying to characterise — JMeter most, Gatling less.

Locust is gevent-based, costs almost nothing at the tens-of-QPS this stack
serves, and is Python, so it shares a language with the rest of the harness.

**But size the generator deliberately.** Locust is single-threaded, so one
process caps out well below what the stack can serve — against Druid, 70.9 req/s
single-process versus 175.9 with `--processes 4`. The slow number measured
Locust, not Obsrv. Going the other way is worse: on this 4-core box
`--processes 4` sustained for 3 minutes starved the Flink TaskManager past its
50-second heartbeat deadline, the JobManager declared it dead, the pipeline
restarted from checkpoint, and Druid collapsed from 175 req/s to 0.1 while
competing with the recovery. A 60-second run at the same setting looked
perfectly healthy because it finished before the timeout could trip.

`run.sh` therefore defaults to **half the cores**. Raise it only when the
generator runs on a separate host from the stack.

If you would rather hand people a `.jmx`, the query set and envelope shapes
here port over directly — the two API traps below are the whole difficulty, and
they are not tool-specific.

---

## Run it

```bash
cd local-compose/benchmark/loadtest
python3 -m venv .venv && .venv/bin/pip install locust

# headless, 4 concurrent users, 3 minutes, CSV + HTML report
.venv/bin/locust -f locustfile.py --headless -u 4 -r 4 -t 3m \
    --csv results/run --html results/run.html

# or the web UI on http://localhost:8089
.venv/bin/locust -f locustfile.py
```

### Choosing a target

| `OBSRV_TARGET` | What it hits | What it tells you |
|---|---|---|
| `api` | `POST /v2/data/query/<datasource>` | what an application actually experiences — auth, RBAC, validation, rewrite |
| `druid` | `POST /druid/v2/sql` | the floor, with no API layer in the path |
| `both` (default) | both, evenly weighted | the gap between them is the API layer's cost |

```bash
OBSRV_TARGET=api .venv/bin/locust -f locustfile.py --headless -u 4 -r 4 -t 3m
```

Run the two targets **separately** when you want clean numbers. Run `both` only
when you specifically want them contending.

### Everything else

| Variable | Default |
|---|---|
| `OBSRV_DATASET` | `bench_telemetry` |
| `OBSRV_DATASOURCE` | `<dataset>_events` |
| `OBSRV_DATASET_API` | `http://localhost:3000` |
| `OBSRV_DRUID` | `http://localhost:8888` |
| `OBSRV_KEYCLOAK` | `http://localhost:8080/auth` |
| `OBSRV_REALM` / `OBSRV_CLIENT_ID` | `obsrv` / `obsrv-console` |
| `OBSRV_USERNAME` / `OBSRV_PASSWORD` | `obsrv_admin` / … |
| `OBSRV_SAMPLE_USER` / `OBSRV_SAMPLE_CITY` | `user-0001` / `Bengaluru` |

---

## The nine query classes

Both targets run the same nine shapes, so the two reports are directly
comparable line by line.

| Name | Shape |
|---|---|
| `count` | total row count |
| `filter` | filtered count on a low-cardinality dimension |
| `latest_events` | ordered scan, `LIMIT 100` |
| `group_by` | group by a high-cardinality dimension |
| `time_series` | per-minute `TIME_FLOOR` rollup |
| `top_n` | topN over a dimension |
| `aggregation` | multi-aggregate incl. `COUNT(DISTINCT)` |
| `user_lookup` | point lookup by user |
| `city_lookup` | lookup on a **denormalized** attribute |

---

## Things that will bite you

Each of these cost real debugging time and none of them produce an error
message that points at the cause.

- **The query API's SQL must name the *dataset*, not the datasource.** The
  data-out controller rewrites the dataset id in your SQL to the
  `datasource_ref` before forwarding. Send `FROM "bench_telemetry"` and Druid
  receives `FROM "bench_telemetry_events"` — correct. Send the datasource name
  and the rewrite fires on the substring, Druid receives
  `bench_telemetry_events_events`, and you get an opaque
  `"Request failed with status code 400"`. Querying Druid directly is the
  opposite: it only knows the datasource.
- **The URL path segment is not the dataset id**, despite the route being
  declared `/data/query/:dataset_id`. The lookup matches
  `datasources.datasource` or `datasources.id` and never
  `datasources.dataset_id`, so the dataset id always 404s with
  `DATASET_NOT_FOUND`. Resolve it from `POST /v2/datasources/list`.
- **Data is not queryable through the API until segments hand off.** The API
  gates on the coordinator's `/loadstatus`, which lists only datasources with
  segments published to the metadata store. With the supervisor's default
  `taskDuration` of `PT14400S` (4 hours) rows sit in the realtime task and the
  API answers `DATASOURCE_NOT_AVAILABLE` — while direct Druid SQL returns them
  happily, because the broker also fans out to realtime tasks. Suspend the
  supervisor to force a handoff:
  `curl -X POST .../supervisor/<datasource>/suspend`.
- **The data-out envelope is not the `/v2/datasets/` envelope.** It validates
  `query` at the *top level* and has no `request` property at all. Wrapping the
  body the usual way fails with
  `"#required must have required property 'query'"`.
- **`AS minute` is a parse error.** `MINUTE` is a reserved time-unit keyword in
  Druid's SQL parser, so the alias must be quoted. Unquoted, it 400s on every
  iteration — which in a latency table renders as `0.0 ms`, i.e. the fastest
  query in the run.
- **A load test that degrades over time is probably killing the pipeline.** If
  throughput decays steadily rather than holding flat, check
  `docker logs obsrv-unified-pipeline-jobmanager | grep -i "heartbeat.*timed out"`
  and the TaskManager's `RestartCount` before believing the numbers. A generator
  sized to saturate a shared box takes the Flink pipeline down with it, and the
  resulting figures describe a recovering stack, not a serving one. Read the
  per-second timeline in `*_stats_history.csv`, not just the aggregate row —
  a collapse from 175 req/s to 0.1 still averages to a plausible-looking number.
- **A 200 is not a success.** The API answers HTTP 200 with
  `params.status: "FAILED"` in the envelope. The locustfile checks the envelope,
  not just the status code; a tool that only checks HTTP will report a clean run
  over failing queries.

---

## Reading the output

`--csv results/run` writes `_stats.csv`, `_stats_history.csv` and
`_failures.csv`; `--html` writes a standalone report with the percentile
distribution and a requests-per-second timeline.

Percentiles need samples. At ~30 req/s a 3-minute run gives ~5,000 requests
spread over 18 rows (9 shapes × 2 targets), so ~250–300 per shape — enough for
p95, thin for p99. Lengthen the run rather than reading a p99 off a few dozen
samples.
