"""Autonomous benchmarking framework for a Mini Obsrv deployment.

Standard library only, on purpose. The host this runs against has Python but
no pyyaml, requests or kafka-python, and "one command, no manual intervention"
stops being true the moment an agent has to pip-install something first.

Layout:
    lib/       infrastructure -- clients, config, stats, logging, reporting
    agents/    the specialized execution agents, one concern each
    scripts/   standalone CLIs, each usable without running a full benchmark
    orchestrator.py  the eighteen-step unattended run
"""

__version__ = "1.0.0"
