#!/usr/bin/env bash
# Creates a dataset, publishes it, pushes sample events, and reads them back.
#
# This is the quickest way to prove the stack actually works end to end, and it
# doubles as a worked example of the two things that are easy to get wrong:
#
#  1. Every v2 API payload must be wrapped in obsrv's envelope
#     ({id, ver, ts, params, request}). Posting a bare body fails with
#     "#required must have required property 'id'".
#  2. Events on the ingest topic must be wrapped as
#     {"dataset": "<id>", "event": {...}}. Bare events are rejected by the
#     extractor with ERR_EXT_1004 "Dataset Id is missing from the data" and are
#     counted against ctx_dataset "ALL", so they never show up in the console's
#     per-dataset metrics -- which makes it look like nothing happened.
#
# Usage:
#   scripts/sample-dataset.sh                          # event dataset, 1000 events
#   scripts/sample-dataset.sh event  my_events   500
#   scripts/sample-dataset.sh master my_master    50
#   scripts/sample-dataset.sh denorm my_joined   200   # needs a master first:
#       scripts/sample-dataset.sh master demo_master 50
#       scripts/sample-dataset.sh denorm demo_joined 200      # MASTER_DS=demo_master
#
# An "event" dataset flows unified-pipeline -> Druid on the shared "ingest" topic,
# and is verified with a Druid SQL count.
#
# A "master" dataset flows cache-indexer -> Valkey, and differs in two ways that
# are not obvious from the datasets table: it ingests on a topic named after the
# dataset id (not entry_topic, which the API sets to "ingest" regardless of type),
# and cache-indexer only discovers those topics when the job starts, so the job is
# restarted below. It needs COMPOSE_PROFILES to include masterdata.
#
# A "denorm" dataset is an event dataset with a denorm_config pointing at an
# existing live master dataset. It is the only mode that exercises both jobs at
# once, and it is the one that proves the master path is actually useful rather
# than merely populated. Note what denorm can and cannot join on: the lookup is
# `GET <event[denorm_key]>` against the master's Redis DB, so it resolves only
# through the master dataset's own keys_config.data_key. There is no join on any
# other column -- pick the master's data_key to be whatever the event datasets
# will carry.
set -uo pipefail

TYPE="${1:-event}"
DS="${2:-}"
COUNT="${3:-1000}"
# Which master dataset the denorm mode joins against. Must already be Live and
# populated -- run the master mode first.
MASTER_DS="${MASTER_DS:-demo_master}"
# denorm_out_field: the object the joined master record is nested under on the
# outgoing event. Druid flattens it to "<field>.<master column>" columns.
DENORM_OUT="${DENORM_OUT:-region}"

case "$TYPE" in
  event)  DS="${DS:-sample_events}" ;;
  master) DS="${DS:-sample_master}" ;;
  denorm) DS="${DS:-sample_joined}" ;;
  *) echo "usage: $0 [event|master|denorm] [dataset_id] [count]" >&2; exit 2 ;;
esac

API="${API_URL:-http://localhost:3000}"
KC="${KEYCLOAK_URL:-http://localhost:8080}/auth/realms/obsrv/protocol/openid-connect/token"
KC_USER="${KEYCLOAK_ADMIN_USER:-obsrv_admin}"
KC_PASS="${KEYCLOAK_ADMIN_PASSWORD:-enDoPvTAxFSd}"
# curl is not installed in the Druid image, so Druid is reached from nginx, which
# has wget. admin:admin123 base64-encoded.
DRUID_AUTH="YWRtaW46YWRtaW4xMjM="

step()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
ok()    { printf '\033[32m%s\033[0m\n' "$*"; }
fail()  { printf '\033[31m%s\033[0m\n' "$*" >&2; exit 1; }

jget() { python3 -c "import json,sys; d=json.load(sys.stdin); print(${1})" 2>/dev/null; }

