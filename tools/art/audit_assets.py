"""Audit committed GLBs against the Section 5 budgets of VISUAL_UPGRADE_PLAN.md.

  python tools/art/audit_assets.py [paths or globs ...] [--category NAME] [--budgets tools/art/budgets.json] [-v] [--json out.json]

With no paths it walks assets/**/*.glb of the checkout this script lives in.
Each file is mapped to the first category in budgets.json whose glob matches its
repo-relative path (files outside the repo are matched by file name) and checked
for LOD0 triangles and the largest texture dimension. Violations listed in the
allow-list (with a reason) are reported as ALLOW; any other violation, or a file
that matches no category, makes the exit status 1.

Counting reads the glTF JSON directly (no decode of geometry): triangles are
summed over the nodes of the default scene, so instanced meshes count per node
and skinned or morphing meshes count their base primitives; strips and fans count
n-2; points and lines count 0. Image sizes come from the embedded image headers.
"""
from __future__ import annotations

import argparse
import fnmatch
import glob
import io
import json
import struct
import sys
from pathlib import Path

from PIL import Image

REPO = Path(__file__).resolve().parents[2]
BUDGETS = Path(__file__).resolve().parent / "budgets.json"


def read_gltf(path: Path):
    data = path.read_bytes()
    if data[:4] == b"glTF":
        _, _, length = struct.unpack_from("<III", data, 0)
        off, doc, binchunk = 12, None, b""
        while off < length:
            clen, ctype = struct.unpack_from("<II", data, off)
            chunk = data[off + 8:off + 8 + clen]
            if ctype == 0x4E4F534A:
                doc = json.loads(chunk)
            elif ctype == 0x004E4942:
                binchunk = chunk
            off += 8 + clen
        return doc, binchunk
    return json.loads(data), b""


def primitive_triangles(doc: dict, prim: dict) -> int:
    mode = prim.get("mode", 4)
    if "indices" in prim:
        n = doc["accessors"][prim["indices"]]["count"]
    else:
        n = doc["accessors"][prim["attributes"]["POSITION"]]["count"]
    if mode == 4:
        return n // 3
    if mode in (5, 6):
        return max(n - 2, 0)
    return 0


def image_size(doc: dict, binchunk: bytes, img: dict, base: Path):
    try:
        if "bufferView" in img:
            bv = doc["bufferViews"][img["bufferView"]]
            start = bv.get("byteOffset", 0)
            raw = binchunk[start:start + bv["byteLength"]]
            return Image.open(io.BytesIO(raw)).size
        uri = img.get("uri", "")
        if uri.startswith("data:"):
            import base64
            return Image.open(io.BytesIO(base64.b64decode(uri.split(",", 1)[1]))).size
        return Image.open(base / uri).size
    except Exception:  # KTX2 / basisu / missing file
        return None


def glb_stats(path: Path) -> dict:
    doc, binchunk = read_gltf(path)
    meshes = doc.get("meshes", [])
    mesh_tris = [sum(primitive_triangles(doc, p) for p in m.get("primitives", [])) for m in meshes]
    nodes = doc.get("nodes", [])
    scenes = doc.get("scenes", [])
    roots = scenes[doc.get("scene", 0)]["nodes"] if scenes else [i for i in range(len(nodes))
                                                                    if not any(i in n.get("children", []) for n in nodes)]
    per_mesh: dict = {}
    total = 0
    stack = list(roots)
    while stack:
        n = nodes[stack.pop()]
        if "mesh" in n:
            k = n["mesh"]
            per_mesh[k] = per_mesh.get(k, 0) + 1
            total += mesh_tris[k]
        stack.extend(n.get("children", []))
    images = []
    for img in doc.get("images", []):
        size = image_size(doc, binchunk, img, path.parent)
        images.append({"name": img.get("name") or img.get("uri", "?"), "size": size, "mime": img.get("mimeType", "")})
    return {
        "triangles": total,
        "unique_triangles": sum(mesh_tris),
        "meshes": [{"name": m.get("name", "#%d" % i), "triangles": mesh_tris[i], "instances": per_mesh.get(i, 0)}
                   for i, m in enumerate(meshes)],
        "skinned": bool(doc.get("skins")),
        "images": images,
        "max_texture": max((max(i["size"]) for i in images if i["size"]), default=0),
    }


def rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(REPO).as_posix()
    except ValueError:
        return path.name


def categorise(relpath: str, categories: list):
    for c in categories:
        if any(fnmatch.fnmatchcase(relpath, g) for g in c["globs"]):
            return c
    return None


def audit(files: list, budgets: dict, force: str | None = None) -> tuple:
    rows, failures = [], 0
    allow = budgets.get("allow", {})
    by_cat: dict = {}
    for f in files:
        r = rel(f)
        s = glb_stats(f)
        cat = next((c for c in budgets["categories"] if c["name"] == force), None) if force else             categorise(r, budgets["categories"])
        problems = []
        if cat is None:
            problems.append("no category")
        else:
            limit = cat.get("triangles")
            if limit is not None and s["triangles"] > limit:
                problems.append("tris %d > %d" % (s["triangles"], limit))
            tex = cat.get("texture_px")
            if tex is not None and s["max_texture"] > tex:
                large = cat.get("texture_px_large")
                if large and s["max_texture"] <= large:
                    by_cat.setdefault(cat["name"], []).append(r)
                    if len(by_cat[cat["name"]]) > cat.get("large_quota", 0):
                        problems.append("tex %d > %d (large quota %d used)" % (s["max_texture"], tex, cat.get("large_quota", 0)))
                else:
                    problems.append("tex %d > %d" % (s["max_texture"], large or tex))
        status = "OK"
        if problems:
            if r in allow:
                status = "ALLOW"
            else:
                status = "FAIL"
                failures += 1
        rows.append({"path": r, "category": cat["name"] if cat else "-", "stats": s,
                     "tri_limit": cat.get("triangles") if cat else None,
                     "tex_limit": cat.get("texture_px") if cat else None,
                     "problems": problems, "status": status, "reason": allow.get(r, "")})
    stale = sorted(set(allow) - {r["path"] for r in rows if r["status"] == "ALLOW"} - {"_comment"})
    return rows, failures, stale


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="*", help="GLB files or globs (default: assets/**/*.glb)")
    ap.add_argument("--budgets", type=Path, default=BUDGETS)
    ap.add_argument("-v", "--verbose", action="store_true", help="list meshes and images per file")
    ap.add_argument("--json", type=Path, help="also write the full report as JSON")
    ap.add_argument("--category", help="check every given file against this category (e.g. for files outside assets/)")
    args = ap.parse_args(argv)
    budgets = json.loads(args.budgets.read_text(encoding="utf-8"))
    files = []
    for p in args.paths or [str(REPO / "assets" / "**" / "*.glb")]:
        files += [Path(h) for h in sorted(glob.glob(p, recursive=True))] if glob.has_magic(p) else [Path(p)]
    files = [f for f in files if f.suffix.lower() in (".glb", ".gltf")]
    if args.category and args.category not in {c["name"] for c in budgets["categories"]}:
        raise SystemExit("unknown category %r" % args.category)
    rows, failures, stale = audit(files, budgets, args.category)

    print("%-50s %-14s %9s %8s %6s %6s  %s" % ("file", "category", "tris", "limit", "tex", "limit", "status"))
    for r in rows:
        s = r["stats"]
        print("%-50s %-14s %9d %8s %6s %6s  %s%s" % (
            r["path"][-50:], r["category"], s["triangles"], "-" if r["tri_limit"] is None else r["tri_limit"],
            s["max_texture"] or "-", "-" if r["tex_limit"] is None else r["tex_limit"], r["status"],
            ("  " + "; ".join(r["problems"])) if r["problems"] else ""))
        if args.verbose:
            for m in s["meshes"]:
                print("    mesh %-36s %8d tris x%d" % (m["name"][:36], m["triangles"], m["instances"]))
            for i in s["images"]:
                print("    image %-35s %s %s" % (i["name"][:35], "x".join(map(str, i["size"])) if i["size"] else "?", i["mime"]))
    counts = {k: sum(r["status"] == k for r in rows) for k in ("OK", "ALLOW", "FAIL")}
    print("\n%d files: %d ok, %d allow-listed, %d failing" % (len(rows), counts["OK"], counts["ALLOW"], counts["FAIL"]))
    if stale and not args.paths:
        print("allow-list entries no longer needed (remove them): %s" % ", ".join(stale))
    if args.json:
        args.json.write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
