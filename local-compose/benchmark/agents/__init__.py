"""Specialized execution agents.

Each module owns one concern and exposes plain functions taking the run
context, so any of them can be driven from a script without the orchestrator:

    dataset_engineering        create, publish and verify the dataset configs
    telemetry_generation       user profiles and the telemetry corpus
    validation                 the functional checks, with evidence
    kafka_benchmark            backlog generation and drain measurement
    unified_pipeline_benchmark Flink throughput, latency, JVM, backpressure
    druid_benchmark            indexing rate, tasks, segments, e2e latency
    infrastructure_metrics     host and per-container resource cost
    query_benchmark            query-latency distribution and sustainable QPS
    reporting                  bottleneck attribution, capacity, artefacts
"""
