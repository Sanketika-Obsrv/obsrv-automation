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
| Realtime store | `zookeeper`, `druid` (all five roles in one container) | `druid` |
| Pipeline | `unified-pipeline-{jobmanager,taskmanager}` | `flink` |
| Master data | `cache-indexer-{jobmanager,taskmanager}` | `masterdata` |

## Memory

This is the binding constraint, not CPU.

Measured after running the ingest → query path, so these include real
ingestion rather than idle:

| Selection | Measured RSS | What it gives you |
|---|---|---|
| Control plane only (no profiles) | ~2.2 GB | console, auth, APIs, Kafka, Postgres |
| `+ druid` | ~5.3 GB | the above plus a queryable realtime store |
| `+ druid,flink` (default) | ~6.7 GB | the full event-dataset path, end to end |
| `+ masterdata` | ~7.9 GB | adds master datasets / denormalization |

`.env` enables `druid,flink` by default — the smallest selection that runs a
dataset end to end. **Give Docker Desktop 10 GB**, or trim `COMPOSE_PROFILES`
in `.env` to go smaller. Check what you have with
`docker info --format '{{.MemTotal}}'`.

10 GB against a measured 6.7 GB is deliberate headroom, not slack: the Flink
taskmanager and the Druid indexer grow once data flows. Running this stack on a
VM sized close to its measured floor has crashed the Docker daemon outright,
taking every container down at once.

`cache-indexer` is behind its own profile because it only handles master
datasets — its config is `dataset.type = "master-dataset"` reading the
`masterdata.*` topics. Plain event datasets go entirely through
`unified-pipeline`, so most first-time users never need it. Add it with
`COMPOSE_PROFILES=druid,flink,masterdata`.

The Flink memory numbers are deliberately below the chart's: managed memory is
set to 0 (it is only used by the RocksDB state backend, which is not
configured — Obsrv keeps dedup/denorm state in Valkey), and jobmanagers get
384m of Flink memory instead of the chart's 1024m since in application mode
they only coordinate. See `docs/obsrv-local-docker-compose.md` for the full
reasoning.

## Start

```bash
cd local-compose
cp .env.example .env                # once: ports + which profiles come up
./scripts/gen-token-env.sh          # once: PEM keypair -> secrets/tokens.env
docker compose up -d
docker compose logs -f flyway keycloak-init kafka-topics-init
```

Don't skip the `.env` copy. `.env` is gitignored so local port changes stay
local, and every variable in it except `COMPOSE_PROFILES` has a default baked
into `docker-compose.yaml`. `COMPOSE_PROFILES` is read by the Compose CLI
itself rather than by the compose file, so without `.env` it is simply unset —
`docker compose up -d` then brings up the control plane alone, with no Druid
and no Flink, and publishing a dataset fails in confusing ways.

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
entirely. The `druid-deepstorage` volume must be visible to **both** the
historical and the indexer — with local deep storage, segment handoff silently
never completes if they don't share it. Running both roles in one container
makes that automatic; it was an explicit two-container mount before, and is a
constraint to remember if the roles are ever split apart again.

**Druid is 5 roles in 1 container, not 6 processes in 6.** The coordinator runs
with `druid.coordinator.asOverlord=true`, which drops a JVM while keeping the
overlord API reachable. And it uses the **Indexer** rather than the
MiddleManager: the Indexer runs tasks as threads in one JVM instead of forking a
512 MB peon per task. Heaps are 512m/1g against the chart's `-Xms7g -Xmx9g`, and
worker capacity is 2 against the chart's 30.

All five then share one container, which is where most of the memory saving over
the chart comes from. Three consequences worth knowing before you debug it:

- **`config/druid/start-all.sh` launches the roles, not the image entrypoint.**
  The image is distroless with no Python, so Druid's own `bin/start-druid`
  launcher cannot run; the script backgrounds the plain-bash `bin/run-druid`
  once per role. If any role dies the script kills the rest and exits, so a
  partial failure shows up in `docker compose ps` instead of running silently
  degraded.