# --- envelope ---------------------------------------------------------------
# $1 = api id, $2 = request object as JSON
envelope() {
  python3 - "$1" "$2" <<'PY'
import json, sys, time
print(json.dumps({
    "id": sys.argv[1], "ver": "v2",
    "ts": time.strftime("%Y-%m-%dT%H:%M:%S+00:00", time.gmtime()),
    "params": {"msgid": "sample-dataset"},
    "request": json.loads(sys.argv[2]),
}))
PY
}

api_post() {  # $1 = api id (api.datasets.<path>), $2 = request JSON
  envelope "$1" "$2" \
    | curl -s -X POST "${API}/v2/datasets/${1##api.datasets.}" \
        -H "Authorization: Bearer ${TOKEN}" -H "Content-Type: application/json" \
        --data-binary @-
}

# --- 1. token ---------------------------------------------------------------
step "authenticating as ${KC_USER}"
TOKEN=$(curl -s -X POST "$KC" \
  -d grant_type=password -d client_id=obsrv-console \
  -d "username=${KC_USER}" -d "password=${KC_PASS}" \
  | jget 'd.get("access_token","")')
[ -n "${TOKEN:-}" ] || fail "could not get a token from ${KC} -- is keycloak up?"
ok "  got a token (${#TOKEN} chars)"

# --- 2. create --------------------------------------------------------------
# The create schema is strict (additionalProperties: false) and narrower than the
# docs suggest: dataset_config accepts only file_upload_path, dataset_tz,
# indexing_config and keys_config, and dedup_config only drop_duplicates and
# dedup_key. entry_topic is NOT accepted -- the API derives it, and this script
# reads it back below.
if [ "$TYPE" = master ]; then
  # A master dataset is a lookup table: keyed rows cached in Valkey for the
  # denorm step of other datasets to join against. No timestamp, no OLAP store.
  REQUEST=$(cat <<JSON
{"dataset_id":"${DS}","name":"${DS}","type":"master",
 "data_schema":{"\$schema":"https://json-schema.org/draft/2020-12/schema","type":"object",
   "properties":{
     "code":{"type":"string","arrival_format":"text","data_type":"string"},
     "name":{"type":"string","arrival_format":"text","data_type":"string"},
     "population":{"type":"integer","arrival_format":"number","data_type":"integer"}},
   "additionalProperties":true},
 "dataset_config":{
   "indexing_config":{"olap_store_enabled":false,"lakehouse_enabled":false,"cache_enabled":true},
   "keys_config":{"data_key":"code"},
   "file_upload_path":[]},
 "validation_config":{"validate":true,"mode":"Strict"},
 "dedup_config":{"drop_duplicates":false,"dedup_key":"code"},
 "denorm_config":{"denorm_fields":[]},
 "transformations_config":[],"connectors_config":[],"tags":[],"sample_data":{}}
JSON
)
elif [ "$TYPE" = event ]; then
  REQUEST=$(cat <<JSON
{"dataset_id":"${DS}","name":"${DS}","type":"event",
 "data_schema":{"\$schema":"https://json-schema.org/draft/2020-12/schema","type":"object",
   "properties":{
     "id":{"type":"string","arrival_format":"text","data_type":"string"},
     "ets":{"type":"integer","arrival_format":"number","data_type":"epoch"},
     "value":{"type":"integer","arrival_format":"number","data_type":"integer"}},
   "additionalProperties":true},
 "dataset_config":{
   "indexing_config":{"olap_store_enabled":true,"lakehouse_enabled":false,"cache_enabled":false},
   "keys_config":{"data_key":"id","timestamp_key":"ets"},
   "file_upload_path":[]},
 "validation_config":{"validate":true,"mode":"Strict"},
 "dedup_config":{"drop_duplicates":true,"dedup_key":"id"},
 "denorm_config":{"denorm_fields":[]},
 "transformations_config":[],"connectors_config":[],"tags":[],"sample_data":{}}
JSON
)
elif [ "$TYPE" = denorm ]; then
  # Same as the event dataset, plus "code" -- the field whose value the
  # DenormalizerJob uses as the Redis key -- and a denorm_config entry naming the
  # master dataset.
  #
  # denorm_key names a field on the EVENT; its value is looked up as-is in the
  # master's Redis DB, which is why it has to hold the master's data_key values
  # ("C00000"...). denorm_out_field is where the joined record is attached.
  # dataset_id must be a master dataset that is already Live -- dataset-api
  # rejects anything else with DEPENDENT_MASTER_DATA_NOT_FOUND (404) if it does
  # not exist, or DEPENDENT_MASTER_DATA_NOT_LIVE (428) if it is still Draft.
  #
  # "code" is deliberately NOT declared in data_schema properties: it is only a
  # join key, and additionalProperties:true lets it through validation. Declaring
  # it would work too, it would just also land in Druid as its own column.
  REQUEST=$(cat <<JSON
{"dataset_id":"${DS}","name":"${DS}","type":"event",
 "data_schema":{"\$schema":"https://json-schema.org/draft/2020-12/schema","type":"object",
   "properties":{
     "id":{"type":"string","arrival_format":"text","data_type":"string"},
     "ets":{"type":"integer","arrival_format":"number","data_type":"epoch"},
     "value":{"type":"integer","arrival_format":"number","data_type":"integer"}},
   "additionalProperties":true},
 "dataset_config":{
   "indexing_config":{"olap_store_enabled":true,"lakehouse_enabled":false,"cache_enabled":false},
   "keys_config":{"data_key":"id","timestamp_key":"ets"},
   "file_upload_path":[]},
 "validation_config":{"validate":true,"mode":"Strict"},
 "dedup_config":{"drop_duplicates":true,"dedup_key":"id"},
 "denorm_config":{"denorm_fields":[
   {"dataset_id":"${MASTER_DS}","denorm_key":"code","denorm_out_field":"${DENORM_OUT}"}]},
 "transformations_config":[],"connectors_config":[],"tags":[],"sample_data":{}}
JSON
)
fi

