"""Package the finished source and assert anatomical/export invariants."""
import bpy,json,hashlib
import numpy as np
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1];OUT=ROOT/'artifacts/miner-finished'
def actions():
    result={}
    for a in bpy.data.actions:
        values=[]
        for layer in a.layers:
            for strip in layer.strips:
                for slot in a.slots:
                    bag=strip.channelbag(slot,ensure=False)
                    if bag:
                        for f in bag.fcurves:
                            corrected=['pan_socket']+[side+part for side in ['Left','Right'] for part in ['UpperArm','LowerArm','Hand']+[digit+segment for digit in ['Thumb','Index','Middle','Ring','Little'] for segment in ['Proximal','Intermediate','Distal']]]
                            if a.name.startswith('pan_') and any('"'+name+'"' in f.data_path for name in corrected):continue
                            values.append((f.data_path,f.array_index,[(tuple(k.co),tuple(k.handle_left),tuple(k.handle_right),k.interpolation) for k in f.keyframe_points]))
        result[a.name]=hashlib.sha256(repr(values).encode()).hexdigest()
    return result
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'experiments/miner_anatomy_study/refinement/miner_refined.blend'))
old_actions=actions();old_rest={b.name:np.array(b.matrix_local) for b in bpy.data.objects['MinerRig'].data.bones}
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/miner_finished.blend'))
rig=bpy.data.objects['MinerRig'];report={'animation_curves_unchanged_outside_corrected_panning_arms':old_actions==actions(),'panning_arm_fit':json.loads((OUT/'panning_arm_fit.json').read_text()),'rest_matrix_max_difference':max(float(np.max(abs(np.array(rig.data.bones[n].matrix_local)-m))) for n,m in old_rest.items()),'hands':{}}
for side in ['Left','Right']:
    o=bpy.data.objects['FINISH | continuous forearm and hand '+side]
    # Every wrist vertex must belong to faces on the same connected arm surface.
    adjacency=[set() for _ in o.data.vertices]
    for e in o.data.edges:
        a,b=e.vertices;adjacency[a].add(b);adjacency[b].add(a)
    todo=set(range(len(adjacency)));sizes=[]
    while todo:
        pending=[todo.pop()];count=0
        while pending:
            v=pending.pop();count+=1
            for other in adjacency[v]:
                if other in todo:todo.remove(other);pending.append(other)
        sizes.append(count)
    error=max(abs(sum(g.weight for g in v.groups)-1) for v in o.data.vertices)
    report['hands'][side]={'vertices':len(o.data.vertices),'connected_component_sizes':sorted(sizes,reverse=True),'weight_sum_error':error}
    assert len(sizes)==1 and error<1e-5
assert report['animation_curves_unchanged_outside_corrected_panning_arms'] and report['rest_matrix_max_difference']==0
assert all(row['pan_matrix_max_error']<1e-5 and row['wrist_reach_offset']<.04001 for row in report['panning_arm_fit'].values())
(OUT/'source_verification.json').write_text(json.dumps(report,indent=2))
note=bpy.data.texts['MINER FINISHED — READ ME'];note.clear();note.write((ROOT/'MINER_GAME_INTEGRATION.md').read_text(encoding='utf-8'))
for im in bpy.data.images:
    if im.source=='FILE' and not im.packed_file:
        try:im.pack()
        except RuntimeError:pass
bpy.context.scene.camera=bpy.data.objects['Study full']
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/miner_finished.blend'))
print('FINISHED_SOURCE_VERIFIED',json.dumps(report))
