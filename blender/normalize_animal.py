"""Normalise an outside (CC0) rigged, animated animal into a game-ready skinned GLB.

  blender --background --python blender/normalize_animal.py -- <input.glb|.blend|.fbx>
      --out assets/wildlife/<name>.glb --clips idle=Idle,walk=Walk,run=Gallop,graze=Eating
      [--height 1.45 | --scale 0.01] [--height-exclude Horns] [--drop Icosphere,Plane,Teeth]
      [--colors "Main=0.46,0.38,0.30;Main_Light=0.80,0.76,0.68"] [--roughness 0.9]
      [--material-image "body=doe-body;head=doe-head"] [--image "doe-body=<png>"] [--tex 1024]
      [--smooth-angle 60] [--tris 8000] [--max-influences 4] [--pose "Mouth=rx:-12"]
      [--object-scale "Stag_Horns=0.62"] [--paint "Tail2,Tail3@up=r,g,b;..."] [--rest-uv]
      [--image-format AUTO|JPEG|WEBP] [--manifest-id source:id:resolution]

normalize_asset.py is for static props (it drops armatures). This keeps the skin and
the clips; it never moves vertices by hand.

Steps, in order:
  1. Open (.blend) or import (.glb/.gltf/.fbx). Delete objects named in --drop (prefix
     match) and any mesh that is neither skinned to the armature nor parented to one of
     its bones (preview planes, spheres). --object-scale rescales a bone-parented part
     (e.g. antlers) about its origin. Meshes named like a bone are renamed (glTF node
     names are unique, so the bone would otherwise be renamed on import).
  2. Keep only the actions named in --clips and rename them to the game's clip names
     (`idle`, `walk`, `run`, `graze`, ...). Duplicate `Armature|Clip` copies go.
  3. Materials: --colors sets base colours (sRGB) by material name; --material-image
     rebuilds a material around an image (legacy Blender-Internal blends keep their
     textures outside the node tree, which the glTF exporter cannot see); --image
     swaps an image's pixels for a prepared file (e.g. a repaint). Images are resized
     to --tex. Metallic is zeroed and roughness set (fur and feathers are not metal).
  4. --smooth-angle welds the split vertices of a flat-shaded source (same position,
     so the same weights) and shades smooth below that angle.
  5. --pose bone=rx:deg[,ry:deg,rz:deg] adds a constant rotation to that bone in every
     kept clip (e.g. close a jaw that the source animates open).
  6. Skin: at most --max-influences weights per vertex, normalised.
  7. Scale (--height of the mesh in the first clip's first frame, ignoring
     --height-exclude objects) and place under one root so the feet stand on the origin
     and the head faces Blender +Y (glTF/Godot -Z, the game's forward).
  8. --paint (or --rest-uv) moves flat material colours into a corner colour layer
     (materials go white) and paints faces whose vertices are mostly weighted to the
     named bones and that face up/down/front/back/side, e.g. a dark tail top. --rest-uv
     writes the placed rest coordinates into UV0 (x, y) and UV1 (z) so a shader's fur
     noise does not swim with the skin (untextured meshes only). Export GLB with the
     kept clips, sampled; --image-format JPEG shrinks embedded photo textures.
  9. --manifest-id appends the output path to that row of assets/CC0_MANIFEST.json.

Prints triangles, joints, clips (length) and final dimensions.
"""
import argparse
import math
import sys
import time
from pathlib import Path

import bpy
import numpy as np
from mathutils import Euler, Quaternion, Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "blender"))
sys.path.insert(0, str(ROOT / "tools" / "art"))


