"""Verify source preservation, skin bindings and limited pose compatibility."""
import bpy,json,hashlib,sys
import numpy as np
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT));import run_refine as refine
def geometry(o):
    a=np.empty(len(o.data.vertices)*3,dtype=np.float32);o.data.vertices.foreach_get('co',a)
    h=hashlib.sha256(a.tobytes())
    for p in o.data.polygons:h.update(np.array(p.vertices,dtype=np.int32).tobytes())
    return h.hexdigest()
def actions():
    result={}
    for a in bpy.data.actions:
        vals=[]
        for layer in a.layers:
            for strip in layer.strips:
                for slot in a.slots:
                    bag=strip.channelbag(slot,ensure=False)
                    if bag:
                        for f in bag.fcurves:vals.append((f.data_path,f.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in f.keyframe_points]))
        result[a.name]=hashlib.sha256(repr(vals).encode()).hexdigest()
    return result
bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'miner_anatomy_candidate.blend'))
rig=bpy.data.objects['MinerRig'];rest={b.name:np.array(b.matrix_local) for b in rig.data.bones};source_actions=actions()
source_geometry={o.name:geometry(o) for o in bpy.context.scene.objects if o.type=='MESH'}
old_hair=len(bpy.data.objects['STUDY | swept wavy hair'].data.vertices)
bpy.ops.wm.open_mainfile(filepath=str(OUT/'miner_refined.blend'))
rig=bpy.data.objects['MinerRig'];scene=bpy.context.scene
new=[o for o in scene.objects if o.type=='MESH' and o.name.startswith('REFINE |') and not o.hide_render]
report={'rest_matrix_max_difference':max(float(np.max(abs(np.array(rig.data.bones[n].matrix_local)-m))) for n,m in rest.items()),'animation_curves_unchanged':source_actions==actions(),'original_meshes_preserved':all(n in bpy.data.objects and geometry(bpy.data.objects[n])==h for n,h in source_geometry.items()),'original_mesh_count':len(source_geometry),'hair_vertices_before':old_hair,'hair_vertices_after':sum(len(o.data.vertices) for o in new if 'hair' in o.name),'new_meshes':{},'deformation_samples':[]}
for o in new:
    error=max(abs(sum(g.weight for g in v.groups)-1) for v in o.data.vertices)
    report['new_meshes'][o.name]={'vertices':len(o.data.vertices),'weight_sum_max_error':error,'missing_bone_groups':[g.name for g in o.vertex_groups if g.name not in rig.data.bones]}
for track in rig.animation_data.nla_tracks:track.mute=True
for act in bpy.data.actions:
    rig.animation_data.action=act
    if act.slots:rig.animation_data.action_slot=act.slots[0]
    for t in [0,.5,.95]:
        scene.frame_set(round(act.frame_range[0]+t*(act.frame_range[1]-act.frame_range[0])));dep=bpy.context.evaluated_depsgraph_get();finite=True
        for o in new:
            ev=o.evaluated_get(dep);mesh=ev.to_mesh();a=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',a);finite=finite and bool(np.isfinite(a).all());ev.to_mesh_clear()
        report['deformation_samples'].append({'action':act.name,'frame':scene.frame_current,'finite':finite})
assert report['rest_matrix_max_difference']==0 and report['animation_curves_unchanged'] and report['original_meshes_preserved']
assert all(r['weight_sum_max_error']<1e-5 and not r['missing_bone_groups'] for r in report['new_meshes'].values())
assert all(r['finite'] for r in report['deformation_samples'])
(OUT/'verification.json').write_text(json.dumps(report,indent=2))
print('VERIFIED',len(source_actions),'clips',len(report['deformation_samples']),'pose samples','HAIR VERTICES',old_hair,'->',report['hair_vertices_after'],flush=True)
refine.previous.OUT=OUT
for name in ['walk','pan_swirl','lie_down']:
    act=bpy.data.actions[name];rig.animation_data.action=act
    if act.slots:rig.animation_data.action_slot=act.slots[0]
    scene.frame_set(round(sum(act.frame_range)/2));bpy.context.view_layer.update()
    if name!='walk':
        center=rig.matrix_world@rig.pose.bones['Chest'].head+Vector((0,0,.06));cam=bpy.data.objects['Study torso'];cam.location=center+Vector((2.1,-5,.45));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.86
    refine.previous.render('pose_'+name,['full' if name=='walk' else 'torso'])
