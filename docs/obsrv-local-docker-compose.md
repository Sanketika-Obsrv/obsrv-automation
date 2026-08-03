# Obsrv Local Docker Compose — Design

## Goal

Run enough of Obsrv on a single machine, via Docker Compose, that a user can:
log in → open the web console → configure a dataset → write data to it → see
it land in the realtime store.

Scope is deliberately streaming-only: no batch/lakehouse layer (Spark, Livy,
Hive Metastore, Trino), no observability stack (Grafana, Superset, Prometheus,
Alertmanager). The implementation lives in `local-compose/`; this doc records
the decisions behind it and why it differs from a straight reading of
`helmcharts/`.

## Why this scope

Obsrv's real deployment target is Kubernetes via Helm (`helmcharts/`), with
~40 services covering ingestion, batch/lakehouse processing, and monitoring.
Reproducing that whole surface in Compose isn't useful for local dev — most of
it isn't needed to exercise the core loop above, and several pieces
(Kubernetes-API-driven Helm installs, multi-node Druid/Flink topologies sized
for production) don't translate to a laptop at all. `local-compose/` scopes
down to the subset that supports the acceptance path, pulls pre-built images
rather than building from source, and documents every point where a value or
topology had to change to run outside Kubernetes.

## What runs

| Group | Services |
|---|---|
| Stores | `postgres`, `kafka` (KRaft, single broker), `valkey-dedup`, `valkey-denorm` |
| Schema/bootstrap | `flyway` (one-shot), `kafka-topics-init` (one-shot) |
| Auth | `keycloak`, `keycloak-init` (one-shot) |
| APIs | `dataset-api`, `command-api` |
| UI/ingress | `web-console`, `nginx` (Kong stand-in) |
| Realtime store | `zookeeper`, `druid-coordinator`, `druid-broker`, `druid-historical`, `druid-indexer`, `druid-router` (profile `druid`) |
| Pipeline | `unified-pipeline-{jobmanager,taskmanager}`, `cache-indexer-{jobmanager,taskmanager}` (profile `flink`) |

Full detail, credentials, ports, and start/reset instructions:
`local-compose/README.md`.

## Key decisions and deviations from the charts

These were evaluated against a "single-container Druid + MinIO wired in via
the `aws`-provider pattern" alternative during design, and rejected in favor
of what's actually implemented:

- **Druid runs as five processes** (coordinator running with
  `asOverlord=true` in place of a separate overlord, indexer in place of
  MiddleManager, plus broker/historical/router), each with cut-down heaps and
  worker capacity, rather than one `apache/druid` micro-quickstart container.
  This costs more memory (~3.5 GB extra) but keeps each service's role
  separable and closer to the chart's topology, which made the per-service
  memory/threading tuning in the README possible.
- **No object store.** Obsrv's own Flink config
  (`job.enable.distributed.checkpointing = false`) already disables
  distributed checkpointing, and Druid is configured with
  `druid.storage.type=local`. Given that, MinIO would add a service without
  removing a real dependency — deep storage and checkpoints use local volumes
  instead (`druid-deepstorage`, shared between historical and indexer since
  local deep storage requires both to see the same directory for segment
  handoff to complete).
- **Keycloak's `obsrv` realm is built by script (`kcadm`), not imported.**
  The chart imports a ~2600-line realm JSON from `helmcharts/obsrv/values.yaml`.
  `config/keycloak-init.sh` creates only what web-console needs — the realm,
  the `obsrv-console` public client, and the two seed users — idempotently,
  against upstream `quay.io/keycloak/keycloak` in `start-dev` mode.
- **nginx replaces Kong.** Kong's install here is DB-less, driven entirely by
  Ingress objects with no path-stripping and `preserve-host: true`; those two
  behaviors are reproduced directly in `config/nginx.conf` rather than running
  Kong itself.
- **Flyway migrations are rendered, not copied.** The real migration SQL under
  `helmcharts/services/postgresql-migration/configs/migrations/` is `tpl`-
  templated by Helm before it reaches Postgres. `scripts/migrate.sh`
  substitutes the same `global-values.yaml` values and hard-fails if any
  `{{ }}` survives, instead of maintaining a parallel copy of the SQL.

## Known limitations (accepted, not worked around)

- **`command-api` cannot deploy Flink jobs or connectors.** In Kubernetes,
  `PUBLISH_DATASET`'s `START_PIPELINE_JOBS` and `DEPLOY_CONNECTORS` steps
  issue live `helm install/upgrade` calls against the Kubernetes API —
  fundamentally incompatible with plain Compose. `config/service_config.yml`
  drops both steps from the workflow; the Flink jobs here are started by
  Compose directly and stay up continuously instead of being deployed
  per-dataset. Publishing a dataset still writes the schema and creates the
  Druid supervisor, which is what the acceptance path needs.
- **`config-api` is absent.** It's `config-service-ext`, an enterprise image
  not available in this repo. Anything routed through it fails fast
  (`CONFIG_API_EXT_URL` points at `dataset-api` rather than an unresolvable
  host).
- **No Grafana/Superset/Prometheus/Alertmanager.** Console panels and
  dataset-api endpoints backed by them return errors or stay blank — out of
  scope per the streaming-only, UI-focused goal.
- **No lakehouse.** `storage_types` is
  `{"lake_house":false,"realtime_store":true}` throughout, unlike the chart's
  default.
- **Cloud storage paths are unexercised.** Connector-registry upload,
  data-exhaust download, and telemetry archival all assume an object store
  that doesn't exist in this stack; the config keeps the shape the services
  expect but points at nothing real.

## Status

Implemented in `local-compose/`, not yet verified end-to-end against the
acceptance path in this environment (Docker Desktop was not running during
this pass). See `local-compose/README.md` for start/reset commands and full
credentials.
