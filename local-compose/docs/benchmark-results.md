# Obsrv local stack — measured capacity

**What this answers:** if you run the Obsrv local Docker Compose stack on a
laptop, how much can it actually ingest, and what does it cost you in
resources?

Measured 5 August 2026 against the `feature/obsrv-local-docker-compose` stack
using `local-compose/benchmark`. Every number below comes from a recorded
run; nothing is extrapolated. Reproduce with:

```bash
cd local-compose/benchmark
./benchmark run --profile standard --no-queries
```

---

## The short answer

> On a **4-core / 11.7 GB Docker VM**, the Obsrv local stack sustains
> **59–71 events/sec — roughly 3,500–4,300 events/minute** — through the full
> ingest pipeline (validate → dedup → transform → denormalize → Druid), with
> events averaging **2.2 KB**.
>
> For continuous production-style load, plan for **2,500–3,000 events/minute
> (~40–50 events/sec)**. That is the sustained rate with 30% headroom.
>
> The stack holds **8.9–9.2 GB** of the 11.7 GB VM, and does **not** saturate
> the host: CPU averaged 65–73% and peaked at 85%.

The ceiling is **not** the hardware. It is the Flink job's own concurrency —
2 task slots at parallelism 2. See [Where the limit actually is](#where-the-limit-actually-is).

---

## Runs behind these numbers

Three 20,000-event runs of the `standard` profile, ingest only.

| Run | Drain time | Sustained | Peak | Rows in Druid | Checks |
|---|---|---|---|---|---|
| A | 6m35s | 71 ev/s (4.28K/min) | 104 ev/s | contaminated¹ | 10/12 |
| B | 5m34s | 71 ev/s (4.25K/min) | — | contaminated¹ | 10/12 |
| **C (clean)** | **7m51s** | **59 ev/s (3.55K/min)** | **72 ev/s** | **19,801 exact** | **11/12** |

¹ Runs A and B counted rows left behind by their predecessors, because
dropping a Druid datasource does not stop the realtime indexing tasks that
serve its rows. That defect is fixed; run C's 19,801 is exactly 19,600 unique
events + 201 validation probes, which is how you can tell the counts are
clean. **Throughput** in A and B is still valid — it is measured from Kafka
consumer-group progress, which the Druid contamination does not touch.

Treat **59–71 events/sec** as the honest range. Run-to-run variance on a
laptop is real; a shared 4-core VM does not repeat to the percent.

---

## What is actually being measured

### How the measurement works

Not a fixed-rate test. Producing at a steady rate and watching the pipeline
keep up only proves it can handle *that* rate. Instead:

1. Stop the Flink TaskManager.
2. Produce all 20,000 events into the `ingest` topic — 5 s at
   **3,980 events/sec**. Kafka accepts events ~60× faster than the pipeline
   processes them, so the broker is nowhere near the bottleneck.
3. Start the TaskManager and time how long the backlog takes to drain.

Throughout the drain there is always more work queued than the pipeline can
take, so the drain rate *is* the ceiling.

### The input events

Deterministically generated (fixed seed), so two runs are comparable.

| Property | Value |
|---|---|
| Event count | 20,000 (`standard` profile) |
| Unique events | 19,600 |
| Deliberate duplicates | 400 (2%, to exercise dedup) |
| **Average event size** | **2,238 bytes (~2.2 KB)** |
| Size range | 400 B – 4 KB padding, plus a large-event tail |
| Large events | 25% carry `edata.size > 100000` |
| Total corpus | 42.7 MB |
| Timestamp spread | 30 minutes |
| Distinct users | 100 (master dataset) |

Shape: a telemetry event with nested `actor`, `context.pdata` and `edata`
objects — an Obsrv/Sunbird-style envelope, not a flat row.

### The pipeline operations performed on every event

This is a **fully-featured** dataset, not a pass-through. Every event goes
through all of it:

| Stage | What runs |
|---|---|
| **Extraction** | Envelope unwrapping, batch de-batching |
| **Validation** | JSON-schema validation, mode `IgnoreNewFields` |
| **Deduplication** | On `mid`, backed by Valkey, 1-hour key TTL |
| **Transformation** | 2 JSONata expressions per event (below) |
| **Denormalization** | Join to the `bench_users` master via JSONata on the nested `actor.id`, pulling 10 columns from a Valkey-cached master |
| **Indexing** | Druid Kafka supervisor → `bench_telemetry_events` |

The two JSONata transformations:

```
pipeline     = context.pdata.pid & "-" & context.env      (string concat)
isLargeEvent = edata.size > 100000                        (boolean predicate)
```

If you strip dedup, denorm and transformations, throughput will be higher
than the numbers here. These figures are for the full feature set.

---

## Resource usage

### What is allocated

The compose file sets **no per-container CPU or memory limits**. The binding
constraint is the Docker VM itself, plus the JVM heaps configured per service.

| Boundary | Value |
|---|---|
| Docker Desktop VM | **4 CPUs, 11.67 GB** |
| Per-container limits | none set — the VM is the ceiling |

Configured JVM heaps (the real allocation, tuned for local use):

| Service | Heap |
|---|---|
| Flink JobManager | 256 MB (total Flink memory) |
| Flink TaskManager | 448 MB (total Flink memory), 2 task slots |
| Druid broker | 384 MB |
| Druid coordinator-overlord | 384 MB |
| Druid historical | 512 MB |
| Druid indexer | 640 MB |
| Druid router | 256 MB |
| Druid processing buffers | 16 MiB × 1 thread per service |

### What is consumed, under load

Measured across the drain in run C (sampled every 5s):

| Container | CPU avg | CPU p95 | Mem avg | Mem peak |
|---|---|---|---|---|
| unified-pipeline taskmanager | 96.5% | 149.5% | 1.3 GiB | 1.6 GiB |
| kafka | 32.5% | 56.6% | 429 MiB | 506 MiB |
| druid (all services, one container) | 22.4% | 33.0% | 3.1 GiB | 3.1 GiB |
| unified-pipeline jobmanager | 19.1% | 28.5% | 567 MiB | 575 MiB |
| cache-indexer taskmanager | 13.0% | 24.2% | 669 MiB | 672 MiB |
| cache-indexer jobmanager | 9.3% | 15.2% | 542 MiB | 546 MiB |
| dataset-api | 7.9% | 11.9% | 379 MiB | 380 MiB |
| web-console | 3.6% | 5.1% | 271 MiB | 272 MiB |
| command-api | 3.3% | 4.3% | 74 MiB | 75 MiB |
| postgres | 2.7% | 4.3% | 31 MiB | 33 MiB |
| prometheus | 2.1% | 4.6% | 288 MiB | 309 MiB |
| valkey (dedup) | 1.7% | 2.4% | 11 MiB | 12 MiB |
| valkey (denorm) | 1.2% | 1.7% | 10 MiB | 10 MiB |
| zookeeper | 1.2% | 1.7% | 122 MiB | 122 MiB |
| keycloak | 1.1% | 1.9% | 549 MiB | 549 MiB |
| nginx | 0.5% | 0.7% | 2 MiB | 2 MiB |

CPU percentages are per-core-normalised: 149.5% means one and a half cores.

**Host totals during the drain:**

| | |
|---|---|
| Host CPU | avg **72.9%**, peak **84.6%** |
| Host memory | peak **84.4%** (≈9.8 GB of 11.67 GB) |
| Live container memory sum, mid-drain | **8.85 GiB of 11.67 GiB (76%)** |
| Live container memory sum, after the run | **9.15 GiB (78%)** |

Note the stack does not release memory after a run — the JVM heaps stay
resident. Plan for ~9 GB held continuously once the stack has done work, not
just at peak.

**Is the stack staying inside its allocation?** Yes. Nothing crossed a
saturation threshold (85% CPU / 90% memory). The TaskManager is the heaviest
consumer at ~1.5 cores, and the stack as a whole leaves roughly 2.8 GB of
memory and 15% of CPU unused at peak. It is comfortable, not starved — and
the throughput ceiling is not coming from resource exhaustion.

**Sizing guidance:** allocate the Docker VM **at least 4 CPUs and 12 GB**.
Below 8 GB the JVM heaps alone (Druid ~2.2 GB + Flink ~1.5 GB + Keycloak,
Kafka, Postgres) will not fit alongside the OS page cache, and Druid will
OOM-restart mid-ingest.

---

## Where the limit actually is

The bottleneck is attributed from Flink operator metrics, not guessed:

```
operator                                      par  busy%  bp%   rec/s out
Source: pipeline-consumer                     2    15     0     72
ExtractionFunction -> extractor-batch-...     2    87     0     0.00
```

(`par` is operator parallelism; `bp%` is time spent backpressured.)

The extraction operator is **busy 87% of the time with 0% backpressure**.
That combination is the diagnosis: an operator that is backpressured is
*waiting* on something downstream (and the downstream thing is the real
answer); an operator that is busy and not backpressured is doing the work
that sets the pace. Combined with host CPU at 73% average, the constraint is
**inside the Flink job**, not the hardware.

Supporting evidence:
- TaskManager JVM heap peaked at **85% of max**, with 2.29% of wall clock in GC.
- Checkpoints: **15 completed, 2 failed, p95 16 s** — long enough to interrupt
  processing, and the two failures are a symptom of the same pressure.
- Druid kept up easily: rows were queryable **0 s** after the drain finished.

### To go faster, in order of expected effect

1. **Add TaskManager slots.** The deployment runs 2 slots at parallelism 2.
   The reactive scheduler rescales automatically when another TaskManager
   registers, so this is a `docker compose` scale operation, not a job
   redeploy. This is the single highest-value change.
2. **Raise the TaskManager heap** past 448 MB if you add slots — 85% peak
   leaves no room for a larger dedup or denorm working set.
3. **Lengthen the checkpoint interval**, or move the checkpoint store off the
   container filesystem. A 16 s p95 with 2 of 17 checkpoints failing is a
   meaningful share of a 7m51s drain.
4. **Increase Druid `segmentGranularity`.** Run C produced 1 segment of
   19,801 rows; Druid targets ~5M rows per segment. Irrelevant at this
   volume, but it matters if you scale up.

---

## Functional correctness

Verified before any throughput was measured — a benchmark of a pipeline that
is silently dropping events is worse than no benchmark. Run C, on a clean
datasource:

| Check | Result |
|---|---|
| Master dataset published and Live | PASS |
| Telemetry dataset published and Live | PASS |
| Master data cached in Valkey | PASS — 100/100 records |
| Kafka ingestion | PASS — offset +225 for 225 published |
| Unified pipeline processing | PASS — 201/200 probes in 32 s |
| Druid ingestion | PASS — 201/200 rows queryable |
| **Deduplication** | **FAIL — 1 of 25 burst duplicates stored twice** |
| Transformation (`pipeline`) | PASS |
| Transformation (`isLargeEvent`) | PASS — 150 false / 51 true, boundary correct |
| Denormalization | PASS — 201/201 rows joined (100%), values match master |
| Druid query | PASS — group-by in 537 ms |
| No lost events | PASS — 24 duplicate rejections, zero real loss |

**11 of 12 pass.**

### The one failure is real Obsrv behaviour, not a harness bug

Deduplication misses a small number of duplicates that arrive in a **tight
burst** — 1 of 25 in run C, 2 of 25 in earlier runs. The same dedup catches
**400 of 400** when duplicates are spread across a 20,000-event stream.

Likely mechanism: an unkeyed producer round-robins the two copies of a `mid`
onto different partitions; different parallel instances of the dedup operator
process them concurrently, and both read Valkey before either writes. A
classic check-then-act race, visible only when the copies arrive close enough
together in time.

**Practical impact:** duplicates arriving milliseconds apart on different
partitions may both be stored. Duplicates arriving in normal traffic are
caught. If exact-once matters for your use case, key the producer on the dedup
field so copies land on the same partition.

`ERR_PP_1010` on the `failed` topic is **not** data loss — it means the
duplicate check rejected an event whose row is already in the datasource.
The 400 deliberate duplicates all land there, correctly.

---

## Caveats

- **One machine, one shape.** These numbers are for a 4-core/11.7 GB Docker
  Desktop VM on macOS. Docker Desktop's VM adds virtualisation overhead that
  a native Linux host does not.
- **Ingest only.** The query benchmark was not run; `--no-queries` was used.
  Query latency figures are not included here.
- **20,000 events is a lower bound.** The measured rate is what the pipeline
  sustained over ~7 minutes. Re-run with `--profile heavy` (500,000 events)
  to confirm the ceiling holds over a longer window.
- **The 59–71 ev/s spread is genuine variance**, not measurement error. Quote
  the range, not a single figure.

---

## Reproducing

```bash
cd local-compose && docker compose up -d      # wait for all 17 healthy
cd benchmark
./benchmark run --profile smoke --no-queries      # ~12 min, 2,000 events
./benchmark run --profile standard --no-queries   # ~15 min, 20,000 events
./benchmark run --profile heavy                   # ~2 h, 500,000 events
```

Artefacts land in `benchmark/results/<run-id>/`: a one-page summary, a full
report with every measurement and its evidence, a standalone HTML page, the
raw JSON, and seven CSVs (Kafka lag, throughput series, Flink operators,
Druid indexing, per-container resources, host resources).

Operating details, configuration layering and known traps:
[`benchmark/AGENTS.md`](../benchmark/AGENTS.md).
