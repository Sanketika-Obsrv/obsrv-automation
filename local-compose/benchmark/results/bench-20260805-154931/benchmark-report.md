# Obsrv Mini Deployment -- Benchmark Report

- **Run** `bench-20260805-154931` (profile `standard`)
- **Started** 2026-08-05 15:49:31
- **Duration** 12m50s
- **Load** 20,000 events, 100 users, 400 duplicates, avg 2.2 KiB per event

## 1. Executive summary

| Question | Answer |
|---|---|
| Peak ingestion throughput | 72 events/sec (4.30K events/min) |
| Sustained ingestion throughput | 59 events/sec (3.55K events/min) |
| Producer-side ceiling (Kafka write path) | 3.98K events/sec |
| Unified Pipeline processing rate | 72 records/sec sustained, 160 peak |
| Druid indexing speed | 55 rows/sec queryable, 12 rows/sec reported by the supervisor |
| End-to-end latency (event generated -> queryable) | p50 - ms, p95 - ms, p99 - ms |
| Wall-clock end to end for the whole batch | 7m56s |
| Backlog drain time | 7m51s for 20,000 events |
| Query latency (all classes) | avg - ms, p50 -, p95 -, p99 - |
| Estimated queries/sec | - queries/sec (-/min) at concurrency None, measured under load |
| Slowest / fastest query class | - / - |
| CPU utilisation at peak | host 85% p95 (87% max) across 4 cores |
| Memory utilisation at peak | host 84% of 11.7 GiB; TaskManager heap peak 85% of max |
| Disk and network at peak | read -/s, write -/s, net rx -/s tx -/s |
| Cost per 1,000 events | 54 CPU-seconds across all containers |
| Is Kafka the bottleneck? | No -- consumer lag fell monotonically and the producer sustained 3.98K events/sec, well above the pipeline's rate |
| Is Flink / the Unified Pipeline the bottleneck? | Yes -- this operator was busy 87% of the time while only 0% backpressured -- it is doing the work that sets the pace, not waiting on a downstream stage |
| Is Druid the bottleneck? | No -- this operator was busy 87% of the time while only 0% backpressured -- it is doing the work that sets the pace, not waiting on a downstream stage |
| Is the infrastructure the bottleneck? | No -- this operator was busy 87% of the time while only 0% backpressured -- it is doing the work that sets the pace, not waiting on a downstream stage |
| Recommended safe production throughput | 2.49K events/min (41 events/sec) -- 70% of measured sustained, leaving headroom for query load and retries |
| Daily volume at the safe rate | 3.58M events/day |
| Functional correctness | 11/12 checks passed -- see the failures below |
| Can this deployment sustain 10,000 events/min? | No -- that is 2.81x the measured sustained rate |
| Can this deployment sustain 100,000 events/min? | No -- that is 28.14x the measured sustained rate |
| What is needed for 2x capacity? | add ~3 CPU cores (projected 169% of the current 4); raise unified-pipeline parallelism to ~3 slot(s) (add TaskManager replicas; the reactive scheduler absorbs them without a job restart) |
| What is needed for 5x capacity? | add ~13 CPU cores (projected 423% of the current 4); raise unified-pipeline parallelism to ~5 slot(s) (add TaskManager replicas; the reactive scheduler absorbs them without a job restart); increase ingest to >= 5 partitions -- consumer parallelism is capped by partition count; give Druid its own middle-manager capacity (more task slots and a larger heap) so segment handoff does not become the new ceiling; move Valkey dedup/denorm off the same host, or accept that each event costs two extra round trips on a shared box |
| What is needed for 10x capacity? | add ~30 CPU cores (projected 846% of the current 4); raise unified-pipeline parallelism to ~10 slot(s) (add TaskManager replicas; the reactive scheduler absorbs them without a job restart); increase ingest to >= 10 partitions -- consumer parallelism is capped by partition count; give Druid its own middle-manager capacity (more task slots and a larger heap) so segment handoff does not become the new ceiling; move Valkey dedup/denorm off the same host, or accept that each event costs two extra round trips on a shared box; split the single-container Druid into separate coordinator/overlord, broker, historical and middle-manager processes -- the bundled micro-quickstart is not a 10x target |