# The master has to be live and populated before the denorm dataset is created --
# dataset-api resolves the reference at create time, not at publish time.
if [ "$TYPE" = denorm ]; then
  step "checking master dataset ${MASTER_DS}"
  mstatus=$(docker exec obsrv-postgres psql -U obsrv -d obsrv -tAc \
    "SELECT status FROM datasets WHERE dataset_id='${MASTER_DS}' AND type='master';" \
    2>/dev/null | tr -d ' ')
  [ "${mstatus:-}" = Live ] \
    || fail "  ${MASTER_DS} is '${mstatus:-missing}', not Live -- run: $0 master ${MASTER_DS} 50"
  MDB=$(docker exec obsrv-postgres psql -U obsrv -d obsrv -tAc \
    "SELECT dataset_config->'cache_config'->>'redis_db' FROM datasets WHERE dataset_id='${MASTER_DS}';" \
    2>/dev/null | tr -d ' ')
  mkeys=$(docker exec obsrv-valkey-denorm valkey-cli -n "${MDB:-0}" DBSIZE 2>/dev/null | tr -d '\r')
  [ "${mkeys:-0}" -gt 0 ] 2>/dev/null \
    || fail "  ${MASTER_DS} is Live but Valkey db ${MDB} is empty -- run: $0 master ${MASTER_DS} 50"
  ok "  ${MASTER_DS} is Live with ${mkeys} keys in Valkey db ${MDB}"
fi

step "creating ${TYPE} dataset ${DS}"
RES=$(api_post api.datasets.create "$REQUEST")
STATUS=$(echo "$RES" | jget 'd["params"]["status"]')
if [ "$STATUS" != SUCCESS ]; then
  echo "$RES" | jget 'json.dumps(d.get("error") or d, indent=2)'
  fail "  create failed"
fi
ok "  created"