def parse():
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    ap = argparse.ArgumentParser(prog="normalize_animal.py", description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input", type=Path)
    ap.add_argument("--out", type=Path, required=True)
    ap.add_argument("--clips", required=True, help="game=source,... e.g. idle=Idle,walk=Walk")
    size = ap.add_mutually_exclusive_group()
    size.add_argument("--height", type=float, help="rest-pose height in metres")
    size.add_argument("--scale", type=float, help="uniform scale factor")
    ap.add_argument("--height-exclude", default="", help="objects ignored when measuring height (e.g. antlers)")
    ap.add_argument("--drop", default="", help="comma list of object-name prefixes to delete")
    ap.add_argument("--colors", default="", help="Material=r,g,b;... sRGB base colours")
    ap.add_argument("--material-image", default="", help="material=image;... rebuild material around image")
    ap.add_argument("--image", action="append", default=[], help="image=path: replace pixels from a file")
    ap.add_argument("--normal-image", default="", help="material=image;... add a normal map")
    ap.add_argument("--roughness", type=float, default=0.9)
    ap.add_argument("--tex", type=int, default=1024)
    ap.add_argument("--smooth-angle", type=float, help="weld and shade smooth below this angle (degrees)")
    ap.add_argument("--tris", type=int, default=8000, help="budget; decimate (collapse) above it")
    ap.add_argument("--max-influences", type=int, default=4)
    ap.add_argument("--object-scale", default="", help="object=f;... rescale a bone-parented part about its origin")
    ap.add_argument("--pose", action="append", default=[], help="bone=rx:deg,ry:deg,rz:deg constant offset")
    ap.add_argument("--paint", default="", help="bones@facing=r,g,b;... vertex-colour paint (bakes material colours)")
    ap.add_argument("--rest-uv", action="store_true", help="write rest-pose coordinates into UV0/UV1")
    ap.add_argument("--image-format", default="AUTO", choices=["AUTO", "JPEG", "WEBP"], help="embedded texture format")
    ap.add_argument("--manifest-id")
    return ap.parse_args(argv)


def pairs(text, sep=";"):
    out = {}
    for item in filter(None, (s.strip() for s in text.split(sep))):
        k, _, v = item.partition("=")
        out[k.strip()] = v.strip()
    return out


def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def load(path: Path):
    ext = path.suffix.lower()
    if ext == ".blend":
        bpy.ops.wm.open_mainfile(filepath=str(path))
        return
    bpy.ops.wm.read_factory_settings(use_empty=True)
    if ext in (".glb", ".gltf"):
        bpy.ops.import_scene.gltf(filepath=str(path))
    elif ext == ".fbx":
        bpy.ops.import_scene.fbx(filepath=str(path), automatic_bone_orientation=True)
    else:
        raise SystemExit("unsupported input %s" % path)


def armature_of(obj):
    for m in obj.modifiers:
        if m.type == "ARMATURE" and m.object:
            return m.object
    return None


def activate(o):
    for other in bpy.context.view_layer.objects:
        other.select_set(False)
    o.select_set(True)
    bpy.context.view_layer.objects.active = o


def tris(meshes):
    return sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in meshes)


def clean_objects(args):
    drop = [d for d in args.drop.split(",") if d]
    for o in list(bpy.data.objects):
        if any(o.name.startswith(d) for d in drop):
            bpy.data.objects.remove(o, do_unlink=True)
    arms = [o for o in bpy.data.objects if o.type == "ARMATURE"]
    if len(arms) != 1:
        raise SystemExit("expected one armature, found %s" % [a.name for a in arms])
    arm = arms[0]
    for o in list(bpy.data.objects):
        if o.type == "MESH" and armature_of(o) is not arm and not (o.parent is arm and o.parent_type == "BONE"):
            print("  dropping unskinned mesh %s" % o.name)
            bpy.data.objects.remove(o, do_unlink=True)
        elif o.type not in ("MESH", "ARMATURE", "EMPTY"):
            bpy.data.objects.remove(o, do_unlink=True)
    for o in list(bpy.data.objects):  # bone-tip empties from FBX2glTF
        if o.type == "EMPTY" and not o.children:
            bpy.data.objects.remove(o, do_unlink=True)
    meshes = [o for o in bpy.data.objects if o.type == "MESH"]
    bones = {b.name for b in arm.data.bones}
    for o in meshes:  # glTF node names are unique: a mesh named like a bone renames the bone
        if o.name in bones:
            o.name = o.name + "_mesh"
    for name, f in pairs(args.object_scale).items():
        o = bpy.data.objects[name]
        o.scale = tuple(x * float(f) for x in o.scale)
    for o in meshes:  # one UV layer: the first is the painted one in every source used
        while len(o.data.uv_layers) > 1:
            o.data.uv_layers.remove(o.data.uv_layers[-1])
        o.hide_render = o.hide_viewport = False
        o.hide_set(False)
    return arm, meshes


