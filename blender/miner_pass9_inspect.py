import bpy, json
from pathlib import Path
from mathutils import Vector
root=Path(__file__).resolve().parents[1]
bpy.ops.wm.open_mainfile(filepath=str(root/'blender/miner_convergence_working.blend'))
dg=bpy.context.evaluated_depsgraph_get()
def bounds(vs):return [[round(fn(v[k] for v in vs),5) for k in range(3)] for fn in [min,max]]
rows=[]
for o in bpy.context.scene.objects:
    if o.type!='MESH' or o.hide_render:continue
    if ('source_component' in o and o['source_component'] in [10,11,12,13,26,27,28,29,35,36,37,48,49,51,52,55,56,61,63,65,67]) or o.name.startswith(('Vest |','Pickaxe |','Gold pan |')):
        e=o.evaluated_get(dg);m=e.to_mesh()
        rows.append(dict(name=o.name,source=o.get('source_component'),rest=bounds([v.co for v in o.data.vertices]),world=bounds([e.matrix_world@v.co for v in m.vertices]),parent=o.parent.name if o.parent else '',bone=o.parent_bone,mods=[m.type for m in o.modifiers],n=len(o.data.vertices)))
        e.to_mesh_clear()
rig=bpy.data.objects['MinerRig']
for side in ['Left','Right']:
    for bone in ['Hand','IndexProximal','MiddleProximal','ThumbProximal','ThumbDistal']:
        p=rig.pose.bones.get(side+bone)
        if p:rows.append(dict(bone=p.name,head=list(p.head),tail=list(p.tail),rot=list(p.rotation_euler)))
(root/'artifacts/miner-convergence/pass9_inspection.json').write_text(json.dumps(rows,indent=2))
print(json.dumps(rows))
