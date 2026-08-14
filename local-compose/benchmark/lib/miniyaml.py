"""A YAML subset loader, so the framework has no pip dependencies.

The host this runs on is whatever laptop the stack is on, and requiring
`pip install pyyaml` before a benchmark can start is exactly the kind of
friction that stops another agent from being able to run this unattended.
PyYAML is used when it happens to be importable and this is the fallback.

What is supported is the subset benchmark-config.yaml actually uses:
nested block mappings, block sequences of scalars and of mappings, `key:`
with an empty value meaning an empty container, quoted and bare scalars,
ints, floats, underscore-separated ints (1_000_000), bools, null, and
`#` comments. What is NOT supported -- flow collections ({a: 1}, [1, 2]),
anchors, multi-document streams, block scalars (| and >) -- raises rather
than silently mis-parsing, because a config file that parses to the wrong
thing produces a benchmark report full of confidently wrong numbers.
"""

import re

try:  # pragma: no cover - depends on the host
    import yaml as _pyyaml
except ImportError:
    _pyyaml = None


class YamlError(ValueError):
    pass


_INT_RE = re.compile(r"^[-+]?\d+(_\d+)*$")
_FLOAT_RE = re.compile(r"^[-+]?(\d+(_\d+)*\.\d*|\.\d+|\d+(_\d+)*[eE][-+]?\d+)$")


def _scalar(raw, lineno):
    """Convert one bare or quoted scalar to a Python value."""
    s = raw.strip()
    if not s:
        return None
    if s[0] in "\"'":
        if len(s) < 2 or s[-1] != s[0]:
            raise YamlError("line %d: unterminated quote: %s" % (lineno, raw))
        body = s[1:-1]
        # Only the escapes that show up in practice; a double-quoted JSONata
        # expression needs \" and a Windows path would need \\.
        if s[0] == '"':
            body = body.replace('\\"', '"').replace("\\\\", "\\").replace("\\n", "\n")
        return body
    if s in ("{}", "[]"):
        return {} if s == "{}" else []
    if s[0] == "[" and s[-1] == "]":
        # Flow sequences of scalars only -- [400, 4000], [10000, 100000]. That
        # covers every list in the config; a nested flow collection is a sign
        # the config wants a block sequence instead.
        return [_scalar(item, lineno) for item in _split_flow(s[1:-1], lineno)]
    if s[0] in "{[":
        raise YamlError("line %d: flow collections are not supported: %s" % (lineno, s))
    low = s.lower()
    if low in ("null", "~"):
        return None
    if low in ("true", "yes", "on"):
        return True
    if low in ("false", "no", "off"):
        return False
    if _INT_RE.match(s):
        return int(s.replace("_", ""))
    if _FLOAT_RE.match(s):
        return float(s.replace("_", ""))
    return s


def _split_flow(body, lineno):
    """Split a flow sequence's body on commas that are not inside quotes."""
    items, cur, quote = [], [], None
    for i, ch in enumerate(body):
        if quote:
            cur.append(ch)
            if ch == quote and body[i - 1 : i] != "\\":
                quote = None
        elif ch in "\"'":
            quote = ch
            cur.append(ch)
        elif ch in "[{":
            raise YamlError("line %d: nested flow collections are not supported" % lineno)
        elif ch == ",":
            items.append("".join(cur))
            cur = []
        else:
            cur.append(ch)
    if "".join(cur).strip():
        items.append("".join(cur))
    return [x.strip() for x in items if x.strip()]


def _strip_comment(line):
    """Drop a trailing `# comment`, respecting quotes."""
    out, quote = [], None
    for i, ch in enumerate(line):
        if quote:
            out.append(ch)
            if ch == quote and line[i - 1 : i] != "\\":
                quote = None
        elif ch in "\"'":
            quote = ch
            out.append(ch)
        elif ch == "#" and (not out or out[-1] in " \t"):
            break
        else:
            out.append(ch)
    return "".join(out).rstrip()


def _tokenize(text):
    """(indent, is_seq_item, content, lineno) for every significant line."""
    toks = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        if "\t" in raw[: len(raw) - len(raw.lstrip())]:
            raise YamlError("line %d: tabs are not valid YAML indentation" % lineno)
        line = _strip_comment(raw)
        if not line.strip():
            continue
        if line.lstrip().startswith("---"):
            continue
        indent = len(line) - len(line.lstrip())
        body = line.strip()
        if body == "-" or body.startswith("- "):
            # "- key: value" starts a mapping whose own indent is past the dash.
            toks.append((indent, True, body[1:].strip(), lineno))
        else:
            toks.append((indent, False, body, lineno))
    return toks