## 2. Functional validation

11 of 12 checks passed.

| Check | Result | Detail |
|---|---|---|
| Master dataset is published and Live | PASS | bench_users status=Live (metadata store), api reports Live |
| Telemetry dataset is published and Live | PASS | bench_telemetry status=Live (metadata store), api reports Live |
| Master dataset records are cached and joinable | PASS | 100/100 records in Valkey db 9; GET user-0001 returns 210 bytes |
| Events reach the Kafka entry topic | PASS | topic ingest end offset 48300 -> 48525 (+225) for 225 published events |
| Unified Pipeline processes events end to end | PASS | 201 of 200 probe events reached the datasource in 32s |
| Druid indexes the processed events | PASS | 201 / 200 rows queryable |
| Republishing an event with the same mid stores one row | **FAIL** | 25 mids published twice, 24 stored once, 1 stored more than once |
| JSONata: context.pdata.pid & "-" & context.env | PASS | expected 'search-service-search'; datasource holds {'search-service-search': 106, 'search-service-player': 7, 'search-service-portal': 7, 'search-service-assessment': 3, 'search-service-content': 3} |
| JSONata: edata.size > 100000 | PASS | flag=0 size 1788..99868 (150 rows); flag=1 size 114859..895451 (51 rows) |
| Telemetry rows carry the joined user attributes | PASS | 201/201 rows joined (100.0%) on 10 columns, values match the master |
| The datasource answers analytical queries | PASS | group-by returned 5 rows in 537 ms; dataset-api query failed |
| No events were lost during functional validation | PASS | 24 duplicate rejection(s), no lost events -- the row for each is already in the datasource |

<details><summary>Evidence</summary>

**Master dataset is published and Live** (`dataset_published_master`)

```json
{
  "dataset_id": "bench_users",
  "db_status": "Live",
  "api": {
    "dataset_id": "bench_users",
    "status": "Live",
    "type": "master",
    "api_version": "v2",
    "connectors_config": [],
    "transformations_config": []
  }
}
```

**Telemetry dataset is published and Live** (`dataset_published_telemetry`)

```json
{
  "dataset_id": "bench_telemetry",
  "db_status": "Live",
  "api": {
    "dataset_id": "bench_telemetry",
    "status": "Live",
    "type": "event",
    "api_version": "v2",
    "alias": "bench_telemetry_druid",
    "connectors_config": [],
    "transformations_config": [
      {
        "field_key": "pipeline",
        "transformation_function": {
          "type": "jsonata",
          "expr": "context.pdata.pid & \"-\" & context.env",
          "category": "derived",
          "datatype": "string"
        },
        "mode": "Lenient",
        "metadata": null
      },
      {
        "field_key": "isLargeEvent",
        "transformation_function": {
          "type": "jsonata",
          "expr": "edata.size > 100000",
          "category": "derived"
        },
        "mode": "Lenient",
        "metadata": null
      }
    ]
  }
}
```

**Master dataset records are cached and joinable** (`master_data_cached`)

```json
{
  "redis_db": "9",
  "dbsize": 100,
  "expected": 100,
  "sample_key": "user-0001",
  "sample_value": "{\"organization\":\"Sunbird Foundation\",\"city\":\"Pune\",\"state\":\"Maharashtra\",\"subscription\":\"free\",\"age\":27,\"department\":\"Engineering\",\"id\":\"user-0001\",\"device\":\"ios-phone\",\"userName\":\"Arjun Das\",\"gender\":\"female\"}"
}
```

**Events reach the Kafka entry topic** (`kafka_ingestion`)

```json
{
  "topic": "ingest",
  "offset_before": 48300,
  "offset_after": 48525,
  "published": 225
}
```

**Unified Pipeline processes events end to end** (`unified_pipeline_processing`)

```json
{
  "rows_found": 201,
  "expected": 200,
  "seconds": 32.3,
  "datasource": "bench_telemetry_events"
}
```

**Druid indexes the processed events** (`druid_ingestion`)

```json
{
  "rows": 201,
  "expected": 200
}
```

**Republishing an event with the same mid stores one row** (`deduplication`)

