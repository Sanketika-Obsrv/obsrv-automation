# Obsrv on Docker Compose

A local, single-machine Obsrv stack derived from `helmcharts/`. Every value here
traces back to a chart; where something had to change to work outside
Kubernetes, the reason is in a comment next to it.

## What runs

| Group | Services | Profile |
|---|---|---|
| Stores | `postgres`, `kafka` (KRaft), `valkey-dedup`, `valkey-denorm` | always |
| Schema | `flyway` (one-shot), `kafka-topics-init` (one-shot) | always |
| Auth | `keycloak`, `keycloak-init` (one-shot) | always |
| APIs | `dataset-api`, `command-api` | always |
| UI | `web-console`, `nginx` (Kong stand-in) | always |
| Realtime store | `zookeeper`, `druid-coordinator`, `druid-broker`, `druid-historical`, `druid-indexer`, `druid-router` | `druid` |
| Pipeline | `unified-pipeline-{jobmanager,taskmanager}`, `cache-indexer-{jobmanager,taskmanager}` | `flink` |

## Memory

This is the binding constraint, not CPU.

| Selection | Rough RSS |
|---|---|
| Control plane only (no profiles) | ~3.5 GB |
| `+ druid` | ~7 GB |
| `+ druid,flink` | ~11 GB |

`.env` enables both profiles by default. **Raise Docker Desktop to 12 GB** for
the full stack, or trim `COMPOSE_PROFILES` in `.env`. Check what you have with
`docker info --format '{{.MemTotal}}'`.

## Start

```bash
cd local-compose
./scripts/gen-token-env.sh          # once: PEM keypair -> secrets/tokens.env
docker compose up -d
docker compose logs -f flyway keycloak-init kafka-topics-init
```

Then open **http://localhost:8080/console** and log in as
`obsrv_admin` / `enDoPvTAxFSd`.

Change `HTTP_PORT` in `.env` if 8080 is taken — it is one variable because it
feeds the Keycloak redirect URI and the console's own base URL as well as the
nginx binding.

### Other endpoints

| | |
|---|---|
| Console | http://localhost:8080/console |
| Keycloak | http://localhost:8080/auth (master admin `admin` / `admin123`) |
| dataset-api | http://localhost:3000 |
| command-api | http://localhost:8000 |
| Druid console | http://localhost:8888 (`admin` / `admin123`) |
| Flink UI — unified-pipeline | http://localhost:8181 |
| Flink UI — cache-indexer | http://localhost:8182 |
| Kafka from the host | `localhost:29092` |
| Postgres | `localhost:5432`, `postgres` / `postgres` |

## Reset

```bash
docker compose down -v      # -v also drops the schema, so flyway reruns
```

## How this maps to the charts

### Schema comes from the repo, not from this directory

`config/postgres-init/00-databases.sql` creates the three databases, mirroring
`global-values.yaml` → `postgresql.primary.initdb.scripts`. Everything else —
roles, tables, `system_settings`, the `oauth_users` admin row — comes from the
real migrations at
`helmcharts/services/postgresql-migration/configs/migrations/`, mounted
read-only.

Those `.sql` files are **not plain SQL**. The chart renders them through helm's
`tpl` before writing them into a ConfigMap, and they contain 19 distinct
`{{ .Values.* }}` expressions. `scripts/migrate.sh` substitutes those with the
values `global-values.yaml` supplies, then runs the same per-folder migrate loop
(and the same `repair`-and-retry fallback) as the chart's `configs/migrate.sh`.
It hard-fails if any `{{` survives rather than handing a template to Postgres.

Check the render without a database:

```bash
docker compose run --rm -e RENDER_ONLY=1 flyway
```

Folders `01-superset` and `04-hms` are skipped — Superset and the Hive metastore
are out of scope.

### Substitutions worth knowing about

- `kong_ingress_domain` → `localhost:$HTTP_PORT`
- `global.ssl_enabled` → false, so the `http{{ if … }}s{{ end }}` pairs collapse to `http`
- Superset and Grafana `oauth_clients` rows get **placeholder** client IDs, not the
  chart's real dev credentials. They cannot be empty: `client_id` is `UNIQUE` and
  two rows are inserted, so blanks collide. Neither component runs here.

### Deliberate departures

**No object store.** `obsrv-core/framework/.../baseconfig.conf` ships
`job.enable.distributed.checkpointing = false`, so Flink checkpoints to the local
filesystem, and Druid uses `druid.storage.type=local`. That removes MinIO
entirely. The `druid-deepstorage` volume is mounted into **both** historical and
indexer — with local deep storage, segment handoff silently never completes if
they don't share it.

**Druid is 5 processes, not 6.** The coordinator runs with
`druid.coordinator.asOverlord=true`, which drops a JVM while keeping the overlord
API reachable. And it uses the **Indexer** rather than the MiddleManager: the
Indexer runs tasks as threads in one JVM instead of forking a 512 MB peon per
task. Heaps are 512m/1g against the chart's `-Xms7g -Xmx9g`, and worker capacity
is 2 against the chart's 30.

**nginx replaces Kong.** The Kong install is DB-less and driven entirely by the
Ingress objects in `kong-ingress-routes`, so there is no Kong config to port. Two
behaviours from those Ingresses are preserved in `config/nginx.conf`: no path
stripping (there is no `konghq.com/strip-path` anywhere in the repo) and
`preserve-host: true`. Routes for `/grafana` and Superset's `/` catch-all are
dropped.