# --- 3. publish -------------------------------------------------------------
# Live is the transition that matters: it generates the Druid ingestion spec for
# event datasets and hands the dataset to the running Flink job for both types.
for want in ReadyToPublish Live; do
  step "status-transition -> ${want}"
  RES=$(api_post api.datasets.status-transition "{\"dataset_id\":\"${DS}\",\"status\":\"${want}\"}")
  STATUS=$(echo "$RES" | jget 'd["params"]["status"]')
  if [ "$STATUS" != SUCCESS ]; then
    echo "$RES" | jget 'json.dumps(d.get("error") or d, indent=2)'
    fail "  transition to ${want} failed"
  fi
  ok "  now ${want}"
done

# --- 4. work out the ingest topic and wait for the consumer -----------------
# denorm datasets are event datasets as far as topics and Druid are concerned --
# the join happens mid-pipeline, inside DenormalizerJob.
if [ "$TYPE" != master ]; then
  # Event datasets share one entry topic ("ingest"); the extractor fans them out
  # per dataset using the "dataset" field on the wrapper.
  TOPIC=$(docker exec obsrv-postgres psql -U obsrv -d obsrv -tAc \
    "SELECT entry_topic FROM datasets WHERE dataset_id='${DS}';" 2>/dev/null | tr -d ' ')
  [ -n "$TOPIC" ] || fail "no entry_topic recorded for ${DS}"

  step "waiting for the Druid supervisor"
  for _ in $(seq 1 40); do
    sup=$(docker exec obsrv-nginx wget -q --header="Authorization: Basic ${DRUID_AUTH}" \
          -O- http://druid:8888/druid/indexer/v1/supervisor 2>/dev/null)
    case "$sup" in *"\"${DS}_events\""*) ok "  supervisor ${DS}_events is running"; break ;; esac
    sleep 3
  done
  case "${sup:-}" in
    *"\"${DS}_events\""*) ;;
    *) echo "  supervisor did not appear (last: ${sup:-none}); continuing anyway" ;;
  esac
else
  docker inspect -f '{{.State.Status}}' obsrv-cache-indexer-taskmanager >/dev/null 2>&1 \
    || fail "cache-indexer is not running -- add masterdata to COMPOSE_PROFILES in .env"

  # Master datasets do NOT use entry_topic. The datasets row says "ingest" for
  # every type (the API hardcodes it -- see configs/Config.ts, where the
  # createMasterDataset topic is defined but never assigned), yet CacheIndexerJob
  # subscribes to one topic per live master dataset, named after the dataset id.
  # Verified from the JobManager log:
  #   Discovered new partitions: [demo_master-0]
  TOPIC="${DS}"

  # And it builds that subscription list once, at job startup: the enumerator
  # logs "without periodic partition discovery". A master dataset created after
  # the job started is invisible to it -- the source sits at zero partitions and
  # silently consumes nothing, with the job still reporting RUNNING. Restarting
  # the job is the only way to pick the new dataset up.
  step "restarting cache-indexer so it discovers ${DS}"
  docker compose restart cache-indexer-jobmanager cache-indexer-taskmanager >/dev/null 2>&1
  for _ in $(seq 1 60); do
    st=$(docker exec obsrv-nginx wget -qO- http://cache-indexer-jobmanager:8081/jobs/overview \
         2>/dev/null | jget 'd["jobs"][0]["state"] if d.get("jobs") else "NONE"')
    [ "${st:-}" = RUNNING ] && { ok "  CacheIndexerJob is RUNNING"; break; }
    sleep 5
  done
  [ "${st:-}" = RUNNING ] || fail "  CacheIndexerJob did not reach RUNNING (last: ${st:-none})"

  # RUNNING is necessary but not sufficient, and the difference silently loses
  # events. The source's starting offset is COMMITTED_OFFSET, and with no
  # committed offsets for this brand-new topic it falls back to LATEST -- so
  # anything published before the reader takes its split is skipped outright,
  # leaving the job healthy, the topic full and Valkey empty. Wait for the
  # enumerator to actually announce the partition before publishing anything.
  step "waiting for the reader to take its split on ${TOPIC}"
  for _ in $(seq 1 40); do
    docker logs --since 5m obsrv-cache-indexer-jobmanager 2>&1 \
      | grep -q "Discovered new partitions: \[${TOPIC}-" \
      && { ok "  partition assigned"; break; }
    sleep 5
  done
  docker logs --since 5m obsrv-cache-indexer-jobmanager 2>&1 \
    | grep -q "Discovered new partitions: \[${TOPIC}-" \
    || fail "  cache-indexer never discovered ${TOPIC}"