- **Config is static files, not environment variables.**
  `config/druid/local-single-conf/` holds one directory per role plus
  `_common`, each with its own `jvm.config` and `runtime.properties` — the
  layout `run-druid` already expects. This bypasses the image's `/druid.sh`,
  which exists to translate `druid_*` env vars into properties files at boot:
  that works with one container per role, but a single container can only hold
  one value per variable name. So to change a heap or a port, edit the file
  under `local-single-conf/`; setting `druid_*` in Compose will do nothing.
- **It runs as `user: "0:0"`.** Docker creates named volumes root-owned, and
  the image's default `druid` user (uid 1000) cannot create the segment-cache
  and task subdirectories inside them. Root avoids a separate chown-init step.

Druid enforces basic auth, so `curl http://localhost:8888/status` returns 401 —
that is the listener working, not a fault. Use `-u admin:admin123`.

**nginx replaces Kong.** The Kong install is DB-less and driven entirely by the
Ingress objects in `kong-ingress-routes`, so there is no Kong config to port. Two
behaviours from those Ingresses are preserved in `config/nginx.conf`: no path
stripping (there is no `konghq.com/strip-path` anywhere in the repo) and
`preserve-host: true`. Routes for `/grafana` and Superset's `/` catch-all are
dropped.

`preserve-host` is `proxy_set_header Host $http_host`, and the choice of
variable matters: nginx's more common `$host` strips the port. Because
`HTTP_PORT` is rarely 80, `$host` makes web-console's keycloak-connect
middleware build a `redirect_uri` with no port, which Keycloak then rejects with
`Invalid redirect_uri` at login. `$http_host` passes the client's Host header
through verbatim, port included.

**Keycloak is built by script, not imported.** The chart imports a ~2600-line
realm JSON from `helmcharts/obsrv/values.yaml`. `config/keycloak-init.sh` uses
`kcadm` to create just what web-console needs: realm `obsrv`, public client
`obsrv-console` with callback `/console?auth_callback=1`, and one user. It
is idempotent. Upstream `quay.io/keycloak/keycloak` in `start-dev` replaces the
bitnami sub-chart.

One user, not two. The realm sets `loginWithEmailAllowed=true`, so `obsrv_admin`
and `admin@obsrv.in` are two ways into the same account. Adding a second user
carrying that same email is actively rejected by Keycloak
(`User exists with same email`), which fails the script — and because it runs
under `restart: on-failure`, that turns into an endless restart loop rather than
a visible error.

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
- **The `AUTH_OIDC_*` variables on web-console are placeholders and are never
  read.** The console registers a `passport-openidconnect` strategy at startup
  no matter what `AUTHENTICATION_TYPE` is, and that constructor throws on an
  empty issuer (`OpenIDConnectStrategy requires an issuer option`), crash-looping
  the container. `AUTH_OIDC_ISSUER`, `AUTH_OIDC_AUTHRIZATION_URL`,
  `AUTH_OIDC_TOKEN_URL` and `AUTH_OIDC_CLIENT_ID` are set only to get past it;
  auth actually goes through `keycloak`. `AUTHRIZATION` is misspelled because
  that is the name the image looks up — do not "fix" it.
- **Publishing a dataset must go through dataset-api's
  `/v2/datasets/status-transition` (`status: "Live"`), never command-api's
  `/system/v1/dataset/command` directly.** The status-transition endpoint is
  what generates the Druid ingestion spec and writes the
  `datasources`/`datasources_draft` row before invoking command-api's
  `PUBLISH_DATASET`. Skipping it leaves no ingestion spec for command-api to
  submit; its `SUBMIT_INGESTION_TASKS` step (`druid_command.py`) treats an
  empty query result as success instead of `None`, so it silently no-ops and
  deletes the draft rows anyway, leaving the dataset stuck `Live` with no
  supervisor and no transition back to `Draft`. Vendor image bug, not fixable
  here — the only recovery is `DELETE FROM datasets WHERE dataset_id = ...`.
- **`command-api`'s `druid.router_host` needs an explicit `http://` scheme.**
  `druid_command.py` concatenates `router_host:router_port` with no scheme
  added in code, so a bare hostname makes the ingestion-submit request fail
  with `No host specified.`. `config/service_config.yml` sets
  `router_host: http://druid`, same convention dataset-api uses for its own
  `druid_host`.

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