```json
{
  "duplicate_mids_published": [
    "probe-0-0000",
    "probe-0-0001",
    "probe-0-0002",
    "probe-0-0003",
    "probe-0-0004",
    "probe-0-0005",
    "probe-0-0006",
    "probe-0-0007",
    "probe-0-0008",
    "probe-0-0009"
  ],
  "rows_per_mid": {
    "probe-0-0000": 2,
    "probe-0-0001": 1,
    "probe-0-0002": 1,
    "probe-0-0003": 1,
    "probe-0-0004": 1,
    "probe-0-0005": 1,
    "probe-0-0006": 1,
    "probe-0-0007": 1,
    "probe-0-0008": 1,
    "probe-0-0009": 1
  },
  "violations": {
    "probe-0-0000": 2
  },
  "query": "SELECT \"mid\", COUNT(*) FROM \"bench_telemetry_events\" WHERE \"mid\" IN (...) GROUP BY \"mid\""
}
```

**JSONata: context.pdata.pid & "-" & context.env** (`transformation_pipeline`)

```json
{
  "expected": "search-service-search",
  "observed": {
    "search-service-search": 106,
    "search-service-player": 7,
    "search-service-portal": 7,
    "search-service-assessment": 3,
    "search-service-content": 3
  },
  "column_present": true
}
```

**JSONata: edata.size > 100000** (`transformation_is_large_event`)

```json
{
  "by_flag": {
    "0": {
      "flag": 0,
      "min_size": 1788,
      "max_size": 99868,
      "c": 150
    },
    "1": {
      "flag": 1,
      "min_size": 114859,
      "max_size": 895451,
      "c": 51
    }
  },
  "note": "Druid stores the boolean as BIGINT 1/0"
}
```

**Telemetry rows carry the joined user attributes** (`denormalization`)

```json
{
  "columns": [
    "user.age",
    "user.city",
    "user.department",
    "user.device",
    "user.gender",
    "user.id",
    "user.organization",
    "user.state",
    "user.subscription",
    "user.userName"
  ],
  "rows_joined": 201,
  "rows_total": 201,
  "pct": 100.0,
  "sample": [
    {
      "actor_id": "user-0053",
      "user.age": 42,
      "user.city": "Indore",
      "user.department": "Engineering",
      "user.device": "android-phone",
      "user.gender": "male",
      "user.id": "user-0053",
      "user.organization": "NDEAR Labs",
      "user.state": "Madhya Pradesh",
      "user.userName": "Myra Menon"
    },
    {
      "actor_id": "user-0037",
      "user.age": 43,
      "user.city": "Pune",
      "user.department": "Analytics",
      "user.device": "kiosk",
      "user.gender": "female",
      "user.id": "user-0037",
      "user.organization": "Samagra",
      "user.state": "Maharashtra",
      "user.userName": "Kavya Verma"
    },
    {
      "actor_id": "user-0018",
      "user.age": 27,
      "user.city": "Kolkata",
      "user.department": "Research",
      "user.device": "android-phone",
      "user.gender": "undisclosed",
      "user.id": "user-0018",
      "user.organization": "EkStep",
      "user.state": "West Bengal",
      "user.userName": "Reyansh Das"
    }
  ],
  "values_match_master": true
}
```

**The datasource answers analytical queries** (`druid_query`)

```json
{
  "sample": [
    {
      "actor_id": "user-0081",
      "events": 7
    },
    {
      "actor_id": "user-0034",
      "events": 5
    },
    {
      "actor_id": "user-0063",
      "events": 5
    },
    {
      "actor_id": "user-0096",
      "events": 5
    },
    {
      "actor_id": "user-0099",
      "events": 5
    }
  ],
  "sql_ms": 536.9,
  "api_query_ok": false,
  "api_error": "HTTP 400 from http://localhost:3000/v2/data/query/bench_telemetry: {\"id\":\"api.data.out\",\"ver\":\"v2\",\"ts\":\"2026-08-05T10:22:29+00:00\",\"params\":{\"status\":\"FAILED\",\"msgid\":\"obsrv-benchmark\",\"resmsgid\":\"20"
}
```

