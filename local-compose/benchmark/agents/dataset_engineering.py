"""Dataset Engineering Agent -- build and publish the two datasets.

Creates the user master dataset and the telemetry dataset with deduplication,
JSONata transformations and denormalization enabled, and gets both to Live in
a state where the running Flink jobs will actually honour their config. That
last part is the whole job: publishing a dataset is easy, and there are two
independent ways for a published dataset to be silently ignored by the
pipeline. Both are handled here and neither produces an error anywhere.
"""

import json
import os
import time

from ..lib.log import Fatal


# --- payload builders ---------------------------------------------------------
def master_request(cfg):
    """The user master dataset: a lookup table cached in Valkey.

    data_key is `id`. It is the Redis key each record is stored under and the
    only field another dataset can denormalize against -- denorm resolves via
    GET <value> against the master's Redis DB, so there is no join on any other
    column. Everything the telemetry events need to inherit therefore has to
    hang off records keyed by the user id.
    """
    ds = cfg["datasets"]["master_id"]
    text = lambda: {"type": "string", "arrival_format": "text", "data_type": "string"}
    num = lambda: {"type": "integer", "arrival_format": "number", "data_type": "integer"}
    return {
        "dataset_id": ds, "name": ds, "type": "master",
        "data_schema": {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "type": "object",
            "properties": {
                "id": text(), "userName": text(), "city": text(), "state": text(),
                "department": text(), "organization": text(), "subscription": text(),
                "device": text(), "gender": text(), "age": num(),
            },
            "additionalProperties": True,
        },
        "dataset_config": {
            "indexing_config": {"olap_store_enabled": False, "lakehouse_enabled": False,
                                "cache_enabled": True},
            "keys_config": {"data_key": "id"},
            "file_upload_path": [],
        },
        "validation_config": {"validate": True, "mode": "Strict"},
        "dedup_config": {"drop_duplicates": False},
        "denorm_config": {"denorm_fields": []},
        "transformations_config": [], "connectors_config": [], "tags": ["benchmark"],
        "sample_data": {},
    }


def telemetry_request(cfg, denorm_strategy="jsonata"):
    """The telemetry dataset, with all three features the scenario requires.

    dedup on `mid`; two JSONata derived fields; a denorm join against the user
    master. `category` is set on every transformation because ReadyToPublish
    requires it even though create does not -- omit it and the dataset is
    created successfully and can never be published.
    """
    d = cfg["datasets"]
    ds, master, out_field = d["telemetry_id"], d["master_id"], d["denorm_out_field"]
    text = lambda: {"type": "string", "arrival_format": "text", "data_type": "string"}

    denorm_field = {"dataset_id": master, "denorm_out_field": out_field}
    if denorm_strategy == "jsonata":
        # actor.id is nested, and denorm_key reads a flat field name, so the
        # only way to join on it is jsonata_expr.
        denorm_field["jsonata_expr"] = "actor.id"
    else:
        # Fallback: the generator also writes the same value to a top-level
        # actor_id, which denorm_key can address directly.
        denorm_field["denorm_key"] = "actor_id"

    def jsonata(expr, category="derived", datatype=None):
        fn = {"type": "jsonata", "expr": expr, "category": category}
        if datatype:
            fn["datatype"] = datatype
        return fn

    return {
        "dataset_id": ds, "name": ds, "type": "event",
        "data_schema": {
            "$schema": "https://json-schema.org/draft/2020-12/schema",
            "type": "object",
            "properties": {
                "eid": text(),
                "mid": text(),
                "ver": text(),
                "actor_id": text(),
                "ets": {"type": "integer", "arrival_format": "number", "data_type": "epoch"},
                "actor": {
                    "type": "object", "arrival_format": "object", "data_type": "object",
                    "properties": {"id": text(), "type": text()},
                },
                "context": {
                    "type": "object", "arrival_format": "object", "data_type": "object",
                    "properties": {
                        "channel": text(), "env": text(), "sid": text(), "did": text(),
                        "pdata": {
                            "type": "object", "arrival_format": "object",
                            "data_type": "object",
                            "properties": {"id": text(), "pid": text(), "ver": text()},
                        },
                    },
                },
                "edata": {
                    "type": "object", "arrival_format": "object", "data_type": "object",
                    "properties": {
                        "size": {"type": "integer", "arrival_format": "number",
                                 "data_type": "integer"},
                        "query": text(), "type": text(),
                        "duration": {"type": "number", "arrival_format": "number",
                                     "data_type": "double"},
                    },
                },
            },
            # IgnoreNewFields rather than Strict: the generator varies the
            # payload (filters, sort, padding) on purpose, and under Strict
            # every one of those events would be rejected as a schema
            # violation, which would benchmark the validator rather than the
            # pipeline.
            "additionalProperties": True,
        },
        "dataset_config": {
            "indexing_config": {"olap_store_enabled": True, "lakehouse_enabled": False,
                                "cache_enabled": False},
            "keys_config": {"data_key": "mid", "timestamp_key": "ets"},
            "file_upload_path": [],
        },
        "validation_config": {"validate": True, "mode": "IgnoreNewFields"},
        "dedup_config": {"drop_duplicates": True, "dedup_key": "mid"},
        "denorm_config": {"denorm_fields": [denorm_field]},
        "transformations_config": [
            {"field_key": "pipeline",
             "transformation_function": jsonata('context.pdata.pid & "-" & context.env',
                                                datatype="string"),
             "mode": "Lenient"},
            {"field_key": "isLargeEvent",
             "transformation_function": jsonata("edata.size > 100000"),
             "mode": "Lenient"},
        ],
        "connectors_config": [], "tags": ["benchmark"], "sample_data": {},
    }


