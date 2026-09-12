"""Check source preservation, bindings, and evaluated head motion in existing clips."""
import bpy,json,math,sys,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent;ROOT=OUT.parents[1]
sys.path.insert(0,str(OUT));import run as study

def fingerprint(o):
    h=hashlib.sha256()
    a=np.empty(len(o.data.vertices)*3,dtype=np.float32);o.data.vertices.foreach_get('co',a);h.update(a.tobytes())
    return h.hexdigest()

bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/miner_convergence_working.blend'))
source_rig=bpy.data.objects['MinerRig']
rest={b.name:np.array(b.matrix_local) for b in source_rig.data.bones}
actions={a.name:tuple(a.frame_range) for a in bpy.data.actions}
protected={o.name:fingerprint(o) for o in bpy.context.scene.objects if o.type=='MESH' and any(c.name.startswith(('COSTUME','GEAR','BODY | arms','BODY | hands')) for c in o.users_collection)}
bpy.ops.wm.open_mainfile(filepath=str(OUT/'miner_anatomy_candidate.blend'))
rig=bpy.data.objects['MinerRig'];scene=bpy.context.scene
new=[o for o in scene.objects if o.type=='MESH' and o.name.startswith('STUDY |')]
audit={'rest_matrix_max_difference':max(float(np.max(abs(np.array(rig.data.bones[n].matrix_local)-m))) for n,m in rest.items()),'actions_unchanged':actions=={a.name:tuple(a.frame_range) for a in bpy.data.actions},'protected_mesh_count':len(protected),'protected_geometry_unchanged':all(fingerprint(bpy.data.objects[n])==v for n,v in protected.items()),'new_meshes':{},'deformation_samples':[]}
for o in new:
    error=max(abs(sum(g.weight for g in v.groups)-1) for v in o.data.vertices)
    audit['new_meshes'][o.name]={'vertices':len(o.data.vertices),'weight_sum_max_error':error,'missing_bone_groups':[g.name for g in o.vertex_groups if g.name not in rig.data.bones]}
for track in rig.animation_data.nla_tracks:track.mute=True
for act in bpy.data.actions:
    rig.animation_data.action=act
    if act.slots:rig.animation_data.action_slot=act.slots[0]
    for t in [0,.5,.95]:
        scene.frame_set(round(act.frame_range[0]+t*(act.frame_range[1]-act.frame_range[0])))
        dep=bpy.context.evaluated_depsgraph_get();row={'action':act.name,'frame':scene.frame_current,'finite':True}
        for o in new:
            ev=o.evaluated_get(dep);mesh=ev.to_mesh();a=np.empty(len(mesh.vertices)*3,dtype=np.float32);mesh.vertices.foreach_get('co',a)
            row['finite']=row['finite'] and bool(np.isfinite(a).all());ev.to_mesh_clear()
        audit['deformation_samples'].append(row)
assert audit['rest_matrix_max_difference']==0 and audit['actions_unchanged'] and audit['protected_geometry_unchanged']
assert all(r['weight_sum_max_error']<1e-5 and not r['missing_bone_groups'] for r in audit['new_meshes'].values())
assert all(r['finite'] for r in audit['deformation_samples'])
(OUT/'verification.json').write_text(json.dumps(audit,indent=2))
print('VERIFIED',len(actions),'actions',len(audit['deformation_samples']),'pose samples',len(protected),'protected meshes')
print('ACTION_NAMES',list(actions))
for name in ['walk','pan','crouch']:
    if name not in bpy.data.actions:continue
    act=bpy.data.actions[name];rig.animation_data.action=act
    if act.slots:rig.animation_data.action_slot=act.slots[0]
    scene.frame_set(round(sum(act.frame_range)/2))
    study.render('pose_'+name,['full'])