def keep_clips(arm, clips):
    wanted = {src: game for game, src in clips.items()}
    for a in list(bpy.data.actions):
        if a.name not in wanted:
            bpy.data.actions.remove(a)
    kept = [(a, wanted[a.name]) for a in bpy.data.actions]  # renaming re-sorts the collection
    for a, _ in kept:
        a.name = "__" + a.name
    for a, game in kept:
        a.name = game
        a.use_fake_user = True
    missing = set(clips) - {a.name for a in bpy.data.actions}
    if missing:
        raise SystemExit("clips not found in source: %s" % sorted(missing))
    arm.animation_data_create()
    if arm.animation_data.nla_tracks:
        for t in list(arm.animation_data.nla_tracks):
            arm.animation_data.nla_tracks.remove(t)
    first = bpy.data.actions[clips and list(clips)[0]]
    arm.animation_data.action = first
    if hasattr(arm.animation_data, "action_slot") and first.slots:
        arm.animation_data.action_slot = first.slots[0]


def material_setup(meshes, args):
    colors = pairs(args.colors)
    images = pairs(args.material_image)
    normals = pairs(args.normal_image)
    for spec in args.image:
        name, _, path = spec.partition("=")
        img = bpy.data.images[name]
        src = bpy.data.images.load(path)
        img.scale(*src.size)
        img.pixels.foreach_set(np.array(src.pixels[:], dtype=np.float32))
        img.update()
        img.pack()
        bpy.data.images.remove(src)
    for key in [k for k in colors if ":" in k]:  # object:material gets its own copy
        obj, _, mat = key.partition(":")
        o = bpy.data.objects[obj]
        for slot in o.material_slots:
            if slot.material and slot.material.name == mat:
                copy = slot.material.copy()
                copy.name = "%s_%s" % (obj, mat)
                slot.link = "OBJECT"
                slot.material = copy
                colors[copy.name] = colors[key]
    seen = set()
    for o in meshes:
        for slot in o.material_slots:
            m = slot.material
            if m is None or m.name in seen:
                continue
            seen.add(m.name)
            m.use_nodes = True
            nt = m.node_tree
            if m.name in images:
                for n in list(nt.nodes):
                    nt.nodes.remove(n)
                out = nt.nodes.new("ShaderNodeOutputMaterial")
                bsdf = nt.nodes.new("ShaderNodeBsdfPrincipled")
                nt.links.new(bsdf.outputs["BSDF"], out.inputs["Surface"])
                tex = nt.nodes.new("ShaderNodeTexImage")
                tex.image = bpy.data.images[images[m.name]]
                nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
                if m.name in normals:
                    nimg = bpy.data.images[normals[m.name]]
                    nimg.colorspace_settings.name = "Non-Color"
                    ntex = nt.nodes.new("ShaderNodeTexImage")
                    ntex.image = nimg
                    nmap = nt.nodes.new("ShaderNodeNormalMap")
                    nt.links.new(ntex.outputs["Color"], nmap.inputs["Color"])
                    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
            bsdf = next((n for n in nt.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf is None:
                continue
            bsdf.inputs["Metallic"].default_value = 0.0
            bsdf.inputs["Roughness"].default_value = args.roughness
            for link in list(nt.links):  # imported factors may arrive through nodes
                if link.to_socket in (bsdf.inputs["Metallic"], bsdf.inputs["Roughness"]):
                    nt.links.remove(link)
            if m.name in colors:
                rgb = [srgb_to_linear(float(x)) for x in colors[m.name].split(",")]
                for link in list(nt.links):
                    if link.to_socket == bsdf.inputs["Base Color"]:
                        nt.links.remove(link)
                bsdf.inputs["Base Color"].default_value = (*rgb, 1.0)
                m.diffuse_color = (*rgb, 1.0)
    for img in bpy.data.images:
        if img.size[0] > args.tex or img.size[1] > args.tex:
            k = args.tex / max(img.size)
            img.scale(max(1, round(img.size[0] * k)), max(1, round(img.size[1] * k)))
            img.pack()


def base_color(m):
    bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None) if m and m.node_tree else None
    if bsdf is None or bsdf.inputs["Base Color"].is_linked:
        return None
    return tuple(bsdf.inputs["Base Color"].default_value[:3])


def bake_vertex_colors(meshes, rules):
    """Move flat material colours into a corner colour layer (white materials), then
    paint faces by bone weight and facing: `Tail2,Tail3@up=r,g,b` (sRGB). Directions are
    in the placed model: forward +Y (the head), up +Z, side +-X."""
    dirs = {"up": Vector((0, 0, 1)), "down": Vector((0, 0, -1)), "front": Vector((0, 1, 0)),
            "back": Vector((0, -1, 0)), "side": None, "any": None}
    parsed = []
    for rule, rgb in pairs(rules).items():
        bones, _, facing = rule.partition("@")
        parsed.append(([b for b in bones.split(",") if b], facing or "any",
                       tuple(srgb_to_linear(float(x)) for x in rgb.split(","))))
    dg = bpy.context.evaluated_depsgraph_get()
    painted = 0
    for o in meshes:
        me = o.data
        colours = [base_color(slot.material) for slot in o.material_slots]
        if not any(c is not None for c in colours):
            continue
        while me.color_attributes:  # FBX2glTF sources carry an all-white layer
            me.color_attributes.remove(me.color_attributes[0])
        layer = me.color_attributes.new("Color", "FLOAT_COLOR", "CORNER")
        ev = o.evaluated_get(dg)
        posed = ev.to_mesh()
        rot = ev.matrix_world.to_3x3()
        groups = {g.index: g.name for g in o.vertex_groups}
        for poly in me.polygons:
            c = colours[poly.material_index] if poly.material_index < len(colours) else None
            c = c or (1.0, 1.0, 1.0)
            n = (rot @ posed.polygons[poly.index].normal).normalized()
            for bones, facing, rgb in parsed:
                weight = 0.0
                for vi in poly.vertices:
                    weight += sum(g.weight for g in me.vertices[vi].groups if groups.get(g.group) in bones)
                weight /= len(poly.vertices)
                if weight < 0.5:
                    continue
                if facing == "side" and abs(n.x) < 0.5:
                    continue
                if dirs.get(facing) is not None and n.dot(dirs[facing]) < 0.25:
                    continue
                c = rgb
                painted += 1
            for li in poly.loop_indices:
                layer.data[li].color = (*c, 1.0)
        ev.to_mesh_clear()
        me.color_attributes.active_color = layer
        me.color_attributes.render_color_index = me.color_attributes.find("Color")
    for o in meshes:
        for slot in o.material_slots:
            m = slot.material
            if m and base_color(m) is not None:
                bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
                bsdf.inputs["Base Color"].default_value = (1, 1, 1, 1)
                m.diffuse_color = (1, 1, 1, 1)
    print("  vertex colours baked; %d face paints" % painted)


def rest_uvs(meshes):
    """UV0 = rest (x, y), UV1 = (z, 0) in metres of the placed model, for shaders that
    want a coordinate that does not swim with the skin (fur noise). Untextured only."""
    dg = bpy.context.evaluated_depsgraph_get()
    for o in meshes:
        me = o.data
        if me.uv_layers:
            raise SystemExit("--rest-uv needs untextured meshes; %s has UVs" % o.name)
        ev = o.evaluated_get(dg)
        posed = ev.to_mesh()
        world = [ev.matrix_world @ v.co for v in posed.vertices]
        ev.to_mesh_clear()
        a = me.uv_layers.new(name="RestXY")
        b = me.uv_layers.new(name="RestZ")
        for loop in me.loops:
            p = world[loop.vertex_index]
            a.data[loop.index].uv = (p.x, p.y)
            b.data[loop.index].uv = (p.z, 0.0)


def smooth(meshes, angle):
    for o in meshes:
        activate(o)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_all(action="SELECT")
        bpy.ops.mesh.remove_doubles(threshold=1e-5 * max(o.dimensions))
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(angle))