def _split_key(content, lineno):
    """Split `key: value` at the first colon that is not inside quotes."""
    quote = None
    for i, ch in enumerate(content):
        if quote:
            if ch == quote and content[i - 1 : i] != "\\":
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == ":" and (i + 1 == len(content) or content[i + 1] in " \t"):
            return content[:i].strip(), content[i + 1 :].strip()
    raise YamlError("line %d: expected 'key: value', got: %s" % (lineno, content))


class _Parser:
    def __init__(self, toks):
        self.toks, self.i = toks, 0

    def peek(self):
        return self.toks[self.i] if self.i < len(self.toks) else None

    def parse_block(self, indent):
        tok = self.peek()
        if tok is None or tok[0] < indent:
            return None
        return self.parse_seq(indent) if tok[1] else self.parse_map(indent)

    def parse_seq(self, indent):
        # `indent` is a minimum, not an exact column: a nested block may be
        # indented by any number of spaces, and the first token that belongs to
        # the block fixes the column every later sibling has to match.
        items = []
        while True:
            tok = self.peek()
            if tok is None or tok[0] < indent or not tok[1]:
                return items
            if not items:
                indent = tok[0]
            if tok[0] > indent:
                raise YamlError("line %d: unexpected indent in sequence" % tok[3])
            _, _, content, lineno = tok
            self.i += 1
            if not content:
                # A bare "-" -- the item is the nested block below it.
                items.append(self.parse_block(indent + 1))
            elif _is_pair(content):
                # "- key: value": an inline mapping whose remaining keys are
                # indented to line up after the dash.
                key, rest = _split_key(content, lineno)
                inner_indent = indent + 2
                item = {}
                item[key] = self._value(rest, inner_indent, lineno)
                nxt = self.peek()
                while nxt is not None and not nxt[1] and nxt[0] >= inner_indent:
                    k2, r2 = _split_key(nxt[2], nxt[3])
                    self.i += 1
                    item[k2] = self._value(r2, nxt[0] + 1, nxt[3])
                    nxt = self.peek()
                items.append(item)
            else:
                items.append(_scalar(content, lineno))

    def parse_map(self, indent):
        # As in parse_seq, `indent` is the minimum column this block may start
        # at; the first key fixes the column for the rest of the mapping.
        out = {}
        while True:
            tok = self.peek()
            if tok is None or tok[0] < indent or tok[1]:
                return out
            if not out:
                indent = tok[0]
            if tok[0] > indent:
                raise YamlError("line %d: unexpected indent in mapping" % tok[3])
            _, _, content, lineno = tok
            self.i += 1
            key, rest = _split_key(content, lineno)
            out[key] = self._value(rest, indent + 1, lineno)

    def _value(self, rest, child_indent, lineno):
        if rest:
            return _scalar(rest, lineno)
        # Empty value: the real value is the block indented under this key. A
        # key with nothing under it is an empty mapping, matching YAML.
        block = self.parse_block(child_indent)
        return {} if block is None else block


def _is_pair(content):
    try:
        _split_key(content, 0)
        return True
    except YamlError:
        return False


def loads(text):
    """Parse a YAML document into Python data."""
    if _pyyaml is not None:
        return _pyyaml.safe_load(text)
    p = _Parser(_tokenize(text))
    doc = p.parse_block(0)
    if p.peek() is not None:
        raise YamlError("line %d: trailing content" % p.peek()[3])
    return {} if doc is None else doc


def load_file(path):
    with open(path, "r", encoding="utf-8") as fh:
        return loads(fh.read())


def dumps(obj, indent=0):
    """Emit the same subset back out, for recording the effective config."""
    pad = "  " * indent
    if isinstance(obj, dict):
        if not obj:
            return pad + "{}\n"
        out = []
        for k, v in obj.items():
            if isinstance(v, (dict, list)) and v:
                out.append("%s%s:\n%s" % (pad, k, dumps(v, indent + 1)))
            else:
                out.append("%s%s: %s\n" % (pad, k, _emit_scalar(v)))
        return "".join(out)
    if isinstance(obj, list):
        if not obj:
            return pad + "[]\n"
        out = []
        for v in obj:
            if isinstance(v, dict):
                body = dumps(v, indent + 1)
                first, rest = body.split("\n", 1) if "\n" in body else (body, "")
                out.append("%s- %s\n%s" % (pad, first.strip(), rest))
            else:
                out.append("%s- %s\n" % (pad, _emit_scalar(v)))
        return "".join(out)
    return pad + _emit_scalar(obj) + "\n"


def _emit_scalar(v):
    if v is None:
        return "null"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, (int, float)):
        return repr(v)
    s = str(v)
    if s == "" or s != s.strip() or s[0] in "\"'#-[{&*!|>%@`" or ": " in s:
        return '"%s"' % s.replace("\\", "\\\\").replace('"', '\\"')
    return s
