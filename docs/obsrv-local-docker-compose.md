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
| Realtime store | `zookeeper`, `druid` — one container running all five Druid roles (profile `druid`) |
| Pipeline | `unified-pipeline-{jobmanager,taskmanager}` (profile `flink`) |
| Master data | `cache-indexer-{jobmanager,taskmanager}` (profile `masterdata`, off by default) |

Full detail, credentials, ports, and start/reset instructions:
`local-compose/README.md`.

## Key decisions and deviations from the charts

- **Druid runs as five roles inside one container** (`druid`), not five
  containers and not the chart's six processes. The roles are
  coordinator-overlord (`asOverlord=true`, dropping a separate overlord JVM),
  broker, historical, indexer (in place of MiddleManager, so tasks run as
  threads in one JVM rather than forking a 512 MB peon each), and router.
  Collapsing them removes four containers' worth of duplicated base overhead;
  measured steady-state cost is ~2.9 GB for the whole container.

  Two implementation details are forced by the image. `sanketikahub/druid` is
  distroless with no Python, so Druid's own multi-service launcher
  (`bin/start-druid`) cannot run; `config/druid/start-all.sh` backgrounds the
  plain-bash `bin/run-druid` once per role instead, and exits the container if
  any role dies so `docker compose ps` shows the failure rather than running
  silently degraded. Config is static, read-only, and checked in under
  `config/druid/local-single-conf/` — one directory per role plus `_common`,
  each with its own `jvm.config` and `runtime.properties`, which is the layout
  `run-druid` already expects. That deliberately avoids the image's
  `/druid.sh` entrypoint, whose job is to translate `druid_*` environment
  variables into properties files at boot: with one container per role that
  works, but a single container can only hold one value per variable name.

  The service also runs as `user: "0:0"`. Docker creates named volumes
  root-owned, and the image's default `druid` user (uid 1000) cannot create
  the segment-cache and task subdirectories inside them; running as root
  avoids a separate chown-init container.
- **No object store.** Obsrv's own Flink config
  (`job.enable.distributed.checkpointing = false`) already disables
  distributed checkpointing, and Druid is configured with
  `druid.storage.type=local`. Given that, MinIO would add a service without
  removing a real dependency — deep storage and checkpoints use local volumes
  instead (`druid-deepstorage`, which the historical and the indexer must both
  see, since local deep storage requires a shared directory for segment handoff
  to complete; running both roles in one container satisfies that implicitly).
- **Keycloak's `obsrv` realm is built by script (`kcadm`), not imported.**
  The chart imports a ~2600-line realm JSON from `helmcharts/obsrv/values.yaml`.
  `config/keycloak-init.sh` creates only what web-console needs — the realm,
  the `obsrv-console` public client, and a single `obsrv_admin` user —
  idempotently, against upstream `quay.io/keycloak/keycloak` in `start-dev`
  mode. One user rather than two: the realm sets `loginWithEmailAllowed=true`,
  so `obsrv_admin` and `admin@obsrv.in` are two ways to log into the same
  account. Creating a second user with the same email address is in fact
  rejected by Keycloak (`User exists with same email`), which fails the
  script and, under `restart: on-failure`, loops it indefinitely.
- **nginx replaces Kong.** Kong's install here is DB-less, driven entirely by
  Ingress objects with no path-stripping and `preserve-host: true`; those two
  behaviors are reproduced directly in `config/nginx.conf` rather than running
  Kong itself. `preserve-host` is implemented as
  `proxy_set_header Host $http_host` — deliberately not nginx's more common
  `$host`, which strips the port. Since `HTTP_PORT` is rarely 80, dropping it
  makes web-console's keycloak-connect middleware build a `redirect_uri`
  without the port, which Keycloak then rejects as an invalid redirect URI.
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
- **`command-api`'s `druid.router_host` needs an explicit `http://` scheme.**
  `druid_command.py` builds the ingestion-submit URL as
  `f"{router_host}:{router_port}/druid"` with no scheme prepended in code, so
  a bare hostname (`druid`) makes urllib3 fail with `No host specified.` —
  the scheme has to be baked into the config value itself.
  `config/service_config.yml` sets `router_host: http://druid`, matching the
  convention dataset-api already uses for its own `druid_host` env var.
- **web-console needs placeholder OIDC settings it never uses.** It registers
  a `passport-openidconnect` strategy unconditionally at startup, regardless
  of `AUTHENTICATION_TYPE`, and that constructor throws on an empty issuer
  (`OpenIDConnectStrategy requires an issuer option`), crash-looping the
  container. The `AUTH_OIDC_ISSUER` / `AUTH_OIDC_AUTHRIZATION_URL` /
  `AUTH_OIDC_TOKEN_URL` / `AUTH_OIDC_CLIENT_ID` values in
  `docker-compose.yaml` exist only to satisfy that constructor; the stack
  authenticates via `keycloak`, so they are never read. (The misspelled
  `AUTHRIZATION` matches the variable name the image actually looks up.)

## Status

Implemented in `local-compose/` and booted successfully: 15 containers running
with no restart loops, and all three one-shot jobs exiting 0 (`flyway` applying
`druid_raw` v1 / `obsrv` v5 / `keycloak` v1, `kafka-topics-init`,
`keycloak-init`).

