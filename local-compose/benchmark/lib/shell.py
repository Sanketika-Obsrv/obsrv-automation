"""Subprocess and docker helpers.

Everything that has to reach inside a container goes through here, so the
container names and the compose invocation live in exactly one place.
"""

import os
import subprocess


class CmdError(RuntimeError):
    def __init__(self, cmd, rc, out, err):
        self.cmd, self.rc, self.out, self.err = cmd, rc, out, err
        super().__init__("exit %d: %s\n%s" % (rc, " ".join(cmd), (err or out or "").strip()[:2000]))


def run(cmd, check=True, timeout=120, stdin=None, cwd=None, env=None):
    """Run argv and return (rc, stdout, stderr) with output decoded."""
    full_env = None
    if env:
        full_env = dict(os.environ)
        full_env.update(env)
    p = subprocess.run(
        cmd, capture_output=True, timeout=timeout, cwd=cwd, env=full_env,
        input=stdin.encode() if isinstance(stdin, str) else stdin,
    )
    out = p.stdout.decode("utf-8", "replace")
    err = p.stderr.decode("utf-8", "replace")
    if check and p.returncode != 0:
        raise CmdError(cmd, p.returncode, out, err)
    return p.returncode, out, err


def out(cmd, **kw):
    """stdout only, stripped -- for the many one-line reads."""
    return run(cmd, **kw)[1].strip()


class Docker:
    """Compose- and container-level operations for one deployment."""

    def __init__(self, cfg, log):
        self.log = log
        d = cfg.get("docker", {}) or {}
        self.project_dir = d.get("compose_dir") or os.path.abspath(
            os.path.join(os.path.dirname(__file__), "..", "..")
        )
        self.compose_file = d.get("compose_file", "docker-compose.yaml")
        self.prefix = d.get("container_prefix", "obsrv")
        self.names = dict(_DEFAULT_NAMES)
        self.names.update(d.get("containers", {}) or {})

    def c(self, role):
        """Container name for a logical role ('kafka', 'druid', ...)."""
        name = self.names.get(role, role)
        return name if name.startswith(self.prefix) else "%s-%s" % (self.prefix, name)

    def exec(self, role, argv, check=True, timeout=180, stdin=None, interactive=False):
        base = ["docker", "exec"]
        if interactive or stdin is not None:
            base.append("-i")
        return run(base + [self.c(role)] + argv, check=check, timeout=timeout, stdin=stdin)

    def sh(self, role, script, check=True, timeout=180, stdin=None):
        """Run a shell one-liner in a container. `sh -c`, not bash: several of
        these images (kafka, valkey, keycloak) have no bash."""
        return self.exec(role, ["sh", "-c", script], check=check, timeout=timeout, stdin=stdin)

    def cp_to(self, role, local_path, remote_path):
        run(["docker", "cp", local_path, "%s:%s" % (self.c(role), remote_path)], timeout=600)

    def compose(self, args, check=True, timeout=600):
        return run(
            ["docker", "compose", "-f", self.compose_file] + args,
            check=check, timeout=timeout, cwd=self.project_dir,
        )

    def running(self, role):
        rc, o, _ = run(
            ["docker", "inspect", "-f", "{{.State.Running}}", self.c(role)], check=False
        )
        return rc == 0 and o.strip() == "true"

    def state(self, role):
        rc, o, _ = run(
            ["docker", "inspect", "-f",
             "{{.State.Status}}|{{if .State.Health}}{{.State.Health.Status}}{{else}}-{{end}}",
             self.c(role)], check=False)
        if rc != 0:
            return ("missing", "-")
        parts = o.strip().split("|")
        return (parts[0], parts[1] if len(parts) > 1 else "-")

    def logs(self, role, since="10m", tail=None):
        """Container logs. Used to read the Flink enumerator's partition
        announcements, which are not exposed through any REST endpoint."""
        cmd = ["docker", "logs", "--since", since]
        if tail:
            cmd += ["--tail", str(tail)]
        rc, o, e = run(cmd + [self.c(role)], check=False, timeout=120)
        return (o or "") + (e or "")

    def ps(self):
        """[(name, status)] for every container in the project."""
        o = out(["docker", "ps", "-a", "--format", "{{.Names}}\t{{.Status}}"], check=False)
        rows = []
        for line in o.splitlines():
            if not line.strip():
                continue
            name, _, status = line.partition("\t")
            if name.startswith(self.prefix):
                rows.append((name, status))
        return sorted(rows)

    def psql(self, sql, timeout=60):
        """One-column-per-line tuples-only query against the metadata store."""
        rc, o, err = self.exec(
            "postgres",
            ["psql", "-U", self.names.get("pg_user", "obsrv"),
             "-d", self.names.get("pg_db", "obsrv"), "-tAc", sql],
            check=False, timeout=timeout,
        )
        if rc != 0:
            raise CmdError(["psql"], rc, o, err)
        return [ln.strip() for ln in o.splitlines() if ln.strip()]

    def psql_one(self, sql, default=None):
        rows = self.psql(sql)
        return rows[0] if rows else default


_DEFAULT_NAMES = {
    "kafka": "obsrv-kafka",
    "zookeeper": "obsrv-zookeeper",
    "postgres": "obsrv-postgres",
    "druid": "obsrv-druid",
    "nginx": "obsrv-nginx",
    "dataset_api": "obsrv-dataset-api",
    "command_api": "obsrv-command-api",
    "web_console": "obsrv-web-console",
    "keycloak": "obsrv-keycloak",
    "prometheus": "obsrv-prometheus",
    "node_exporter": "obsrv-node-exporter",
    "valkey_dedup": "obsrv-valkey-dedup",
    "valkey_denorm": "obsrv-valkey-denorm",
    "up_jobmanager": "obsrv-unified-pipeline-jobmanager",
    "up_taskmanager": "obsrv-unified-pipeline-taskmanager",
    "ci_jobmanager": "obsrv-cache-indexer-jobmanager",
    "ci_taskmanager": "obsrv-cache-indexer-taskmanager",
}
