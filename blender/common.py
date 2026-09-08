"""Shared deterministic Blender export helpers. Run builders with Blender's Python."""
from pathlib import Path
import bpy, math, time
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "assets"

def reset():
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.object.delete(use_global=False)

def material(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    p = m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value = (*color, 1)
    p.inputs['Roughness'].default_value = .85
    return m

def mesh_object(name, verts, faces, uvs=None, colors=None, materials=None, slots=None):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata(verts, [], faces)
    mesh.update()
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if uvs:
        layer = mesh.uv_layers.new(name='UVMap')
        for poly in mesh.polygons:
            for li in poly.loop_indices:
                layer.data[li].uv = uvs[mesh.loops[li].vertex_index]
    if colors:
        attr = mesh.color_attributes.new(name='Color', type='FLOAT_COLOR', domain='POINT')
        for i, c in enumerate(colors): attr.data[i].color = c
    for m in materials or []: mesh.materials.append(m)
    for i, poly in enumerate(mesh.polygons):
        poly.use_smooth = True
        if slots: poly.material_index = slots[i]
    return obj

def export(obj, relative):
    # Supply explicit UVs/tangents even for world-projected rocks and ledges.
    if not obj.data.uv_layers:
        uv=obj.data.uv_layers.new(name='UVMap')
        for poly in obj.data.polygons:
            axis=max(range(3),key=lambda a:abs(poly.normal[a]))
            axes=[a for a in range(3) if a!=axis]
            for li in poly.loop_indices:
                p=obj.data.vertices[obj.data.loops[li].vertex_index].co
                uv.data[li].uv=(p[axes[0]],p[axes[1]])
    if not obj.data.color_attributes:
        color=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
        for item in color.data: item.color=(1,1,1,1)
    path = ASSETS / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.export_scene.gltf(filepath=str(path), export_format='GLB', use_selection=True,
        export_yup=True, export_apply=True, export_normals=True, export_tangents=True,
        export_animations=False, export_cameras=False, export_lights=False,
        export_materials='EXPORT', export_vertex_color='ACTIVE', export_all_vertex_colors=True)
    print('EXPORTED', relative, sum(len(p.vertices)-2 for p in obj.data.polygons), 'triangles')

def save(name):
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'blender' / (name + '.blend')))
    bpy.ops.file.make_paths_relative()
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT / 'blender' / (name + '.blend')))

def tube(verts, faces, uvs, colors, slots, points, radii, sides=6, weight=0):
    base = len(verts)
    for j, (p, radius) in enumerate(zip(points, radii)):
        p = Vector(p)
        direction = Vector(points[min(j+1,len(points)-1)]) - Vector(points[max(j-1,0)])
        direction.normalize()
        side = direction.cross(Vector((0,1,0)))
        if side.length < .1: side = direction.cross(Vector((1,0,0)))
        side.normalize()
        other = direction.cross(side).normalized()
        for k in range(sides):
            angle = math.tau*k/sides
            verts.append(p + radius*(math.cos(angle)*side + math.sin(angle)*other))
            uvs.append((k/sides, p.z*.4))
            colors.append((min(.95, weight*j/max(len(points)-1,1)),0,0,1))
    for j in range(len(points)-1):
        for k in range(sides):
            a=base+j*sides+k; b=base+j*sides+(k+1)%sides
            faces.append((a,b,b+sides,a+sides)); slots.append(0)

def card(verts, faces, uvs, colors, slots, center, along, across, weight=1):
    center, along, across = Vector(center), Vector(along), Vector(across)
    base=len(verts)
    for dx,dy in [(-1,0),(1,0),(1,1),(-1,1)]:
        verts.append(center + across*dx*.5 + along*dy)
        uvs.append(((dx+1)*.5,dy))
        colors.append((weight*(.65+.35*dy),1,0,1))
    faces.append((base,base+1,base+2,base+3)); slots.append(1)
