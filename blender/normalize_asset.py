"""Normalise an outside (CC0) mesh into a game-ready static GLB.

  blender --background --python blender/normalize_asset.py -- <input.gltf|glb|fbx|obj>
      --out assets/<category>/<name>.glb --tris 3000 [--lod1 800] [--lod1-suffix _distant]
      [--height 1.6 | --scale 0.01] [--origin base|center]
      [--tint r,g,b[,strength]] [--saturation 1.0] [--value 1.0] [--tex 1024]
      [--manifest-id source:id[:resolution]] [--no-bake] [--smooth-angle 180]
      [--object NAME]

Steps, in order:
  1. Import; drop LOD siblings (`*_LOD1`, `LOD2` ...; keeps the lowest index) and
     armatures (this is for static props); join meshes; apply transforms.
  2. Scale to metres (--height sets the up extent, or --scale) and move the origin
     to the bottom centre (base) or bounding-box centre. Blender Z-up is exported
     as glTF Y-up, so --height is the in-game height.
  3. Keep a copy of the source mesh, weld the working mesh (merge by distance,
     default 1e-5 x bbox diagonal) and only then decimate (collapse, triangulated).
     Scans arrive split at every UV and normal seam; unwelded, the decimator cannot
     collapse across the splits and stalls far above the target.
  4. Clear imported split normals and shade smooth (--smooth-angle < 180 marks
     sharper edges flat). The source detail (geometry and its normal map) is baked
     with Cycles into a new tangent-space normal map on the decimated mesh, so the
     scan's normals survive decimation. --no-bake reuses the source normal map.
  5. Textures, each at most --tex px: albedo (sRGB) with optional --saturation
     (lerp from linear Rec.709 luminance), --value (multiplier) and --tint, applied
     in that order. --tint r,g,b are sRGB 0..1; the pixels are recoloured so the
     texture's mean becomes that colour while each pixel keeps its luminance ratio
     to the mean, blended by strength (default 1). ORM is packed as the glTF / game
     convention: R = ambient occlusion, G = roughness, B = metallic (the same
     layout as assets/textures/*_orm.png); AO comes from the glTF occlusion map or,
     failing that, from the R channel of an `arm`/`orm` named roughness map
     (Poly Haven, ambientCG). The exporter writes one image for both
     occlusionTexture and metallicRoughnessTexture.
  6. Export with blender/common.py's GLTF_EXPORT conventions (Y-up, normals,
     tangents, no animation). Textures embed as JPEG (albedo/ORM q92, normal q95;
     a 1k set is about 1.4 MB, PNG about 2.9 MB) or all PNG with --image-format png.
     Materials are single-sided unless --double-sided.
  7. --lod1 N writes a further-decimated copy sharing the same UVs and textures as a
     separate file `<name><suffix>.glb`. The game's only LOD convention is a sibling
     file: Assets.plant(..., distant=true) loads `assets/trees/<species>_distant.glb`
     and Assets.mesh() takes the first MeshInstance3D of a file, so the default
     suffix is `_distant`. Godot also auto-generates LODs on import.
  8. --manifest-id appends the output path(s) to that row of assets/CC0_MANIFEST.json
     (resolution inferred from a cache path when omitted).

Prints triangles before and after, final dimensions (x, y-up, z) and texture sizes.
"""
import argparse
import math
import re
import sys
import tempfile
import time
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "blender"))
sys.path.insert(0, str(ROOT / "tools" / "art"))
from common import GLTF_EXPORT  # noqa: E402

