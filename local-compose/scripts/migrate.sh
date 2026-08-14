#!/bin/bash
# Runs the repo's real Flyway migrations against the local Postgres.
#
# Why this wrapper exists: the .sql files under
#   helmcharts/services/postgresql-migration/configs/migrations/
# are not plain SQL -- they are rendered through helm's tpl before being placed
# in a ConfigMap (see that chart's templates/configmap.yaml). They contain 19
# distinct {{ .Values.* }} expressions. Flyway cannot read them as-is, so this
# script renders them with the same values global-values.yaml supplies, then
# runs the migration loop from configs/migrate.sh (including its
# repair-and-retry fallback).
#
# Sources are mounted read-only at /migrations-src and rendered to /migrations.
set -euo pipefail

SRC="${SRC:-/migrations-src}"
DST="${DST:-/migrations}"
PGHOST="${PGHOST:-postgres}"
PGPORT="${PGPORT:-5432}"

# Folders to run, in order. 01-superset and 04-hms are skipped: Superset and the
# Hive metastore are out of scope for this stack.
MIGRATION_FOLDERS="${MIGRATION_FOLDERS:-02-druid-raw 03-obsrv 05-keycloak}"

# --- values ------------------------------------------------------------------
# From helmcharts/global-values.yaml unless noted.
obsrv_password="${POSTGRES_OBSRV_PASSWORD:-obsrv123}"
druid_raw_password="${POSTGRES_DRUID_RAW_PASSWORD:-druidraw123}"
keycloak_password="${POSTGRES_KEYCLOAK_PASSWORD:-keycloak123}"
superset_password="${POSTGRES_SUPERSET_PASSWORD:-superset123}"
hms_password="${POSTGRES_HMS_PASSWORD:-hms123}"

# Browser-facing host. In the chart this is the Kong ingress domain; here it is
# whatever nginx is reachable on.
ingress_domain="${INGRESS_DOMAIN:-localhost}"

# web-console admin (global-values.yaml: web_console_user / _password / _login).
web_console_user="${WEB_CONSOLE_USER:-obsrv_admin}"
web_console_password="${WEB_CONSOLE_PASSWORD:-enDoPvTAxFSd}"
web_console_login="${WEB_CONSOLE_LOGIN:-admin@obsrv.in}"

# oauth_clients rows for Superset and Grafana. Both components are out of scope,
# but client_id is UNIQUE and two rows are inserted, so these must be distinct
# and non-empty or V1 fails. Placeholders, deliberately not the chart's real
# dev credentials.
superset_oauth_clientid="${SUPERSET_OAUTH_CLIENT_ID:-local-superset-client}"
superset_oauth_client_secret="${SUPERSET_OAUTH_CLIENT_SECRET:-local-superset-secret}"
grafana_oauth_clientid="${GRAFANA_OAUTH_CLIENT_ID:-local-grafana-client}"
grafana_oauth_client_secret="${GRAFANA_OAUTH_CLIENT_SECRET:-local-grafana-secret}"

# system_settings (postgresql-migration/values.yaml defaults).
ss_encryption_key="${SYSTEM_ENCRYPTION_KEY:-strong_encryption_key_to_encrypt}"
ss_default_dataset_id="${SYSTEM_DEFAULT_DATASET_ID:-ALL}"
ss_max_event_size="${SYSTEM_MAX_EVENT_SIZE:-1048576}"
ss_dedup_period="${SYSTEM_DEDUP_PERIOD:-604800}"

# --- render ------------------------------------------------------------------
echo "Rendering migrations ${SRC} -> ${DST}"
rm -rf "${DST}"
mkdir -p "${DST}"

for folder in ${MIGRATION_FOLDERS}; do
  [ -d "${SRC}/${folder}" ] || { echo "no such folder: ${SRC}/${folder}" >&2; exit 1; }
  mkdir -p "${DST}/${folder}"
  for f in "${SRC}/${folder}"/*.sql; do
    sed \
      -e 's|{{ if \.Values\.global\.ssl_enabled }}s{{ end }}||g' \
      -e "s|{{ tpl \.Values\.postgresql_obsrv_user_password \. }}|${obsrv_password}|g" \
      -e "s|{{ tpl \.Values\.postgresql_druid_raw_user_password \. }}|${druid_raw_password}|g" \
      -e "s|{{ tpl \.Values\.postgresql_keycloak_user_password \. }}|${keycloak_password}|g" \
      -e "s|{{ tpl \.Values\.postgresql_superset_user_password \. }}|${superset_password}|g" \
      -e "s|{{ tpl \.Values\.postgresql_hms_user_password \. }}|${hms_password}|g" \
      -e "s|{{ tpl \.Values\.kong_ingress_domain \. }}|${ingress_domain}|g" \
      -e "s|{{\.Values\.web_console_user}}|${web_console_user}|g" \
      -e "s|{{ \.Values\.web_console_password }}|${web_console_password}|g" \
      -e "s|{{ \.Values\.web_console_login }}|${web_console_login}|g" \
      -e "s|{{ \.Values\.superset_oauth_clientid }}|${superset_oauth_clientid}|g" \
      -e "s|{{ \.Values\.superset_oauth_client_secret }}|${superset_oauth_client_secret}|g" \
      -e "s|{{ \.Values\.gf_auth_generic_oauth_client_id }}|${grafana_oauth_clientid}|g" \
      -e "s|{{ \.Values\.gf_auth_generic_oauth_client_secret }}|${grafana_oauth_client_secret}|g" \
      -e "s|{{ \.Values\.system_settings\.encryption_key }}|${ss_encryption_key}|g" \
      -e "s|{{ \.Values\.system_settings\.default_dataset_id }}|${ss_default_dataset_id}|g" \
      -e "s|{{ \.Values\.system_settings\.max_event_size }}|${ss_max_event_size}|g" \
      -e "s|{{ \.Values\.system_settings\.dedup_period }}|${ss_dedup_period}|g" \
      "$f" > "${DST}/${folder}/$(basename "$f")"
  done
done

# Fail loudly rather than feeding a stray {{ ... }} to Postgres.
if grep -rn '{{' "${DST}" ; then
  echo "ERROR: unrendered helm template expressions remain (see above)." >&2
  echo "Add the missing substitution to $0." >&2
  exit 1
fi
echo "All template expressions rendered."

# Escape hatch for checking the render without touching a database:
#   docker compose run --rm -e RENDER_ONLY=1 flyway
if [ -n "${RENDER_ONLY:-}" ]; then
  echo "RENDER_ONLY set; not migrating."
  exit 0
fi

# --- migrate -----------------------------------------------------------------
# Same loop and repair fallback as
# helmcharts/services/postgresql-migration/configs/migrate.sh.
for folder in ${MIGRATION_FOLDERS}; do
  db="${folder#*-}"
  # Kubernetes disallows _ in ConfigMap names, so the folder is druid-raw while
  # the database is druid_raw.
  [ "$db" = "druid-raw" ] && db="druid_raw"

  url="jdbc:postgresql://${PGHOST}:${PGPORT}/${db}"
  echo
  echo "=== flyway migrate: ${db} (${folder}) ==="
  if ! flyway migrate -url="${url}" -locations="filesystem:${DST}/${folder}"; then
    echo "Migration failed; running flyway repair and retrying."
    flyway repair  -url="${url}" -locations="filesystem:${DST}/${folder}"
    flyway migrate -url="${url}" -locations="filesystem:${DST}/${folder}"
  fi
done

echo
echo "Migrations complete."
