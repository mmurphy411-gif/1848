"""Fetch one CC0 asset into the shared cache and record its provenance row.

  python tools/art/fetch_cc0.py <source> <id> <resolution> [--maps ...] [--force] [--no-manifest]

Sources
  polyhaven  models, textures and HDRIs via https://api.polyhaven.com (/info, /files).
             resolution: 1k|2k|4k|8k, optionally with a format suffix: "2k-png",
             "4k-exr". Models download the glTF package (gltf + bin + textures at
             that resolution, jpg only). Textures download the maps in --maps
             (default Diffuse,nor_gl,arm,Displacement) as jpg unless suffixed.
             HDRIs download the .hdr (or "-exr").
  ambientcg  https://ambientcg.com/api/v2/full_json; resolution is the download
             attribute, e.g. 1K-JPG, 2K-PNG. The zip is verified and unpacked.
  polypizza  https://poly.pizza/m/<PublicID>; resolution must be `glb` (the only
             format served without an API key). The model page's embedded state
             gives title, creator, ResourceID and licence; anything whose licence
             is not CC0 is refused (Poly Pizza mixes CC0 with CC-BY "Poly by
             Google" models). The GLB comes from static.poly.pizza. One page
             request per fetch; robots.txt asks for 10 s between page requests.
  opengameart  https://opengameart.org/content/<slug>; resolution is the name of
             one attached file (e.g. `doe.blend`, `fish.zip`). The page must list
             CC0 among its licences. Zips are unpacked; other archives (7z) are
             cached as downloaded.

Files land in <main checkout>/.tools/cc0_cache/<source>/<id>/<resolution>/, so every
git worktree shares one cache. A `_fetch.json` sidecar there records sizes and
SHA-256; a later run that finds every file intact does no network I/O. Sizes and
Poly Haven's MD5s are verified on download.

The row is written to assets/CC0_MANIFEST.json of the checkout this script lives
in (see tools/art/manifest.py for format and merging). The local path(s) are
printed on success; the last line is `main: <path>`.

Adding a source (e.g. quaternius, sketchfab): subclass `Source`, implement
`plan()` to return a `Plan` of `Remote` files (url, relative path, optional
size/md5, `unpack=True` for archives), and register it in `SOURCES`. Download,
verification, unpacking, caching and the manifest row are shared.
"""
from __future__ import annotations

import argparse
import datetime
import hashlib
import html
import json
import re
import shutil
import sys
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import manifest  # noqa: E402

USER_AGENT = "1848-art-intake/1.0"
SIDECAR = "_fetch.json"


@dataclass
class Remote:
    path: str                 # relative to the cache entry
    url: str
    size: int | None = None
    md5: str | None = None
    unpack: bool = False      # zip archive: extract next to it


@dataclass
class Plan:
    kind: str                 # model | texture | hdri | material | ...
    page: str
    files: list = field(default_factory=list)
    name: str = ""
    authors: list = field(default_factory=list)
    main: str = ""            # relative path printed as the main entry point
    options: dict = field(default_factory=dict)  # recorded so a cache hit can be matched


def get_json(url: str):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT, "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        raise SystemExit("%s: HTTP %d %s" % (url, e.code, e.reason))