LUMA = np.array([0.2126, 0.7152, 0.0722], dtype=np.float32)
LOD_RE = re.compile(r"(?:^|[_.\- ])lod[_ ]?(\d+)", re.I)


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="normalize_asset.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", type=Path)
    ap.add_argument("--out", type=Path, required=True, help="assets/<category>/<name>.glb")
    ap.add_argument("--tris", type=int, required=True, help="LOD0 triangle target")
    ap.add_argument("--lod1", type=int, help="also write <name><suffix>.glb at this many triangles")
    ap.add_argument("--lod1-suffix", default="_distant")
    size = ap.add_mutually_exclusive_group()
    size.add_argument("--height", type=float, help="final up extent in metres")
    size.add_argument("--scale", type=float, help="uniform scale factor")
    ap.add_argument("--origin", choices=["base", "center"], default="base")
    ap.add_argument("--tint", help="r,g,b[,strength] sRGB 0..1: target mean albedo colour")
    ap.add_argument("--saturation", type=float, default=1.0, help="albedo saturation factor")
    ap.add_argument("--value", type=float, default=1.0, help="albedo brightness factor")
    ap.add_argument("--tex", type=int, default=1024, help="max texture side in px")
    ap.add_argument("--manifest-id", help="source:id[:resolution] row to record the output in")
    ap.add_argument("--no-bake", action="store_true", help="reuse the source normal map instead of baking")
    ap.add_argument("--cage", type=float, help="bake cage extrusion in metres (default 1.5%% of max dimension)")
    ap.add_argument("--smooth-angle", type=float, default=180.0, help="degrees; 180 = smooth everywhere")
    ap.add_argument("--weld", type=float, help="merge distance (default 1e-5 x bbox diagonal)")
    ap.add_argument("--keep-lods", action="store_true", help="do not drop *_LODn siblings")
    ap.add_argument("--image-format", choices=["jpg", "png"], default="jpg", help="embedded texture format")
    ap.add_argument("--double-sided", action="store_true")
    ap.add_argument("--object", help="keep only mesh objects with this name (one piece of a multi-object set)")
    a = ap.parse_args(argv)
    if a.tint:
        t = [float(v) for v in a.tint.split(",")]
        if len(t) not in (3, 4):
            ap.error("--tint takes r,g,b[,strength]")
        a.tint = (np.array(t[:3], dtype=np.float32), t[3] if len(t) == 4 else 1.0)
    return a


def tris(obj):
    return sum(len(p.vertices) - 2 for p in obj.data.polygons)


def activate(*objs):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[-1]


def import_any(path: Path):
    ext = path.suffix.lower()
    if ext in (".gltf", ".glb"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path))
    elif ext == ".obj":
        bpy.ops.wm.obj_import(filepath=str(path))
    else:
        raise SystemExit("unsupported input %s" % path)


def lod_index(o):
    for name in (o.name, o.data.name):
        m = LOD_RE.search(name)
        if m:
            return int(m.group(1))
    return None


def gather(args):
    scene = bpy.context.scene
    meshes = [o for o in scene.objects if o.type == "MESH"]
    if args.object:
        for o in [o for o in meshes if o.name != args.object]:
            bpy.data.objects.remove(o)
        meshes = [o for o in scene.objects if o.type == "MESH"]
    if not meshes:
        raise SystemExit("no meshes in %s" % args.input)
    lods = {o: lod_index(o) for o in meshes}
    if not args.keep_lods and any(v is not None for v in lods.values()):
        best = min(v for v in lods.values() if v is not None)
        drop = [o for o, v in lods.items() if v is not None and v != best]
        if drop:
            print("dropping LOD siblings:", ", ".join(o.name for o in drop))
        meshes = [o for o in meshes if o not in drop]
        for o in drop:
            bpy.data.objects.remove(o)
    for o in meshes:
        for mod in [m for m in o.modifiers if m.type == "ARMATURE"]:
            print("warning: dropping armature modifier on %s (static props only)" % o.name)
            o.modifiers.remove(mod)
        if o.data.shape_keys:
            activate(o)
            bpy.ops.object.shape_key_remove(all=True, apply_mix=False)
    activate(*meshes)
    bpy.ops.object.parent_clear(type="CLEAR_KEEP_TRANSFORM")
    for o in list(scene.objects):
        if o.type != "MESH":
            bpy.data.objects.remove(o)
    activate(*meshes)
    if len(meshes) > 1:
        bpy.ops.object.join()
    obj = bpy.context.view_layer.objects.active
    obj.data = obj.data.copy() if obj.data.users > 1 else obj.data
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    return obj


