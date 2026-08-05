"""Percentiles, rate derivation and CSV output.

Kept separate from the collectors because every collector produces the same
shape of thing -- a time series of samples -- and the analysis of "what rate
does this series imply" should be identical whether the series came from
Kafka offsets, Druid row counts or cgroup counters.
"""

import csv
import math
import os


def pct(values, p):
    """Nearest-rank percentile. Empty -> None."""
    xs = sorted(v for v in values if v is not None)
    if not xs:
        return None
    if len(xs) == 1:
        return xs[0]
    k = (len(xs) - 1) * (p / 100.0)
    lo, hi = math.floor(k), math.ceil(k)
    if lo == hi:
        return xs[int(k)]
    return xs[lo] + (xs[hi] - xs[lo]) * (k - lo)


def summarize(values, unit=""):
    """The latency/throughput summary block used everywhere in the reports."""
    xs = [v for v in values if v is not None]
    if not xs:
        return {"count": 0, "unit": unit}
    xs_sorted = sorted(xs)
    return {
        "count": len(xs),
        "unit": unit,
        "min": round(xs_sorted[0], 3),
        "avg": round(sum(xs) / len(xs), 3),
        "p50": round(pct(xs, 50), 3),
        "p90": round(pct(xs, 90), 3),
        "p95": round(pct(xs, 95), 3),
        "p99": round(pct(xs, 99), 3),
        "max": round(xs_sorted[-1], 3),
        "stdev": round(_stdev(xs), 3),
    }


def _stdev(xs):
    if len(xs) < 2:
        return 0.0
    mean = sum(xs) / len(xs)
    return math.sqrt(sum((x - mean) ** 2 for x in xs) / (len(xs) - 1))


def deltas(samples, key, tkey="t"):
    """[(t_mid, per_second_rate)] from a monotonic counter series.

    Non-monotonic steps are dropped rather than reported as a negative rate:
    Kafka offsets can go backwards when a topic is recreated, and a negative
    "throughput" in a capacity report is worse than a missing point.
    """
    out = []
    for a, b in zip(samples, samples[1:]):
        dt = b[tkey] - a[tkey]
        dv = (b.get(key) or 0) - (a.get(key) or 0)
        if dt > 0 and dv >= 0:
            out.append(((a[tkey] + b[tkey]) / 2.0, dv / dt))
    return out


def rate_summary(samples, key, tkey="t"):
    """Sustained vs peak, the two numbers the executive summary asks for.

    Sustained is the median of the per-interval rates rather than the mean,
    because a run that includes the ramp-up and the tail-off (both near zero)
    would otherwise report a "sustained" rate well below what the system
    actually held. Peak is p95 rather than max for the same reason in reverse:
    a single short sampling interval can produce an outlier that no
    infrastructure decision should be based on.
    """
    rates = [r for _, r in deltas(samples, key, tkey)]
    if not rates:
        return {"samples": 0}
    nz = [r for r in rates if r > 0]
    return {
        "samples": len(rates),
        "sustained_per_sec": round(pct(nz, 50) or 0.0, 2),
        "sustained_per_min": round((pct(nz, 50) or 0.0) * 60, 1),
        "peak_per_sec": round(pct(rates, 95) or 0.0, 2),
        "peak_per_min": round((pct(rates, 95) or 0.0) * 60, 1),
        "max_per_sec": round(max(rates), 2),
        "mean_per_sec": round(sum(rates) / len(rates), 2),
        "total": round((samples[-1].get(key) or 0) - (samples[0].get(key) or 0), 2),
        "window_sec": round(samples[-1][tkey] - samples[0][tkey], 2),
    }


def write_csv(path, rows, columns=None):
    """Write rows (list of dicts) to CSV. Union of keys, stable order."""
    os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
    if columns is None:
        columns, seen = [], set()
        for r in rows:
            for k in r:
                if k not in seen:
                    seen.add(k)
                    columns.append(k)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        w = csv.DictWriter(fh, fieldnames=columns, extrasaction="ignore")
        w.writeheader()
        for r in rows:
            w.writerow(r)
    return path


def human_count(n):
    if n is None:
        return "-"
    n = float(n)
    for unit, div in (("M", 1e6), ("K", 1e3)):
        if abs(n) >= div:
            return "%.2f%s" % (n / div, unit)
    return "%.0f" % n if abs(n) >= 10 else "%.2f" % n


def human_bytes(n):
    if n is None:
        return "-"
    n = float(n)
    for unit in ("B", "KiB", "MiB", "GiB", "TiB"):
        if abs(n) < 1024 or unit == "TiB":
            return "%.1f %s" % (n, unit)
        n /= 1024.0


def human_dur(seconds):
    if seconds is None:
        return "-"
    s = int(round(seconds))
    if s < 60:
        return "%ds" % s
    if s < 3600:
        return "%dm%02ds" % (s // 60, s % 60)
    return "%dh%02dm" % (s // 3600, (s % 3600) // 60)
