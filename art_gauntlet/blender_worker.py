"""Fresh-process worker. No numbered stages, species branches or promotion."""
import importlib
import json
import math
from pathlib import Path
import sys
import bpy
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from art_gauntlet.storage import write, read, digest, fingerprint


def configure(manifest):
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = manifest["protocol"].get("samples", 16)
    scene.cycles.seed = 0
    scene.cycles.use_denoising = True
    scene.cycles.device = "CPU"
    device = "CPU"
    try:
        prefs = bpy.context.preferences.addons["cycles"].preferences
        prefs.compute_device_type = "OPTIX"
        prefs.get_devices()
        devices = [d for d in prefs.devices if d.type == "OPTIX"]
        if devices:
            for d in prefs.devices:
                d.use = d.type == "OPTIX"
            scene.cycles.device = "GPU"
            device = "OPTIX: " + ", ".join(d.name for d in devices)
    except (TypeError, RuntimeError):
        pass
    scene.render.resolution_x = scene.render.resolution_y = manifest["protocol"].get("resolution", 512)
    scene.render.resolution_percentage = 100
    scene.render.image_settings.file_format = "PNG"
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "AgX"
    scene.view_settings.look = "AgX - Medium High Contrast"
    scene.view_settings.exposure = 0
    scene.view_settings.gamma = 1
    scene.render.use_compositing = False
    scene.render.use_sequencer = False
    bpy.context.view_layer.material_override = None
    for obj in list(scene.objects):
        if obj.type in {"CAMERA", "LIGHT"}:
            bpy.data.objects.remove(obj, do_unlink=True)
    world = bpy.data.worlds.new("Gauntlet neutral world")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (.55,.55,.55,1)
    world.node_tree.nodes["Background"].inputs[1].default_value = .6
    scene.world = world
    for name, settings in manifest["protocol"]["views"].items():
        data = bpy.data.cameras.new(name)
        data.type = "ORTHO"
        data.ortho_scale = settings["scale"]
        data.clip_start = .001
        data.clip_end = 1000
        camera = bpy.data.objects.new("Gauntlet " + name, data)
        scene.collection.objects.link(camera)
        camera.location = settings["eye"]
        camera.rotation_euler = (Vector(settings["target"])-camera.location).to_track_quat("-Z", "Y").to_euler()
        camera.rotation_euler.rotate_axis("Z", math.radians(settings.get("roll_degrees", 0)))
    scale = manifest["protocol"].get("light_scale", 1)
    target = Vector(manifest["protocol"]["views"]["side"]["target"])
    for name, position, power, size in [("Key",(3,4,5),500,4), ("Fill",(-4,2,3),320,4), ("Rim",(1,-4,4),400,3)]:
        data = bpy.data.lights.new(name, "AREA")
        data.energy = power*scale*scale
        data.shape = "DISK"
        data.size = size*scale
        light = bpy.data.objects.new(name, data)
        scene.collection.objects.link(light)
        light.location = Vector(position)*scale
        light.rotation_euler = (target-light.location).to_track_quat("-Z", "Y").to_euler()
    return device


def audit(objects, manifest, adapter, exported=False):
    errors = [] if exported else adapter.audit(manifest, objects)
    if not objects:
        errors.append("No visible subject")
    graph = bpy.context.evaluated_depsgraph_get()
    triangles = 0
    materials = set()
    bounds = [[math.inf]*3, [-math.inf]*3]
    details = []
    for obj in objects:
        evaluated = obj.evaluated_get(graph)
        mesh = evaluated.to_mesh()
        count = sum(len(p.vertices)-2 for p in mesh.polygons)
        triangles += count
        finite = True
        for vertex in mesh.vertices:
            point = obj.matrix_world @ vertex.co
            for axis in range(3):
                finite &= math.isfinite(point[axis])
                bounds[0][axis] = min(bounds[0][axis], point[axis])
                bounds[1][axis] = max(bounds[1][axis], point[axis])
        if not finite:
            errors.append("Nonfinite geometry: " + obj.name)
        materials.update(m.name for m in mesh.materials if m)
        details.append({"name": obj.name, "triangles": count, "uv": bool(mesh.uv_layers)})
        evaluated.to_mesh_clear()
    if not objects or not all(math.isfinite(x) for row in bounds for x in row):
        bounds = None
    used_images = set()
    visited = set()
    def collect_images(tree):
        if tree is None or tree.as_pointer() in visited:
            return
        visited.add(tree.as_pointer())
        for node in tree.nodes:
            if node.type == "TEX_IMAGE" and node.image:
                used_images.add(node.image)
            if node.type == "GROUP":
                collect_images(node.node_tree)
    for obj in objects:
        for material in obj.data.materials:
            if material:
                collect_images(material.node_tree)
    images = [{"name": i.name, "size": list(i.size), "packed": bool(i.packed_file)} for i in used_images]
    for image in images:
        if min(image["size"]) <= 0:
            errors.append("Unreadable texture: " + image["name"])
    budget = manifest["game_budget"]
    violations = []
    for key, count in (("max_triangles", triangles), ("max_objects", len(objects)), ("max_materials", len(materials))):
        if count > budget[key]:
            violations.append(f"{key}: {count} > {budget[key]}")
    return {"errors": errors, "triangles": triangles, "objects": details, "materials": sorted(materials), "bounds": bounds, "images": images, "budget_violations": violations}