def bounds(obj):
    co = np.empty(len(obj.data.vertices) * 3, dtype=np.float64)
    obj.data.vertices.foreach_get("co", co)
    co = co.reshape(-1, 3)
    return co.min(0), co.max(0)


def place(obj, args, final=False):
    """Scale to metres and move the origin. `final` re-fits after decimation:
    exact --height again, no second --scale."""
    lo, hi = bounds(obj)
    dims = hi - lo
    s = args.height / dims[2] if args.height else (1.0 if final else args.scale or 1.0)
    obj.data.transform(Matrix.Scale(s, 4))
    lo, hi = bounds(obj)
    c = (lo + hi) / 2
    pivot = Vector((c[0], c[1], lo[2] if args.origin == "base" else c[2]))
    obj.data.transform(Matrix.Translation(-pivot))
    obj.location = (0, 0, 0)
    print("scale x%.5g, origin %s" % (s, args.origin))


def weld_and_decimate(obj, target, weld):
    activate(obj)
    if obj.data.has_custom_normals:
        bpy.ops.mesh.customdata_custom_splitnormals_clear()
    lo, hi = bounds(obj)
    dist = weld if weld is not None else float(np.linalg.norm(hi - lo)) * 1e-5
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    n0 = len(bm.verts)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=dist)
    print("weld: %d -> %d vertices (distance %.3g)" % (n0, len(bm.verts), dist))
    bm.to_mesh(obj.data)
    bm.free()
    decimate(obj, target)


def decimate(obj, target):
    activate(obj)
    for _ in range(4):
        now = tris(obj)
        if now <= target * 1.01:
            break
        mod = obj.modifiers.new("decimate", "DECIMATE")
        mod.decimate_type = "COLLAPSE"
        mod.use_collapse_triangulate = True
        mod.ratio = target / now
        bpy.ops.object.modifier_apply(modifier=mod.name)


def shade(obj, angle):
    activate(obj)
    bpy.ops.object.shade_smooth()
    if angle < 180:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))


# ---------------------------------------------------------------- materials

def upstream(socket, seen=None):
    """(image, channel) feeding a socket; channel None = colour, 0/1/2 = R/G/B."""
    if socket is None or not socket.is_linked:
        return None, None
    seen = seen or set()
    link = socket.links[0]
    node = link.from_node
    if node in seen:
        return None, None
    seen.add(node)
    if node.type == "TEX_IMAGE" and node.image:
        return node.image, None
    if node.type in ("SEPARATE_COLOR", "SEPRGB", "SEPARATE_RGB"):
        img, _ = upstream(node.inputs[0], seen)
        names = [o.name for o in node.outputs]
        return img, names.index(link.from_socket.name)
    for inp in node.inputs:
        img, ch = upstream(inp, seen)
        if img:
            return img, ch
    return None, None


def describe(mat):
    out = {"name": mat.name, "base": None, "base_value": (0.8, 0.8, 0.8), "rough": None, "rough_value": 0.85,
           "metal": None, "metal_value": 0.0, "normal": None, "ao": None}
    if mat.node_tree is None:
        out["base_value"] = tuple(mat.diffuse_color[:3])
        return out
    nodes = mat.node_tree.nodes
    p = next((n for n in nodes if n.type == "BSDF_PRINCIPLED"), None)
    if p:
        out["base"] = upstream(p.inputs["Base Color"])[0]
        out["base_value"] = tuple(p.inputs["Base Color"].default_value[:3])
        out["rough"] = upstream(p.inputs["Roughness"])
        out["rough_value"] = p.inputs["Roughness"].default_value
        out["metal"] = upstream(p.inputs["Metallic"])
        out["metal_value"] = p.inputs["Metallic"].default_value
        n = p.inputs["Normal"]
        if n.is_linked and n.links[0].from_node.type == "NORMAL_MAP":
            out["normal"] = upstream(n.links[0].from_node.inputs["Color"])[0]
    for g in nodes:
        if g.type == "GROUP" and g.node_tree and (g.node_tree.name.startswith("glTF Material Output")
                                                  or g.node_tree.name.lower().startswith("gltf settings")):
            if "Occlusion" in g.inputs:
                img, ch = upstream(g.inputs["Occlusion"])
                if img:
                    out["ao"] = (img, 0 if ch is None else ch)
    if out["ao"] is None and out["rough"] and out["rough"][0] and re.search(r"(^|[_\-.])(arm|orm)([_\-.]|$)",
                                                                             out["rough"][0].name + " " + out["rough"][0].filepath, re.I):
        out["ao"] = (out["rough"][0], 0)
    return out