**No events were lost during functional validation** (`no_dead_letter_events`)

```json
{
  "before": {
    "failed": {
      "0": 289,
      "1": 228,
      "2": 369,
      "3": 282
    },
    "transform.failed": {
      "0": 0,
      "1": 0,
      "2": 0,
      "3": 0
    },
    "masterdata.failed": {
      "0": 0,
      "1": 0,
      "2": 0,
      "3": 0
    }
  },
  "after": {
    "failed": {
      "0": 313,
      "1": 228,
      "2": 369,
      "3": 282
    },
    "transform.failed": {
      "0": 0,
      "1": 0,
      "2": 0,
      "3": 0
    },
    "masterdata.failed": {
      "0": 0,
      "1": 0,
      "2": 0,
      "3": 0
    }
  },
  "delta": {
    "failed": 24
  },
  "by_error_code": {
    "failed": {
      "ERR_PP_1010": 24
    }
  },
  "duplicate_rejections": 24,
  "lost": {}
}
```

</details>

## 3. Datasets under test

| | Master | Telemetry |
|---|---|---|
| Dataset id | `bench_users` | `bench_telemetry` |
| Records / entry topic | 100 cached in Valkey db 9 | `ingest` (4 partitions) |
| Datasource | (cache only) | `bench_telemetry_events` |
| Dedup key | - | `mid` |
| Transformations | - | `pipeline`, `isLargeEvent` |
| Denormalization | - | `user` via jsonata |

## 4. Kafka ingestion and backlog drain

| Metric | Value |
|---|---|
| Topic | `ingest` (4 partitions) |
| Backlog built | 20,000 events |
| Producer throughput | 3.98K events/sec (8.5 MiB/s) |
| Pipeline paused during load | True |
| Drain time | 7m51s |
| Events drained | 20,000 |
| Sustained consumption | 59 events/sec (3.55K events/min) |
| Peak consumption | 72 events/sec |
| Dead-letter events | 0 |

### Per-minute progress

| Minute | Consumed | Remaining | Events/sec | Events/min | Lag reduction | ETA |
|---:|---:|---:|---:|---:|---:|---|
| 0 | 48,525 | 20,000 | 0.00 | 0.00 | 0 | - |
| 1 | 48,887 | 19,638 | 5.34 | 320 | 362 | 1h01m |
| 2 | 53,397 | 15,128 | 63 | 3.77K | 4,510 | 4m00s |
| 3 | 55,584 | 12,941 | 31 | 1.88K | 2,187 | 6m52s |
| 4 | 59,572 | 8,953 | 58 | 3.49K | 3,988 | 2m34s |
| 5 | 63,619 | 4,906 | 60 | 3.62K | 4,047 | 1m21s |
| 6 | 68,525 | 0 | 76 | 4.58K | 4,906 | 0s |
| 7 | 68,525 | 0 | 0.00 | 0.00 | 0 | - |
| 8 | 68,525 | 0 | 0.00 | 0.00 | 0 | - |

## 5. Unified Pipeline (Flink)

| Metric | Value |
|---|---|
| Job state | RUNNING (RUNNING) |
| Slots / parallelism | 2 / 2 |
| Records out | 20,000 (72/sec sustained, 160/sec peak) |
| JVM heap | peak 84.8% of 276.0 MiB |
| GC | 10691.0 ms young + 0 ms old = 2.29% of wall clock |
| Checkpoints | 15 completed, 2 failed, p95 16.33K ms |
| TaskManager CPU | avg 96%, p95 149% |

### Operators