def decimate(meshes, budget):
    total = tris(meshes)
    if total <= budget:
        return
    ratio = budget / total * 0.98
    for o in meshes:
        activate(o)
        mod = o.modifiers.new("Decimate", "DECIMATE")
        mod.ratio = ratio
        # Collapse must run before the armature deforms; move it to the top.
        while o.modifiers.find(mod.name) > 0:
            bpy.ops.object.modifier_move_up(modifier=mod.name)
        bpy.ops.object.modifier_apply(modifier=mod.name)


def limit_influences(meshes, limit):
    worst = 0
    for o in meshes:
        if not o.vertex_groups:
            continue
        activate(o)
        bpy.ops.object.vertex_group_clean(group_select_mode="ALL", limit=0.001)
        bpy.ops.object.vertex_group_limit_total(group_select_mode="ALL", limit=limit)
        bpy.ops.object.vertex_group_normalize_all(group_select_mode="ALL", lock_active=False)
        for v in o.data.vertices:
            worst = max(worst, sum(1 for g in v.groups if g.weight > 0))
    return worst


def pose_offsets(arm, specs):
    for spec in specs:
        bone, _, rest = spec.partition("=")
        rot = [0.0, 0.0, 0.0]
        for part in rest.split(","):
            axis, _, deg = part.partition(":")
            rot["xyz".index(axis[-1])] = math.radians(float(deg))
        q = Euler(rot).to_quaternion()
        path = 'pose.bones["%s"].rotation_quaternion' % bone
        for a in bpy.data.actions:
            curves = [fc for fc in fcurves(a) if fc.data_path == path]
            if len(curves) != 4:
                pb = arm.pose.bones[bone]
                pb.rotation_mode = "QUATERNION"
                frames = sorted({int(k.co[0]) for fc in fcurves(a) for k in fc.keyframe_points}) or [0]
                for f in (frames[0], frames[-1]):
                    pb.rotation_quaternion = q
                    pb.keyframe_insert("rotation_quaternion", frame=f, group=bone)
                continue
            curves.sort(key=lambda fc: fc.array_index)
            for i in range(len(curves[0].keyframe_points)):
                old = [c.keyframe_points[i].co[1] for c in curves]
                new = Quaternion(old) @ q
                for c, value in zip(curves, new):
                    c.keyframe_points[i].co[1] = value
                    c.keyframe_points[i].handle_left[1] = value
                    c.keyframe_points[i].handle_right[1] = value


