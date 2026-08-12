"""Telemetry Generation Agent -- user profiles and realistic telemetry.

Two generators, both deterministic given a seed, because a benchmark whose
input changes between runs cannot be used to compare two configurations.

Everything is written to NDJSON on disk rather than held in memory: a
1,000,000-event run is a few hundred MB, and the producer streams the file
into the broker rather than through the Python process.
"""

import json
import os
import random
import time

FIRST = ["Aarav", "Diya", "Vihaan", "Ananya", "Arjun", "Ishita", "Kabir", "Meera",
         "Rohan", "Saanvi", "Vivaan", "Aditi", "Dhruv", "Kavya", "Reyansh", "Tara",
         "Advik", "Anika", "Ayaan", "Myra", "Neel", "Riya", "Shaurya", "Zara"]
LAST = ["Sharma", "Iyer", "Reddy", "Nair", "Patel", "Gupta", "Bose", "Menon",
        "Kulkarni", "Rao", "Singh", "Das", "Joshi", "Pillai", "Chandra", "Verma"]
CITIES = [("Bengaluru", "Karnataka"), ("Chennai", "Tamil Nadu"), ("Mumbai", "Maharashtra"),
          ("Pune", "Maharashtra"), ("Hyderabad", "Telangana"), ("Delhi", "Delhi"),
          ("Kolkata", "West Bengal"), ("Kochi", "Kerala"), ("Jaipur", "Rajasthan"),
          ("Ahmedabad", "Gujarat"), ("Indore", "Madhya Pradesh"), ("Lucknow", "Uttar Pradesh")]
DEPARTMENTS = ["Engineering", "Data Platform", "Content", "Operations", "Support",
               "Analytics", "Quality", "Research"]
ORGS = ["Sunbird Foundation", "EkStep", "Diksha State Cell", "NDEAR Labs",
        "Obsrv Systems", "Samagra"]
SUBSCRIPTIONS = ["free", "basic", "pro", "enterprise"]
DEVICES = ["android-tablet", "android-phone", "ios-phone", "web-chrome",
           "web-firefox", "web-safari", "kiosk"]
GENDERS = ["female", "male", "other", "undisclosed"]

EIDS = ["SEARCH", "IMPRESSION", "INTERACT", "START", "END", "ASSESS", "SHARE"]
ENVS = ["search", "content", "player", "assessment", "portal"]
PIDS = ["search-service", "content-service", "player-service",
        "assessment-service", "portal-service"]
CHANNELS = ["in.ekstep", "in.diksha", "in.sunbird", "in.tenant-01"]
DIALCODES = ["WGHSK", "BQTMZ", "LKP291", "ZXQ88", "MND741", "TRV003", "HJK220"]
QUERIES = ["", "class 5 maths", "photosynthesis", "algebra practice", "hindi grammar",
           "periodic table", "", "map of india", "fractions", ""]
SORTS = [{}, {"lastUpdatedOn": "desc"}, {"name": "asc"}]
TYPES = ["all", "content", "collection", "assessment"]


# --- users -------------------------------------------------------------------
def generate_users(count, seed=0):
    """Realistic user profiles.

    `id` is the master dataset's data_key and is what telemetry joins against
    via actor.id, so it has to be a plain top-level string: CacheIndexerFunction
    looks the data_key up at the TOP LEVEL of the master record, and the Redis
    key it stores under is that value verbatim.
    """
    rnd = random.Random(seed)
    users = []
    for i in range(count):
        city, state = rnd.choice(CITIES)
        first, last = rnd.choice(FIRST), rnd.choice(LAST)
        users.append({
            "id": "user-%04d" % (i + 1),
            "userName": "%s %s" % (first, last),
            "city": city,
            "state": state,
            "department": rnd.choice(DEPARTMENTS),
            "organization": rnd.choice(ORGS),
            "subscription": rnd.choice(SUBSCRIPTIONS),
            "device": rnd.choice(DEVICES),
            "age": rnd.randint(18, 64),
            "gender": rnd.choice(GENDERS),
        })
    return users


