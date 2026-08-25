"""The run context: every client, path and shared result the agents use.

One object rather than nine globals, so a single script can build a partial
context (say, just Druid) and call one agent without dragging the whole
deployment up. Everything constructed here is lazy in the sense that no client
touches the network until it is used, so `Context(cfg)` succeeds even when
half the stack is down -- which is exactly the state in which you want to run
the diagnostics.
"""

import os
import time

from . import config as config_lib
from .druid import Druid
from .flink import Flink
from .infra import Infra
from .kafkautil import Kafka
from .log import Log
from .obsrv_api import ObsrvApi
from .sampler import Sampler
from .shell import Docker


class Context:
    def __init__(self, cfg, log=None, run_dir=None, with_sampler=True):
        self.cfg = cfg
        self.started_at = time.time()
        self.run_dir = run_dir or config_lib.run_dir(cfg)
        os.makedirs(self.run_dir, exist_ok=True)

        self.log = log or Log(os.path.join(self.run_dir, "run.jsonl"))
        self.docker = Docker(cfg, self.log)
        self.api = ObsrvApi(cfg, self.log)
        self.druid = Druid(cfg, self.log)
        self.kafka = Kafka(cfg, self.log, self.docker)
        self.infra = Infra(cfg, self.log, self.docker)
        self.pipeline = Flink(cfg, self.log, self.docker, which="unified")
        # The cache indexer is optional: without the masterdata compose profile
        # the deployment still ingests telemetry, it just cannot denormalize.
        # Treating its absence as fatal here would stop a run that is perfectly
        # able to produce throughput numbers.
        self.cache_indexer = (Flink(cfg, self.log, self.docker, which="cache_indexer")
                              if self.docker.running("ci_jobmanager") else None)

        self.results = {}
        self.users = []
        self.users_file = None
        self.load_file = None
        self.entry_topic = cfg["kafka"]["ingest_topic"]
        self.drain_start = None
        self.drain_end = None
        self.settle_end = None
        self.sampler = Sampler(self, cfg["datasets"]["telemetry_id"]) if with_sampler else None

    def dir(self, name):
        """A subdirectory of the run directory, created on first use."""
        path = os.path.join(self.run_dir, name)
        os.makedirs(path, exist_ok=True)
        return path

    def rel(self, path):
        try:
            return os.path.relpath(path, self.run_dir)
        except ValueError:
            return path

    def close(self):
        if self.sampler:
            self.sampler.stop()
        self.log.close()