def fit(img, limit):
    w, h = img.size
    k = min(1.0, limit / max(w, h))
    return max(1, round(w * k)), max(1, round(h * k))


def pixels(img, size):
    """Stored (encoded) RGBA values, float32 (h, w, 4), resized to size."""
    work = img.copy()
    if tuple(work.size) != tuple(size):
        work.scale(*size)
    buf = np.empty(size[0] * size[1] * 4, dtype=np.float32)
    work.pixels.foreach_get(buf)
    bpy.data.images.remove(work)
    return buf.reshape(size[1], size[0], 4)


def to_lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def grade(rgb, args):
    lin = to_lin(rgb)
    before = float((lin @ LUMA).mean())
    if args.saturation != 1.0:
        y = (lin @ LUMA)[..., None]
        lin = np.clip(y + (lin - y) * args.saturation, 0, None)
    if args.value != 1.0:
        lin = lin * args.value
    if args.tint is not None:
        colour, strength = args.tint
        y = lin @ LUMA
        target = to_lin(colour)[None, None, :] * (y / max(float(y.mean()), 1e-6))[..., None]
        lin = lin + (target - lin) * strength
    out = to_srgb(lin)
    return out, before, float((to_lin(out) @ LUMA).mean())


def new_image(name, array, colour, fmt, tmp: Path):
    h, w = array.shape[:2]
    # Colour space first: changing it later regenerates a GENERATED image and
    # discards the pixels. Byte pixels are stored as given (encoded values).
    img = bpy.data.images.new(name, w, h, alpha=False, is_data=colour == "Non-Color")
    img.colorspace_settings.name = colour
    rgba = np.ones((h, w, 4), dtype=np.float32)
    rgba[..., :3] = array[..., :3]
    img.pixels.foreach_set(rgba.ravel())
    img.update()
    ext = {"PNG": ".png", "JPEG": ".jpg"}[fmt]
    img.filepath_raw = str(tmp / (name + ext))
    img.file_format = fmt
    img.save(quality=92) if fmt == "JPEG" else img.save()
    return img


def build_material(name, albedo, orm, normal, double_sided, link_normal=True):
    m = bpy.data.materials.new(name)
    if m.node_tree is None or not any(n.type == "BSDF_PRINCIPLED" for n in m.node_tree.nodes):
        m.use_nodes = True  # Blender < 5 creates materials without a node tree
    m.use_backface_culling = not double_sided
    nt = m.node_tree
    nodes, links = nt.nodes, nt.links
    p = next(n for n in nodes if n.type == "BSDF_PRINCIPLED")

    def tex(img, x, y, data):
        t = nodes.new("ShaderNodeTexImage")
        t.image = img
        t.location = (x, y)
        if data:
            img.colorspace_settings.name = "Non-Color"
        return t

    links.new(tex(albedo, -700, 300, False).outputs["Color"], p.inputs["Base Color"])
    o = tex(orm, -900, 0, True)
    sep = nodes.new("ShaderNodeSeparateColor")
    sep.location = (-600, 0)
    links.new(o.outputs["Color"], sep.inputs[0])
    links.new(sep.outputs[1], p.inputs["Roughness"])
    links.new(sep.outputs[2], p.inputs["Metallic"])
    group = bpy.data.node_groups.get("glTF Material Output")
    if group is None:
        group = bpy.data.node_groups.new("glTF Material Output", "ShaderNodeTree")
        group.interface.new_socket("Occlusion", in_out="INPUT", socket_type="NodeSocketFloat")
    g = nodes.new("ShaderNodeGroup")
    g.node_tree = group
    g.location = (0, -300)
    links.new(sep.outputs[0], g.inputs["Occlusion"])
    nt_node = nm = None
    if normal is not None:
        # A bake target must not feed the shader it is baked through (circular), so
        # the normal map is linked after the bake.
        nt_node = tex(normal, -700, -350, True)
        nm = nodes.new("ShaderNodeNormalMap")
        nm.location = (-300, -350)
        links.new(nm.outputs["Normal"], p.inputs["Normal"])
        if link_normal:
            links.new(nt_node.outputs["Color"], nm.inputs["Color"])
    return m, nt_node, nm


