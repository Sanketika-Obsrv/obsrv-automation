# Obsrv benchmark — operating guide

A benchmark harness for the local Docker Compose Obsrv stack. It builds a
realistic dataset, pushes a known event corpus through the ingest pipeline,
and measures what the deployment can actually sustain.

Everything is stdlib Python 3. No `pip install`, no virtualenv, no
`requirements.txt`. If `python3` and `docker` work, this works.

---

## 1. Run it

```bash
cd local-compose/benchmark

./benchmark run --profile smoke --no-queries     # ~12 min, 2,000 events
./benchmark run --profile standard --no-queries  # ~15 min, 20,000 events
./benchmark run --profile heavy                  # ~2 h,   500,000 events
```

The stack must be up first (`cd local-compose && docker compose up -d`) and
all 17 containers healthy. The run refuses to start otherwise, naming the
container that is not ready.

| Profile | Events | Users | Producers | Drain timeout |
|---|---|---|---|---|
| `smoke` | 2,000 | 25 | 1 | 30 min |
| `standard` | 20,000 | 100 | 2 | 30 min |
| `heavy` | 500,000 | 100 | 4 | 90 min |

`--no-queries` skips the query benchmark and measures ingest only. Use it
when you care about throughput; it removes roughly a third of the wall clock.

### Overriding anything

Three layers, later beats earlier: `lib/config.py` defaults → the chosen
profile → `benchmark-config.yaml` → `--set` / flags → `OBSRV_BENCH_*` env.

```bash
./benchmark run --events 50000
./benchmark run --set load.duplicate_fraction=0.10
./benchmark run --set pipeline.drain_timeout_sec=7200
OBSRV_BENCH_LOAD_EVENTS=100000 ./benchmark run
```

One trap worth knowing: keys the profiles govern (`load.events`,
`users.count`, the `queries` block) are **commented out** in
`benchmark-config.yaml` on purpose. The file merges *on top of* the profile,
so uncommenting `load.events` pins it for every profile — which is how
`--profile smoke` once still ran 20,000 events.

---

## 2. What one run does

18 steps across 9 agents. In order:

1. **Preflight** — every container running and healthy, every endpoint
   reachable. Fails fast and names what is wrong.
2. **Dataset engineering** — drops and recreates `bench_users` (master) and
   `bench_telemetry` (event), takes both to `Live`, waits for the Druid
   supervisor, restarts the unified-pipeline so it loads the transformations.
3. **Telemetry generation** — a deterministic corpus (`users.seed`,
   `load.seed`), so two runs on the same profile are comparable.
4. **Validation** — 12 functional checks with recorded evidence, before any
   throughput is measured. A benchmark of a pipeline that is silently
   dropping events is worse than no benchmark.
5. **Kafka benchmark** — stops the TaskManager, builds the full backlog on
   `ingest`, restarts it, and times the drain.
6. **Unified pipeline / Druid / infrastructure** — Flink operator busy and
   backpressure, checkpoint durations, Druid indexing rate and segments,
   per-container CPU and memory, host CPU and memory.
7. **Reporting** — bottleneck attribution, a safe production rate, and
   `benchmark-results.json`, seven CSVs, a summary, a full report and an
   HTML page under `results/<run-id>/`.

**Why backlog-and-drain rather than a fixed rate.** Producing at a steady
rate and watching the pipeline keep up tells you it can handle that rate. It
does not tell you what it can handle. Stopping the consumer, building a
known backlog, then starting the consumer and timing the drain measures the
ceiling, because throughout the drain there is always more work available
than the pipeline can take. Every throughput number in the report comes from
that window.

---

## 3. Reading the result

```
results/bench-<timestamp>/
  benchmark-summary.md      one page: throughput, bottleneck, top fixes
  benchmark-report.md       full: every check, every measurement, evidence
  benchmark.html            the same, standalone and shareable
  benchmark-results.json    raw — everything the report is derived from
  csv/kafka.csv             lag and consumption over the drain
  csv/throughput.csv        events/sec and events/min series
  csv/flink.csv             per-operator busy%, backpressure%, records/sec
  csv/druid.csv             queryable rows, segments, indexing rate
  csv/infrastructure.csv    per-container CPU and memory samples
  csv/host.csv              host CPU, memory, load
```