fi

# --- 5. push events ---------------------------------------------------------
step "pushing ${COUNT} events to ${TOPIC}"
python3 - "$DS" "$COUNT" "$TYPE" "${mkeys:-0}" <<'PY' > /tmp/sample-events.ndjson
import json, sys, time
ds, count, kind = sys.argv[1], int(sys.argv[2]), sys.argv[3]
master_keys = int(sys.argv[4] or 0)
now = int(time.time() * 1000)
for i in range(count):
    if kind == "denorm":
        # "code" cycles through the keys the master mode actually created
        # (C00000..C000<master_keys-1>) so every event finds a match. A value with
        # no master row is not an error -- DenormalizerJob counts it as
        # denorm_partial_success and passes the event through with the
        # denorm_out_field simply absent, which is why a silently-failing join
        # looks like a working pipeline unless you check the joined column.
        print(json.dumps({"dataset": ds,
                          "event": {"id": f"evt-{i:05d}", "ets": now + i,
                                    "value": i,
                                    "code": f"C{i % max(master_keys, 1):05d}"}}))
    elif kind == "master":
        # Master events are pushed BARE -- no {"dataset","event"} wrapper. The
        # topic is already dataset-specific, so there is nothing for a wrapper to
        # disambiguate, and CacheIndexerFunction looks for the dataset's
        # keys_config.data_key ("code" here) at the TOP LEVEL of the message.
        # Wrapping it puts the key one level down, and every event is rejected to
        # masterdata.failed with:
        #   ERR_MASTER_DATA_1017 "Master dataset configuration key is missing"
        # which is easy to misread as a dataset-config problem rather than an
        # event-shape one. The data_key must be present on every event -- it is
        # the Redis key the record is stored under, and it is also the only field
        # another dataset can denormalize against.
        print(json.dumps({"code": f"C{i:05d}", "name": f"region-{i}",
                          "population": 1000 + i}))
    else:
        # Event datasets arrive on the shared "ingest" topic, so here the wrapper
        # is required -- it is how the extractor knows which dataset the event
        # belongs to. Without it the extractor fails with ERR_EXT_1004
        # "Dataset Id is missing from the data" and attributes it to no dataset.
        print(json.dumps({"dataset": ds,
                          "event": {"id": f"evt-{i:05d}", "ets": now + i,
                                    "value": i}}))
PY
docker cp /tmp/sample-events.ndjson obsrv-kafka:/tmp/sample-events.ndjson >/dev/null
docker exec obsrv-kafka sh -c \
  "/opt/kafka/bin/kafka-console-producer.sh --bootstrap-server localhost:9092 --topic ${TOPIC} \
   < /tmp/sample-events.ndjson" 2>&1 | grep -v '^\[' || true
ok "  pushed ${COUNT}"

