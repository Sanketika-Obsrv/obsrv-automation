"""A small JSON-over-HTTP client on urllib, with per-call timing.

urllib rather than requests because the host may not have requests, and a
benchmark framework that cannot start until someone runs pip is not
autonomous. The timing return is the reason this is a module rather than
three inline calls: the query benchmark needs the latency of every single
request, measured as close to the socket as this can get.
"""

import base64
import json
import time
import urllib.error
import urllib.parse
import urllib.request


class HttpError(RuntimeError):
    def __init__(self, url, code, body):
        self.url, self.code, self.body = url, code, body
        super().__init__("HTTP %s from %s: %s" % (code, url, (body or "")[:1000]))


def request(url, method="GET", body=None, headers=None, timeout=60, basic=None, bearer=None,
            raw=False):
    """Return (status, parsed_json_or_text, elapsed_seconds).

    Raises HttpError for >=400 so callers do not have to check twice, except
    that the caller can catch it and still read .code and .body -- several
    Obsrv endpoints answer 404/428 with a meaningful error envelope.
    """
    hdrs = {"Accept": "application/json"}
    if headers:
        hdrs.update(headers)
    data = None
    if body is not None:
        if isinstance(body, (dict, list)):
            data = json.dumps(body).encode()
            hdrs.setdefault("Content-Type", "application/json")
        elif isinstance(body, str):
            data = body.encode()
        else:
            data = body
    if basic:
        hdrs["Authorization"] = "Basic " + base64.b64encode(
            ("%s:%s" % basic).encode()).decode()
    if bearer:
        hdrs["Authorization"] = "Bearer " + bearer

    req = urllib.request.Request(url, data=data, headers=hdrs, method=method)
    t0 = time.perf_counter()
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            payload = resp.read()
            elapsed = time.perf_counter() - t0
            status = resp.status
    except urllib.error.HTTPError as e:
        payload = e.read()
        elapsed = time.perf_counter() - t0
        text = payload.decode("utf-8", "replace")
        raise HttpError(url, e.code, text)
    except (urllib.error.URLError, TimeoutError, OSError) as e:
        raise HttpError(url, "connect", str(e))

    text = payload.decode("utf-8", "replace")
    if raw:
        return status, text, elapsed
    try:
        return status, json.loads(text) if text.strip() else None, elapsed
    except ValueError:
        return status, text, elapsed


def get_json(url, **kw):
    return request(url, "GET", **kw)[1]


def post_json(url, body, **kw):
    return request(url, "POST", body=body, **kw)[1]


def form_post(url, fields, timeout=30):
    """application/x-www-form-urlencoded -- only Keycloak's token endpoint."""
    return request(
        url, "POST", body=urllib.parse.urlencode(fields),
        headers={"Content-Type": "application/x-www-form-urlencoded"}, timeout=timeout,
    )[1]


def reachable(url, timeout=3):
    try:
        request(url, timeout=timeout)
        return True
    except HttpError as e:
        # Any HTTP answer at all proves the port is open; only a connect
        # failure means the service is not there.
        return e.code != "connect"
