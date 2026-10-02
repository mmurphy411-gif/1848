import bpy,sys,json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(Path(__file__).resolve().parent));import run
a,uv,groups=run.source_mesh()
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'experiments/miner_anatomy_study/refinement/miner_refined.blend'))
rig=bpy.data.objects['MinerRig']
data={'joints':{},'bones':{}}
for n,fs in groups.items():
    if n.startswith('joint-l-') and any(x in n for x in ['hand','finger','elbow','shoulder']):
        ids=sorted({v for f in fs for v,t in f});data['joints'][n]=a[ids].mean(0).tolist()
for p in rig.data.bones:
    if p.name.startswith('Left'):data['bones'][p.name]={'head':list(p.head_local),'tail':list(p.tail_local),'matrix':[list(r) for r in p.matrix_local]}
(ROOT/'experiments/miner_anatomy_study/finish_inspection.json').write_text(json.dumps(data,indent=2))
print(json.dumps(data))