def textures(low, high, args, tmp: Path, stem: str):
    """Rebuild every material slot of `low` with processed textures; bake normals."""
    fmt_colour = "PNG" if args.image_format == "png" else "JPEG"
    fmt_normal = fmt_colour
    made, bake_nodes, report, created = [], [], [], []
    slots = list(low.material_slots) or [None]
    for i, slot in enumerate(slots):
        src = slot.material if slot else None
        d = describe(src) if src else {"name": stem, "base": None, "base_value": (0.8, 0.8, 0.8), "rough": None,
                                        "rough_value": 0.85, "metal": None, "metal_value": 0.0, "normal": None, "ao": None}
        tag = stem if len(slots) == 1 else "%s_%d" % (stem, i)
        sources = [x for x in (d["base"], d["rough"] and d["rough"][0], d["metal"] and d["metal"][0],
                               d["normal"], d["ao"] and d["ao"][0]) if x]
        biggest = max(sources, key=lambda im: max(im.size)) if sources else None
        size = fit(biggest, args.tex) if biggest else (min(args.tex, 256),) * 2
        if d["base"]:
            base = pixels(d["base"], size)[..., :3]
        else:
            base = np.ones((size[1], size[0], 3), dtype=np.float32) * to_srgb(np.array(d["base_value"], dtype=np.float32))
        base, lum0, lum1 = grade(base, args)
        albedo = new_image(tag + "_albedo", base, "sRGB", fmt_colour, tmp)

        def channel(spec, value):
            if spec and spec[0]:
                px = pixels(spec[0], size)
                return px[..., spec[1] if spec[1] is not None else 0]
            return np.full((size[1], size[0]), value, dtype=np.float32)

        orm = np.stack([channel(d["ao"], 1.0), channel(d["rough"], d["rough_value"]),
                        channel(d["metal"], d["metal_value"])], -1)
        orm_img = new_image(tag + "_orm", orm, "Non-Color", fmt_colour, tmp)
        normal_img = None
        bake = not args.no_bake and high is not None and low.data.uv_layers
        if bake:
            normal_img = bpy.data.images.new(tag + "_normal", size[0], size[1], alpha=False)
            normal_img.colorspace_settings.name = "Non-Color"
            normal_img.generated_color = (0.5, 0.5, 1.0, 1.0)
        elif d["normal"]:
            normal_img = new_image(tag + "_normal", pixels(d["normal"], size)[..., :3], "Non-Color", fmt_normal, tmp)
        mat, node, nm = build_material(tag, albedo, orm_img, normal_img, args.double_sided, link_normal=not bake)
        if bake:
            mat.node_tree.nodes.active = node
            bake_nodes.append((normal_img, node, nm, mat))
        created.extend([(albedo, fmt_colour), (orm_img, fmt_colour)] + ([(normal_img, fmt_normal)] if normal_img else []))
        made.append(mat)
        report.append((tag, size, lum0, lum1, d))
    for i, m in enumerate(made):
        if i < len(low.material_slots):
            low.material_slots[i].material = m
        else:
            low.data.materials.append(m)
    if bake_nodes:
        bake_normals(low, high, args)
        for img, node, nm, mat in bake_nodes:
            img.filepath_raw = str(tmp / (img.name + {"PNG": ".png", "JPEG": ".jpg"}[fmt_normal]))
            img.file_format = fmt_normal
            img.save(quality=95) if fmt_normal == "JPEG" else img.save()
            mat.node_tree.links.new(node.outputs["Color"], nm.inputs["Color"])
    for tag, size, lum0, lum1, d in report:
        print("material %s: %dx%d; albedo mean linear luminance %.3f -> %.3f; ao %s, roughness %s, normal %s"
              % (tag, size[0], size[1], lum0, lum1, "map" if d["ao"] else "1.0",
                 "map" if d["rough"] and d["rough"][0] else "%.2f" % d["rough_value"],
                 "baked" if bake_nodes else ("source" if d["normal"] else "none")))
    return [(img.name, img.size[0], img.size[1], fmt) for img, fmt in created]