**Keycloak is built by script, not imported.** The chart imports a ~2600-line
realm JSON from `helmcharts/obsrv/values.yaml`. `config/keycloak-init.sh` uses
`kcadm` to create just what web-console needs: realm `obsrv`, public client
`obsrv-console` with callback `/console?auth_callback=1`, and the two users. It
is idempotent. Upstream `quay.io/keycloak/keycloak` in `start-dev` replaces the
bitnami sub-chart.

**Secrets.** `secrets/{private,public}.pem` replace the `openssl-secrets` Secret
the bootstrapper creates. `scripts/gen-token-env.sh` writes them into
`secrets/tokens.env` double-quoted with `\n` escapes, which Compose's `env_file`
parser expands back into real newlines. Verify with
`docker compose config | grep -A3 user_token_public_key`.

**Kafka has two advertised listeners.** `kafka:9092` for in-network clients and
`localhost:29092` for tools run from your shell. One listener cannot serve both.
`config/create-topics.sh` creates all 23 topics explicitly (partitions 4,
replication 1, matching the chart) rather than relying on auto-create — the
`kafka40` chart only provisions 8.

**Flink runs in application mode**, via `standalone-job.sh` with
`--job-classname`, matching `services/flink/templates/deployment.yaml`. Not a
session cluster. One change: `taskmanager.numberOfTaskSlots` is 2, not the
chart's 1 — `unified-pipeline.conf` asks for `consumer.parallelism = 2`, and
`scheduler-mode: reactive` caps parallelism at available slots, so with 1 slot
the job can never reach the parallelism its own config requests.

**Platform.** Five images are published amd64-only and are pinned to
`linux/amd64` to run under emulation: `obsrv-api-service`,
`obsrv-command-service`, `obsrv-web-console`, `unified-pipeline`,
`cache-indexer`. Everything else is arm64-native. `sanketikahub/druid:32.0.1` is
genuinely multi-arch, so Druid runs natively. The repo's `Dockerfiles/druid` and
`Dockerfiles/flink` were checked and add only cloud filesystem plugins and a
`chmod` — nothing needed locally.

**Postgres auth.** The chart forces `password_encryption = md5`; this stack keeps
Postgres 17's `scram-sha-256` default, since every client here speaks it.

**dataset-api connects as the `postgres` superuser**, not as `obsrv`. That looks
wrong but it is what the chart does — `dataset-api/values.yaml` has
`postgres_username: {{ .Values.postgresqlUser | default .Values.global.postgresql.username }}`
and nothing overrides `postgresqlUser`. Kept identical to avoid a
permissions difference between local and deployed.

## What does not work here

Be aware of these before debugging:

- **`config-api`** is missing. It is `config-service-ext`, an enterprise image
  absent from `kitchen/install.sh`. `CONFIG_API_EXT_URL` points at `dataset-api`
  so calls fail fast instead of hanging on an unresolvable host.
- **Grafana, Superset, Prometheus, Alertmanager** are out of scope. Console
  panels and dataset-api endpoints that read them will error or stay blank.
  `GF_BEARER_TOKEN` is empty.
- **Anything that touches cloud storage** — connector-registry upload,
  data-exhaust download, telemetry archival. The `cloud_storage_*` variables keep
  the config shape the service expects but point at nothing real.
- **`command-api` cannot deploy Flink jobs or connectors.** In Kubernetes it
  scales Deployments through the API server. `config/service_config.yml` drops
  `START_PIPELINE_JOBS` and `DEPLOY_CONNECTORS` from the `PUBLISH_DATASET`
  workflow. The Flink jobs here are started by Compose and stay up; publishing a
  dataset still writes the schema and creates the Druid supervisor.
- **Lakehouse (Trino/Hudi)** — `storage_types` is
  `{"lake_house":false,"realtime_store":true}` in both dataset-api and
  web-console, unlike the chart's default.

## Credentials

All from `helmcharts/global-values.yaml`. Local-only defaults — do not reuse.

| What | Value |
|---|---|
| Postgres superuser | `postgres` / `postgres` |
| Postgres `obsrv` | `obsrv` / `obsrv123` |
| Postgres `druid_raw` | `druid_raw` / `druidraw123` |
| Postgres `keycloak` | `keycloak` / `keycloak123` |
| Druid basic auth | `admin` / `admin123` (internal client `druid_system` / `internal123`) |
| Keycloak master | `admin` / `admin123` |
| Console / realm user | `obsrv_admin` / `enDoPvTAxFSd` (email `admin@obsrv.in`) |
| Encryption key | `strong_encryption_key_to_encrypt` |

## Notes

`AUTHENTICATION_TYPE` is `keycloak`, matching the chart — it is the only path
exercised in this repo. `web-console/values.yaml` also lists
`AUTHENTICATION_ALLOWED_TYPES: "obsrv,ad"`, and the `obsrv` mode authenticates
against the `oauth_users` row that migration `03-obsrv/V1` creates with `crypt()`
— the same `obsrv_admin` / `enDoPvTAxFSd`. If that works for you, setting
`AUTHENTICATION_TYPE=obsrv` lets you drop `keycloak` and `keycloak-init` and
save ~600 MB. Untested.