def write_users_ndjson(users, path):
    """Master records go on the wire BARE -- no {"dataset","event"} wrapper.

    The master topic is already dataset-specific, so there is nothing for a
    wrapper to disambiguate, and wrapping puts the data_key one level down;
    every event is then rejected to masterdata.failed with ERR_MASTER_DATA_1017
    "Master dataset configuration key is missing", which reads like a dataset
    misconfiguration rather than an event-shape problem.
    """
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        for u in users:
            # Synthetic mock user profiles for local performance benchmarking -- not real PII
            fh.write(json.dumps(u, separators=(",", ":")) + "\n")  # codeql[py/clear-text-storage-sensitive-data]
    return path


# --- telemetry ---------------------------------------------------------------
def _mid(pid, ts, rnd):
    return "%s.%d.%08x-%04x-%04x" % (pid[:2].upper(), ts, rnd.getrandbits(32),
                                     rnd.getrandbits(16), rnd.getrandbits(16))


def make_event(rnd, users, now_ms, spread_ms, large, target_bytes):
    """One telemetry event in the shape the requirement specifies.

    actor.id is drawn from the generated users so the denormalization join has
    something to resolve; actor_id carries the same value at the top level as a
    fallback join key, because a deployment whose DenormalizerJob does not
    support jsonata_expr can only join on a flat field.
    """
    user = rnd.choice(users)
    ets = now_ms - rnd.randint(0, spread_ms)
    pid = rnd.choice(PIDS)
    env = rnd.choice(ENVS)
    # edata.size drives the isLargeEvent transformation, so the split between
    # >100000 and <=100000 is controlled rather than incidental.
    size = rnd.randint(100001, 900000) if large else rnd.randint(1000, 99999)
    ev = {
        "eid": rnd.choice(EIDS),
        "ets": ets,
        "ver": "3.0",
        "mid": _mid(pid, ets, rnd),
        "actor": {"id": user["id"], "type": "user"},
        "actor_id": user["id"],
        "context": {
            "channel": rnd.choice(CHANNELS),
            "pdata": {"id": "dev.sunbird.learning.platform", "pid": pid, "ver": "1.0"},
            "env": env,
            "sid": "%08x" % rnd.getrandbits(32),
            "did": user["device"],
        },
        "edata": {
            "size": size,
            "query": rnd.choice(QUERIES),
            "filters": {
                "dialCodes": rnd.choice(DIALCODES),
                "board": rnd.choice(["CBSE", "ICSE", "State Board"]),
                "medium": rnd.choice(["English", "Hindi", "Kannada", "Tamil"]),
            },
            "sort": rnd.choice(SORTS),
            "type": rnd.choice(TYPES),
            "duration": round(rnd.uniform(0.05, 45.0), 3),
        },
    }
    # Pad to the requested wire size with a repeatable filler. Event size is one
    # of the axes the requirement asks to randomize, and it is a real variable:
    # it drives Kafka bytes/sec and Druid segment size independently of the
    # event count.
    current = len(json.dumps(ev, separators=(",", ":")))
    if target_bytes > current + 20:
        ev["edata"]["payload"] = "x" * (target_bytes - current - 20)
    return ev


