"""Extract one piece of a multi-object CC0 scan set into its own GLB, ready for
blender/normalize_asset.py (which joins every mesh it imports).

  blender --background --python blender/extract_piece.py -- <input.gltf|glb> <object-name> --out <piece.glb>
      [--crop] [--margin 0.004] [--rotate x,y,z] [--round iterations] [--fit metres]

  --crop     The set shares one texture atlas and each piece owns a rectangle of it
             (Poly Haven `rock_moss_set_02`, `bark_debris_01`). Crop every image of
             the piece's material to the piece's UV bounds (plus --margin) and remap
             the UVs to 0..1, so the normalised 1k maps spend all their texels on
             this piece instead of on its neighbours. Cropped images are written
             losslessly (PNG) so the only lossy step stays normalize_asset's export.
  --rotate   Euler degrees applied before export (e.g. stand a slab on edge).
  --round    Water wear: N smoothing passes (factor 0.6) round a blocky scan's
             fracture edges; the scan's normal map keeps the grain in the bake.
  --cast     River rounding before --round: pull every vertex this share of the way
             toward the ellipsoid of the piece's own bounding box (Blender's Cast
             modifier on the box-normalised mesh). Smoothing alone turns a fractured
             block into a pillow with sheer sides and a flat top; cast 0.4-0.5 gives
             the domed, egg-shaped section of a tumbled boulder and keeps the scan's
             lumps at reduced height.
  --fit      Uniform scale so the larger horizontal half-extent is this many metres
             (the bar boulders' unit-footprint convention is --fit 1; normalise the
             result with --scale 1).

The piece keeps its world transform (location is zeroed; normalize_asset re-centres).
Outputs are intermediates: write them under artifacts/ (git-ignored), never assets/.
"""
import argparse
import math
import sys
import tempfile
from pathlib import Path

import bmesh
import bpy
import numpy as np


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="extract_piece.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", type=Path)
    ap.add_argument("name", help="object (glTF node) name of the piece to keep")
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--crop", action="store_true")
    ap.add_argument("--margin", type=float, default=0.004, help="UV margin around the crop")
    ap.add_argument("--rotate", help="x,y,z degrees")
    ap.add_argument("--fit", type=float, help="scale so the larger horizontal half-extent is this many metres")
    ap.add_argument("--round", type=int, default=0, help="smoothing iterations (water wear) before --fit")
    ap.add_argument("--cast", type=float, default=0.0, help="0..1 pull toward the bounding ellipsoid (river rounding)")
    return ap.parse_args(argv)


