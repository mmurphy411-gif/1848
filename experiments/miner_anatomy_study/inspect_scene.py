import bpy,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/miner_convergence_working.blend'))
obs=[]
for o in bpy.context.scene.objects:
    if o.type in {'MESH','CURVE'} and not o.hide_render:
        pts=[o.matrix_world@v.co for v in o.data.vertices] if o.type=='MESH' else []
        obs.append({'name':o.name,'type':o.type,'source':o.get('source_component'), 'collections':[c.name for c in o.users_collection], 'bounds':[[min(p[i] for p in pts),max(p[i] for p in pts)] for i in range(3)] if pts else None,'vertices':len(pts),'materials':[m.name for m in o.data.materials if m], 'parent':o.parent.name if o.parent else None,'modifiers':[(m.name,m.type) for m in o.modifiers]})
(OUT/'scene_inventory.json').write_text(json.dumps(obs,indent=2))
rig=bpy.data.objects['MinerRig']
print('RIG',list(rig.location), 'HEAD',list(rig.data.bones['Head'].head_local),list(rig.data.bones['Head'].tail_local))
for r in obs:
    if r['source'] in [50,51,52,53,63,64] or any(s in r['name'] for s in ['Hair |','Face |']):print(r)
