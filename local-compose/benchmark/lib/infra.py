"""Host and per-container CPU / memory / disk / network sampling.

Per-container numbers come from the cgroup files rather than `docker stats`,
for two reasons. `docker stats` reports memory including page cache, which for
Postgres and Keycloak alone is well over 100 MB of reclaimable noise -- sizing
a deployment off that number over-provisions it. And `docker stats` costs a
full second per call because it samples CPU over an interval; reading
cpu.stat twice and differencing gives the same answer without blocking the
poll loop.

Host-level numbers come from node-exporter when it is running (it is part of
the metrics profile) and fall back to the cgroup root otherwise.
"""

import re
import time

from . import httpc


class Infra:
    def __init__(self, cfg, log, docker):
        self.cfg, self.log, self.d = cfg, log, docker
        self.prom = cfg["endpoints"]["prometheus"].rstrip("/")
        self._prev_cpu = {}
        self._prev_net = {}
        self._cores = None

    # --- capability probes -------------------------------------------------
    def prometheus_up(self):
        return httpc.reachable("%s/-/ready" % self.prom, timeout=3)

    def cores(self):
        if self._cores is None:
            out = self.d.sh("kafka", "nproc", check=False)[1].strip()
            try:
                self._cores = int(out)
            except ValueError:
                self._cores = 1
        return self._cores

    # --- per-container cgroup reads ----------------------------------------
    def _cgroup(self, role, path):
        rc, o, _ = self.d.sh(role, "cat /sys/fs/cgroup/%s 2>/dev/null" % path, check=False,
                             timeout=20)
        return o if rc == 0 else ""

    def container_sample(self, role):
        """One CPU/memory sample for a container, as rates where meaningful.

        cpu_pct is derived against the previous call for the same role, so the
        first sample for any container has cpu_pct None -- there is nothing to
        difference against yet.
        """
        now = time.time()
        out = {"role": role, "container": self.d.c(role), "t": now}
        if not self.d.running(role):
            out["state"] = "stopped"
            return out
        out["state"] = "running"

        usage_us = None
        stat = self._cgroup(role, "cpu.stat")
        m = re.search(r"usage_usec\s+(\d+)", stat)
        if m:
            usage_us = int(m.group(1))
        else:
            # cgroup v1 fallback: cpuacct.usage is nanoseconds.
            raw = self._cgroup(role, "cpuacct/cpuacct.usage") or self._cgroup(
                role, "cpuacct.usage")
            if raw.strip().isdigit():
                usage_us = int(raw.strip()) // 1000
        if usage_us is not None:
            prev = self._prev_cpu.get(role)
            self._prev_cpu[role] = (now, usage_us)
            if prev and now > prev[0]:
                delta_cpu_s = (usage_us - prev[1]) / 1e6
                out["cpu_pct"] = round(100.0 * delta_cpu_s / (now - prev[0]), 2)
                out["cpu_cores_used"] = round(delta_cpu_s / (now - prev[0]), 3)
            out["cpu_usage_sec"] = round(usage_us / 1e6, 3)

        mstat = self._cgroup(role, "memory.stat")
        anon = _kv(mstat, "anon")
        fil = _kv(mstat, "file")
        if anon is None:
            anon = _kv(mstat, "rss")          # cgroup v1
            fil = _kv(mstat, "cache")
        out["mem_anon_bytes"] = anon
        out["mem_cache_bytes"] = fil
        cur = self._cgroup(role, "memory.current").strip()
        if cur.isdigit():
            out["mem_current_bytes"] = int(cur)
        lim = self._cgroup(role, "memory.max").strip()
        out["mem_limit_bytes"] = int(lim) if lim.isdigit() else None
        if out.get("mem_limit_bytes") and anon:
            out["mem_pct_of_limit"] = round(100.0 * anon / out["mem_limit_bytes"], 2)
        return out

    def sample_all(self, roles):
        return [self.container_sample(r) for r in roles]

    # --- host level --------------------------------------------------------
    def host_sample(self):
        """CPU / memory / disk / network for the Docker VM as a whole."""
        s = {"t": time.time()}
        if self.prometheus_up():
            s.update(self._host_from_prometheus())
        if "cpu_pct" not in s:
            s.update(self._host_from_container())
        return s

    def _promq(self, expr, default=None):
        try:
            res = httpc.get_json(
                "%s/api/v1/query?query=%s" % (self.prom, _q(expr)), timeout=15)
        except httpc.HttpError:
            return default
        results = ((res or {}).get("data") or {}).get("result") or []
        if not results:
            return default
        try:
            return float(results[0]["value"][1])
        except (KeyError, IndexError, TypeError, ValueError):
            return default

    def _host_from_prometheus(self):
        """node-exporter is scraped by the bundled Prometheus in the metrics
        profile; these are the standard expressions for a single node."""
        out = {}
        cpu_idle = self._promq(
            'avg(rate(node_cpu_seconds_total{mode="idle"}[1m]))')
        if cpu_idle is not None:
            out["cpu_pct"] = round(100.0 * (1.0 - cpu_idle), 2)
        iowait = self._promq('avg(rate(node_cpu_seconds_total{mode="iowait"}[1m]))')
        if iowait is not None:
            out["cpu_iowait_pct"] = round(100.0 * iowait, 2)
        total = self._promq("node_memory_MemTotal_bytes")
        avail = self._promq("node_memory_MemAvailable_bytes")
        if total and avail is not None:
            out["mem_total_bytes"] = int(total)
            out["mem_available_bytes"] = int(avail)
            out["mem_used_bytes"] = int(total - avail)
            out["mem_pct"] = round(100.0 * (total - avail) / total, 2)
        out["load1"] = self._promq("node_load1")
        out["disk_read_bps"] = self._promq("sum(rate(node_disk_read_bytes_total[1m]))")
        out["disk_write_bps"] = self._promq("sum(rate(node_disk_written_bytes_total[1m]))")
        out["disk_io_util"] = self._promq("max(rate(node_disk_io_time_seconds_total[1m]))")
        out["net_rx_bps"] = self._promq(
            'sum(rate(node_network_receive_bytes_total{device!="lo"}[1m]))')
        out["net_tx_bps"] = self._promq(
            'sum(rate(node_network_transmit_bytes_total{device!="lo"}[1m]))')
        fs_avail = self._promq('sum(node_filesystem_avail_bytes{fstype!~"tmpfs|overlay"})')
        fs_size = self._promq('sum(node_filesystem_size_bytes{fstype!~"tmpfs|overlay"})')
        if fs_size:
            out["disk_avail_bytes"] = fs_avail
            out["disk_size_bytes"] = fs_size
            out["disk_pct"] = round(100.0 * (fs_size - (fs_avail or 0)) / fs_size, 2)
        return {k: v for k, v in out.items() if v is not None}

    def _host_from_container(self):
        """Fallback: read the VM's own /proc through a container that has it.

        Every container here shares the VM kernel, so /proc/meminfo and
        /proc/stat inside any of them describe the host.
        """
        out = {}
        rc, o, _ = self.d.sh("kafka", "cat /proc/meminfo", check=False)
        if rc == 0:
            total = _meminfo(o, "MemTotal")
            avail = _meminfo(o, "MemAvailable")
            if total:
                out["mem_total_bytes"] = total
                out["mem_available_bytes"] = avail
                out["mem_used_bytes"] = total - (avail or 0)
                out["mem_pct"] = round(100.0 * (total - (avail or 0)) / total, 2)
        rc, o, _ = self.d.sh("kafka", "cat /proc/stat | head -1", check=False)
        if rc == 0 and o.startswith("cpu "):
            fields = [int(x) for x in o.split()[1:] if x.isdigit()]
            idle = fields[3] + (fields[4] if len(fields) > 4 else 0)
            total = sum(fields)
            prev = self._prev_cpu.get("__host__")
            self._prev_cpu["__host__"] = (total, idle)
            if prev and total > prev[0]:
                out["cpu_pct"] = round(
                    100.0 * (1.0 - (idle - prev[1]) / float(total - prev[0])), 2)
        rc, o, _ = self.d.sh("kafka", "cat /proc/loadavg", check=False)
        if rc == 0 and o.split():
            try:
                out["load1"] = float(o.split()[0])
            except ValueError:
                pass
        return out

    # --- prometheus passthrough for the report -----------------------------
    def flink_operator_rate(self, job_pattern="", window="1m"):
        """Records/sec through Flink operators, from the Prometheus reporter.

        The Flink REST API gives cumulative per-vertex counters; this gives the
        already-differentiated rate, which is a useful cross-check that the
        two agree.
        """
        expr = ('sum(rate(flink_taskmanager_job_task_operator_numRecordsOut[%s]))' % window)
        if job_pattern:
            expr = ('sum(rate(flink_taskmanager_job_task_operator_numRecordsOut'
                    '{job_name=~"%s"}[%s]))' % (job_pattern, window))
        return self._promq(expr)

    def kafka_broker_rate(self, window="1m"):
        return {
            "messages_in_per_sec": self._promq(
                "sum(rate(kafka_server_brokertopicmetrics_messagesin_total[%s]))" % window),
            "bytes_in_per_sec": self._promq(
                "sum(rate(kafka_server_brokertopicmetrics_bytesin_total[%s]))" % window),
        }


def _kv(text, key):
    for line in text.splitlines():
        parts = line.split()
        if len(parts) == 2 and parts[0] == key and parts[1].lstrip("-").isdigit():
            return int(parts[1])
    return None


def _meminfo(text, key):
    for line in text.splitlines():
        if line.startswith(key + ":"):
            parts = line.split()
            if len(parts) >= 2 and parts[1].isdigit():
                return int(parts[1]) * 1024
    return None


def _q(expr):
    import urllib.parse
    return urllib.parse.quote(expr, safe="")


# The containers worth sampling. Roles absent from the deployment (a profile
# without masterdata, say) report state=stopped rather than failing the run.
DEFAULT_ROLES = [
    "kafka", "zookeeper", "postgres", "druid",
    "up_jobmanager", "up_taskmanager", "ci_jobmanager", "ci_taskmanager",
    "valkey_dedup", "valkey_denorm", "dataset_api", "command_api",
    "web_console", "keycloak", "nginx", "prometheus",
]
