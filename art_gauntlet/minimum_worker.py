"""Blender evidence worker for the deliberately small preservation gate."""
import hashlib
import json
import sys
from pathlib import Path
import bpy
from mathutils import Vector


def encode(value):
    if isinstance(value,(str,int,float,bool)) or value is None:return value
    if isinstance(value,bpy.types.ID):return {'id':value.name,'type':value.bl_rna.identifier}
    try:return [encode(x) for x in value]
    except TypeError:return str(value)


def rna(block,depth=0):
    result={}
    for prop in block.bl_rna.properties:
        key=prop.identifier
        if key in {'rna_type','name','name_full','users','session_uid','is_updated','is_updated_data','is_runtime_data','original'}:continue
        try:
            value=getattr(block,key)
            if prop.type=='COLLECTION':
                if depth<3:result[key]=[rna(v,depth+1) for v in value]
            elif prop.type=='POINTER':
                result[key]=encode(value) if value is None or isinstance(value,bpy.types.ID) else rna(value,depth+1) if depth<3 else value.bl_rna.identifier
            else:result[key]=encode(value)
        except (AttributeError,TypeError,ValueError,RuntimeError):continue
    return result


def snapshot(config):
    obj=bpy.data.objects[config['mesh']];mesh=obj.data
    editable=set(config['editable_vertices'])
    material_data={}
    for material in mesh.materials:
        material_data[material.name]={'surface':rna(material),
            'nodes':[{ 'name':n.name,'type':n.bl_idname,'properties':rna(n),
                      'inputs':[(s.identifier,encode(s.default_value)) for s in n.inputs if hasattr(s,'default_value')]}
                     for n in material.node_tree.nodes] if material.use_nodes else [],
            'links':[(l.from_node.name,l.from_socket.identifier,l.to_node.name,l.to_socket.identifier)
                     for l in material.node_tree.links] if material.use_nodes else []}
    actions=[]
    for a in bpy.data.actions:
        curves=[]
        if hasattr(a,'fcurves'):curves.extend(a.fcurves)
        for layer in getattr(a,'layers',[]):
            for strip in layer.strips:
                for bag in getattr(strip,'channelbags',[]):curves.extend(bag.fcurves)
        actions.append({'name':a.name,'curves':[{'path':f.data_path,'index':f.array_index,
                     'keys':[rna(k) for k in f.keyframe_points],'modifiers':[rna(m) for m in f.modifiers]} for f in curves]})
    rigs={}
    transforms={}
    for o in bpy.context.scene.objects:
        if o.type not in {'MESH','ARMATURE'}:continue
        transforms[o.name]={'type':o.type,'parent':o.parent.name if o.parent else None,'parent_type':o.parent_type,
            'parent_bone':o.parent_bone,'basis':encode(o.matrix_basis),'world':encode(o.matrix_world),
            'parent_inverse':encode(o.matrix_parent_inverse),'modifiers':[rna(m) for m in o.modifiers],
            'constraints':[rna(c) for c in o.constraints],'animation':rna(o.animation_data) if o.animation_data else None}
        if o.type=='ARMATURE':
            rigs[o.name]={'bones':[{ 'name':b.name,'parent':b.parent.name if b.parent else None,
                'matrix':encode(b.matrix_local),'head':encode(b.head_local),'tail':encode(b.tail_local),
                'properties':rna(b)} for b in o.data.bones],
                'pose':[{'name':b.name,'basis':encode(b.matrix_basis),'constraints':[rna(c) for c in b.constraints]} for b in o.pose.bones],
                'pose_position':o.data.pose_position}
    keys=mesh.shape_keys
    return {'geometry':{'vertex_count':len(mesh.vertices),'protected_positions':[(v.index,list(v.co)) for v in mesh.vertices if v.index not in editable],
                'edges':[list(e.vertices) for e in mesh.edges],'faces':[(list(p.vertices),p.material_index,p.use_smooth) for p in mesh.polygons],
                'uv':{u.name:[list(d.uv) for d in u.data] for u in mesh.uv_layers},
                'colors':{a.name:[list(d.color) for d in a.data] for a in mesh.color_attributes}},
            'materials':material_data,'transforms':transforms,
            'rig':{'armatures':rigs,'groups':[g.name for g in obj.vertex_groups],
                'weights':[[(g.group,g.weight) for g in v.groups] for v in mesh.vertices],
                'shape_keys':[{'name':k.name,'relative':k.relative_key.name,'value':k.value,'data':[list(p.co) for p in k.data]} for k in keys.key_blocks] if keys else [],
                'actions':actions,'frame':bpy.context.scene.frame_current}}