Exit code is non-zero when a functional check failed, even though the run
completed and the numbers are valid (`run.keep_going: true`). Read the
check table before treating a non-zero exit as a crash.

**Bottleneck attribution, in the order the reporter tries it:** host CPU or
memory over its saturation threshold (`capacity.cpu_saturation_pct`, default
85%) → the busiest Flink operator that is *not* backpressured → Druid
indexing. An operator busy at 70% with 0% backpressure is setting the pace
itself; an operator that is backpressured is waiting on something downstream,
and the thing downstream is the real answer.

---

## 4. Individual tools

Each step is also a standalone script, useful when iterating:

```bash
./benchmark validate                 # the 12 functional checks, nothing else
./benchmark queries                  # query benchmark against existing data
./benchmark cleanup                  # drop the benchmark datasets
./benchmark report results/<run-id>  # regenerate artefacts from raw JSON

./benchmark watch kafka | pipeline | druid | infra    # live monitors
./benchmark pause | resume | restart                  # TaskManager control

./benchmark users      -n 100        # generate a user corpus
./benchmark telemetry  -n 20000      # generate an event corpus
./benchmark produce    --topic ingest --file ...
```

---

## 5. Things that will bite you

These are all real failures this harness has hit, each now handled — but
they explain the code and matter if you change it.

- **Dedup keys outlive the dataset.** The preprocessor keys duplicates on the
  dataset *name* with a 1-hour TTL, and the corpus is deterministically
  seeded. Drop and recreate the dataset inside that hour and every probe
  event is rejected as a duplicate — the run reports "0 of 100 probe events
  reached the datasource" with every component healthy. `_purge_dedup`
  clears them by prefix on every recreate.
- **Terminating a Kafka supervisor does not stop its indexing tasks**, and a
  running task serves its rows *itself* — they are in no segment yet, so no
  segment-level operation can reach them. This is the one that looks
  impossible when you hit it: `markUnused` answers
  `{"numChangedSegments": 0}` — truthfully, there are no used segments — while
  `SELECT COUNT(*)` on the same datasource answers 19,800. `drop_datasource`
  shuts the tasks down explicitly before touching segments.
- **Dropping a Druid datasource takes two committed steps.** Mark-unused must
  land before a kill removes anything; a kill only removes segments that are
  *already* unused. Mark-unused is metadata and safe to repeat while polling;
  a kill spawns an indexing task, so issue it once at the end. An earlier
  version fired one per poll and piled 110 kill tasks onto the single indexer,
  starving the work they were waiting on.
- **`ERR_PP_1010` on a dead-letter topic is not data loss.** It means the
  duplicate check refused a mid whose row is already in the datasource. The
  corpus generates deliberate duplicates (`load.duplicate_fraction`), and
  restarting the pipeline makes Flink replay uncheckpointed events, which
  arrive as more of the same. `ERR_EXT_1005` from the extractor is genuine
  loss. The checks classify by code rather than counting messages.
- **Dead-letter topics are never truncated.** Any check on them must baseline
  per partition before the run and read back only that range.
- **The unified-pipeline reads `transformations_config` once, at job start.**
  Adding transformations to a Live dataset does nothing until the job
  restarts. Step 2 does this deliberately.
- **A dataset is `foo`; its datasource is `foo_events`.** Querying the bare
  dataset id returns nothing, with no error — which reads exactly like the
  pipeline dropped everything.
- **Transformations need `category` set.** Without it the dataset is created
  successfully and can never reach `ReadyToPublish`.

## 6. Tests

```bash
python3 -m pytest tests/ -q          # or: python3 tests/test_<name>.py
```

Tests ending in a live-stack assertion need the stack up. The others are
pure and run anywhere.
