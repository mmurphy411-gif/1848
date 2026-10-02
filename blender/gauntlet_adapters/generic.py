"""Asset meaning is configuration; recipes never own the run state."""
import bpy
from mathutils import Vector


def subject(manifest):
    return [o for o in bpy.context.scene.objects if o.type == "MESH" and not o.hide_render
            and not any(c.hide_render for c in o.users_collection) and o.visible_get()]


def audit(manifest, objects):
    names = {o.name for o in objects}
    errors = [f"Missing required feature: {name}" for name in manifest.get("required_objects", []) if name not in names]
    for obj in objects:
        if obj.name not in manifest.get("continuous_objects", []):
            continue
        parents = list(range(len(obj.data.vertices)))
        def root(i):
            while parents[i] != i:
                parents[i] = parents[parents[i]]
                i = parents[i]
            return i
        for edge in obj.data.edges:
            a, b = (root(i) for i in edge.vertices)
            parents[a] = b
        count = len({root(i) for i in range(len(parents))})
        if count != 1:
            errors.append(f"Expected one connected component in {obj.name}, found {count}")
    graph = bpy.context.evaluated_depsgraph_get()
    for view, features in manifest.get("visibility_checks", {}).items():
        camera = bpy.data.objects["Gauntlet " + view]
        direction = camera.rotation_euler.to_matrix() @ Vector((0,0,-1))
        for name in features:
            obj = bpy.data.objects.get(name)
            if obj is None or name not in names:
                errors.append(f"Missing visible feature: {name}")
                continue
            # Rays through the center and sampled actual mesh vertices detect a
            # completely buried eye independently of the placement recipe.
            stride = max(1, len(obj.data.vertices)//16)
            points = [obj.matrix_world.translation] + [obj.matrix_world @ obj.data.vertices[i].co for i in range(0, len(obj.data.vertices), stride)]
            visible = False
            for point in points:
                origin = point - direction * 10
                hit, location, normal, face, found, matrix = bpy.context.scene.ray_cast(graph, origin, direction, distance=20)
                if hit and found.original == obj:
                    visible = True
                    break
            if not visible:
                errors.append(f"Feature fully occluded in {view}: {name}")
    return errors


def apply(manifest, plan):
    from blender.gauntlet_recipes import deform
    for step in plan.get("operations", []):
        recipe = step["recipe"]
        if recipe == "affine_region":
            deform.affine_region(subject(manifest), step)
        elif recipe == "decimate":
            deform.decimate(subject(manifest), step)
        elif recipe == "bake_atlas":
            from blender.gauntlet_recipes.bake import bake_atlas
            bake_atlas(subject(manifest), step)
        else:
            raise ValueError(f"Unknown recipe: {recipe}")
