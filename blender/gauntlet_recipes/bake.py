"""Bake procedural color into a shared atlas on static geometry.

This preserves per-object editability and material names. It deliberately does
not claim high-to-low normal transfer or preserve procedural roughness.
"""
import bpy


def bake_atlas(objects, step):
    size = int(step.get("size", 1024))
    if size not in (256, 512, 1024, 2048, 4096):
        raise ValueError("Unsupported atlas size")
    if any(o.find_armature() for o in objects):
        raise ValueError("Static atlas recipe cannot edit a rigged asset")
    bpy.ops.object.select_all(action="DESELECT")
    for obj in objects:
        obj.select_set(True)
        obj.data = obj.data.copy()
    bpy.context.view_layer.objects.active = objects[0]
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(island_margin=.018)
    bpy.ops.object.mode_set(mode="OBJECT")
    image = bpy.data.images.new("Gauntlet albedo atlas", width=size, height=size, alpha=False)
    image.generated_color = (.1,.1,.1,1)
    image.colorspace_settings.name = "sRGB"
    # Duplicate materials so inactive archived objects cannot affect the bake.
    materials = {}
    for obj in objects:
        for slot in obj.material_slots:
            old = slot.material
            if old is None:
                raise ValueError("Cannot bake an empty material slot")
            if old.name not in materials:
                material = old.copy()
                material.use_nodes = True
                texture = material.node_tree.nodes.new("ShaderNodeTexImage")
                texture.image = image
                material.node_tree.nodes.active = texture
                materials[old.name] = material
            slot.material = materials[old.name]
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    scene.cycles.samples = 8
    scene.render.bake.use_clear = False
    scene.render.bake.margin = 8
    bpy.ops.object.bake(type="DIFFUSE", pass_filter={"COLOR"}, use_clear=False)
    image.pack()
    material = bpy.data.materials.new("Gauntlet baked surface")
    material.use_nodes = True
    shader = material.node_tree.nodes.get("Principled BSDF")
    shader.inputs["Roughness"].default_value = float(step.get("roughness", .55))
    shader.inputs["Metallic"].default_value = float(step.get("metallic", 0))
    texture = material.node_tree.nodes.new("ShaderNodeTexImage")
    texture.image = image
    material.node_tree.links.new(texture.outputs["Color"], shader.inputs["Base Color"])
    for obj in objects:
        obj.data.materials.clear()
        obj.data.materials.append(material)
        for polygon in obj.data.polygons:
            polygon.material_index = 0