def setup(config):
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=16;scene.cycles.seed=0
    scene.cycles.use_denoising=False;scene.cycles.device='CPU'
    scene.render.resolution_x=scene.render.resolution_y=config['resolution']
    scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
    scene.render.film_transparent=True;scene.render.use_compositing=False;scene.render.use_sequencer=False
    scene.view_settings.view_transform='Standard';scene.view_settings.look='None'
    scene.view_settings.exposure=0;scene.view_settings.gamma=1
    for obj in list(scene.objects):
        if obj.type in {'CAMERA','LIGHT'}:bpy.data.objects.remove(obj,do_unlink=True)
    camera_data=bpy.data.cameras.new('Gate camera');camera=bpy.data.objects.new('Gate camera',camera_data)
    scene.collection.objects.link(camera);camera_data.type='ORTHO';scene.camera=camera
    world=bpy.data.worlds.new('Gate world');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs['Color'].default_value=(.15,.15,.15,1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value=.25
    scene.world=world
    data=bpy.data.lights.new('Gate key','AREA');light=bpy.data.objects.new('Gate key',data);scene.collection.objects.link(light)
    light.location=(5,-6,10);light.rotation_euler=(Vector((0,-3.7,6))-light.location).to_track_quat('-Z','Y').to_euler()
    data.energy=1800;data.size=.15
    return scene


def camera(scene,view):
    scene.camera.location=view['eye']
    scene.camera.rotation_euler=(Vector(view['target'])-scene.camera.location).to_track_quat('-Z','Y').to_euler()
    scene.camera.data.ortho_scale=view['scale']


def emission(name,color):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    nodes=mat.node_tree.nodes;nodes.clear()
    shader=nodes.new('ShaderNodeEmission');shader.inputs['Color'].default_value=(*color,1)
    output=nodes.new('ShaderNodeOutputMaterial');mat.node_tree.links.new(shader.outputs[0],output.inputs[0])
    return mat


def render(config,out):
    scene=setup(config);obj=bpy.data.objects[config['mesh']]
    graph=bpy.context.evaluated_depsgraph_get();evaluated=obj.evaluated_get(graph)
    evaluated_mesh=evaluated.to_mesh()
    assert len(evaluated_mesh.vertices)==len(obj.data.vertices),'Unsupported topology-changing modifier'
    points=[obj.matrix_world@v.co for v in evaluated_mesh.vertices]
    editable=set(config['editable_vertices'])
    protected=[p for p in obj.data.polygons if not editable.intersection(p.vertices)]
    changed=[p for p in obj.data.polygons if editable.intersection(p.vertices)]
    def clone(name,polygons):
        mesh=bpy.data.meshes.new(name);mesh.from_pydata(points,[],[list(p.vertices) for p in polygons]);mesh.update()
        copy=bpy.data.objects.new(name,mesh);scene.collection.objects.link(copy)
        return copy
    isolated=clone('Protected surface',protected)
    ids=[emission('ID head',(.05,.65,.9)),emission('ID body',(.9,.3,.05))]
    white=emission('Matte',(1,1,1))
    head_faces=set(config['head_faces'])
    for mat in ids:isolated.data.materials.append(mat)
    for p,original in zip(isolated.data.polygons,protected):p.material_index=0 if original.index in head_faces else 1
    obj.hide_render=True
    for name,view in config['views'].items():
        camera(scene,view)
        scene.view_layers[0].material_override=None
        scene.render.filepath=str(out/f'{name}_id.png');bpy.ops.render.render(write_still=True)
        scene.view_layers[0].material_override=white
        scene.render.filepath=str(out/f'{name}_matte.png');bpy.ops.render.render(write_still=True)
    scene.view_layers[0].material_override=None
    isolated.hide_render=True;obj.hide_render=False
    camera(scene,config['views']['head'])
    scene.render.filepath=str(out/'beauty.png');bpy.ops.render.render(write_still=True)
    # Validation witness only, never a preservation gate: editable surfaces
    # are camera-invisible but still cast shadows on the protected receiver.
    shadow=clone('Editable shadow caster',changed)
    for mat in obj.data.materials:shadow.data.materials.append(mat)
    for p,original in zip(shadow.data.polygons,changed):p.material_index=original.material_index
    isolated.data.materials.clear()
    for mat in obj.data.materials:isolated.data.materials.append(mat)
    for p,original in zip(isolated.data.polygons,protected):p.material_index=original.material_index
    isolated.hide_render=False;obj.hide_render=True
    shadow.visible_camera=False;shadow.visible_glossy=False;shadow.visible_diffuse=False;shadow.visible_transmission=False
    scene.render.filepath=str(out/'shadow_witness.png');bpy.ops.render.render(write_still=True)
    evaluated.to_mesh_clear()


def main():
    job=json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text())
    config=job['config'];out=Path(job['output']);out.mkdir(parents=True,exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=job['source'])
    obj=bpy.data.objects[config['mesh']]
    for operation in job.get('operations',[]):
        if operation['type']=='move_vertices':
            for index in operation['vertices']:obj.data.vertices[index].co+=Vector(operation['delta'])
        elif operation['type']=='weight':
            obj.vertex_groups[operation['group']].add([operation['vertex']],operation['value'],'REPLACE')
        elif operation['type']=='material':obj.data.materials[0].diffuse_color[0]=operation['value']
        elif operation['type']=='transform':obj.location.x+=operation['delta']
        else:raise ValueError('Unknown operation')
    obj.data.update();bpy.context.view_layer.update()
    (out/'snapshot.json').write_text(json.dumps(snapshot(config),sort_keys=True,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(out/'candidate.blend'))
    if job.get('render',True):render(config,out)


if __name__=='__main__':main()
