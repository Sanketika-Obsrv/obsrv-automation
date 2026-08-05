# Obsrv Benchmark Summary

`bench-20260805-154931` | profile `standard` | 2026-08-05 15:49:31

| | |
|---|---|
| Events processed | 20,000 |
| Sustained throughput | **59 events/sec** (3.55K events/min) |
| Peak throughput | 72 events/sec |
| Backlog drain | 7m51s | 
| Query p95 | - ms |
| Queries/sec | - at concurrency None |
| Functional checks | **11/12 passed |
| Bottleneck | unified-pipeline operator: ExtractionFunction -> (extractor-batch-failed-events-sink: Writer -> extractor-b |
| Recommended safe rate | **2.49K events/min** |

## Bottleneck

**unified-pipeline operator: ExtractionFunction -> (extractor-batch-failed-events-sink: Writer -> extractor-b** -- this operator was busy 87% of the time while only 0% backpressured -- it is doing the work that sets the pace, not waiting on a downstream stage

## Top recommendations

1. **Add TaskManager slots before anything else** (high) -- The constraint is inside the stream job (unified-pipeline operator: ExtractionFunction -> (extractor-batch-failed-events-sink: Writer -> extractor-b). This deployment runs 2 slot(s); the reactive scheduler rescales automatically when another TaskManager registers, so this is a compose scale operation rather than a job redeploy.
2. **Checkpoints are slow enough to interrupt processing** (medium) -- p95 checkpoint duration was 16.3 s. Increase the interval or move the checkpoint store off the container filesystem.
3. **Segments are smaller than Druid's target** (low) -- 1 segment(s) averaging 19,801 rows. Druid targets ~5M rows per segment; small segments multiply query fan-out and metadata overhead. Increase segmentGranularity or run compaction.
4. **Throughput is not CPU-limited** (low) -- Correlation between host CPU and throughput was r=-0.55. Adding cores is unlikely to help; the constraint is concurrency or an external wait.
5. **Re-run at a higher volume to confirm the ceiling** (low) -- This run drained 20,000 events. The measured rate is a lower bound; OBSRV_BENCH_LOAD_EVENTS=100000 re-runs the identical benchmark at 5x.

Full report: `benchmark-report.md` | Raw data: `benchmark-results.json`
