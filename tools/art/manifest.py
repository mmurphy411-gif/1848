"""CC0 provenance manifest: shared paths, canonical writer and union merge.

`assets/CC0_MANIFEST.json` holds one row per (source, id, resolution) that was
fetched by `tools/art/fetch_cc0.py`. `blender/normalize_asset.py` appends the
committed game files it built from a row to that row's `outputs`.

Layout, chosen so parallel branches rarely conflict:
  * rows sorted by (source, id, resolution); new rows land at scattered places
    instead of all at the end;
  * fixed key order and 2-space indentation, one file entry per line, `outputs`
    above `files` so an output added to one row is not adjacent to the next row;
  * no derived or volatile fields (a cache hit never rewrites `fetched`).

If two branches still conflict, merge with union semantics instead of by hand:

  python tools/art/manifest.py merge a.json b.json [-o out.json]
  python tools/art/manifest.py normalize [file]       # rewrite canonically
  python tools/art/manifest.py add-output polyhaven:boulder_01[:1k] assets/rocks/x.glb
  python tools/art/manifest.py driver %O %A %B        # git merge driver

To let git do it automatically (local, opt-in; `.gitattributes` already names
the driver and git falls back to a text merge when it is not configured):

  git config merge.cc0manifest.name "CC0 manifest union"
  git config merge.cc0manifest.driver "python tools/art/manifest.py driver %O %A %B"

Stdlib only: Blender's bundled Python imports this module too.
"""
from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
MANIFEST = REPO / "assets" / "CC0_MANIFEST.json"
LICENCE = "CC0-1.0"
ABOUT = ("Provenance of outside assets. Raw downloads live in the git-ignored "
         ".tools/cc0_cache/<source>/<id>/<resolution>/ of the main checkout. "
         "Written by tools/art/fetch_cc0.py and blender/normalize_asset.py; "
         "merge with tools/art/manifest.py.")
ROW_KEYS = ["source", "id", "resolution", "kind", "name", "licence", "fetched",
            "page", "authors", "outputs", "files"]
FILE_KEYS = ["path", "from", "url", "size", "md5", "sha256"]


def cache_root() -> Path:
    """`.tools/cc0_cache/` of the main checkout, shared by every worktree."""
    if os.environ.get("CC0_CACHE"):
        return Path(os.environ["CC0_CACHE"]).resolve()
    try:
        out = subprocess.run(["git", "-C", str(REPO), "rev-parse", "--path-format=absolute",
                              "--git-common-dir"], capture_output=True, text=True, check=True).stdout.strip()
        common = Path(out)
        if not common.is_absolute():
            common = (REPO / common).resolve()
        return common.parent / ".tools" / "cc0_cache"
    except (OSError, subprocess.CalledProcessError):
        return REPO / ".tools" / "cc0_cache"


def row_key(row: dict) -> tuple:
    return (row["source"], row["id"], row["resolution"])


def _order(d: dict, keys: list) -> dict:
    out = {k: d[k] for k in keys if k in d}
    out.update({k: d[k] for k in sorted(d) if k not in out})
    return out


def canonical(rows: list) -> list:
    out = []
    for r in sorted(rows, key=row_key):
        r = dict(r)
        r["outputs"] = sorted(set(r.get("outputs", [])))
        r["files"] = [_order(f, FILE_KEYS) for f in sorted(r.get("files", []), key=lambda f: f["path"])]
        out.append(_order(r, ROW_KEYS))
    return out


def dumps(rows: list) -> str:
    """Canonical text. Scalars and short lists inline, file entries one per line."""
    lines = ["{", '  "about": %s,' % json.dumps(ABOUT), '  "rows": [']
    rows = canonical(rows)
    for i, r in enumerate(rows):
        lines.append("    {")
        items = list(r.items())
        for j, (k, v) in enumerate(items):
            comma = "," if j < len(items) - 1 else ""
            if k in ("outputs", "files") and v:
                lines.append('      "%s": [' % k)
                for n, item in enumerate(v):
                    c = "," if n < len(v) - 1 else ""
                    lines.append("        %s%s" % (json.dumps(item, ensure_ascii=False), c))
                lines.append("      ]%s" % comma)
            else:
                lines.append('      "%s": %s%s' % (k, json.dumps(v, ensure_ascii=False), comma))
        lines.append("    }%s" % ("," if i < len(rows) - 1 else ""))
    lines += ["  ]", "}", ""]
    return "\n".join(lines)


def load(path: Path = MANIFEST) -> list:
    path = Path(path)
    if not path.exists() or not path.read_text(encoding="utf-8").strip():
        return []
    data = json.loads(path.read_text(encoding="utf-8"))
    return data["rows"] if isinstance(data, dict) else data


def save(rows: list, path: Path = MANIFEST) -> None:
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    tmp = path.with_suffix(".json.tmp")
    tmp.write_text(dumps(rows), encoding="utf-8", newline="\n")
    os.replace(tmp, path)


