# Claude Prompt — Build an Autonomous Mini Obsrv Benchmarking Agent Framework

You are a Principal Staff Engineer with deep expertise in Distributed Systems, Apache Kafka, Apache Flink, Apache Druid, Data Engineering, Performance Engineering, Platform Engineering, and AI Agent Systems.

## Your First Task

Spawn multiple specialized execution agents to complete this work.

Suggested agents (or equivalent):

1. Dataset Engineering Agent
2. Telemetry Generation Agent
3. Kafka Benchmark Agent
4. Unified Pipeline Benchmark Agent
5. Druid Benchmark Agent
6. Infrastructure Metrics Agent
7. Validation Agent
8. Reporting Agent
9. Automation Framework Agent

Each agent should own its respective area and collaborate to produce one complete benchmarking framework.

---

# Goal

Build a **fully autonomous Benchmarking Agent Framework** for Mini Obsrv.

This should **NOT** be a one-time benchmark.

Instead, build something that another AI agent can execute any time to benchmark a Mini Obsrv deployment and automatically answer questions like:

* Can the deployment process 10K events/min?
* Can it process 100K events/min?
* What is the sustained throughput?
* What is the peak throughput?
* What is the bottleneck?
* How much CPU and memory are being consumed?
* What is Kafka throughput?
* What is Unified Pipeline throughput?
* What is Druid indexing throughput?
* What is end-to-end latency?
* What is Druid query latency?
* What is the approximate Query TPS/QPS?
* What infrastructure changes would double throughput?

The final framework should automatically produce these answers.

---

# Primary Requirement

Generate **ALL** code, scripts, utilities, configuration files, documentation, sample datasets, monitoring tools, benchmark orchestration, validation scripts, dashboards (if applicable), and reporting utilities required to execute the benchmark.

Assume nothing exists.

Build everything required.

The framework should be production quality.

---

# Functional Test Scenario

## Step 1

Create a User Master Dataset.

Create approximately 100 realistic user profiles.

Example fields

* actor.id
* name
* city
* state
* department
* organization
* subscription
* device
* age
* gender

This dataset will be used as a cache/master dataset.

---

## Step 2

Create a Telemetry Dataset.

Use telemetry similar to:

```json
{
  "eid":"SEARCH",
  "ets":1577826509166,
  "ver":"3.0",
  "mid":"LP.1577826509166.c5d13bb7-43c6-4174-9bbe-b06aed6758f2",
  "actor":{
      "id":"user-1",
      "type":"user"
  },
  "context":{
      "channel":"in.ekstep",
      "pdata":{
          "id":"dev.sunbird.learning.platform",
          "pid":"search-service",
          "ver":"1.0"
      },
      "env":"search"
  },
  "edata":{
      "size":112402,
      "query":"",
      "filters":{
          "dialCodes":"WGHSK"
      },
      "sort":{},
      "type":"all"
  }
}
```

---

Enable the following Dataset Features.

## Deduplication

Enable deduplication using

```
mid
```

Validation

Publish the same event twice.

Only one record should exist in Druid.

---

## Transformation

Apply JSONata transformations.

Create a field

```
pipeline
```

using

```jsonata
context.pdata.pid & "-" & context.env
```

Expected

```
search-service-search
```

Also create

```
isLargeEvent
```

using

```jsonata
edata.size > 100000
```

Expected

```
true
```

---

## Denormalization

Join using

```
actor.id
```

Append

* userName
* city
* department
* subscription
* organization

Publish the dataset.

---

# Functional Validation

Automatically validate

* Dataset published
* Kafka ingestion
* Unified Pipeline processing
* Deduplication
* JSONata transformation
* Denormalization
* Druid ingestion
* Druid query

Produce evidence.

---

# Performance Benchmark

## Stop or Scale Down Unified Pipeline

Pause the Unified Pipeline.

---

## Generate Backlog

Generate configurable event volumes.

Support

* 20,000
* 50,000
* 100,000
* 500,000
* 1 Million

Randomize

* actor.id
* timestamps
* filters
* event size
* query
* telemetry payload

Generate realistic production traffic.

---

## Resume Unified Pipeline

Start Unified Pipeline.

Measure backlog processing.

---

# Kafka Monitoring

Every minute collect

