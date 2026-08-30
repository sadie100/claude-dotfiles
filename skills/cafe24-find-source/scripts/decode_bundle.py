#!/usr/bin/env python3
"""Decode a Cafe24 HTML-optimizer bundle `filename` param into its source file list.

Cafe24's optimizer merges many skin CSS/JS files into one bundle served at
`ind-script/optimizer.php`   (Cafe24 built-in files: framework/… , program/…) or
`ind-script/optimizer_user.php` (USER skin files: sdedesign/<skin>/…).
The `filename` query param is the merged source list, encoded as
`urlsafe-base64( raw-DEFLATE( packed-paths ) )`.

The packed path list uses low control bytes as markers, and the exact mapping
varies slightly between bundles, but empirically:
  - 0x0A  -> `-`  (hyphen in a filename)
  - 0x0C  -> `.`  (dot before the extension)
  - 0x15  -> file separator
  - 0x0B  -> dropped (noise / prefix marker)
  - some rare chars (e.g. `_`) may not survive cleanly.
So the reconstructed paths are usually EXACT, but a few (underscores, unusual names)
can be off by a character. ALWAYS confirm the real target by fetching the raw file
and grepping for your search string — see the skill's SKILL.md workflow.

Usage:
    python decode_bundle.py '<filename-param-or-full-optimizer-URL>'
    python decode_bundle.py --user-only '<...>'   # only sdedesign/* (skin) files
    python decode_bundle.py --urls '<...>'        # also print guessed raw fetch paths
"""
import sys
import re
import base64
import zlib
from urllib.parse import urlparse, parse_qs, unquote

_SPLIT_RE = re.compile(r"\x15|(?=sdedesign/|framework/|program/)")


def extract_filename(arg: str) -> str:
    """Accept either a bare filename param or a full optimizer URL."""
    if "filename=" in arg:
        q = parse_qs(urlparse(arg).query)
        if "filename" in q:
            return q["filename"][0]
        m = re.search(r"filename=([^&]+)", arg)
        if m:
            return unquote(m.group(1))
    return arg


def decode(param: str) -> bytes:
    s = param.replace("-", "+").replace("_", "/")
    s += "=" * (-len(s) % 4)
    # Cafe24 uses raw DEFLATE (no zlib/gzip header) -> wbits = -15.
    return zlib.decompress(base64.b64decode(s), -15)


def normalize(raw: bytes):
    t = raw.decode("latin1")
    t = t.replace("\x0b", "")   # VT: noise / prefix marker -> drop
    t = t.replace("\x0a", "-")  # LF: hyphen in filename
    t = t.replace("\x0c", ".")  # FF: dot before extension
    out = []
    for seg in _SPLIT_RE.split(t):
        seg = seg.strip()
        if not seg:
            continue
        if not (seg.endswith(".css") or seg.endswith(".js")):
            if seg.endswith("css"):
                seg = seg[:-3] + ".css"
            elif seg.endswith("js"):
                seg = seg[:-2] + ".js"
        out.append(seg)
    return out


def to_raw_path(entry: str) -> str:
    """Guess the web-accessible path of a skin source file.
    `sdedesign/skin3/css/module/product/first-improve-product-detail.css`
      -> `/css/module/product/first-improve-product-detail.css`
    Prepend the mall origin (e.g. https://cloop.co.kr) to fetch it."""
    parts = entry.split("/")
    if len(parts) >= 3 and parts[0] == "sdedesign":
        return "/" + "/".join(parts[2:])
    return "/" + entry


def main():
    flags = {a for a in sys.argv[1:] if a.startswith("--")}
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    if not args:
        print(__doc__)
        sys.exit(1)
    entries = normalize(decode(extract_filename(args[0])))
    if "--user-only" in flags:
        entries = [e for e in entries if e.startswith("sdedesign")]
    print("# %d file(s) in bundle (confirm exact name via raw fetch + grep)" % len(entries))
    for e in entries:
        if "--urls" in flags:
            print("%s\t%s" % (e, to_raw_path(e)))
        else:
            print(e)


if __name__ == "__main__":
    main()
