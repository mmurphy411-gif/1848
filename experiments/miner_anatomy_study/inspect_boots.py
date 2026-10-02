import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/miner_finished.blend'))
dep=bpy.context.evaluated_depsgraph_get();rows=[]
for o in bpy.context.scene.objects:
    if o.type!='MESH' or o.hide_render:continue
    ev=o.evaluated_get(dep);m=ev.to_mesh();pts=[o.matrix_world@v.co for v in m.vertices]
    if pts and max(p.z for p in pts)<.5:rows.append({'name':o.name,'bounds':[[min(p[i] for p in pts),max(p[i] for p in pts)] for i in range(3)],'modifiers':[(q.name,q.type) for q in o.modifiers]})
    ev.to_mesh_clear()
print(json.dumps(rows,indent=2))