def render(manifest, folder, signature, device):
    folder.mkdir(parents=True, exist_ok=True)
    scene = bpy.context.scene
    black = bpy.data.materials.new("Gauntlet mask")
    black.use_nodes = True
    nodes = black.node_tree.nodes
    nodes.clear()
    emission = nodes.new("ShaderNodeEmission")
    emission.inputs["Color"].default_value = (0,0,0,1)
    output = nodes.new("ShaderNodeOutputMaterial")
    black.node_tree.links.new(emission.outputs[0], output.inputs["Surface"])
    capture_key = fingerprint({"job": signature, "device": device})
    def capture(path):
        marker = path.with_suffix(".capture.json")
        if marker.exists() and path.exists():
            old = read(marker)
            if old["signature"] == capture_key and old["sha256"] == digest(path):
                print("REUSED VIEW", path.name, flush=True)
                return
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        write(marker, {"signature": capture_key, "sha256": digest(path)})
    for name in manifest["protocol"]["views"]:
        scene.camera = bpy.data.objects["Gauntlet " + name]
        capture(folder / f"{name}.png")
        if name in manifest["references"]:
            bpy.context.view_layer.material_override = black
            capture(folder / f"{name}_mask.png")
            bpy.context.view_layer.material_override = None


def main(job):
    manifest = job["manifest"]
    output = Path(job["output"])
    output.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=job["input"])
    external = {}
    for asset in list(bpy.data.images) + list(bpy.data.libraries):
        if getattr(asset, "packed_file", None) or not getattr(asset, "filepath", ""):
            continue
        path = Path(bpy.path.abspath(asset.filepath))
        if path.is_file():
            external[str(path.resolve())] = digest(path)
    write(output / "dependencies.json", external)
    adapter = importlib.import_module("blender.gauntlet_adapters." + manifest["adapter"])
    device = configure(manifest)
    if job["action"] == "build":
        adapter.apply(manifest, job.get("plan", {}))
        objects = adapter.subject(manifest)
        report = audit(objects, manifest, adapter)
        write(output / "audit.json", report)
        if report["errors"]:
            raise ValueError("Structural audit failed: " + str(report["errors"]))
        bpy.ops.file.pack_all()
        bpy.context.scene.camera = bpy.data.objects["Gauntlet side"]
        bpy.ops.wm.save_as_mainfile(filepath=str(output / "candidate.blend"))
        render(manifest, output / "renders", job["signature"], device)
    elif job["action"] == "export":
        objects = adapter.subject(manifest)
        if any(o.find_armature() for o in objects):
            raise ValueError("Static export refuses a rigged source")
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        bpy.ops.export_scene.gltf(filepath=str(output / "asset.glb"), export_format="GLB", use_selection=True,
                                  export_apply=True, export_animations=False, export_yup=True)
        for obj in list(bpy.context.scene.objects):
            bpy.data.objects.remove(obj, do_unlink=True)
        bpy.ops.import_scene.gltf(filepath=str(output / "asset.glb"))
        device = configure(manifest)
        report = audit(adapter.subject(manifest), manifest, adapter, exported=True)
        write(output / "audit.json", report)
        bpy.ops.wm.save_as_mainfile(filepath=str(output / "reimport.blend"))
        render(manifest, output / "renders", job["signature"], device)
    else:
        raise ValueError("Unknown worker action")
    write(output / "worker.json", {"blender": bpy.app.version_string, "device": device, "action": job["action"]})


if __name__ == "__main__":
    main(json.loads(Path(sys.argv[sys.argv.index("--")+1]).read_text(encoding="utf-8")))
