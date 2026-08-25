#!/usr/bin/env bash
# The postgresql-migration seed (V1__create_obsrv_initial_data.sql) inserts
# the obsrv_admin row into web-console's oauth_users table with a hardcoded
# id of "1". But web-console looks up that row by the "sub" claim of the
# Keycloak access token -- the Keycloak-assigned id (a UUID) for the
# obsrv_admin user, which keycloak-init.sh writes to /shared/obsrv_admin_id.
# Without this, a brand-new SSO login never finds a matching local user (or
# its admin role), and the "fill first/last name" profile-completion flow
# 403s ("Access denied") since creating a user itself requires the admin
# role no session has yet.
set -euo pipefail

admin_id="$(cat /shared/obsrv_admin_id)"
if [ -z "$admin_id" ]; then
  echo "obsrv_admin id not found in /shared/obsrv_admin_id" >&2
  exit 1
fi

# Keycloak ids are plain UUIDs, so this is safe to interpolate directly --
# psql's own -v variable substitution doesn't apply inside -c.
echo "Reconciling oauth_users.id for obsrv_admin -> ${admin_id} ..."
PGPASSWORD="${PGPASSWORD:-postgres}" psql -v ON_ERROR_STOP=1 \
  -h "${PGHOST:-postgres}" -U "${PGUSER:-postgres}" -d "${PGDATABASE:-obsrv}" \
  -c "UPDATE oauth_users SET id = '${admin_id}' WHERE user_name = 'obsrv_admin' AND id <> '${admin_id}';"

echo "Done."