def main():
    a = parse()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(a.input.resolve()))
    keep = None
    for o in list(bpy.context.scene.objects):
        if o.type == "MESH" and (o.name == a.name or o.data.name == a.name):
            keep = o
    if keep is None:
        names = sorted(o.name for o in bpy.context.scene.objects if o.type == "MESH")
        raise SystemExit("no mesh object %r in %s (have %s)" % (a.name, a.input, ", ".join(names)))
    world = keep.matrix_world.copy()
    for o in list(bpy.context.scene.objects):
        if o is not keep:
            bpy.data.objects.remove(o)
    keep.parent = None
    keep.matrix_world = world
    bpy.ops.object.select_all(action="DESELECT")
    keep.select_set(True)
    bpy.context.view_layer.objects.active = keep
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    keep.location = (0, 0, 0)
    if a.rotate:
        r = [math.radians(float(v)) for v in a.rotate.split(",")]
        keep.rotation_euler = r
        bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    if a.cast:
        # River rounding: normalise the piece to a unit box, cast toward a sphere
        # (that is, toward the ellipsoid of the original box), scale back. Positions
        # alone decide the move, so coincident seam vertices stay together.
        co = np.empty(len(keep.data.vertices) * 3, dtype=np.float64)
        keep.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        lo, hi = co.min(0), co.max(0)
        centre, size = (lo + hi) / 2, np.maximum(hi - lo, 1e-6)
        keep.data.vertices.foreach_set("co", ((co - centre) / size).ravel())
        mod = keep.modifiers.new("river_cast", "CAST")
        mod.cast_type = "SPHERE"
        mod.factor = a.cast
        bpy.ops.object.modifier_apply(modifier=mod.name)
        keep.data.vertices.foreach_get("co", co.ravel())
        keep.data.vertices.foreach_set("co", (co * size + centre).ravel())
        keep.data.update()
        print("river cast: %.2f toward the bounding ellipsoid" % a.cast)
    if a.round:
        # Water wear: Laplacian-style relaxation of the scan surface rounds the
        # fracture edges of a blocky scan into a river boulder. The source normal map
        # still rides on the UVs, so normalize_asset's bake keeps the surface grain.
        # Scans arrive split at every UV seam; weld first or the passes tear the seams.
        bm = bmesh.new()
        bm.from_mesh(keep.data)
        lo = np.array([min(v.co[i] for v in bm.verts) for i in range(3)])
        hi = np.array([max(v.co[i] for v in bm.verts) for i in range(3)])
        bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=float(np.linalg.norm(hi - lo)) * 1e-5)
        bm.to_mesh(keep.data)
        bm.free()
        mod = keep.modifiers.new("water_wear", "SMOOTH")
        mod.factor = 0.6
        mod.iterations = a.round
        bpy.ops.object.modifier_apply(modifier=mod.name)
        print("water wear: %d smoothing iterations" % a.round)
    if a.fit:
        co = np.empty(len(keep.data.vertices) * 3, dtype=np.float64)
        keep.data.vertices.foreach_get("co", co)
        co = co.reshape(-1, 3)
        half = float((co.max(0) - co.min(0))[:2].max()) / 2  # Blender Z is up
        keep.scale = (a.fit / half,) * 3
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        print("fit: horizontal half-extent %.4f -> %.4f (x%.5g)" % (half, a.fit, a.fit / half))

    if a.crop:
        uv = keep.data.uv_layers.active.data
        co = np.empty(len(uv) * 2, dtype=np.float64)
        uv.foreach_get("uv", co)
        co = co.reshape(-1, 2)
        lo = co.min(0) - a.margin
        hi = co.max(0) + a.margin
        # Square crops keep the normalised maps square (block compression wants
        # sides that are multiples of 4; 1024x841 is not).
        side = min(float((hi - lo).max()), 1.0)
        mid = (lo + hi) / 2
        lo = np.clip(mid - side / 2, 0, 1 - side)
        hi = lo + side
        print("UV bounds %s - %s" % (lo.round(4), hi.round(4)))
        co = (co - lo) / (hi - lo)
        uv.foreach_set("uv", co.ravel())
        tmp = Path(tempfile.mkdtemp(prefix="extract_"))
        done = {}
        for slot in keep.material_slots:
            if not slot.material or not slot.material.node_tree:
                continue
            for node in slot.material.node_tree.nodes:
                if node.type != "TEX_IMAGE" or not node.image:
                    continue
                img = node.image
                if img.name not in done:
                    w, h = img.size
                    px = np.empty(w * h * 4, dtype=np.float32)
                    img.pixels.foreach_get(px)
                    px = px.reshape(h, w, 4)
                    # Blender image rows start at the bottom, as UV v does.
                    x0, y0 = int(math.floor(lo[0] * w)), int(math.floor(lo[1] * h))
                    x1, y1 = x0 + int(round(side * w)), y0 + int(round(side * h))
                    crop = np.ascontiguousarray(px[y0:y1, x0:x1])
                    data = img.colorspace_settings.name != "sRGB"
                    new = bpy.data.images.new(img.name + "_crop", x1 - x0, y1 - y0, alpha=False, is_data=data)
                    new.colorspace_settings.name = img.colorspace_settings.name
                    new.pixels.foreach_set(crop.ravel())
                    new.filepath_raw = str(tmp / (img.name + "_crop.png"))
                    new.file_format = "PNG"
                    new.save()
                    done[img.name] = new
                    print("cropped %s %dx%d -> %dx%d" % (img.name, w, h, x1 - x0, y1 - y0))
                node.image = done[img.name]

    a.out.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(filepath=str(a.out.resolve()), use_selection=True, export_format="GLB",
                              export_image_format="AUTO", export_materials="EXPORT", export_yup=True,
                              export_apply=True, export_animations=False)
    tris = sum(len(p.vertices) - 2 for p in keep.data.polygons)
    print("EXTRACTED %s: %d triangles -> %s" % (keep.name, tris, a.out))


if __name__ == "__main__":
    main()