def generate_telemetry(path, dataset_id, count, users, cfg, log=None):
    """Write `count` wrapped telemetry events to `path`.

    Returns a manifest the validation phase needs: how many lines were written,
    how many of them are deliberate duplicates, and therefore how many rows
    Druid should hold once deduplication has done its job.

    Duplicates are emitted as a byte-identical re-send of an already-written
    event (same mid), interleaved rather than appended, so they arrive on
    different partitions at different times and actually exercise the dedup
    store rather than being collapsed by chance.
    """
    load = cfg["load"]
    rnd = random.Random(load.get("seed", 0))
    lo, hi = load["event_size_bytes"][:2]
    spread_ms = int(load["timestamp_spread_minutes"] * 60 * 1000)
    dup_fraction = float(load["duplicate_fraction"])
    large_fraction = float(load["large_event_fraction"])
    now_ms = int(time.time() * 1000)

    n_dups = int(count * dup_fraction)
    n_unique = count - n_dups
    dup_pool, dup_mids = [], []
    # Positions in the output stream that will carry a duplicate.
    dup_slots = set(rnd.sample(range(1, count), n_dups)) if n_dups else set()

    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    written = unique_written = dups_written = 0
    large_written = 0
    total_bytes = 0
    with open(path, "w", encoding="utf-8") as fh:
        for i in range(count):
            if i in dup_slots and dup_pool:
                ev = rnd.choice(dup_pool)
                dups_written += 1
                dup_mids.append(ev["mid"])
            else:
                large = rnd.random() < large_fraction
                ev = make_event(rnd, users, now_ms, spread_ms, large,
                                rnd.randint(lo, hi))
                unique_written += 1
                if large:
                    large_written += 1
                # Keep a bounded pool of candidates to duplicate; unbounded
                # would hold the whole run in memory at a million events.
                if len(dup_pool) < 2000:
                    dup_pool.append(ev)
                elif rnd.random() < 0.02:
                    dup_pool[rnd.randrange(len(dup_pool))] = ev
            line = json.dumps({"dataset": dataset_id, "event": ev}, separators=(",", ":"))
            fh.write(line + "\n")
            total_bytes += len(line) + 1
            written += 1
            if log and written % 100000 == 0:
                log.dim("  generated %s / %s events" % (f"{written:,}", f"{count:,}"))

    return {
        "path": path,
        "dataset_id": dataset_id,
        "lines": written,
        "unique_events": unique_written,
        "duplicate_events": dups_written,
        "expected_rows_after_dedup": unique_written,
        "large_events": large_written,
        "large_fraction_actual": round(large_written / float(unique_written), 4)
        if unique_written else 0,
        "bytes": total_bytes,
        "avg_event_bytes": int(total_bytes / written) if written else 0,
        "users": len(users),
        "generated_at": now_ms,
        "timestamp_spread_minutes": load["timestamp_spread_minutes"],
    }


def write_wrapped(path, dataset_id, events):
    """Small helper for the functional-validation event set."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    with open(path, "w", encoding="utf-8") as fh:
        for ev in events:
            fh.write(json.dumps({"dataset": dataset_id, "event": ev},
                                separators=(",", ":")) + "\n")
    return path


def run(ctx):
    """Agent entrypoint: generate users + the load file, record the manifest."""
    cfg, log = ctx.cfg, ctx.log
    log.phase("Telemetry Generation Agent", "users and event corpus")

    users = generate_users(cfg["users"]["count"], cfg["users"]["seed"])
    users_path = os.path.join(ctx.dir("data"), "users.ndjson")
    write_users_ndjson(users, users_path)
    log.info("%d user profiles -> %s" % (len(users), _rel(ctx, users_path)))
    ctx.users = users

    count = cfg["load"]["events"]
    load_path = os.path.join(ctx.dir("data"), "telemetry.ndjson")
    log.step("generating %s telemetry events" % f"{count:,}")
    manifest = generate_telemetry(load_path, cfg["datasets"]["telemetry_id"],
                                  count, users, cfg, log)
    log.info("%s lines, %s unique, %s duplicates, avg %d B/event, %.1f MB total"
             % (f"{manifest['lines']:,}", f"{manifest['unique_events']:,}",
                f"{manifest['duplicate_events']:,}", manifest["avg_event_bytes"],
                manifest["bytes"] / 1048576.0))
    ctx.results["generation"] = manifest
    ctx.load_file = load_path
    ctx.users_file = users_path
    return manifest


def _rel(ctx, path):
    try:
        return os.path.relpath(path, ctx.run_dir)
    except ValueError:
        return path
