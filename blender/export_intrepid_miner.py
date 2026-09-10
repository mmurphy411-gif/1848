"""Build a baked, modular game asset from Pass 17 without modifying the art source.

Blender --background --python blender/export_intrepid_miner.py -- prepare|bake|export
"""
import bpy,sys,math,json
from pathlib import Path
from mathutils import Matrix,Vector,Quaternion
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts/miner-game';OUT.mkdir(exist_ok=True,parents=True)
ASSETS=ROOT/'assets/miner/intrepid';ASSETS.mkdir(exist_ok=True,parents=True)
STAGE=sys.argv[sys.argv.index('--')+1]
SIZES={'Body':2048,'Skin':1024,'Hair':1024,'Pack':1024,'Satchel':512,'Canteen':512,'Pickaxe':512,'TravelPan':512}
GEAR={'GEAR | backpack':'Pack','GEAR | bedroll':'Pack','GEAR | satchel':'Satchel','GEAR | canteen':'Canteen','GEAR | pickaxe':'Pickaxe','GEAR | pan':'TravelPan'}

def active(o):return o.type in {'MESH','CURVE'} and not o.hide_render and not any(c.hide_render for c in o.users_collection)
def select(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.hide_set(False);o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
def group(o):
    for c in o.users_collection:
        if c.name in GEAR:return GEAR[c.name]
    if o.type=='CURVE' or any('hair' in c.name.lower() or 'beard' in c.name.lower() for c in o.users_collection):return 'Hair'
    if any('BODY |' in c.name for c in o.users_collection):return 'Skin'
    if o.get('source_component',-1) in list(range(10,34))+list(range(50,71)):return 'Hair' if o.get('source_component') in [51,55,56,69,70] else 'Skin'
    if o.name.startswith(('Face |','Skin |')):return 'Skin'
    if o.name.startswith(('Hair |','Beard |','Moustache |')):return 'Hair'
    return 'Body'
def normalize(o,rig):
    for v in o.data.vertices:
        pairs=sorted([(o.vertex_groups[g.group].name,g.weight) for g in v.groups if o.vertex_groups[g.group].name in rig.data.bones and g.weight>.00001],key=lambda x:-x[1])[:4]
        if not pairs:raise RuntimeError('Unweighted vertex '+o.name+' '+str(v.index))
        for g in list(v.groups):o.vertex_groups[g.group].remove([v.index])
        total=sum(w for _,w in pairs)
        for name,w in pairs:o.vertex_groups[name].add([v.index],w/total,'REPLACE')
def reset(rig):
    if rig.animation_data:
        rig.animation_data.action=None
        for track in rig.animation_data.nla_tracks:track.mute=True
    for p in rig.pose.bones:p.rotation_mode='QUATERNION';p.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()

def prepare():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/miner_convergence_working.blend'))
    rig=bpy.data.objects['MinerRig'];scene=bpy.context.scene
    review_pose={p.name:{'location':list(p.matrix_basis.to_translation()),'rotation':list(p.matrix_basis.to_quaternion()),'scale':list(p.matrix_basis.to_scale())} for p in rig.pose.bones}
    (OUT/'review_pose.json').write_text(json.dumps(review_pose,indent=2))
    sources=[o for o in scene.objects if active(o)];groups={o.name:group(o) for o in sources}
    for o in scene.objects:
        if o.animation_data:
            for fc in list(o.animation_data.drivers):o.driver_remove(fc.data_path,fc.array_index)
    reset(rig)
    # Clear review-only visibility drivers and pose offsets. Original rest joints and actions are retained.
    for o in sources:o.hide_viewport=False;o.hide_set(False)
    buckets={name:[] for name in SIZES};before={}
    for o in sources:
        name=groups[o.name];select([o]);bone=o.parent_bone if o.parent_type=='BONE' else None
        if o.type=='CURVE':
            # Keep one third of the fine strand curves. Broad modeled locks carry the distant silhouette.
            for i in range(len(o.data.splines)-1,-1,-1):
                if i%3:o.data.splines.remove(o.data.splines[i])
            o.data.bevel_resolution=0;o.data.resolution_u=1
            bpy.ops.object.convert(target='MESH');o=bpy.context.object
        world=o.matrix_world.copy();o.parent=None;o.matrix_world=world
        # Apply construction modifiers in the unposed mesh; never bake the armature pose into vertices.
        for mod in list(o.modifiers):
            if mod.type=='ARMATURE':o.modifiers.remove(mod)
            else:
                try:bpy.ops.object.modifier_apply(modifier=mod.name)
                except RuntimeError:o.modifiers.remove(mod)
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
        if bone:
            o.vertex_groups.clear();o.vertex_groups.new(name=bone).add(list(range(len(o.data.vertices))),1,'REPLACE')
        if not o.vertex_groups:
            fallback='Head' if name in ['Skin','Hair'] else 'Chest' if name=='Pack' else 'Hips'
            o.vertex_groups.new(name=fallback).add(list(range(len(o.data.vertices))),1,'REPLACE')
        tris=sum(len(p.vertices)-2 for p in o.data.polygons);before[o.name]=tris
        # Reduce the dense cloth shells, retaining face and hand landmarks and small hardware.
        if name=='Body' and tris>3500:
            dec=o.modifiers.new('Game cloth reduction','DECIMATE');dec.ratio=.60
            bpy.ops.object.modifier_apply(modifier=dec.name)
        normalize(o,rig);buckets[name].append(o)
    exported=[]
    for name,objects in buckets.items():
        select(objects);bpy.ops.object.join();o=bpy.context.object;o.name=name;o.data.name=name+'Mesh'
        triangulate=o.modifiers.new('Stable tangent triangulation','TRIANGULATE');bpy.ops.object.modifier_apply(modifier=triangulate.name)
        # Replace overlapping construction UVs with a unique atlas per detachable component.
        while o.data.uv_layers:o.data.uv_layers.remove(o.data.uv_layers[0])
        o.data.uv_layers.new(name='GameUV');bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT')
        bpy.ops.uv.smart_project(angle_limit=math.radians(66),island_margin=.002,area_weight=.2,correct_aspect=True)
        bpy.ops.object.mode_set(mode='OBJECT')
        normalize(o,rig);o.parent=rig;o.matrix_parent_inverse=rig.matrix_world.inverted()
        mod=o.modifiers.new('MinerRig','ARMATURE');mod.object=rig
        exported.append(o)
    keep=set(exported+[rig])
    for o in list(bpy.data.objects):
        if o not in keep:bpy.data.objects.remove(o,do_unlink=True)
    scene.render.engine='CYCLES';scene.cycles.samples=8;scene.render.bake.margin=12;scene.render.bake.use_selected_to_active=False
    prefs=bpy.context.preferences.addons['cycles'].preferences
    try:
        prefs.compute_device_type='OPTIX';prefs.get_devices()
        for d in prefs.devices:d.use=d.type=='OPTIX'
        scene.cycles.device='GPU'
    except Exception:scene.cycles.device='CPU'
    scene.world.color=(.15,.15,.15)
    audit={'source':'miner_convergence_working.blend / Pass 17','rest_bones':{p.name:[list(row) for row in p.matrix_local] for p in rig.data.bones},'groups':{o.name:{'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'vertices':len(o.data.vertices),'source_materials':len(o.data.materials)} for o in exported},'original_actions':[a.name for a in bpy.data.actions]}
    (OUT/'prepare_audit.json').write_text(json.dumps(audit,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'prepared.blend'));print('PREPARED',audit['groups'])

def bake():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'prepared.blend'));scene=bpy.context.scene
    for name,size in SIZES.items():
        o=bpy.data.objects[name];select([o]);materials=list(o.data.materials);images={}
        # Use independent copies: shared source materials must not retain bake rewiring between atlases.
        for i,mat in enumerate(materials):o.data.materials[i]=mat.copy()
        materials=list(o.data.materials)
        for channel in ['albedo','orm','normal']:
            im=bpy.data.images.new(name+'_'+channel,width=size,height=size,alpha=False)
            im.colorspace_settings.name='sRGB' if channel=='albedo' else 'Non-Color'
            restore=[]
            for mat in materials:
                mat.use_nodes=True;nodes=mat.node_tree.nodes;links=mat.node_tree.links
                output=next(n for n in nodes if n.type=='OUTPUT_MATERIAL' and n.is_active_output)
                principled=next((n for n in nodes if n.type=='BSDF_PRINCIPLED'),None)
                target=nodes.new('ShaderNodeTexImage');target.image=im;nodes.active=target
                old=output.inputs['Surface'].links[0].from_socket if output.inputs['Surface'].is_linked else None
                temporary=[target]
                if channel!='normal':
                    emit=nodes.new('ShaderNodeEmission');temporary.append(emit)
                    if channel=='albedo':
                        inp=principled.inputs['Base Color'] if principled else None
                        if inp and inp.is_linked:links.new(inp.links[0].from_socket,emit.inputs['Color'])
                        else:emit.inputs['Color'].default_value=inp.default_value if inp else mat.diffuse_color
                    else:
                        combine=nodes.new('ShaderNodeCombineColor');temporary.append(combine);combine.inputs['Red'].default_value=1
                        for dst,src in [('Green','Roughness'),('Blue','Metallic')]:
                            inp=principled.inputs[src] if principled else None
                            if inp and inp.is_linked:links.new(inp.links[0].from_socket,combine.inputs[dst])
                            else:combine.inputs[dst].default_value=inp.default_value if inp else .8 if src=='Roughness' else 0
                        links.new(combine.outputs[0],emit.inputs['Color'])
                    links.new(emit.outputs[0],output.inputs['Surface'])
                restore.append((mat,output,old,temporary))
            bpy.ops.object.bake(type='NORMAL' if channel=='normal' else 'EMIT')
            im.filepath_raw=str(ASSETS/(name.lower()+'_'+channel+'.png'));im.file_format='PNG';im.save();images[channel]=im
            for mat,output,old,temporary in restore:
                if old:mat.node_tree.links.new(old,output.inputs['Surface'])
                for n in temporary:mat.node_tree.nodes.remove(n)
            print('BAKED',name,channel,flush=True)
        mat=bpy.data.materials.new('Intrepid_'+name);mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
        for channel,im in images.items():
            tex=n.new('ShaderNodeTexImage');tex.image=im
            if channel=='albedo':l.new(tex.outputs['Color'],p.inputs['Base Color'])
            elif channel=='normal':
                normal=n.new('ShaderNodeNormalMap');l.new(tex.outputs['Color'],normal.inputs['Color']);l.new(normal.outputs[0],p.inputs['Normal'])
            else:
                separate=n.new('ShaderNodeSeparateColor');l.new(tex.outputs['Color'],separate.inputs[0]);l.new(separate.outputs['Green'],p.inputs['Roughness']);l.new(separate.outputs['Blue'],p.inputs['Metallic'])
        for poly in o.data.polygons:poly.material_index=0
        o.data.materials.clear();o.data.materials.append(mat)
        # Retain an inspectable intermediate after each completed atlas.
        bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'baked.blend'))
    print('BAKE_COMPLETE')