# --- agent --------------------------------------------------------------------
def run(ctx):
    cfg, log, api = ctx.cfg, ctx.log, ctx.api
    log.phase("Dataset Engineering Agent", "master + telemetry datasets")
    out = {"master": {}, "telemetry": {}}

    master_id = cfg["datasets"]["master_id"]
    tele_id = cfg["datasets"]["telemetry_id"]

    if cfg["datasets"].get("recreate", True):
        for ds in (tele_id, master_id):
            if api.exists(ds):
                log.step("removing existing dataset %s" % ds)
                _drop(ctx, ds)
            else:
                # Dedup keys outlive the dataset by up to an hour, so a run
                # following one that cleaned up still inherits them and has its
                # seeded corpus rejected as duplicates. _drop covers the case
                # where the dataset is still here; this covers the case where
                # only its keys are.
                _purge_dedup(ctx, ds)

    # --- master ---------------------------------------------------------------
    log.step("creating master dataset %s" % master_id)
    if not api.exists(master_id):
        api.create(master_request(cfg))
    if _status(ctx, master_id) != "Live":
        if not api.publish(master_id):
            raise Fatal("master dataset %s did not reach Live" % master_id)
    log.ok("%s is Live" % master_id)

    redis_db = _redis_db(ctx, master_id)
    out["master"] = {"dataset_id": master_id, "redis_db": redis_db,
                     "status": "Live", "records": 0}

    # CacheIndexerJob builds its Kafka subscription list once, at job startup,
    # and runs "without periodic partition discovery" -- a master dataset
    # created after the job started is invisible to it. The source sits at zero
    # partitions and consumes nothing, with the job still reporting RUNNING.
    # Restarting is the only way it picks the new topic up.
    if ctx.cache_indexer is not None:
        log.step("restarting cache-indexer so it discovers %s" % master_id)
        if not ctx.cache_indexer.restart_job(timeout_sec=300):
            raise Fatal("CacheIndexerJob did not return to RUNNING")
        if not _wait_partition_discovery(ctx, master_id):
            # RUNNING is necessary but not sufficient. The source's start offset
            # is COMMITTED_OFFSET, and with no committed offsets for a new topic
            # it falls back to LATEST -- anything published before the reader
            # takes its split is skipped outright, leaving the job healthy, the
            # topic full and Valkey empty.
            log.warn("cache-indexer never announced a partition for %s; "
                     "records published now may be skipped" % master_id)
    else:
        log.warn("cache-indexer is not running -- add masterdata to COMPOSE_PROFILES; "
                 "denormalization will not resolve")

    log.step("loading %d user records into %s" % (len(ctx.users), master_id))
    ctx.kafka.produce_file(master_id, ctx.users_file, workers=1)
    got = _wait_valkey(ctx, redis_db, len(ctx.users),
                       cfg["validation"]["settle_timeout_sec"])
    out["master"]["records"] = got
    if got >= len(ctx.users):
        log.ok("%d user records cached in Valkey db %s" % (got, redis_db))
    else:
        log.error("only %d/%d user records reached Valkey db %s"
                  % (got, len(ctx.users), redis_db))

    # --- telemetry ------------------------------------------------------------
    strategy = cfg["datasets"].get("denorm_strategy", "jsonata")
    log.step("creating telemetry dataset %s (denorm via %s)" % (tele_id, strategy))
    if not api.exists(tele_id):
        api.create(telemetry_request(cfg, strategy))
    if _status(ctx, tele_id) != "Live":
        if not api.publish(tele_id):
            raise Fatal("telemetry dataset %s did not reach Live" % tele_id)
    log.ok("%s is Live" % tele_id)

    entry_topic = ctx.docker.psql_one(
        "SELECT entry_topic FROM datasets WHERE dataset_id='%s';" % tele_id) or \
        cfg["kafka"]["ingest_topic"]
    ctx.entry_topic = entry_topic
    log.info("entry topic: %s (%d partitions)"
             % (entry_topic, ctx.kafka.partitions(entry_topic)))

    log.step("waiting for the Druid supervisor")
    if ctx.druid.wait_for_supervisor(tele_id, timeout_sec=180):
        log.ok("supervisor %s is running" % ctx.druid.datasource(tele_id))
    else:
        log.warn("supervisor %s did not appear" % ctx.druid.datasource(tele_id))

    # The unified-pipeline job reads transformations_config once, when the job
    # starts. A dataset published afterwards flows end to end -- events arrive,
    # Druid creates the columns from the ingestion spec, nothing lands on
    # transform.failed -- and every transformed field is null. There is no error
    # anywhere; the only symptom is a column of nulls. Restarting the job is
    # what makes the transformations take effect.
    log.step("restarting unified-pipeline so it loads the transformations")
    if not ctx.pipeline.restart_job(timeout_sec=cfg["pipeline"]["resume_timeout_sec"]):
        raise Fatal("unified-pipeline did not return to RUNNING after restart")
    log.ok("unified-pipeline RUNNING with transformations loaded")

    out["telemetry"] = {
        "dataset_id": tele_id,
        "datasource": ctx.druid.datasource(tele_id),
        "entry_topic": entry_topic,
        "partitions": ctx.kafka.partitions(entry_topic),
        "status": "Live",
        "denorm_strategy": strategy,
        "denorm_out_field": cfg["datasets"]["denorm_out_field"],
        "dedup_key": "mid",
        "transformations": ["pipeline", "isLargeEvent"],
    }
    ctx.results["datasets"] = out
    return out


