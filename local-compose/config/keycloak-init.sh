#!/usr/bin/env bash
# Creates the realm + client that web-console expects.
#
# The helm install imports a ~2600-line realm JSON (helmcharts/obsrv/values.yaml).
# Rather than carry that here, this recreates only the parts web-console needs,
# using the values from that JSON and global-values.yaml:
#   realm            obsrv                       (KEYCLOAK_REALM)
#   client           obsrv-console               (global.oauth_configs.web_console_client_id)
#                    public client, callback /console?auth_callback=1
#   realm admin      obsrv_admin / enDoPvTAxFSd  (global-values.yaml:438-441)
#   console login    admin@obsrv.in
# Keycloak master admin is admin / admin123 (global-values.yaml:77-81).
set -euo pipefail

KC="${KC:-/opt/keycloak/bin/kcadm.sh}"
KC_URL="${KC_URL:-http://keycloak:8080/auth}"
KC_ADMIN="${KC_ADMIN:-admin}"
KC_ADMIN_PASSWORD="${KC_ADMIN_PASSWORD:-admin123}"
REALM="${REALM:-obsrv}"
CLIENT_ID="${CLIENT_ID:-obsrv-console}"
# Browser-facing base URL of the stack (through nginx).
BASE_URL="${BASE_URL:-http://localhost}"

echo "Waiting for Keycloak at ${KC_URL} ..."
until "$KC" config credentials --server "$KC_URL" --realm master \
        --user "$KC_ADMIN" --password "$KC_ADMIN_PASSWORD" >/dev/null 2>&1; do
  sleep 3
done
echo "Authenticated against Keycloak."

if "$KC" get "realms/${REALM}" >/dev/null 2>&1; then
  echo "Realm ${REALM} already exists; skipping create."
else
  "$KC" create realms -s "realm=${REALM}" -s enabled=true \
    -s sslRequired=NONE \
    -s registrationAllowed=false \
    -s loginWithEmailAllowed=true
  echo "Created realm ${REALM}."
fi

# --- client ------------------------------------------------------------------
# KEYCLOAK_PUBLIC_CLIENT=true and KEYCLOAK_SSL_REQUIRED=none in the chart, so:
# publicClient (no secret), standard flow, plain HTTP allowed.
existing_client="$("$KC" get clients -r "$REALM" -q "clientId=${CLIENT_ID}" --fields id --format csv --noquotes 2>/dev/null | tail -n +1 | head -1 || true)"
if [ -n "${existing_client}" ]; then
  echo "Client ${CLIENT_ID} already exists; skipping create."
else
  "$KC" create clients -r "$REALM" \
    -s "clientId=${CLIENT_ID}" \
    -s "name=Obsrv Console" \
    -s enabled=true \
    -s publicClient=true \
    -s standardFlowEnabled=true \
    -s directAccessGrantsEnabled=true \
    -s "rootUrl=${BASE_URL}" \
    -s "baseUrl=/console" \
    -s "redirectUris=[\"${BASE_URL}/*\",\"${BASE_URL}/console\",\"${BASE_URL}/console?auth_callback=1\"]" \
    -s "webOrigins=[\"${BASE_URL}\",\"+\"]"
  echo "Created public client ${CLIENT_ID}."
fi

# --- users -------------------------------------------------------------------
create_user() {
  local username="$1" password="$2" email="$3" first="$4" last="$5"
  if "$KC" get users -r "$REALM" -q "username=${username}" --fields username --format csv --noquotes 2>/dev/null | grep -qx "${username}"; then
    echo "User ${username} already exists; skipping."
    return
  fi
  # firstName and lastName are NOT optional here, even though nothing in the
  # stack displays them. Keycloak 24+ enables the declarative user profile by
  # default, which makes both fields required, and a user missing either gets a
  # VERIFY_PROFILE required action attached. Any required action makes the token
  # endpoint reject the password grant with:
  #   invalid_grant / "Account is not fully set up"
  # so scripts/sample-dataset.sh (and anything else using the password grant)
  # cannot authenticate at all until someone completes the profile form in the
  # browser by hand. That is not a startup race -- it never resolves on its own.
  # requiredActions is set empty explicitly so a realm-level default cannot
  # reintroduce the same problem.
  "$KC" create users -r "$REALM" \
    -s "username=${username}" \
    -s "email=${email}" \
    -s "firstName=${first}" \
    -s "lastName=${last}" \
    -s emailVerified=true \
    -s 'requiredActions=[]' \
    -s enabled=true
  "$KC" set-password -r "$REALM" --username "${username}" --new-password "${password}"
  echo "Created user ${username}."
}

create_user "obsrv_admin" "enDoPvTAxFSd" "admin@obsrv.in" "Obsrv" "Admin"
# loginWithEmailAllowed=true above means this one user can log in as either
# "obsrv_admin" or "admin@obsrv.in" -- no need for a second user account.

# Give obsrv_admin realm-admin rights, as the imported realm does.
"$KC" add-roles -r "$REALM" --uusername obsrv_admin --rolename realm-admin \
  --cclientid realm-management 2>/dev/null || true

# web-console looks up its local oauth_users row by the "sub" claim in the
# Keycloak access token, which is this user's Keycloak-assigned id (a UUID) --
# NOT the "1" the postgresql-migration seed hardcodes for obsrv_admin. Hand
# the real id to oauth-admin-sync (config/oauth-admin-sync.sh), which fixes
# the row up once Postgres is seeded, since kcadm has no psql to do it here.
admin_id="$("$KC" get users -r "$REALM" -q "username=obsrv_admin" --fields id --format csv --noquotes 2>/dev/null | tail -n +1 | head -1)"
echo -n "$admin_id" > /shared/obsrv_admin_id
echo "obsrv_admin Keycloak id: ${admin_id}"

echo
echo "Keycloak ready."
echo "  realm  : ${REALM}"
echo "  client : ${CLIENT_ID} (public)"
echo "  login  : obsrv_admin / enDoPvTAxFSd"
