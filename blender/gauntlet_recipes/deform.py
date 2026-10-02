import math
import bpy
from mathutils import Vector


def affine_region(objects, step):
    """Continuous world-space deformation also moves attached feature geometry."""
    axis = int(step.get("axis", 0))
    lo, hi = step["interval"]
    if axis not in (0, 1, 2) or not math.isfinite(lo+hi) or hi <= lo:
        raise ValueError("Invalid deformation interval")
    scale = Vector(step.get("scale", [1,1,1]))
    delta = Vector(step.get("translate", [0,0,0]))
    pivot = Vector(step.get("pivot", [0,0,0]))
    if not all(math.isfinite(v) for v in (*scale, *delta, *pivot)) or min(scale) <= 0:
        raise ValueError("Invalid deformation")
    selectors = step.get("objects")
    selected = [o for o in objects if selectors is None or o.name in selectors]
    if selectors and len(selected) != len(selectors):
        raise ValueError("An edit selector is missing or ambiguous")
    for obj in selected:
        if obj.data.users > 1:
            obj.data = obj.data.copy()
        transform = obj.matrix_world.copy()
        inverse = transform.inverted()
        for vertex in obj.data.vertices:
            point = transform @ vertex.co
            t = max(0, min(1, (point[axis]-lo)/(hi-lo)))
            weight = t*t*(3-2*t)
            if step.get("side", "low") == "low":
                weight = 1-weight
            moved = pivot + Vector([(point[i]-pivot[i])*scale[i] for i in range(3)]) + delta
            vertex.co = inverse @ point.lerp(moved, weight)
        obj.data.update()


def decimate(objects, step):
    ratio = float(step["ratio"])
    if not 0 < ratio <= 1:
        raise ValueError("Decimation ratio must be in (0, 1]")
    for obj in objects:
        if any(m.type == "ARMATURE" for m in obj.modifiers):
            raise ValueError("Static reduction cannot edit a rigged asset")
        if sum(len(p.vertices)-2 for p in obj.data.polygons) < step.get("minimum_triangles", 500):
            continue
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        for modifier in list(obj.modifiers):
            bpy.ops.object.modifier_apply(modifier=modifier.name)
        modifier = obj.modifiers.new("Gauntlet budget reduction", "DECIMATE")
        modifier.ratio = ratio
        bpy.ops.object.modifier_apply(modifier=modifier.name)