def rebuild_with_flat_denorm(ctx):
    """Recreate the telemetry dataset joining on the flat actor_id instead.

    Called only by the validation agent, and only when the jsonata_expr join
    produced no matches -- a deployment whose DenormalizerJob predates
    jsonata_expr support accepts the config at create time and then resolves
    nothing, which looks exactly like a bad key.
    """
    cfg, log = ctx.cfg, ctx.log
    tele_id = cfg["datasets"]["telemetry_id"]
    log.step("rebuilding %s to join on the flat actor_id" % tele_id)
    _drop(ctx, tele_id)
    ctx.api.create(telemetry_request(cfg, "flat"))
    if not ctx.api.publish(tele_id):
        raise Fatal("rebuilt telemetry dataset did not reach Live")
    ctx.druid.wait_for_supervisor(tele_id, timeout_sec=180)
    ctx.pipeline.restart_job(timeout_sec=cfg["pipeline"]["resume_timeout_sec"])
    ctx.results.setdefault("datasets", {}).setdefault("telemetry", {})[
        "denorm_strategy"] = "flat"
    log.ok("%s rebuilt with denorm_key=actor_id" % tele_id)


# --- helpers ------------------------------------------------------------------
def _status(ctx, dataset_id):
    row = ctx.docker.psql_one(
        "SELECT status FROM datasets WHERE dataset_id='%s';" % dataset_id)
    return row


