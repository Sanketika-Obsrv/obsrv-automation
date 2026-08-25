# Obsrv local stack — measured query capacity

**What this answers:** once data is in Druid, how fast can you *read* it back —
through Obsrv's query API, and through Druid directly — and what does that cost
in resources?

Companion to [benchmark-results.md](benchmark-results.md), which covers ingest.
Measured 5–6 August 2026 against the `feature/obsrv-local-docker-compose` stack,
on a **4-core / 11.7 GB Docker VM**, against a datasource holding **70,339 rows**
(~2.2 KB/event) in 1 published segment.

Load generated with **[Locust](https://locust.io)** — see
[`local-compose/benchmark/loadtest/`](../benchmark/loadtest/). Every number
below comes from a recorded run.

```bash
cd local-compose/benchmark/loadtest
./run.sh 3m 4          # 4 concurrent users, 3 minutes, against both targets
```

---

## The short answer

> With 70,339 rows and **4 concurrent clients**, the stack serves
> **36 queries/sec through the Obsrv query API** (2,140/min) at a **median of
> 58 ms**, and **150 queries/sec straight from Druid** (9,000/min) at a
> **median of 17 ms**.
>
> The Obsrv API layer costs roughly **4× the throughput and 3× the median
> latency** versus querying Druid directly. That is the price of auth, RBAC,
> query-rule validation and the table rewrite — and it is bounded by a single
> CPU core, because the API is a single-threaded Node service.
>
> Under query load the stack holds **10.8 GB of the 11.7 GB VM**. Memory, not
> CPU, is the binding constraint on this box.

For continuous load, plan for **~30 queries/sec through the API**.

---

## Runs behind these numbers

All at 70,339 rows, 4 concurrent users, 3 minutes, Locust `--processes 2`.

| Target | Requests | Failures | rps | p50 | p95 | p99 |
|---|---|---|---|---|---|---|
| Druid SQL direct | 27,009 | **0** | **150.0** | 17 ms | 71 ms | 130 ms |
| Obsrv query API | 6,424 | **0** | **35.7** | 58 ms | 300 ms | 930 ms |

Zero failures across 33,433 requests. Both runs held steady for the full three
minutes — Druid between 124 and 189 rps with p50 flat at 16–18 ms — rather than
decaying. That stability is the result of a fix, not luck; see
[The generator was the bug](#the-generator-was-the-bug).

The stdlib harness's own probe, same 4 clients, agrees on the shape:
**105 queries/sec sustained** straight to Druid.

```bash
cd local-compose/benchmark && ./benchmark queries
```

---

## Per-query latency

Same nine query shapes on both targets, so the columns are directly comparable.
~3,000 samples per shape for Druid, ~700 for the API.

| Query | Shape | Druid p50 / p95 / p99 | API p50 / p95 / p99 |
|---|---|---|---|
| `count` | total row count | 12 / 57 / 110 ms | 49 / 280 / 920 ms |
| `latest_events` | ordered scan, LIMIT 100 | 11 / 59 / 110 ms | 50 / 280 / 630 ms |
| `filter` | count on low-cardinality dim | 13 / 63 / 130 ms | 55 / 270 / 660 ms |
| `city_lookup` | lookup on a **denormalized** field | 14 / 64 / 120 ms | 53 / 260 / 700 ms |
| `group_by` | group by high-cardinality dim | 15 / 65 / 130 ms | 57 / 250 / 950 ms |
| `time_series` | per-minute TIME_FLOOR rollup | 17 / 68 / 130 ms | 60 / 290 / 710 ms |
| `top_n` | topN over a dimension | 17 / 71 / 130 ms | 59 / 320 / 1700 ms |
| `user_lookup` | point lookup by user | 18 / 73 / 130 ms | 56 / 260 / 1300 ms |
| `aggregation` | multi-agg + COUNT(DISTINCT) | 38 / 99 / 200 ms | 84 / 380 / 1000 ms |

Three things worth noting:

- **`aggregation` is the slowest on both paths at both scales**, and it is the
  only query with a `COUNT(DISTINCT)`. It is 2–3× the median of any other shape
  on Druid. That is the shape to watch as row count grows.
- **`city_lookup` is as fast as any other filter.** It reads `user.city`, a
  field that does not exist in the source event — it was joined in from the
  master dataset during ingest. Denormalizing at write time means the read costs
  the same as any other dimension filter, which is the entire point of doing it.
- **The API flattens the differences.** On Druid the shapes span 11–38 ms; through
  the API they span 49–84 ms. Fixed per-request overhead dominates, so the API
  number tells you less about your query than the Druid number does.

---

## What changed between 20k and 70k rows

Measured with the stdlib probe at both scales — same 4 clients, same 12
iterations, same nine shapes, so this comparison is apples-to-apples.

| Rows | Sustained qps (direct Druid) | Notes |
|---|---|---|
| 19,801 | **200** | 1 segment |
| 70,339 | **105** | 1 segment |

**3.5× the data cost roughly half the throughput.** That is much better than
linear, which is the expected shape for a columnar store: the fixed per-query
overhead (broker dispatch, segment mapping, result assembly) does not grow with
row count, so only the scan portion scales.

Do not read this as a scaling law from two points. It does say that the 20k
numbers were dominated by fixed overhead and should not be quoted as Druid's
scan speed.

The Locust figures at 19,801 rows are **not** comparable and are deliberately
omitted here — they were taken at a different generator process count, and the
3-minute run at that setting destabilised the stack (below).

---

## The generator was the bug

Worth reading before you trust any load-test number from this box, including
your own.

Locust is gevent-based and therefore single-threaded. One process caps out well
below what the stack can serve: **70.9 rps single-process versus 175.9 with
`--processes 4`** against Druid. The slow number measured Locust, not Obsrv.

So more processes look strictly better — until they aren't. At `--processes 4`
sustained for three minutes, the generator starved the Flink TaskManager past
its 50-second heartbeat deadline:

```
Closing TaskExecutor connection 172.28.0.16:6122-55c9ad because:
  The heartbeat of TaskManager with id 172.28.0.16:6122-55c9ad timed out.
... Restoring job 988a910d... from Checkpoint 213
```

The JobManager declared the TaskManager dead, the pipeline restarted from
checkpoint, and Druid throughput collapsed **from 175 rps to 0.1 rps** while
competing with the recovery. p95 climbed 360 ms → 1400 ms across the run.

A 60-second run at the identical setting looked perfectly healthy — it finished
before the timeout could trip. **The failure only appears at durations longer
than the heartbeat deadline**, which is exactly the duration you need for
percentiles.

`run.sh` now defaults to **half the cores** (`--processes 2`). The runs in this
document were taken at that setting and held flat for the full three minutes.

**How to check your own run:** if throughput decays rather than holding flat,
read `*_stats_history.csv` per-second before believing the aggregate — a
collapse from 175 rps to 0.1 still averages to a plausible-looking number. Then
check the pipeline:

```bash
docker logs obsrv-unified-pipeline-jobmanager | grep -i "heartbeat.*timed out"
docker inspect obsrv-unified-pipeline-taskmanager --format '{{.RestartCount}}'
```

---

## Where the limit is

Container CPU during the API run (% of one core):

| Container | CPU avg | CPU max | Mem avg |
|---|---|---|---|
| `obsrv-druid` | **102.4%** | 150.0% | 3.5 GiB |
| `obsrv-dataset-api` | **91.0%** | 116.2% | 440 MiB |
| `obsrv-kafka` | 17.6% | 116.6% | 254 MiB |
| `obsrv-unified-pipeline-taskmanager` | 8.4% | 74.8% | 2.9 GiB |
| `obsrv-keycloak` | 7.1% | 126.1% | 485 MiB |
| `obsrv-cache-indexer-jobmanager` | 4.3% | 17.1% | 564 MiB |
| `obsrv-postgres` | 4.1% | 10.1% | 54 MiB |

**`obsrv-dataset-api` sits at ~91% of a single core.** It is a Node service and
therefore single-threaded for JavaScript execution, so ~100% of one core is its
ceiling regardless of how many cores the host has. That is the mechanism behind
the API's 4× throughput cost: Druid spreads across cores, the API cannot. Adding
CPUs will not move the API number; running more API replicas behind the nginx
front-end would.

Peak memory under query load was **10.82 GiB of 11.67 GB (93%)**. Memory is the
binding constraint on this box — see the ingest note below.

---

## Getting data in is the harder problem

Observed while loading the corpus these queries run against, and relevant
because it bounds how much data you can put here at all.

| Stage | Rate |
|---|---|
| Producing to Kafka | **14,220 events/sec** |
| Draining through Flink into Druid | **~50–100 events/sec** |

**The Flink pipeline is the bottleneck, by two orders of magnitude.** Kafka
accepted 100,000 events in 7 seconds; the pipeline needed ~25 minutes to make
them queryable. Plan ingest around the drain rate, not the produce rate.

**The pipeline did not survive a sustained 100k ingest.** With no load generator
running at all, memory climbed to **10.92 GiB of 11.67 GB (94%)** and then:

```
18:19:19 ALERT obsrv-unified-pipeline-jobmanager   RESTARTED 0->1
18:21:30 ALERT obsrv-unified-pipeline-taskmanager  RESTARTED 0->1
18:21:49 ALERT flink heartbeat-timeout x4
```

Same heartbeat signature as the load-generator case — this stack has one failure
mode and two ways to reach it. It recovered from checkpoint and kept ingesting,
so no data was lost, but two consequences matter:

- **The harness's drain accounting silently went wrong.** The consumer group
  reset on restart, so the drain reported `PASS drained 0 events in 19m43s
  (0.00 events/sec)` — a pass produced by reading zero remaining, not by
  finishing. Trust the Druid row count, not the drain summary.
- **Deduplication failed under this load.** The functional check reported
  `25 mids published twice, 23 stored once, 2 stored more than once` — 2 of 25
  duplicates got through. The same check passes at 20k. Unresolved; treat
  exactly-once as unverified at this scale.

The run was stopped by hand at 70,339 of the intended 100,000 rows, which is why
this document says 70,339 everywhere.

---

## Input the queries run against

| Property | Value |
|---|---|
| Rows | 70,339 |
| Segments | 1 |
| Avg event size | ~2.2 KB |
| Distinct users (`actor.id`) | 100 |
| Distinct event types (`eid`) | 7 |
| Denormalized columns | 10, joined from `bench_users` at ingest |

70,339 rows is still small. These latencies characterise the stack's fixed
overhead far more than Druid's scan speed. Re-run against your own volume.

---

## Two things you must know before querying

Both cost real debugging time and neither produces an error that points at the
cause. Full list in
[`loadtest/README.md`](../benchmark/loadtest/README.md#things-that-will-bite-you).

**1. Data is not queryable through the API until segments hand off.**

The API gates on the coordinator's `/loadstatus`, which lists only datasources
with segments published to the metadata store. The Kafka supervisor's default
`taskDuration` here is `PT14400S` — **4 hours** — so freshly-ingested rows sit
inside the running realtime task and the API answers
`DATASOURCE_NOT_AVAILABLE` for up to four hours. Direct Druid SQL returns those
same rows immediately, because the broker also fans out to realtime tasks.

That divergence is why the benchmark's functional check reported
`druid_query PASS ... dataset-api query failed` on every run. Force a handoff:

```bash
curl -u admin:admin123 -X POST \
  http://localhost:8888/druid/indexer/v1/supervisor/<datasource>/suspend
```

Suspending is reversible — `/resume` restarts consumption from the committed
offsets. **Remember to resume it**, or the next ingest will pile up in Kafka
and never reach Druid.

Lower `taskDuration` in the supervisor spec if you want data readable through
the API sooner.

**2. SQL sent to the API must name the *dataset*, not the datasource.**

The data-out controller rewrites the dataset id in your SQL to the
`datasource_ref` before forwarding to Druid.

```sql
-- to the Obsrv API   -> Druid receives "bench_telemetry_events".  Correct.
SELECT COUNT(*) FROM "bench_telemetry"

-- to the Obsrv API   -> rewrite fires on the substring, Druid receives
--                       "bench_telemetry_events_events".  Opaque HTTP 400.
SELECT COUNT(*) FROM "bench_telemetry_events"

-- straight to Druid  -> Druid only knows the datasource.  Correct.
SELECT COUNT(*) FROM "bench_telemetry_events"
```

---

## Caveats

- **70,339 rows in 1 segment.** Small, and a single segment means no
  cross-segment parallelism — a larger datasource may scan *faster* per row.
- **p99 is thin.** ~700 API samples per shape supports p95 comfortably; p99
  rests on ~7 requests per shape. Lengthen the run before quoting p99.
- **The load generator shares the machine with the stack.** Locust was chosen
  partly to keep that footprint small, but it is not zero — and at the wrong
  process count it is actively destructive. Numbers from a separate load host
  would be better and safer.
- **Single concurrency level.** Everything here is 4 concurrent clients. The
  saturation curve was not mapped; `./run.sh 3m 16` would start that — but read
  the generator warning above first.
- **Warm cache.** No cache flush between runs, so these are warm-path numbers —
  the realistic case for a served dashboard, the optimistic case for an ad-hoc
  query.
- **Resource table is from the 20k run.** CPU/memory percentages were sampled
  during the earlier run; the totals were re-confirmed at 70k, the per-container
  breakdown was not re-sampled.

---

## Reproducing

```bash
# 1. stack up, with data already ingested
cd local-compose && docker compose up -d
cd benchmark && ./benchmark run --profile standard --no-queries

# 2. force segment handoff so the query API can see the rows
curl -u admin:admin123 -X POST \
  http://localhost:8888/druid/indexer/v1/supervisor/bench_telemetry_events/suspend

# 3. load test both paths
cd loadtest && ./run.sh 3m 4
open results/druid.html results/api.html

# 4. resume the supervisor when you are done
curl -u admin:admin123 -X POST \
  http://localhost:8888/druid/indexer/v1/supervisor/bench_telemetry_events/resume
```

The stdlib harness also has a lighter built-in query pass, useful as a quick
check rather than a load test:

```bash
cd local-compose/benchmark && ./benchmark queries
```
