"""Real Blender fixtures: visibility, connectivity and static recipe safeguards."""
from pathlib import Path
import sys
import bpy
from mathutils import Vector
sys.path.insert(0, str(Path(__file__).resolve().parents[2]))
from blender.gauntlet_adapters.generic import audit, subject
from blender.gauntlet_recipes.deform import decimate

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.mesh.primitive_uv_sphere_add(segments=16, ring_count=8)
shell = bpy.context.object
shell.name = "Shell"
bpy.ops.mesh.primitive_uv_sphere_add(segments=12, ring_count=6, radius=.1)
eye = bpy.context.object
eye.name = "Eye"
camera_data = bpy.data.cameras.new("test")
camera = bpy.data.objects.new("Gauntlet detail", camera_data)
bpy.context.scene.collection.objects.link(camera)
camera.location = (0,-4,0)
camera.rotation_euler = (Vector((0,0,0))-camera.location).to_track_quat("-Z","Y").to_euler()
manifest = {"visibility_checks": {"detail": ["Eye"]}, "continuous_objects": ["Shell"], "required_objects": ["Eye"]}
bpy.context.view_layer.update()
assert any("occluded" in e for e in audit(manifest, subject(manifest))), "A buried eye escaped detection"
eye.location = (0,-1.2,0)
bpy.context.view_layer.update()
assert not audit(manifest, subject(manifest)), "A visible eye was falsely rejected"
bpy.ops.mesh.primitive_cube_add(size=.1, location=(3,0,0))
fragment = bpy.context.object
bpy.ops.object.select_all(action="DESELECT")
shell.select_set(True)
fragment.select_set(True)
bpy.context.view_layer.objects.active = shell
bpy.ops.object.join()
assert any("connected component" in e for e in audit(manifest, subject(manifest))), "Detached geometry escaped detection"
bpy.ops.object.armature_add()
rig = bpy.context.object
modifier = shell.modifiers.new("Rig", "ARMATURE")
modifier.object = rig
try:
    decimate([shell], {"ratio": .5})
except ValueError:
    pass
else:
    raise AssertionError("Static recipe edited a rigged asset")
print("GAUNTLET BLENDER FIXTURES: 4 PASS", flush=True)
