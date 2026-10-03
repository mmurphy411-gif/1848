"""Stage 3 intake: rebuild every scan boulder, cobble and clutter GLB from the CC0 cache.

  python tools/art/intake_rocks.py [name ...] [--list] [--dry-run]

Each recipe below is one committed file. For each: fetch the source with
tools/art/fetch_cc0.py (cache hit after the first run; manifest row), extract the
piece and fit its scale with blender/extract_piece.py (intermediate GLB under
artifacts/intake_rocks/, git-ignored), then normalise it with
blender/normalize_asset.py (weld, decimate, bake normals, ORM, tint, export) and
record the output in assets/CC0_MANIFEST.json. Same inputs, same files.

Conventions the game relies on:
  * boulders (assets/boulders/boulder_NN.glb): larger horizontal half-extent 1 m,
    natural height, origin at the bounding-box centre. greybox.gd::_build_boulders
    fits the first seven to Layout.BOULDERS; cliff boulders and the store ring reuse
    boulder_01..08 at unit scale.
  * cobbles (assets/boulders/cobble_NN.glb): the same unit footprint, neutral grey
    albedo; the MultiMesh colour gives each instance its rock type.
  * clutter (assets/clutter/*.glb): true size in metres, origin at the base centre.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BLENDER = r"C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
WORK = ROOT / "artifacts" / "intake_rocks"

# name: (source id, resolution, piece or None, crop, extract args, normalize args)
RECIPES: dict[str, dict] = {}


def recipe(name, src, res, piece=None, crop=False, fit=1.0, rotate=None, wear=0, tris=3000, tex=1024,
           tint=None, saturation=1.0, value=1.0, origin="center", cast=0.0):
    RECIPES[name] = dict(src=src, res=res, piece=piece, crop=crop, fit=fit, rotate=rotate, wear=wear, tris=tris,
                         tex=tex, tint=tint, saturation=saturation, value=value, origin=origin, cast=cast)


SET1 = ("rock_moss_set_01", "4k")
SET2 = ("rock_moss_set_02", "4k")
SET2_8K = ("rock_moss_set_02", "8k")  # 2k crop for boulder_01, which the bear view meets close
# --- Bar boulders: Layout.BOULDERS index i uses boulder_{i+1}; boulder_08 rings the store and
# joins the margin rocks. Wave C: every bar boulder comes from a different scan and is river
# rounded (`cast` pulls the piece toward its bounding ellipsoid, then `wear` smooths), so
# none keeps the sheer sides and flat top of a fractured block. Granite tint about 0.28
# linear; scan_rock.gdshader adds the crystal grain, quartz veins and iron staining.
# boulder_02 is the white quartz boulder; boulder_06 keeps its scan's iron staining.
GRANITE = "0.575,0.57,0.55"
recipe("boulders/boulder_01", *SET2_8K, "rock_moss_set_02_rock11", crop=True, cast=0.45, wear=20, tex=2048,
       tint=GRANITE + ",0.92", saturation=0.4)
recipe("boulders/boulder_02", "stone_01", "1k", "stone_01", cast=0.5, wear=20, tint="0.66,0.645,0.62,0.85",
       saturation=0.6)
recipe("boulders/boulder_03", "namaqualand_boulders_01", "4k", "namaqualand_rocks_01_a", crop=True, cast=0.25,
       wear=15, tex=2048, tint=GRANITE + ",0.9", saturation=0.45)
recipe("boulders/boulder_04", *SET1, "rock_moss_set_01_rock04", crop=True, cast=0.45, wear=20,
       tint=GRANITE + ",0.92", saturation=0.4)
recipe("boulders/boulder_05", *SET1, "rock_moss_set_01_rock01", crop=True, cast=0.45, wear=20,
       tint=GRANITE + ",0.92", saturation=0.4)
recipe("boulders/boulder_06", "namaqualand_boulder_04", "1k", "boulder_04", cast=0.4, wear=20,
       tint="0.56,0.53,0.49,0.6")
recipe("boulders/boulder_07", *SET1, "rock_moss_set_01_rock05", crop=True, cast=0.45, wear=20,
       tint=GRANITE + ",0.92", saturation=0.4)
recipe("boulders/boulder_08", "namaqualand_boulder_06", "1k", "namaqualand_boulder_06", cast=0.45, wear=20,
       tint="0.56,0.545,0.52,0.8")
# --- Margin rocks (partly buried at the bar ends, back edge and far bank); less worn.
MARGIN = dict(tris=2000, tex=512)
recipe("boulders/boulder_09", *SET2, "rock_moss_set_02_rock10", crop=True, cast=0.25, wear=20, tint=GRANITE + ",0.92",
       saturation=0.4, **MARGIN)
recipe("boulders/boulder_10", "namaqualand_boulder_05", "1k", "namaqualand_boulder_05", cast=0.2, wear=10,
       tint="0.58,0.56,0.52,0.80", **MARGIN)
recipe("boulders/boulder_11", "rock_09", "1k", "rock_09_LOD0", wear=10, tint="0.36,0.37,0.37,0.55", **MARGIN)
recipe("boulders/boulder_12", "namaqualand_boulders_01", "1k", "namaqualand_rocks_01_b", cast=0.2, wear=10,
       tint=GRANITE + ",0.80", **MARGIN)
recipe("boulders/boulder_13", *SET1, "rock_moss_set_01_rock02", crop=True, cast=0.4, wear=20, tint=GRANITE + ",0.92",
       saturation=0.4, **MARGIN)
# --- Cobbles: well rounded, neutral grey; the MultiMesh colour sets the rock type.
COBBLE = dict(tris=180, tex=256, tint="0.66,0.66,0.65,0.85")
recipe("boulders/cobble_01", *SET2, "rock_moss_set_02_rock08", crop=True, wear=60, **COBBLE)
recipe("boulders/cobble_02", *SET2, "rock_moss_set_02_rock09", crop=True, wear=60, **COBBLE)
recipe("boulders/cobble_03", *SET2, "rock_moss_set_02_rock10", crop=True, wear=60, **COBBLE)
recipe("boulders/cobble_04", *SET2, "rock_moss_set_02_rock07", crop=True, wear=60, **COBBLE)
recipe("boulders/cobble_05", *SET2, "rock_moss_set_02_rock12", crop=True, wear=60, **COBBLE)
recipe("boulders/cobble_06", "namaqualand_boulders_01", "1k", "namaqualand_rocks_01_b", wear=60, **COBBLE)
recipe("boulders/cobble_07", "namaqualand_boulders_01", "1k", "namaqualand_rocks_01_a", wear=40, **COBBLE)
recipe("boulders/cobble_08", "rock_09", "1k", "rock_09_LOD0", wear=30, **COBBLE)
recipe("boulders/cobble_09", "stone_01", "1k", "stone_01", wear=40, **COBBLE)
recipe("boulders/cobble_10", "rock_07", "1k", "rock_07", wear=60, **COBBLE)
# --- Clutter: weathered silver-grey driftwood, bark and a cut stump.
WOOD = "0.64,0.62,0.58,0.80"
recipe("clutter/driftwood_01", "dry_branches_medium_01", "1k", "dry_branches_medium_01_a", fit=None, tris=900,
       tex=512, tint=WOOD, origin="base")
recipe("clutter/driftwood_02", "dry_branches_medium_01", "1k", "dry_branches_medium_01_b", fit=None, tris=700,
       tex=512, tint=WOOD, origin="base")
recipe("clutter/driftwood_03", "dry_branches_medium_01", "1k", "dry_branches_medium_01_c", fit=None, tris=700,
       tex=512, tint=WOOD, origin="base")
recipe("clutter/driftwood_log", "dead_tree_trunk", "1k", "dead_tree_trunk", fit=None, tris=1200, tex=512,
       tint=WOOD, origin="base")
# Wave C: a big split snag (4 m, 1 m across the fork) that reads as flood debris from the
# far end of the bar; placed along the spring high-water line and against inland boulders.
recipe("clutter/driftwood_snag", "dead_tree_trunk_02", "1k", "dead_tree_trunk_02", fit=None, tris=1500, tex=512,
       tint="0.60,0.58,0.54,0.75", origin="base")
recipe("clutter/stump_01", "tree_stump_01", "1k", "tree_stump_01", fit=None, tris=1500, tex=512, origin="base",
       tint="0.42,0.37,0.31,0.45")
recipe("clutter/bark_01", "bark_debris_01", "1k", "bark_debris_01_a", crop=True, fit=None, tris=300, tex=256,
       origin="base")
recipe("clutter/bark_02", "bark_debris_01", "1k", "bark_debris_01_c", crop=True, fit=None, tris=300, tex=256,
       origin="base")


def run(cmd, log):
    t = time.time()
    with open(log, "w", encoding="utf-8") as f:
        code = subprocess.call(cmd, stdout=f, stderr=subprocess.STDOUT, cwd=ROOT)
    if code != 0:
        sys.exit("FAILED (%d) %s; see %s" % (code, " ".join(map(str, cmd[:6])), log))
    return time.time() - t


def build(name, r, dry, out_dir=None):
    out = (Path(out_dir).resolve() if out_dir else ROOT / "assets") / (name + ".glb")
    fetch = [sys.executable, str(ROOT / "tools/art/fetch_cc0.py"), "polyhaven", r["src"], r["res"]]
    WORK.mkdir(parents=True, exist_ok=True)
    stem = name.replace("/", "_")
    piece = WORK / (stem + "_piece.glb")
    extract = [BLENDER, "--background", "--python", str(ROOT / "blender/extract_piece.py"), "--", "<src>",
               r["piece"], "--out", str(piece)]
    if r["crop"]:
        extract.append("--crop")
    if r["fit"]:
        extract += ["--fit", str(r["fit"])]
    if r["rotate"]:
        extract += ["--rotate", r["rotate"]]
    if r["cast"]:
        extract += ["--cast", str(r["cast"])]
    if r["wear"]:
        extract += ["--round", str(r["wear"])]
    norm = [BLENDER, "--background", "--python", str(ROOT / "blender/normalize_asset.py"), "--", str(piece),
            "--out", str(out), "--tris", str(r["tris"]), "--scale", "1", "--origin", r["origin"],
            "--tex", str(r["tex"])]
    if not out_dir:
        norm += ["--manifest-id", "polyhaven:%s:%s" % (r["src"], r["res"])]
    if r["tint"]:
        norm += ["--tint", r["tint"]]
    if r["saturation"] != 1.0:
        norm += ["--saturation", str(r["saturation"])]
    if r["value"] != 1.0:
        norm += ["--value", str(r["value"])]
    if dry:
        print(name, "\n ", " ".join(fetch), "\n ", " ".join(extract), "\n ", " ".join(norm))
        return
    got = subprocess.run(fetch, capture_output=True, text=True, cwd=ROOT)
    main = [ln for ln in got.stdout.splitlines() if ln.startswith("main: ")]
    if got.returncode != 0 or not main:
        sys.exit("fetch failed for %s:\n%s%s" % (r["src"], got.stdout, got.stderr))
    extract[extract.index("<src>")] = main[-1][6:].strip()
    t1 = run(extract, WORK / (stem + "_extract.log"))
    t2 = run(norm, WORK / (stem + "_normalize.log"))
    summary = [ln.strip() for ln in open(WORK / (stem + "_normalize.log"), encoding="utf-8")
               if ln.strip().startswith(("triangles", "dimensions", "wrote", "material"))]
    print("%-22s %5.1fs  %s" % (name, t1 + t2, " | ".join(summary)))


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="recipe names (e.g. boulders/boulder_01) or prefixes")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--out-dir", help="write the GLBs here instead of assets/ (trials; no manifest rows)")
    a = ap.parse_args()
    names = [n for n in RECIPES if not a.names or any(n == x or n.startswith(x) for x in a.names)]
    if a.list:
        for n in names:
            print(n, RECIPES[n])
        return
    for n in names:
        build(n, RECIPES[n], a.dry_run, a.out_dir)


if __name__ == "__main__":
    main()