def export():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'baked.blend'));rig=bpy.data.objects['MinerRig'];reset(rig)
    # Tall shafts must bend with the calf. The art pose had rigid Foot weights all the way to the knee.
    body=bpy.data.objects['Body']
    for side in ['Left','Right']:
        foot=body.vertex_groups.get(side+'Foot');calf=body.vertex_groups.get(side+'LowerLeg') or body.vertex_groups.new(name=side+'LowerLeg')
        for vertex in body.data.vertices:
            weight=sum(g.weight for g in vertex.groups if g.group==foot.index)
            if not weight or vertex.co.z<=.11:continue
            t=max(0,min(1,(vertex.co.z-.11)/.10))
            existing=sum(g.weight for g in vertex.groups if g.group==calf.index)
            foot.add([vertex.index],weight*(1-t),'REPLACE');calf.add([vertex.index],existing+weight*t,'REPLACE')
    normalize(body,rig)
    review=json.loads((OUT/'review_pose.json').read_text())
    arm_names=[p.name for p in rig.pose.bones if p.name.startswith(('Left','Right')) and any(t in p.name for t in ['Shoulder','Arm','Hand','Thumb','Index','Middle','Ring','Little'])]
    finger_names=[name for name in arm_names if any(t in name for t in ['Thumb','Index','Middle','Ring','Little'])]
    # Keep established locomotion leg/hip motion; carry the newly reviewed upper-body silhouette.
    for clip in ['idle','walk','wade']:
        action=bpy.data.actions[clip];rig.animation_data.action=action
        if action.slots:rig.animation_data.action_slot=action.slots[0]
        for frame in range(1,round(action.frame_range[1])+1):
            bpy.context.scene.frame_set(frame)
            for name in arm_names:
                pb=rig.pose.bones[name];data=review[name]
                pb.location=data['location'];pb.scale=data['scale'];pb.rotation_quaternion=Quaternion(data['rotation'])
                if name.endswith('UpperArm'):
                    phase=(frame-1)/30*math.tau/(1.2 if clip=='wade' else 1)
                    swing=(.055 if clip=='walk' else .025 if clip=='wade' else .006)*math.sin(phase)*(1 if name.startswith('Left') else -1)
                    pb.rotation_quaternion=pb.rotation_quaternion@Quaternion((1,0,0),swing)
                if name in finger_names:
                    # Relaxed unladen pose; runtime enables the matching authored grip per held tool.
                    pb.rotation_quaternion=Quaternion((1,0,0),.16 if 'Thumb' not in name else .08)
                for channel in ['location','rotation_quaternion','scale']:pb.keyframe_insert(channel,frame=frame,group=name)
    grip_data=json.dumps({name:review[name]['rotation'] for name in finger_names},indent=2)
    (ASSETS/'grips.gd').write_text('extends RefCounted\n# Generated from the reviewed carry pose; imported as a resource for packaged builds.\nconst ROTATIONS = '+grip_data+'\n')
    rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=bpy.data.actions['idle'].slots[0];bpy.context.scene.frame_set(16)
    # Fit the rigid travel props to the closed review grips in the adapted locomotion pose.
    # Rest-space offsets preserve this contact across the carried arm's animation.
    for name in finger_names:rig.pose.bones[name].rotation_quaternion=Quaternion(review[name]['rotation'])
    bpy.context.view_layer.update();deps=bpy.context.evaluated_depsgraph_get();grip_audit={}
    for part,side in [('Pickaxe','Right'),('TravelPan','Left')]:
        obj=bpy.data.objects[part];evaluated=obj.evaluated_get(deps);mesh=evaluated.to_mesh();points=[obj.matrix_world@v.co for v in mesh.vertices]
        target=(rig.pose.bones[side+'MiddleProximal'].head+rig.pose.bones[side+'MiddleDistal'].head)*.5
        if part=='Pickaxe':
            top=max(p.z for p in points);band=[p for p in points if p.z>top-.007]
            contact=sum(band,Vector())/len(band)-Vector((0,0,.038))
        else:contact=min(points,key=lambda p:(p-target).length)
        delta=target-contact;skin=rig.pose.bones[side+'Hand'].matrix@rig.data.bones[side+'Hand'].matrix_local.inverted()
        if part=='Pickaxe':
            bottom=min(p.z for p in points);head_points=[p for p in points if p.z<bottom+.035]
            lower=sum(head_points,Vector())/len(head_points)
            axis=lower-contact;desired=Vector((target.x-.04,target.y+.015,.040))-target
            turn=axis.rotation_difference(desired);unit=axis.normalized();length_ratio=desired.length/axis.length
            for vertex,world_point in zip(obj.data.vertices,points):
                offset=world_point-contact;offset+=unit*offset.dot(unit)*(length_ratio-1)
                vertex.co=skin.inverted()@(target+turn@offset)
        else:
            local_delta=skin.inverted().to_3x3()@delta
            for vertex in obj.data.vertices:vertex.co+=local_delta
        grip_audit[part]={'world_offset':list(delta),'contact_error_before':delta.length}
        evaluated.to_mesh_clear()
    (OUT/'travel_grip_fit.json').write_text(json.dumps(grip_audit,indent=2))
    reset(rig)
    for track in rig.animation_data.nla_tracks:track.mute=False
    select([rig]+[bpy.data.objects[name] for name in SIZES])
    bpy.ops.export_scene.gltf(filepath=str(ASSETS/'miner.glb'),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,export_normals=True,export_tangents=True,export_animations=True,export_animation_mode='NLA_TRACKS',export_skins=True,export_materials='EXPORT',export_all_influences=False,export_cameras=False,export_lights=False,export_extras=False)
    reset(rig);bpy.ops.file.make_paths_relative();bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/miner_game_export.blend'))
    print('EXPORTED_INTREPID_MINER')

{'prepare':prepare,'bake':bake,'export':export}[STAGE]()