# --- 6. read back -----------------------------------------------------------
if [ "$TYPE" != master ]; then
  # Dataset audit_test becomes datasource audit_test_events -- querying the bare
  # dataset id returns nothing at all.
  step "reading back from Druid datasource ${DS}_events"
  for _ in $(seq 1 40); do
    res=$(docker exec obsrv-nginx wget -q --header="Authorization: Basic ${DRUID_AUTH}" \
          --header="Content-Type: application/json" \
          --post-data="{\"query\":\"SELECT COUNT(*) AS c FROM \\\"${DS}_events\\\"\"}" \
          -O- http://druid:8888/druid/v2/sql 2>/dev/null)
    got=$(echo "${res:-[]}" | jget 'd[0]["c"] if d else 0')
    [ "${got:-0}" -ge "$COUNT" ] 2>/dev/null && break
    sleep 5
  done
  echo "  rows in Druid: ${got:-0} / ${COUNT}"
  [ "${got:-0}" -ge "$COUNT" ] || fail "  FAIL -- only ${got:-0} rows after 200s"

  if [ "$TYPE" = denorm ]; then
    # Row count alone does not prove the join: an unmatched lookup is
    # denorm_partial_success, so the event still arrives, just without the
    # joined field. Count the rows where the master's "name" column came
    # through. Druid names the flattened columns "<denorm_out_field>.<column>",
    # which needs the double quotes.
    step "checking the join landed in ${DS}_events"
    for _ in $(seq 1 20); do
      res=$(docker exec obsrv-nginx wget -q --header="Authorization: Basic ${DRUID_AUTH}" \
            --header="Content-Type: application/json" \
            --post-data="{\"query\":\"SELECT COUNT(*) AS c FROM \\\"${DS}_events\\\" WHERE \\\"${DENORM_OUT}.name\\\" IS NOT NULL\"}" \
            -O- http://druid:8888/druid/v2/sql 2>/dev/null)
      joined=$(echo "${res:-[]}" | jget 'd[0]["c"] if d else 0')
      [ "${joined:-0}" -ge "$COUNT" ] 2>/dev/null && break
      sleep 5
    done
    echo "  rows with ${DENORM_OUT} joined from ${MASTER_DS}: ${joined:-0} / ${COUNT}"
    if [ "${joined:-0}" -ge "$COUNT" ]; then
      echo "  sample joined row:"
      docker exec obsrv-nginx wget -q --header="Authorization: Basic ${DRUID_AUTH}" \
        --header="Content-Type: application/json" \
        --post-data="{\"query\":\"SELECT \\\"id\\\", \\\"${DENORM_OUT}.code\\\", \\\"${DENORM_OUT}.name\\\", \\\"${DENORM_OUT}.population\\\" FROM \\\"${DS}_events\\\" WHERE \\\"${DENORM_OUT}.name\\\" IS NOT NULL LIMIT 2\"}" \
        -O- http://druid:8888/druid/v2/sql 2>/dev/null | head -c 400
      echo
      ok "  PASS"
    else
      echo "  the events arrived but the join did not -- check DenormalizerJob's"
      echo "  denorm_failed / denorm_partial_success counters, and that the event's"
      echo "  denorm_key values match keys present in ${MASTER_DS}'s Redis DB."
      fail "  FAIL -- only ${joined:-0} joined rows after 100s"
    fi
  else
    ok "  PASS"
  fi
else
  # Master rows land in Valkey, in the Redis DB the API assigned at create time.
  DB=$(docker exec obsrv-postgres psql -U obsrv -d obsrv -tAc \
    "SELECT dataset_config->'cache_config'->>'redis_db' FROM datasets WHERE dataset_id='${DS}';" \
    2>/dev/null | tr -d ' ')
  step "reading back from Valkey db ${DB:-?}"
  for _ in $(seq 1 40); do
    got=$(docker exec obsrv-valkey-denorm valkey-cli -n "${DB:-0}" DBSIZE 2>/dev/null | tr -d '\r')
    [ "${got:-0}" -ge "$COUNT" ] 2>/dev/null && break
    sleep 5
  done
  echo "  keys in Valkey db ${DB}: ${got:-0} / ${COUNT}"
  if [ "${got:-0}" -ge "$COUNT" ]; then
    echo "  sample row:"
    docker exec obsrv-valkey-denorm valkey-cli -n "${DB:-0}" GET C00000 2>/dev/null | head -c 300
    echo
    ok "  PASS"
  else
    fail "  FAIL -- only ${got:-0} keys after 200s"
  fi
fi