Verified by direct request:

| Check | Result |
|---|---|
| Keycloak realm `:8080/auth/realms/obsrv` | 200 |
| dataset-api `:3000/health` | 200, `"status":"SUCCESS"` |
| command-api `:8000/docs` | 200 (`/` is 404 — no route there, not a fault) |
| Druid router `:8888/status`, coordinator `:8081/status` | 200 with basic auth (401 without — `druid-basic-security` is enforcing, which is correct) |
| `:8080/console` | 302 to the Keycloak login |
| Dataset create → publish → Kafka write → Druid SQL read-back | Full round trip confirmed for a test dataset |

All five Druid roles confirmed live inside the single container, not just the
two published ports: the coordinator holds leadership, the overlord API lists
one worker at capacity 2, the historical and indexer-executor are both
registered as cluster servers (historical with its 20 GB segment cache), and a
`SELECT 1` through router → broker returns 200. Role discovery and leader
election passing also confirms Zookeeper and the Postgres metadata store are
wired correctly.

**Verified end-to-end** (via direct API calls, mirroring what the console
does): create a dataset (`POST /v2/datasets/create`) → set
`dataset_config.indexing_config.lakehouse_enabled: false` (`PATCH
/v2/datasets/update`, required since this stack has no lakehouse) →
`POST /v2/datasets/status-transition` with `status: "ReadyToPublish"` → the
same endpoint again with `status: "Live"` → a Druid supervisor comes up
(`GET :8888/druid/indexer/v1/supervisor`) → an event produced onto the
dataset's Kafka topic is queryable through Druid SQL within seconds.

Publish **must** go through dataset-api's `/v2/datasets/status-transition`
(`status: "Live"`), not command-api's `/system/v1/dataset/command` directly.
The status-transition endpoint is what generates the Druid ingestion spec and
writes the `datasources`/`datasources_draft` row *before* invoking
command-api's `PUBLISH_DATASET`; calling command-api directly skips that, and
`command-api`'s `SUBMIT_INGESTION_TASKS` step (`druid_command.py`) treats an
empty ingestion-spec query result as success (`if datasources_records is not
None` — an empty list isn't `None`), so it silently no-ops and deletes the
draft rows anyway. The dataset is left `Live` in Postgres with no Druid
supervisor, and the status-transition state machine has no path back from
`Live` to `Draft` — the only recovery is a manual `DELETE FROM datasets WHERE
dataset_id = ...`. This is vendor image code (`obsrv-command-service`), not
something fixable here.

Measured memory on a 11.67 GiB Docker Desktop VM, after running the ingest →
query path (so these include real ingestion, not just idle):

| Selection | Measured RSS | What it gives you |
|---|---|---|
| Control plane only (no profiles) | ~2.2 GB | console, auth, APIs, Kafka, Postgres |
| `+ druid` | ~5.3 GB | the above plus a queryable realtime store |
| `+ druid,flink` (default) | ~6.7 GB | the full event-dataset path, end to end |
| `+ masterdata` | ~7.9 GB | adds master datasets / denormalization |

The default selection fits inside an 8 GB Docker VM. Getting there took four
changes beyond collapsing Druid into one container, all traceable to values the
charts size for production clusters:

- **Flink managed memory set to 0** (`taskmanager.memory.managed.size`, was the
  0.4 default = 410 MB reserved per taskmanager). Managed memory is only
  consumed by the RocksDB state backend, batch operators and Python UDFs. No
  `state.backend` is configured, so these jobs use the heap state backend, and
  Obsrv keeps dedup/denorm state in Valkey — the reservation was never used.
  `taskmanager.memory.flink.size` drops 1024m → 614m to give it back, leaving
  heap and network sizing untouched.
- **JobManagers sized separately from TaskManagers.** The chart gives both
  1024m, which works out to an 896 MB JobManager heap. In application mode a
  JobManager only coordinates — no records pass through it — so 384m of Flink
  memory (256m heap) is ample. `jobmanager.*` and `taskmanager.*` are distinct
  keys, so one shared `flink-conf.yaml` still covers both. Total process memory
  per JobManager: 1.438 GB → 832 MB.
- **`cache-indexer` moved to its own `masterdata` profile.** Its config is
  `dataset.type = "master-dataset"` on the `masterdata.*` topics; plain event
  datasets go entirely through `unified-pipeline`. Verified the full
  create → publish → ingest → query path with it stopped.
- **Kafka heap pinned to `-Xms256m -Xmx512m`.** It was the only JVM left on its
  image default (`-Xms1G -Xmx1G`), and since `Xms == Xmx` the JVM committed the
  full gigabyte at startup.

Together these took the 15-container footprint from ~10.5 GB to ~8.0 GB, and
the default 13-container selection to ~6.7 GB. Treat them as a floor: the Flink
taskmanager and Druid indexer grow under sustained load, and the Docker daemon
itself crashed outright during an earlier boot attempt of this stack, so leaving
real headroom is prudent.

See `local-compose/README.md` for start/reset commands and full credentials.
