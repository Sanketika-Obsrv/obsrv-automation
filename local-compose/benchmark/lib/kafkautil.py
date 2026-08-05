"""Kafka: offsets, consumer-group lag, and the bulk producer.

No kafka-python here. Everything runs the broker's own shipped CLI tools
inside the container, which means zero pip dependencies and, for the
producer, a real JVM client rather than a hand-rolled protocol
implementation. `kafka-console-producer` sustains tens of thousands of
messages/second, which is well past what this deployment can consume -- so
the producer is not the thing being measured.
"""

import os
import re
import subprocess
import threading
import time

from . import shell


class Kafka:
    def __init__(self, cfg, log, docker):
        self.cfg, self.log, self.d = cfg, log, docker
        k = cfg["kafka"]
        self.bootstrap = k["bootstrap_internal"]
        self.bin = cfg["docker"].get("kafka_bin", "/opt/kafka/bin")
        self.ingest_topic = k["ingest_topic"]
        self.group = k["consumer_group"]

    def _tool(self, name):
        return "%s/%s.sh" % (self.bin, name)

    # --- topics ------------------------------------------------------------
    def topics(self):
        _, o, _ = self.d.exec("kafka", [
            self._tool("kafka-topics"), "--bootstrap-server", self.bootstrap, "--list"
        ], timeout=60)
        return sorted(t.strip() for t in o.splitlines() if t.strip())

    def topic_exists(self, topic):
        return topic in self.topics()

    def partitions(self, topic):
        _, o, _ = self.d.exec("kafka", [
            self._tool("kafka-topics"), "--bootstrap-server", self.bootstrap,
            "--describe", "--topic", topic], check=False, timeout=60)
        return sum(1 for ln in o.splitlines() if ln.strip().startswith("Topic:")
                   and "Partition:" in ln)

    def end_offsets(self, topic):
        """{partition: log_end_offset}. The producer-side total for a topic.

        Two spellings, because this is the number every throughput figure is
        derived from and the tool for it was renamed. Kafka 3.x ships
        kafka-get-offsets.sh; kafka.tools.GetOffsetShell was removed, and
        invoking it prints nothing and exits 1. Both emit topic:partition:offset,
        so only the invocation differs.

        An empty result here used to be indistinguishable from a genuinely
        empty topic, which is how a broken probe reported "0 of 2,000 events
        reached the topic" while the topic held 3,600. It raises now.
        """
        attempts = (
            [self._tool("kafka-get-offsets"), "--bootstrap-server", self.bootstrap,
             "--topic", topic, "--time", "-1"],
            [self._tool("kafka-run-class"), "kafka.tools.GetOffsetShell",
             "--bootstrap-server", self.bootstrap, "--topic", topic, "--time", "-1"],
        )
        last = ""
        for argv in attempts:
            rc, o, err = self.d.exec("kafka", argv, check=False, timeout=90)
            out = self._parse_offsets(topic, o)
            if out:
                return out
            if rc == 0:
                return out          # tool ran and the topic really has no partitions
            last = (err or o or "").strip()
        raise shell.CmdError(["kafka-get-offsets", topic], 1, "",
                             "no offset tool worked in the broker container: %s"
                             % (last[:300] or "no output"))

    @staticmethod
    def _parse_offsets(topic, out):
        parsed = {}
        for line in out.splitlines():
            parts = line.strip().split(":")
            if len(parts) == 3 and parts[0] == topic:
                try:
                    parsed[int(parts[1])] = int(parts[2])
                except ValueError:
                    pass
        return parsed

    def total_end_offset(self, topic):
        return sum(self.end_offsets(topic).values())

    # --- consumer groups ---------------------------------------------------
    def groups(self):
        _, o, _ = self.d.exec("kafka", [
            self._tool("kafka-consumer-groups"), "--bootstrap-server", self.bootstrap,
            "--list"], check=False, timeout=90)
        return sorted(g.strip() for g in o.splitlines() if g.strip())

    def describe_group(self, group=None, timeout=120):
        """[{topic, partition, current, end, lag}] for one consumer group.

        Parsed positionally from the CLI's fixed column order rather than by
        header name: the header row itself is what tells us the columns are in
        the expected order, and the tool has kept this layout since 0.11.
        """
        group = group or self.group
        rc, o, _ = self.d.exec("kafka", [
            self._tool("kafka-consumer-groups"), "--bootstrap-server", self.bootstrap,
            "--describe", "--group", group], check=False, timeout=timeout)
        rows = []
        for line in o.splitlines():
            parts = line.split()
            if len(parts) < 6 or parts[0] != group:
                continue
            topic, part, cur, end, lag = parts[1], parts[2], parts[3], parts[4], parts[5]
            try:
                rows.append({
                    "topic": topic,
                    "partition": int(part),
                    "current": None if cur == "-" else int(cur),
                    "end": None if end == "-" else int(end),
                    "lag": None if lag == "-" else int(lag),
                })
            except ValueError:
                continue
        return rows

    def lag_snapshot(self, topic=None, group=None):
        """Aggregate the group's position on one topic into a single sample.

        `consumed` is the sum of committed offsets, which is the counter the
        throughput derivation differentiates. `remaining` is the backlog still
        to process -- the number the ETA is computed from.
        """
        topic = topic or self.ingest_topic
        rows = [r for r in self.describe_group(group) if r["topic"] == topic]
        consumed = sum(r["current"] or 0 for r in rows)
        end = sum(r["end"] or 0 for r in rows)
        lag = sum(r["lag"] or 0 for r in rows)
        return {
            "topic": topic,
            "partitions": len(rows),
            "consumed": consumed,
            "end_offset": end,
            "remaining": lag,
            "assigned": sum(1 for r in rows if r["current"] is not None),
        }

    def reset_group_to_latest(self, topic=None, group=None):
        """Skip an existing backlog. Only used by cleanup, never mid-run."""
        topic = topic or self.ingest_topic
        return self.d.exec("kafka", [
            self._tool("kafka-consumer-groups"), "--bootstrap-server", self.bootstrap,
            "--group", group or self.group, "--topic", topic,
            "--reset-offsets", "--to-latest", "--execute"], check=False, timeout=120)

    # --- producing ---------------------------------------------------------
    def produce_file(self, topic, local_path, workers=1, rate=0, batch_size=5000,
                     on_progress=None):
        """Ship an NDJSON file into `topic` and return timing.

        The file is copied into the broker once and then split across `workers`
        console-producer processes by line stride, so N producers each send
        every Nth line. Splitting by stride rather than by contiguous block
        matters when the load is later analysed per-partition: contiguous
        blocks would give each producer a distinct time range of events, and
        the resulting per-partition skew would look like a pipeline problem.

        rate > 0 paces the whole job (events/sec, shared across workers) by
        feeding stdin in batches with a sleep between them. rate == 0 lets the
        broker set the pace, which is what a backlog-generation phase wants.
        """
        remote = "/tmp/obsrv-bench-%d.ndjson" % int(time.time())
        total = _line_count(local_path)
        self.log.dim("  copying %s lines into the broker" % f"{total:,}")
        self.d.cp_to("kafka", local_path, remote)

        t0 = time.time()
        errors = []
        if rate <= 0 and workers == 1:
            self._produce_stream(topic, remote, None, 1, 0, errors)
        else:
            threads = []
            per_worker_rate = (rate / float(workers)) if rate > 0 else 0
            for w in range(workers):
                th = threading.Thread(
                    target=self._produce_stream,
                    args=(topic, remote, w, workers, per_worker_rate, errors),
                    daemon=True)
                th.start()
                threads.append(th)
            while any(t.is_alive() for t in threads):
                if on_progress:
                    on_progress(time.time() - t0)
                time.sleep(1)
            for t in threads:
                t.join()
        elapsed = time.time() - t0
        self.d.sh("kafka", "rm -f %s" % remote, check=False)
        if errors:
            raise shell.CmdError(["kafka-console-producer"], 1, "", "; ".join(errors[:3]))
        return {"events": total, "seconds": round(elapsed, 3),
                "rate_per_sec": round(total / elapsed, 1) if elapsed > 0 else 0}

    def _produce_stream(self, topic, remote, worker, workers, rate, errors):
        """One console-producer fed by awk-strided lines from the copied file."""
        if worker is None or workers == 1:
            feed = "cat %s" % remote
        else:
            feed = "awk 'NR %% %d == %d' %s" % (workers, worker % workers, remote)
        producer = (
            "%s --bootstrap-server %s --topic %s "
            "--producer-property acks=1 "
            "--producer-property linger.ms=20 "
            "--producer-property batch.size=131072 "
            "--producer-property compression.type=lz4"
            % (self._tool("kafka-console-producer"), self.bootstrap, topic)
        )
        if rate and rate > 0:
            # Pace with a shell loop rather than in Python: keeping the data
            # inside the container avoids streaming every event across the
            # docker exec pipe, which becomes the bottleneck well before the
            # broker does.
            script = (
                "%s | awk -v rate=%d 'BEGIN{n=0} {print; n++; "
                "if (n %% rate == 0) system(\"sleep 1\")}' | %s"
                % (feed, max(int(rate), 1), producer)
            )
        else:
            script = "%s | %s" % (feed, producer)
        rc, out, err = self.d.sh("kafka", script, check=False, timeout=7200)
        if rc != 0:
            errors.append((err or out or "rc=%d" % rc).strip()[:500])

    def produce_lines(self, topic, lines, timeout=300):
        """Small synchronous send, for the functional-validation events."""
        payload = "\n".join(lines) + "\n"
        rc, o, err = self.d.exec("kafka", [
            self._tool("kafka-console-producer"), "--bootstrap-server", self.bootstrap,
            "--topic", topic], stdin=payload, check=False, timeout=timeout)
        if rc != 0:
            raise shell.CmdError(["kafka-console-producer"], rc, o, err)
        return len(lines)

    # --- failure topics ----------------------------------------------------
    def failed_counts(self):
        """End offsets of the pipeline's dead-letter topics.

        Any non-zero value here means events were rejected, and a benchmark
        that reports throughput while silently dropping a third of its input
        is worse than no benchmark.
        """
        have = set(self.topics())
        out = {}
        for t in self.cfg["kafka"]["failed_topics"]:
            if t in have:
                out[t] = self.total_end_offset(t)
        return out

    def failed_offsets(self):
        """{topic: {partition: end_offset}} for the dead-letter topics.

        Per partition rather than a single total, because deciding whether a
        run lost anything means reading back exactly the messages that run
        appended and looking at their error codes. A total says how many
        arrived but not where in each partition to start reading, and reading
        an approximate tail instead pulls in older rejections -- which is the
        same mistake as comparing against no baseline at all, just smaller.
        """
        have = set(self.topics())
        return {t: self.end_offsets(t)
                for t in self.cfg["kafka"]["failed_topics"] if t in have}

    def read_range(self, topic, partition, start, end, timeout=90):
        """Raw message lines in [start, end) of one partition.

        The consumer is given an idle timeout and always exits non-zero when it
        trips, so rc is ignored: with --max-messages satisfied it has already
        printed everything asked for.
        """
        if end <= start:
            return []
        _, out, _ = self.d.exec("kafka", [
            self._tool("kafka-console-consumer"),
            "--bootstrap-server", self.bootstrap, "--topic", topic,
            "--partition", str(partition), "--offset", str(start),
            "--max-messages", str(end - start),
            "--timeout-ms", str(int(timeout * 1000))],
            check=False, timeout=timeout + 30)
        return [ln for ln in out.splitlines() if ln.strip()]

    _ERR_CODE = re.compile(r"ERR_[A-Z]+_\d+")

    def classify_failed(self, topic, ranges, timeout=90):
        """Count dead-letter messages by Obsrv error code.

        `ranges` is {partition: (start_offset, end_offset)}. The distinction
        that matters to a caller is ERR_PP_1010 -- the duplicate check refusing
        a mid whose row is already in the datasource -- against everything
        else, which is an event with no row anywhere.
        """
        counts = {}
        for p, (start, end) in sorted(ranges.items()):
            for line in self.read_range(topic, p, start, end, timeout=timeout):
                m = self._ERR_CODE.search(line)
                code = m.group(0) if m else "UNKNOWN"
                counts[code] = counts.get(code, 0) + 1
        return counts


def _line_count(path):
    n = 0
    with open(path, "rb") as fh:
        for _ in fh:
            n += 1
    return n