def fcurves(action):
    if hasattr(action, "fcurves") and len(action.fcurves):
        return list(action.fcurves)
    out = []
    for layer in getattr(action, "layers", []):
        for strip in layer.strips:
            for bag in getattr(strip, "channelbags", []):
                out.extend(bag.fcurves)
    return out


def world_bounds(meshes, exclude):
    dg = bpy.context.evaluated_depsgraph_get()
    lo = Vector((math.inf,) * 3)
    hi = Vector((-math.inf,) * 3)
    for o in meshes:
        if any(o.name.startswith(e) for e in exclude):
            continue
        ev = o.evaluated_get(dg)
        me = ev.to_mesh()
        for v in me.vertices:
            p = ev.matrix_world @ v.co
            lo = Vector(map(min, lo, p))
            hi = Vector(map(max, hi, p))
        ev.to_mesh_clear()
    return lo, hi


def head_direction(arm):
    names = [b.name for b in arm.data.bones]
    head = next((n for n in names if n.lower() == "head"), None) or next(n for n in names if "head" in n.lower() and "ik" not in n.lower())
    tail = next((n for n in names if n.lower().startswith("tail")), None) or names[0]
    h = arm.matrix_world @ arm.data.bones[head].head_local
    t = arm.matrix_world @ arm.data.bones[tail].head_local
    d = h - t
    d.z = 0
    return d.normalized()