* Consumer Lag
* Records Consumed
* Records Remaining
* Lag Reduction
* Events/sec
* Events/min
* ETA

Automatically calculate throughput.

---

# Unified Pipeline Monitoring

Measure

* Throughput
* Processing latency
* CPU
* Memory
* JVM
* Backpressure
* Checkpoint duration
* Failures

---

# Druid Monitoring

Measure

* Rows/sec indexed
* Task duration
* Pending tasks
* Segments created
* CPU
* Memory
* Queue time
* End-to-end latency

---

# Query Benchmark

Execute benchmark queries.

Include

* Count
* Filter
* Latest Events
* Group By
* Time Series
* TopN
* Aggregation
* User lookup
* City lookup

Measure

* Average latency
* P50
* P95
* P99
* Max latency

Estimate

* Queries/sec
* Queries/min

---

# Infrastructure Metrics

Collect

* CPU
* Memory
* Disk
* Network
* Kafka
* Flink
* Unified Pipeline
* Druid
* JVM

Correlate throughput with infrastructure usage.

---

# Automation Framework

This entire benchmark must be executable by another AI agent.

Design the framework so an AI agent only needs to execute one command.

Example

```
benchmark run benchmark-config.yaml
```

The framework should automatically

1. Create datasets
2. Publish datasets
3. Validate configuration
4. Generate users
5. Generate telemetry
6. Stop Unified Pipeline
7. Load Kafka
8. Start Unified Pipeline
9. Monitor Kafka
10. Monitor Druid
11. Execute queries
12. Measure latency
13. Collect metrics
14. Analyze throughput
15. Detect bottlenecks
16. Generate reports
17. Produce recommendations
18. Optionally clean up

No manual intervention should be required.

---

# Configuration Driven

Everything should be configurable.

Use a single YAML configuration.

Example parameters

* Kafka bootstrap servers
* Topic
* Dataset name
* Druid datasource
* Number of users
* Number of events
* Producer rate
* Batch size
* Concurrent producers
* Query concurrency
* Poll interval
* Report interval
* Output directory
* Cleanup enabled

Changing the benchmark should only require modifying the YAML file.

---

# Scripts to Generate

Generate every script required.

Examples

* user-generator.py
* telemetry-generator.py
* kafka-producer.py
* create-dataset.py
* publish-dataset.py
* validate-dataset.py
* kafka-monitor.py
* unified-pipeline-monitor.py
* druid-monitor.py
* query-benchmark.py
* infrastructure-monitor.py
* benchmark-orchestrator.py
* report-generator.py
* cleanup.py

If a shell script or Makefile improves usability, generate those too.

---

# Outputs

Each benchmark execution should generate:

Human-readable reports:

* benchmark-report.md
* benchmark-summary.md
* benchmark.html (optional)

Machine-readable reports:

* benchmark-results.json
* throughput.csv
* kafka.csv
* druid.csv
* query.csv
* infrastructure.csv

These outputs should be easy for another AI agent to consume.

---

# Final Executive Summary

Automatically produce an executive summary answering:

* Did the benchmark complete successfully?
* Did deduplication work?
* Did transformation work?
* Did denormalization work?
* Were events successfully ingested?
* How many events were processed?
* Peak throughput?
* Sustained throughput?
* End-to-end latency?
* Druid indexing speed?
* Average query latency?
* P95 query latency?
* P99 query latency?
* Estimated Query TPS/QPS?
* CPU utilization?
* Memory utilization?
* Kafka bottleneck?
* Flink bottleneck?
* Druid bottleneck?
* Infrastructure bottleneck?
* Recommended safe production throughput?
* Recommendations to improve capacity by 2×, 5×, and 10×.

---

# Deliverable Expectations

Do **not** stop after creating a design or architecture.

Implement the complete framework.

Whenever possible, generate actual code instead of pseudocode.

Ensure all components are modular, reusable, idempotent, configurable, and production-ready.

The final result should be an autonomous **Mini Obsrv Benchmarking Agent Framework** that any engineer—or another AI agent—can execute repeatedly to benchmark a Mini Obsrv deployment, validate functionality, measure throughput, identify bottlenecks, and produce a comprehensive capacity report suitable for engineering leadership and customer demonstrations.