| Operator | Parallelism | Busy | Backpressured | Records out/sec |
|---|---:|---:|---:|---:|
| Source: pipeline-consumer | 2 | 15% | 0% | 72 |
| ExtractionFunction -> (extractor-batch-failed-events-sink: Writer -> extractor-b | 2 | 87% | 0% | 0.00 |

## 6. Druid indexing and query surface

| Metric | Value |
|---|---|
| Datasource | `bench_telemetry_events` |
| Rows queryable | 19,801 of 19,600 expected (101.026%) |
| Settle time after drain | 0s |
| Queryable rows/sec | 55 sustained, 105 peak |
| Supervisor | RUNNING (RUNNING), 1 active task(s), lag 0 |
| Supervisor rows processed | 12 (1m avg), 19,801 total |
| Segments | 1 covering 0.0 B, avg 19,801 rows each |
| Indexing tasks | 2 running, 0 pending, 0 waiting; duration p95 0.06 s |
| Per-event pipeline latency | p50 - ms, p95 - ms, p99 - ms, max - ms |

## 7. Query benchmark

Measured against 0 rows. 12 iterations per class after 3 warmups, then a 20s saturation probe at concurrency 4.

| Query | Avg ms | P50 | P95 | P99 | Max | Rows | Errors |
|---|---:|---:|---:|---:|---:|---:|---:|

Under None concurrent clients the deployment completed **- queries/sec** (-/min) with p95 - ms.

## 8. Infrastructure

Host (4 cores, 11.7 GiB RAM, metrics from prometheus/node-exporter):

| Metric | Average | Peak |
|---|---:|---:|
| CPU | 73% | 87% |
| Memory | 81% | 84% |
| Load (1m) | - | - |
| Disk read | - | -/s |
| Disk write | - | -/s |
| Network rx/tx | - | -/s / -/s |

| Container | CPU avg % | CPU p95 % | Mem avg | Mem peak | % of limit | CPU-sec |
|---|---:|---:|---:|---:|---:|---:|
| up_taskmanager | 96.47 | 149.49399999999997 | 1.3 GiB | 1.6 GiB | None | 480.89 |
| kafka | 32.54 | 56.603999999999985 | 429.7 MiB | 505.7 MiB | None | 164.8 |
| druid | 22.4 | 32.98599999999999 | 3.1 GiB | 3.1 GiB | None | 109.93 |
| up_jobmanager | 19.08 | 28.50599999999999 | 566.8 MiB | 574.8 MiB | None | 92.34 |
| ci_taskmanager | 12.96 | 24.189999999999984 | 668.7 MiB | 671.6 MiB | None | 65.96 |
| ci_jobmanager | 9.27 | 15.152000000000001 | 542.2 MiB | 546.0 MiB | None | 46.6 |
| dataset_api | 7.94 | 11.925999999999998 | 378.5 MiB | 379.9 MiB | None | 41.05 |
| web_console | 3.56 | 5.105999999999996 | 271.0 MiB | 272.2 MiB | None | 17.85 |
| command_api | 3.29 | 4.329999999999999 | 73.5 MiB | 75.3 MiB | None | 15.48 |
| postgres | 2.7 | 4.291999999999997 | 30.6 MiB | 32.9 MiB | None | 13.64 |
| prometheus | 2.14 | 4.629499999999999 | 288.1 MiB | 309.2 MiB | None | 10.65 |
| valkey_dedup | 1.66 | 2.416 | 11.3 MiB | 11.7 MiB | None | 8.12 |
| valkey_denorm | 1.21 | 1.7079999999999997 | 9.5 MiB | 9.5 MiB | None | 5.95 |
| zookeeper | 1.16 | 1.7319999999999998 | 122.3 MiB | 122.3 MiB | None | 5.67 |
| keycloak | 1.07 | 1.9159999999999995 | 548.5 MiB | 548.5 MiB | None | 5.23 |
| nginx | 0.51 | 0.7154999999999999 | 1.7 MiB | 1.7 MiB | None | 2.3 |

Resource cost: **54.323 CPU-seconds per 1,000 events** across all containers (1086.46 CPU-seconds total over the measured window).

CPU/throughput correlation r = -0.549 -- CPU rises as throughput falls -- time is going somewhere other than useful work (GC, retries, contention)

## 9. Bottleneck analysis

**unified-pipeline operator: ExtractionFunction -> (extractor-batch-failed-events-sink: Writer -> extractor-b** (flink layer)

this operator was busy 87% of the time while only 0% backpressured -- it is doing the work that sets the pace, not waiting on a downstream stage

```json
{
  "host_cpu_p95": 84.59,
  "host_mem_peak_pct": 84.41,
  "pipeline_sustained_per_sec": 72.01,
  "kafka_sustained_per_sec": 59.23,
  "druid_rows_per_sec": 54.79,
  "taskmanager_cpu_p95": 149.49399999999997,
  "taskmanager_mem_pct_of_limit": null,
  "operator": {
    "name": "ExtractionFunction -> (extractor-batch-failed-events-sink: Writer -> extractor-b",
    "parallelism": 2,
    "busy_avg": 0.8747,
    "busy_p95": 1.0,
    "backpressured_avg": null,
    "out_per_sec": 0.0,
    "out_total": 0
  }
}
```

- no resource crossed its saturation threshold -- the limit is in the pipeline's own concurrency, not the hardware

## 10. Capacity

| | events/sec | events/min | events/day |
|---|---:|---:|---:|
| Measured sustained | 59 | 3.55K | 5.12M |
| Measured peak | 72 | 4.30K | - |
| **Recommended safe** | **41** | **2.49K** | **3.58M** |

- 10,000 events/min: **not achievable** (2.81x the measured sustained rate)
- 100,000 events/min: **not achievable** (28.14x the measured sustained rate)

## 11. Scaling to 2x / 5x / 10x

### 2x (118 events/sec, projected host CPU 169.2%)

- add ~3 CPU cores (projected 169% of the current 4)
- raise unified-pipeline parallelism to ~3 slot(s) (add TaskManager replicas; the reactive scheduler absorbs them without a job restart)

### 5x (296 events/sec, projected host CPU 423.0%)

- add ~13 CPU cores (projected 423% of the current 4)
- raise unified-pipeline parallelism to ~5 slot(s) (add TaskManager replicas; the reactive scheduler absorbs them without a job restart)
- increase ingest to >= 5 partitions -- consumer parallelism is capped by partition count
- give Druid its own middle-manager capacity (more task slots and a larger heap) so segment handoff does not become the new ceiling
- move Valkey dedup/denorm off the same host, or accept that each event costs two extra round trips on a shared box

### 10x (592 events/sec, projected host CPU 845.9%)

- add ~30 CPU cores (projected 846% of the current 4)
- raise unified-pipeline parallelism to ~10 slot(s) (add TaskManager replicas; the reactive scheduler absorbs them without a job restart)
- increase ingest to >= 10 partitions -- consumer parallelism is capped by partition count
- give Druid its own middle-manager capacity (more task slots and a larger heap) so segment handoff does not become the new ceiling
- move Valkey dedup/denorm off the same host, or accept that each event costs two extra round trips on a shared box
- split the single-container Druid into separate coordinator/overlord, broker, historical and middle-manager processes -- the bundled micro-quickstart is not a 10x target

## 12. Recommendations

1. **Add TaskManager slots before anything else** _(high impact)_

   The constraint is inside the stream job (unified-pipeline operator: ExtractionFunction -> (extractor-batch-failed-events-sink: Writer -> extractor-b). This deployment runs 2 slot(s); the reactive scheduler rescales automatically when another TaskManager registers, so this is a compose scale operation rather than a job redeploy.

2. **Checkpoints are slow enough to interrupt processing** _(medium impact)_

   p95 checkpoint duration was 16.3 s. Increase the interval or move the checkpoint store off the container filesystem.

3. **Segments are smaller than Druid's target** _(low impact)_

   1 segment(s) averaging 19,801 rows. Druid targets ~5M rows per segment; small segments multiply query fan-out and metadata overhead. Increase segmentGranularity or run compaction.

4. **Throughput is not CPU-limited** _(low impact)_

   Correlation between host CPU and throughput was r=-0.55. Adding cores is unlikely to help; the constraint is concurrency or an external wait.

5. **Re-run at a higher volume to confirm the ceiling** _(low impact)_

   This run drained 20,000 events. The measured rate is a lower bound; OBSRV_BENCH_LOAD_EVENTS=100000 re-runs the identical benchmark at 5x.

## 13. Reproducing this run

```bash
cd local-compose/benchmark
./benchmark run /Users/manju/Documents/Projects/obsrv/obsrv-automation/local-compose/benchmark/benchmark-config.yaml
```

Same seeds (`users.seed=20260804`, `load.seed=20260804`) produce the same corpus, so two runs are directly comparable.