def upsert(row: dict, path: Path = MANIFEST) -> dict:
    """Insert or replace a row, keeping outputs already recorded for it."""
    rows = load(path)
    keep = []
    for r in rows:
        if row_key(r) == row_key(row):
            row = dict(row, outputs=sorted(set(r.get("outputs", [])) | set(row.get("outputs", []))))
        else:
            keep.append(r)
    keep.append(row)
    save(keep, path)
    return row


def find(rows: list, spec: str, hint_path: str | None = None) -> dict:
    """Resolve `source:id[:resolution]`; a cache path can disambiguate resolution."""
    parts = spec.split(":")
    if len(parts) not in (2, 3):
        raise SystemExit("manifest id must be source:id[:resolution], got %r" % spec)
    source, ident = parts[0], parts[1]
    res = parts[2] if len(parts) == 3 else None
    if res is None and hint_path:
        p = Path(hint_path).resolve().as_posix().split("/")
        for i in range(len(p) - 2):
            if p[i] == source and p[i + 1] == ident:
                res = p[i + 2]
                break
    hits = [r for r in rows if r["source"] == source and r["id"] == ident and (res is None or r["resolution"] == res)]
    if len(hits) != 1:
        raise SystemExit("manifest: %d rows match %s%s (fetch it first, or add :resolution)"
                         % (len(hits), spec, "" if res is None or len(parts) == 3 else ":" + res))
    return hits[0]


def add_output(spec: str, output: str, hint_path: str | None = None, path: Path = MANIFEST) -> dict:
    rows = load(path)
    row = find(rows, spec, hint_path)
    out = Path(output).resolve()
    try:
        rel = out.relative_to(REPO).as_posix()
    except ValueError:
        rel = out.as_posix()
    row["outputs"] = sorted(set(row.get("outputs", [])) | {rel})
    save(rows, path)
    return row


def _newer(a: dict, b: dict) -> dict:
    return b if b.get("fetched", "") > a.get("fetched", "") else a


def merge_rows(a: dict, b: dict) -> dict:
    """Union of two versions of one row: newer scalars, union of files and outputs."""
    newer = _newer(a, b)
    older = b if newer is a else a
    out = dict(older)
    out.update(newer)
    files = {f["path"]: f for f in older.get("files", [])}
    files.update({f["path"]: f for f in newer.get("files", [])})
    out["files"] = list(files.values())
    out["outputs"] = sorted(set(a.get("outputs", [])) | set(b.get("outputs", [])))
    return out


def merge(a: list, b: list, base: list | None = None) -> list:
    """Union merge. With a base (3-way), rows or outputs deleted on one side and
    untouched on the other stay deleted; everything else is a union."""
    A = {row_key(r): r for r in a}
    B = {row_key(r): r for r in b}
    O = {row_key(r): r for r in (base or [])}
    out = []
    for k in sorted(set(A) | set(B)):
        ra, rb, ro = A.get(k), B.get(k), O.get(k)
        if ra and rb:
            row = merge_rows(ra, rb)
            if ro:
                gone = (set(ro.get("outputs", [])) - set(ra.get("outputs", []))) | \
                       (set(ro.get("outputs", [])) - set(rb.get("outputs", [])))
                row["outputs"] = sorted(set(row["outputs"]) - gone)
            out.append(row)
        else:
            only = ra or rb
            if ro and canonical([ro]) == canonical([only]):
                continue  # deleted on the other side, unchanged here
            out.append(only)
    return canonical(out)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)
    m = sub.add_parser("merge", help="union of two manifests")
    m.add_argument("a"); m.add_argument("b"); m.add_argument("-o", "--out")
    d = sub.add_parser("driver", help="git merge driver: driver %%O %%A %%B (result written to %%A)")
    d.add_argument("base"); d.add_argument("ours"); d.add_argument("theirs")
    n = sub.add_parser("normalize", help="rewrite a manifest in canonical form")
    n.add_argument("file", nargs="?", default=str(MANIFEST))
    o = sub.add_parser("add-output", help="append a built file to a row's outputs")
    o.add_argument("spec"); o.add_argument("output")
    sub.add_parser("cache", help="print the shared cache directory")
    args = ap.parse_args(argv)
    if args.cmd == "merge":
        rows = merge(load(Path(args.a)), load(Path(args.b)))
        if args.out:
            save(rows, Path(args.out))
        else:
            sys.stdout.write(dumps(rows))
    elif args.cmd == "driver":
        try:
            base = load(Path(args.base))
        except (json.JSONDecodeError, KeyError):
            base = []
        save(merge(load(Path(args.ours)), load(Path(args.theirs)), base), Path(args.ours))
    elif args.cmd == "normalize":
        save(load(Path(args.file)), Path(args.file))
    elif args.cmd == "add-output":
        row = add_output(args.spec, args.output)
        print("%s:%s:%s outputs %s" % (row["source"], row["id"], row["resolution"], row["outputs"]))
    elif args.cmd == "cache":
        print(cache_root().as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main())
