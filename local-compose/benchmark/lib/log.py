"""Console output plus a machine-readable event log.

Two audiences: a human watching a 20-minute benchmark scroll past, and the
AI agent that reads results afterwards. Everything printed is also appended
to run.jsonl as a structured record, so an agent never has to scrape ANSI
codes out of a terminal transcript to find out what happened.
"""

import json
import os
import sys
import time

_BOLD, _RED, _GREEN, _YELLOW, _DIM, _OFF = (
    "\033[1m",
    "\033[31m",
    "\033[32m",
    "\033[33m",
    "\033[2m",
    "\033[0m",
)

if not sys.stdout.isatty() or os.environ.get("NO_COLOR"):
    _BOLD = _RED = _GREEN = _YELLOW = _DIM = _OFF = ""


class Log:
    def __init__(self, path=None, quiet=False):
        self.path = path
        self.quiet = quiet
        self.t0 = time.time()
        self._fh = None
        if path:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            self._fh = open(path, "a", encoding="utf-8", buffering=1)

    # --- structured sink ---------------------------------------------------
    def event(self, kind, **fields):
        """Append one record to run.jsonl. Never printed."""
        if not self._fh:
            return
        rec = {"ts": round(time.time(), 3), "elapsed": round(time.time() - self.t0, 3),
               "kind": kind}
        rec.update(fields)
        self._fh.write(json.dumps(rec, default=str) + "\n")

    # --- human sink --------------------------------------------------------
    def _out(self, text):
        if not self.quiet:
            sys.stdout.write(text)
            sys.stdout.flush()

    def phase(self, name, detail=""):
        self._out("\n%s=== %s%s%s\n" % (_BOLD, name, (" -- " + detail) if detail else "", _OFF))
        self.event("phase", name=name, detail=detail)

    def step(self, msg):
        self._out("%s--> %s%s\n" % (_BOLD, msg, _OFF))
        self.event("step", msg=msg)

    def info(self, msg):
        self._out("    %s\n" % msg)
        self.event("info", msg=msg)

    def dim(self, msg):
        self._out("%s    %s%s\n" % (_DIM, msg, _OFF))
        self.event("debug", msg=msg)

    def ok(self, msg):
        self._out("%s    PASS %s%s\n" % (_GREEN, msg, _OFF))
        self.event("ok", msg=msg)

    def warn(self, msg):
        self._out("%s    WARN %s%s\n" % (_YELLOW, msg, _OFF))
        self.event("warn", msg=msg)

    def error(self, msg):
        self._out("%s    FAIL %s%s\n" % (_RED, msg, _OFF))
        self.event("error", msg=msg)

    def table(self, headers, rows):
        """Fixed-width table; the same data always also goes out as CSV."""
        cols = [len(h) for h in headers]
        srows = [[("" if c is None else str(c)) for c in r] for r in rows]
        for r in srows:
            for i, c in enumerate(r):
                if i < len(cols):
                    cols[i] = max(cols[i], len(c))
        fmt = "    " + "  ".join("%-" + str(w) + "s" for w in cols)
        self._out("%s%s%s\n" % (_DIM, fmt % tuple(headers), _OFF))
        for r in srows:
            self._out(fmt % tuple(r + [""] * (len(cols) - len(r))) + "\n")
        self.event("table", headers=headers, rows=rows)

    def close(self):
        if self._fh:
            self._fh.close()
            self._fh = None


class Fatal(RuntimeError):
    """Raised for a condition that makes the rest of the run meaningless.

    The orchestrator catches it, still writes whatever reports it can from
    the phases that did complete, and exits non-zero -- a half-finished run
    with an honest report beats a traceback.
    """