def get_text(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            return r.read().decode("utf-8", "replace")
    except urllib.error.HTTPError as e:
        raise SystemExit("%s: HTTP %d %s" % (url, e.code, e.reason))


class Source:
    name = ""
    licence = manifest.LICENCE

    def plan(self, asset_id: str, resolution: str, args) -> Plan:
        raise NotImplementedError

    def options(self, asset_id: str, resolution: str, args) -> dict:
        """Options that change which files are fetched (compared on cache hits)."""
        return {}


class PolyHaven(Source):
    name = "polyhaven"
    API = "https://api.polyhaven.com"
    TYPES = {0: "hdri", 1: "texture", 2: "model"}
    DEFAULT_MAPS = ["Diffuse", "nor_gl", "arm", "Displacement"]

    def _split(self, resolution):
        res, _, fmt = resolution.lower().partition("-")
        return res, fmt

    def options(self, asset_id, resolution, args):
        return {"maps": args.maps.split(",")} if args.maps else {}

    def plan(self, asset_id, resolution, args):
        info = get_json("%s/info/%s" % (self.API, urllib.parse.quote(asset_id)))
        if not isinstance(info, dict) or "type" not in info:
            raise SystemExit("polyhaven: no asset %r" % asset_id)
        files = get_json("%s/files/%s" % (self.API, urllib.parse.quote(asset_id)))
        kind = self.TYPES[info["type"]]
        res, fmt = self._split(resolution)
        p = Plan(kind=kind, page="https://polyhaven.com/a/%s" % asset_id, name=info.get("name", ""),
                 authors=sorted(info.get("authors", {})), options=self.options(asset_id, resolution, args))

        def pick(table, what):
            if res not in table:
                raise SystemExit("polyhaven %s: no %s at %s (have %s)" % (asset_id, what, res, ", ".join(table)))
            return table[res]

        if kind == "model":
            if fmt not in ("", "gltf"):
                raise SystemExit("polyhaven models are fetched as glTF; drop the -%s suffix" % fmt)
            g = pick(files["gltf"], "gltf")["gltf"]
            main = Path(urllib.parse.urlparse(g["url"]).path).name
            p.files.append(Remote(main, g["url"], g.get("size"), g.get("md5")))
            for rel, f in sorted(g.get("include", {}).items()):
                p.files.append(Remote(rel, f["url"], f.get("size"), f.get("md5")))
            # Extra maps the glTF package omits (e.g. a plant's Alpha), as jpg.
            for m in (args.maps.split(",") if args.maps else []):
                if m not in files:
                    raise SystemExit("polyhaven %s: no map %r (have %s)" % (asset_id, m, ", ".join(sorted(files))))
                f = pick(files[m], m).get("jpg")
                p.files.append(Remote("textures/" + Path(urllib.parse.urlparse(f["url"]).path).name, f["url"], f.get("size"), f.get("md5")))
            p.main = main
        elif kind == "texture":
            fmt = fmt or "jpg"
            maps = args.maps.split(",") if args.maps else [m for m in self.DEFAULT_MAPS if m in files]
            for m in maps:
                if m not in files:
                    raise SystemExit("polyhaven %s: no map %r (have %s)" % (asset_id, m, ", ".join(sorted(files))))
                f = pick(files[m], m).get(fmt)
                if not f:
                    raise SystemExit("polyhaven %s: map %s has no %s" % (asset_id, m, fmt))
                p.files.append(Remote(Path(urllib.parse.urlparse(f["url"]).path).name, f["url"], f.get("size"), f.get("md5")))
            p.main = p.files[0].path
        else:
            fmt = fmt or "hdr"
            f = pick(files["hdri"], "hdri").get(fmt)
            if not f:
                raise SystemExit("polyhaven %s: no %s at %s" % (asset_id, fmt, res))
            p.files.append(Remote(Path(urllib.parse.urlparse(f["url"]).path).name, f["url"], f.get("size"), f.get("md5")))
            p.main = p.files[0].path
        return p


class AmbientCG(Source):
    name = "ambientcg"
    API = "https://ambientcg.com/api/v2/full_json"

    def plan(self, asset_id, resolution, args):
        data = get_json("%s?%s" % (self.API, urllib.parse.urlencode({"id": asset_id, "include": "downloadData"})))
        found = [a for a in data.get("foundAssets", []) if a.get("assetId") == asset_id]
        if not found:
            raise SystemExit("ambientcg: no asset %r" % asset_id)
        a = found[0]
        downloads = [d for folder in a.get("downloadFolders", {}).values()
                     for cat in folder.get("downloadFiletypeCategories", {}).values()
                     for d in cat.get("downloads", [])]
        hit = [d for d in downloads if d.get("attribute", "").lower() == resolution.lower()]
        if not hit:
            raise SystemExit("ambientcg %s: no download %r (have %s)"
                             % (asset_id, resolution, ", ".join(sorted(d.get("attribute", "?") for d in downloads))))
        d = hit[0]
        url = d.get("fullDownloadPath") or d["downloadLink"]
        p = Plan(kind=a.get("dataType", "material").lower(), page=a.get("shortLink") or
                 "https://ambientcg.com/view?id=%s" % asset_id, name=a.get("displayName", ""), authors=["ambientCG"])
        p.files.append(Remote(d["fileName"], url, d.get("size"), None, unpack=d.get("filetype") == "zip"))
        p.main = "."
        return p


class PolyPizza(Source):
    """Poly Pizza model pages; CC0 rows only (e.g. Quaternius' animal packs)."""
    name = "polypizza"
    PAGE = "https://poly.pizza/m/%s"
    STATIC = "https://static.poly.pizza/%s.glb"

    def plan(self, asset_id, resolution, args):
        if resolution.lower() != "glb":
            raise SystemExit("polypizza serves GLB only; use resolution `glb`")
        page = self.PAGE % urllib.parse.quote(asset_id)
        text = get_text(page)
        at = text.find("__SERVER_APP_STATE__")
        if at < 0:
            raise SystemExit("polypizza %s: no embedded model state on %s" % (asset_id, page))
        state = json.JSONDecoder().raw_decode(text[at + len("__SERVER_APP_STATE__"):].lstrip().lstrip("=").lstrip())[0]
        model = (state.get("initialData") or {}).get("model") or {}
        if model.get("PublicID") != asset_id or not model.get("ResourceID"):
            raise SystemExit("polypizza: no model %r" % asset_id)
        licence = str(model.get("Licence", ""))
        if not licence.upper().startswith("CC0"):
            raise SystemExit("polypizza %s: licence %r is not CC0; refused" % (asset_id, licence))
        title = model.get("Title") or asset_id
        stem = re.sub(r"[^A-Za-z0-9_.-]+", "_", title).strip("_") or asset_id
        p = Plan(kind="model", page=page, name=title,
                 authors=[model["Creator"]["Username"]] if model.get("Creator", {}).get("Username") else [])
        p.files.append(Remote(stem + ".glb", self.STATIC % model["ResourceID"]))
        p.main = stem + ".glb"
        return p


class OpenGameArt(Source):
    """OpenGameArt content pages; one attached file per row, CC0 pages only."""
    name = "opengameart"
    PAGE = "https://opengameart.org/content/%s"
    FILES = "https://opengameart.org/sites/default/files/"

    def plan(self, asset_id, resolution, args):
        page = self.PAGE % urllib.parse.quote(asset_id)
        text = get_text(page)
        licences = [html.unescape(x).strip() for x in re.findall(r"class='license-name'>([^<]+)<", text)]
        if not any(x.upper() == "CC0" for x in licences):
            raise SystemExit("opengameart %s: licences %s do not include CC0; refused" % (asset_id, licences or "none"))
        links = sorted(set(re.findall(r'href="(%s[^"?]+)"' % re.escape(self.FILES), text)))
        named = {urllib.parse.unquote(u.rsplit("/", 1)[1]): u for u in links if "/files/css/" not in u and "/styles/" not in u}
        if resolution not in named:
            raise SystemExit("opengameart %s: no attached file %r (have %s)" % (asset_id, resolution, ", ".join(sorted(named))))
        title = re.search(r"<title>(.*?)</title>", text, re.S)
        title = html.unescape(title.group(1)).split("|")[0].strip() if title else asset_id
        author = re.search(r"field-name-author-submitter.*?class='username'><a[^>]*>([^<]+)</a>", text, re.S)
        p = Plan(kind="model", page=page, name=title, authors=[html.unescape(author.group(1)).strip()] if author else [])
        p.files.append(Remote(resolution, named[resolution], unpack=resolution.lower().endswith(".zip")))
        p.main = resolution
        return p


SOURCES = {s.name: s for s in (PolyHaven(), AmbientCG(), PolyPizza(), OpenGameArt())}


def digest(path: Path):
    md5, sha = hashlib.md5(), hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            md5.update(chunk)
            sha.update(chunk)
    return md5.hexdigest(), sha.hexdigest()


def download(remote: Remote, dest: Path) -> dict:
    dest.parent.mkdir(parents=True, exist_ok=True)
    part = dest.with_name(dest.name + ".part")
    req = urllib.request.Request(remote.url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=300) as r, open(part, "wb") as f:
        shutil.copyfileobj(r, f, 1 << 20)
    size = part.stat().st_size
    md5, sha = digest(part)
    if remote.size is not None and size != remote.size:
        part.unlink()
        raise SystemExit("size mismatch for %s: got %d, expected %d" % (remote.url, size, remote.size))
    if remote.md5 and md5 != remote.md5:
        part.unlink()
        raise SystemExit("md5 mismatch for %s: got %s, expected %s" % (remote.url, md5, remote.md5))
    part.replace(dest)
    print("  downloaded %s (%d bytes)" % (remote.path, size))
    return {"path": remote.path, "url": remote.url, "size": size, "md5": remote.md5, "sha256": sha}


def unpack(entry: Path, archive: Path, name: str) -> list:
    out = []
    with zipfile.ZipFile(archive) as z:
        for info in z.infolist():
            if info.is_dir():
                continue
            target = (entry / info.filename).resolve()
            if entry.resolve() not in target.parents:
                raise SystemExit("unsafe path in %s: %s" % (name, info.filename))
            target.parent.mkdir(parents=True, exist_ok=True)
            with z.open(info) as src, open(target, "wb") as dst:
                shutil.copyfileobj(src, dst)
            out.append({"path": target.relative_to(entry.resolve()).as_posix(), "from": name,
                        "size": info.file_size, "sha256": digest(target)[1]})
    return out


def verify(entry: Path, files: list) -> list:
    """Return the entries whose file is missing or whose SHA-256 differs."""
    bad = []
    for f in files:
        p = entry / f["path"]
        if not p.exists() or p.stat().st_size != f["size"] or digest(p)[1] != f["sha256"]:
            bad.append(f)
    return bad


def fetch(source: str, asset_id: str, resolution: str, args) -> tuple:
    src = SOURCES.get(source)
    if not src:
        raise SystemExit("unknown source %r; known: %s" % (source, ", ".join(SOURCES)))
    entry = manifest.cache_root() / source / asset_id / resolution
    sidecar = entry / SIDECAR
    want = src.options(asset_id, resolution, args)
    if sidecar.exists() and not args.force:
        row = json.loads(sidecar.read_text(encoding="utf-8"))
        if all(set(v) <= set(row.get("options", {}).get(k, [])) for k, v in want.items()) and not verify(entry, row["files"]):
            print("%s %s %s: cache hit, %d files verified" % (source, asset_id, resolution, len(row["files"])))
            return entry, row
    plan = src.plan(asset_id, resolution, args)
    print("%s %s %s: %s, %d download(s)" % (source, asset_id, resolution, plan.kind, len(plan.files)))
    old = {}
    if sidecar.exists() and not args.force:
        old = {f["path"]: f for f in json.loads(sidecar.read_text(encoding="utf-8"))["files"]}
    records = []
    for r in plan.files:
        dest = entry / r.path
        prev = old.get(r.path)
        if prev and prev.get("url") == r.url and not verify(entry, [prev]) and (r.size is None or prev["size"] == r.size):
            rec = prev
            print("  kept %s" % r.path)
        else:
            rec = download(r, dest)
        records.append(rec)
        if r.unpack:
            members = unpack(entry, dest, r.path)
            records += members
            print("  unpacked %d files from %s" % (len(members), r.path))
    row = {
        "source": source, "id": asset_id, "resolution": resolution, "kind": plan.kind, "name": plan.name,
        "licence": src.licence, "fetched": datetime.date.today().isoformat(), "page": plan.page,
        "authors": plan.authors, "outputs": [],
        "files": [{k: v for k, v in f.items() if v is not None} for f in records],
        "main": plan.main, "options": plan.options,
    }
    entry.mkdir(parents=True, exist_ok=True)
    sidecar.write_text(json.dumps(row, indent=2) + "\n", encoding="utf-8")
    return entry, row


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("source", choices=sorted(SOURCES))
    ap.add_argument("id")
    ap.add_argument("resolution")
    ap.add_argument("--maps", help="polyhaven textures: comma list of maps (e.g. Diffuse,nor_gl,arm,Displacement); models: extra maps beside the glTF (e.g. Alpha)")
    ap.add_argument("--force", action="store_true", help="re-download even if the cache verifies")
    ap.add_argument("--no-manifest", action="store_true", help="do not write the manifest row")
    ap.add_argument("--manifest", default=str(manifest.MANIFEST), help=argparse.SUPPRESS)
    args = ap.parse_args(argv)
    entry, row = fetch(args.source, args.id, args.resolution, args)
    if not args.no_manifest:
        mrow = {k: v for k, v in row.items() if k not in ("main", "options")}
        mrow = {k: v for k, v in mrow.items() if v not in ("", None)}
        manifest.upsert(mrow, Path(args.manifest))
        print("manifest: %s row %s:%s:%s" % (Path(args.manifest).relative_to(manifest.REPO).as_posix()
                                              if Path(args.manifest).resolve().is_relative_to(manifest.REPO) else args.manifest,
                                              args.source, args.id, args.resolution))
    for f in row["files"]:
        print("  %s" % (entry / f["path"]).as_posix())
    print("dir: %s" % entry.as_posix())
    print("main: %s" % (entry / row.get("main", ".")).resolve().as_posix())
    return 0


if __name__ == "__main__":
    sys.exit(main())