def _redis_db(ctx, dataset_id):
    return ctx.docker.psql_one(
        "SELECT dataset_config->'cache_config'->>'redis_db' "
        "FROM datasets WHERE dataset_id='%s';" % dataset_id) or "0"


# Children before parents: datasources and transformations carry a dataset_id
# foreign key, so deleting the dataset row first is rejected.
_PURGE_TABLES = [
    "dataset_transformations_draft", "dataset_transformations",
    "dataset_source_config_draft", "dataset_source_config",
    "datasources_draft", "datasources",
    "datasets_draft", "datasets",
]


def _drop(ctx, dataset_id):
    """Remove a dataset completely. Four steps, and only two have an API.

      1. Retire -- the transition that tears down the Druid supervisor and
         takes the dataset out of the running Flink job.
      2. Delete -- a status transition, not a route (see ObsrvApi.delete).
         Removes the draft row Retire leaves behind.
      3. The live row, directly. Retire sets status=Retired and keeps the row,
         and checkDatasetExists queries the live table without filtering on
         status, so that tombstone makes the next create fail with 409
         DATASET_EXISTS. No API removes it.
      4. The dedup keys, which outlive all of the above (see _purge_dedup).

    Steps 3 and 4 are the two places the harness reaches past the API into
    state the API does not expose. They are also the only way step 18 -- put
    the deployment back the way it was found -- can be honoured, and they are a
    reason this framework is for a local disposable stack and nothing else.
    """
    _check_id(dataset_id)
    ctx.api.retire(dataset_id)
    ctx.druid.drop_datasource(dataset_id)
    ctx.api.delete(dataset_id)
    _purge_rows(ctx, dataset_id)
    _purge_dedup(ctx, dataset_id)

    left = _rows_left(ctx, dataset_id)
    if left:
        ctx.log.warn("%s still present after delete: %s"
                     % (dataset_id, ", ".join("%s=%d" % kv for kv in left)))
        return False
    return True


# The preprocessor's duplicate store is a plain Valkey keyspace, and which db
# index it uses lives in baseconfig.conf inside the Flink image rather than in
# anything the harness configures. Sweeping the handful of low dbs is cheaper
# than parsing that out of a container, and the prefix match is what makes it
# safe: every key is "<dataset_name>:<mid>".
_DEDUP_DBS = range(4)


def _dedup_keys(ctx, dataset_id):
    """Every duplicate-store key belonging to this dataset, across dbs."""
    _check_id(dataset_id)
    found = []
    for db in _DEDUP_DBS:
        rc, out, _ = ctx.docker.exec("valkey_dedup", [
            "valkey-cli", "-n", str(db), "--scan",
            "--pattern", "%s:*" % dataset_id], check=False, timeout=60)
        if rc != 0:
            continue
        found.extend("%d/%s" % (db, k.strip())
                     for k in out.splitlines() if k.strip())
    return found


