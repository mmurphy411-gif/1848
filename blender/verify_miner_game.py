"""Inspect exported topology, original rest compatibility and actual mesh deformation."""
import bpy,math,json
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'artifacts/miner-game'
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/miner_game_export.blend'))
rig=bpy.data.objects['MinerRig'];scene=bpy.context.scene
for track in rig.animation_data.nla_tracks:track.mute=True
with bpy.data.libraries.load(str(ROOT/'blender/build_miner.blend'),link=False) as (source,target):target.armatures=list(source.armatures)
original=target.armatures[0];rest_error=0
for bone in rig.data.bones:
    if bone.name in original.bones:
        rest_error=max(rest_error,max(abs(bone.matrix_local[i][j]-original.bones[bone.name].matrix_local[i][j]) for i in range(4) for j in range(4)))
objects=[o for o in scene.objects if o.type=='MESH'];audit={'rest_matrix_max_difference':rest_error,'deformations':{}}
deps=bpy.context.evaluated_depsgraph_get()
for action in bpy.data.actions:
    rig.animation_data.action=action
    if action.slots:rig.animation_data.action_slot=action.slots[0]
    rows=[]
    for factor in [0,.5,.95]:
        scene.frame_set(round(action.frame_range[0]+factor*(action.frame_range[1]-action.frame_range[0])))
        row={}
        for o in objects:
            evaluated=o.evaluated_get(deps);mesh=evaluated.to_mesh();points=[o.matrix_world@v.co for v in mesh.vertices]
            lo=[min(p[i] for p in points) for i in range(3)];hi=[max(p[i] for p in points) for i in range(3)]
            row[o.name]={'min':lo,'max':hi,'finite':all(math.isfinite(x) for p in points for x in p)}
            evaluated.to_mesh_clear()
        rows.append(row)
    audit['deformations'][action.name]=rows
(OUT/'deformation_audit.json').write_text(json.dumps(audit,indent=2));assert rest_error<1e-6
assert all(o['finite'] for rows in audit['deformations'].values() for row in rows for o in row.values())
rig.animation_data.action=bpy.data.actions['idle'];rig.animation_data.action_slot=bpy.data.actions['idle'].slots[0];scene.frame_set(16)
world=bpy.data.worlds.new('Verification neutral');world.use_nodes=True;world.node_tree.nodes['Background'].inputs[0].default_value=(.3,.3,.3,1);world.node_tree.nodes['Background'].inputs[1].default_value=.7;scene.world=world
for label,loc,power,size in [('Key',(3,-4,5),650,5),('Fill',(-3,-2,3),350,4)]:
    data=bpy.data.lights.new(label,'AREA');data.energy=power;data.shape='DISK';data.size=size;o=bpy.data.objects.new(label,data);scene.collection.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
cam=bpy.data.cameras.new('Verification');o=bpy.data.objects.new('Verification',cam);scene.collection.objects.link(o);scene.camera=o;cam.type='ORTHO'
scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=800;scene.render.resolution_y=1000;scene.render.resolution_percentage=100
for label,location,target,scale in [('blender_game_face',(1.5,-7,1.62),(0,0,1.59),.40),('blender_game_body',(4,-7,1.1),(0,0,.9),2.1)]:
    o.location=location;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler();cam.ortho_scale=scale;scene.render.filepath=str(OUT/(label+'.png'));bpy.ops.render.render(write_still=True)
print('DEFORMATION_AUDIT_COMPLETE',rest_error)