def place(arm, meshes, args):
    scene = bpy.context.scene
    # Measure in the first frame of the idle clip: some sources' rest pose is a T-pose.
    scene.frame_set(0)
    root = bpy.data.objects.new("Root", None)
    scene.collection.objects.link(root)
    tops = [o for o in bpy.data.objects if o.parent is None and o is not root]
    for o in tops:
        mw = o.matrix_world.copy()
        o.parent = root
        o.matrix_world = mw
    d = head_direction(arm)
    yaw = math.atan2(d.x, d.y)  # rotate head onto +Y
    root.rotation_euler = (0, 0, yaw)
    bpy.context.view_layer.update()
    exclude = [e for e in args.height_exclude.split(",") if e]
    lo, hi = world_bounds(meshes, exclude)
    k = args.scale or (args.height / (hi.z - lo.z) if args.height else 1.0)
    root.scale = (k, k, k)
    bpy.context.view_layer.update()
    lo, hi = world_bounds(meshes, exclude)
    root.location = (-(lo.x + hi.x) / 2, -(lo.y + hi.y) / 2, -lo.z)
    bpy.context.view_layer.update()
    return root


def export(path: Path, image_format="AUTO"):
    path.parent.mkdir(parents=True, exist_ok=True)
    for o in bpy.context.view_layer.objects:
        o.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(path), export_format="GLB", export_yup=True, export_apply=False,
        export_normals=True, export_tangents=False, export_cameras=False, export_lights=False,
        export_materials="EXPORT", export_image_format=image_format, export_jpeg_quality=90,
        export_skins=True, export_influence_nb=4, export_all_influences=False, export_def_bones=True,
        export_animations=True, export_animation_mode="ACTIONS", export_force_sampling=True,
        export_frame_range=False, export_anim_single_armature=True, export_reset_pose_bones=True,
        export_optimize_animation_size=True, export_vertex_color="ACTIVE", export_all_vertex_colors=False, use_selection=True)


def main():
    args = parse()
    t0 = time.time()
    src = args.input.resolve()
    load(src)
    if bpy.context.object and bpy.context.object.mode != "OBJECT":
        bpy.ops.object.mode_set(mode="OBJECT")
    arm, meshes = clean_objects(args)
    before = tris(meshes)
    clips = {k: v for k, v in (p.split("=") for p in args.clips.split(","))}
    keep_clips(arm, clips)
    material_setup(meshes, args)
    if args.smooth_angle is not None:
        smooth(meshes, args.smooth_angle)
    decimate(meshes, args.tris)
    if args.pose:
        pose_offsets(arm, args.pose)
    worst = limit_influences(meshes, args.max_influences)
    root = place(arm, meshes, args)
    if args.paint or args.rest_uv:
        bake_vertex_colors(meshes, args.paint)
    if args.rest_uv:
        rest_uvs(meshes)
    out = args.out if args.out.is_absolute() else (Path.cwd() / args.out)
    export(out, args.image_format)
    lo, hi = world_bounds(meshes, [])
    d = hi - lo
    fps = bpy.context.scene.render.fps / bpy.context.scene.render.fps_base
    print("NORMALIZED %s" % src.name)
    print("  triangles %d -> %d (budget %d), meshes %s" % (before, tris(meshes), args.tris, [o.name for o in meshes]))
    print("  joints %d, max influences %d" % (len([b for b in arm.data.bones if b.use_deform]), worst))
    for a in bpy.data.actions:
        f0, f1 = a.frame_range
        print("  clip %-8s %.2fs" % (a.name, (f1 - f0) / fps))
    print("  dimensions x %.3f, y(up) %.3f, z %.3f m (scale %.4f)" % (d.x, d.z, d.y, root.scale.x))
    for img in bpy.data.images:
        if img.size[0]:
            print("  image %-24s %dx%d" % (img.name, img.size[0], img.size[1]))
    print("  wrote %s (%.0f KB)" % (out.as_posix(), out.stat().st_size / 1024))
    if args.manifest_id:
        import manifest
        row = manifest.add_output(args.manifest_id, str(out), str(src))
        print("  manifest %s:%s:%s outputs %s" % (row["source"], row["id"], row["resolution"], row["outputs"]))
    print("  %.1fs" % (time.time() - t0))


if __name__ == "__main__":
    main()