def _purge_dedup(ctx, dataset_id):
    """Drop the dataset's duplicate-store keys. Returns how many went.

    These are the one piece of dataset state that survives a drop-and-recreate,
    because the preprocessor keys them on the dataset *name* and gives them an
    hour's TTL (redis.database.key.expiry.seconds). The name is what stays the
    same across a recreate, so the keys from the previous run are still there
    for the next one -- and since the corpus is seeded deterministically so
    runs stay comparable, the next run republishes exactly those mids.

    Left in place, a re-run inside the hour has its entire probe set rejected
    as duplicates and reports "0 of 100 probe events reached the datasource"
    while every component is healthy. Scoped by prefix, not FLUSHDB: other
    datasets on this stack keep their keys.
    """
    keys = _dedup_keys(ctx, dataset_id)
    if not keys:
        return 0
    by_db = {}
    for entry in keys:
        db, _, key = entry.partition("/")
        by_db.setdefault(db, []).append(key)
    removed = 0
    for db, klist in by_db.items():
        # Batched: a heavy run leaves tens of thousands of these, and one DEL
        # per key would be tens of thousands of docker execs.
        for i in range(0, len(klist), 500):
            rc, out, _ = ctx.docker.exec(
                "valkey_dedup",
                ["valkey-cli", "-n", db, "DEL"] + klist[i:i + 500],
                check=False, timeout=120)
            if rc == 0:
                try:
                    removed += int(out.strip().splitlines()[-1])
                except (ValueError, IndexError):
                    pass
    ctx.log.dim("  purged %d dedup key(s) for %s" % (removed, dataset_id))
    return removed


def _check_id(dataset_id):
    """These ids are interpolated into SQL, so they get a whitelist first."""
    ok = dataset_id and all(c.isalnum() or c in "_-." for c in dataset_id)
    if not ok:
        raise ValueError("refusing to drop suspicious dataset id %r" % dataset_id)


def _purge_where(table, dataset_id):
    # The two dataset tables key on id; everything downstream keys on
    # dataset_id. Matching both columns costs nothing and survives either.
    if table in ("datasets", "datasets_draft"):
        return "id='%s' OR dataset_id='%s'" % (dataset_id, dataset_id)
    return "dataset_id='%s'" % dataset_id


def _purge_rows(ctx, dataset_id):
    for table in _PURGE_TABLES:
        try:
            ctx.docker.psql("DELETE FROM %s WHERE %s;"
                            % (table, _purge_where(table, dataset_id)))
        except Exception as exc:                                    # noqa: BLE001
            # A table that does not exist in this build is not a failure --
            # the row count check below is what decides whether the drop worked.
            ctx.log.dim("  purge %s: %s" % (table, exc))


def _rows_left(ctx, dataset_id):
    left = []
    for table in _PURGE_TABLES:
        try:
            n = int(ctx.docker.psql_one(
                "SELECT count(*) FROM %s WHERE %s;"
                % (table, _purge_where(table, dataset_id)), "0"))
        except Exception:                                           # noqa: BLE001
            continue
        if n:
            left.append((table, n))
    return left


def _wait_valkey(ctx, db, target, timeout_sec, poll=3):
    deadline = time.time() + timeout_sec
    got = 0
    while time.time() < deadline:
        rc, o, _ = ctx.docker.exec("valkey_denorm", ["valkey-cli", "-n", str(db), "DBSIZE"],
                                   check=False, timeout=20)
        try:
            got = int(o.strip())
        except ValueError:
            got = 0
        if got >= target:
            return got
        time.sleep(poll)
    return got


def _wait_partition_discovery(ctx, topic, timeout_sec=200, poll=5):
    """Wait for the enumerator to announce the topic's partitions.

    The announcement only appears in the JobManager log -- there is no REST
    endpoint for it -- and it is the difference between a job that will read
    the records we are about to publish and one that will skip them.
    """
    needle = "Discovered new partitions: [%s-" % topic
    deadline = time.time() + timeout_sec
    while time.time() < deadline:
        if needle in ctx.docker.logs("ci_jobmanager", since="10m"):
            return True
        time.sleep(poll)
    return False