def bake_normals(low, high, args):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.device = "CPU"
    scene.cycles.samples = 4
    lo, hi = bounds(low)
    ext = args.cage if args.cage is not None else float((hi - lo).max()) * 0.015
    high.hide_render = False
    activate(high, low)
    t = time.time()
    bpy.ops.object.bake(type="NORMAL", use_selected_to_active=True, cage_extrusion=ext, max_ray_distance=ext * 2,
                        margin=16, normal_space="TANGENT", use_clear=True)
    print("baked tangent normals from %d source triangles in %.1fs (cage %.3f m)" % (tris(high), time.time() - t, ext))


def export(obj, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    activate(obj)
    settings = dict(GLTF_EXPORT, export_image_format="AUTO", export_jpeg_quality=92)
    bpy.ops.export_scene.gltf(filepath=str(path), use_selection=True, export_materials="EXPORT", **settings)


def main():
    args = parse()
    t0 = time.time()
    bpy.ops.wm.read_factory_settings(use_empty=True)
    src = args.input.resolve()
    import_any(src)
    obj = gather(args)
    before = tris(obj)
    place(obj, args)
    out = args.out if args.out.is_absolute() else (Path.cwd() / args.out)
    stem = out.stem
    obj.name = obj.data.name = stem

    high = None
    if before > args.tris and not args.no_bake:
        high = obj.copy()
        high.data = obj.data.copy()
        high.name = stem + "_source"
        bpy.context.collection.objects.link(high)
    weld_and_decimate(obj, args.tris, args.weld)
    shade(obj, args.smooth_angle)
    after = tris(obj)

    with tempfile.TemporaryDirectory(prefix="normalize_") as tmp:
        images = textures(obj, high, args, Path(tmp), stem)
        if high is not None:
            bpy.data.objects.remove(high)
        place(obj, args, final=True)  # decimation moves the bounds slightly
        export(obj, out)
        written = [out]
        if args.lod1:
            lod = obj.copy()
            lod.data = obj.data.copy()
            lod.name = lod.data.name = stem + args.lod1_suffix
            bpy.context.collection.objects.link(lod)
            decimate(lod, args.lod1)
            lod_path = out.with_name(stem + args.lod1_suffix + ".glb")
            export(lod, lod_path)
            written.append(lod_path)
            print("LOD1 %s: %d triangles" % (lod_path.name, tris(lod)))

    lo, hi = bounds(obj)
    d = hi - lo
    print("NORMALIZED %s" % src.name)
    print("  triangles %d -> %d (target %d)" % (before, after, args.tris))
    print("  dimensions x %.3f, y(up) %.3f, z %.3f m" % (d[0], d[2], d[1]))
    for name, w, h, fmt in images:
        print("  texture %-28s %4dx%-4d %s" % (name, w, h, fmt))
    for p in written:
        print("  wrote %s (%.0f KB)" % (p.as_posix(), p.stat().st_size / 1024))
    if args.manifest_id:
        import manifest
        for p in written:
            row = manifest.add_output(args.manifest_id, str(p), str(src))
        print("  manifest %s:%s:%s outputs %s" % (row["source"], row["id"], row["resolution"], row["outputs"]))
    print("  %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
