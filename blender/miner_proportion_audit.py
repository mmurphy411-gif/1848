import bpy,sys,json
from pathlib import Path
from mathutils import Vector
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence_continue as c
n=int(sys.argv[sys.argv.index('--')+1]);OUT=c.OUT
bpy.ops.wm.open_mainfile(filepath=str(OUT/f'pass_{n:02}.blend'));c.loadout('expedition')
dg=bpy.context.evaluated_depsgraph_get()
def points(objects):
    out=[]
    for o in objects:
        if o.type!='MESH' or o.hide_render or any(g.hide_render for g in o.users_collection):continue
        ev=o.evaluated_get(dg);mesh=ev.to_mesh();out.extend(ev.matrix_world@v.co for v in mesh.vertices);ev.to_mesh_clear()
    return out
def bounds(ps):
    low=[min(p[k] for p in ps) for k in range(3)];high=[max(p[k] for p in ps) for k in range(3)]
    return {'min':low,'max':high,'size':[b-a for a,b in zip(low,high)]}
data={}
for name,filter_fn in [('head',lambda o:o.get('source_component')==52),('hat',lambda o:o.get('source_component')==71),('shirt',lambda o:o.get('source_component') in [35,36,37,39,40]),('hands',lambda o:o.get('source_component') in range(10,32)),('boots',lambda o:any(g.name=='COSTUME | boots' for g in o.users_collection)),('backpack',lambda o:any(g.name=='GEAR | backpack' for g in o.users_collection) and 'harness' not in o.name),('bedroll',lambda o:any(g.name=='GEAR | bedroll' for g in o.users_collection)),('satchel',lambda o:any(g.name=='GEAR | satchel' for g in o.users_collection)),('canteen',lambda o:'pressed steel halves' in o.name),('pan',lambda o:'original spun mesh' in o.name),('pickaxe',lambda o:any(g.name=='GEAR | pickaxe' for g in o.users_collection))]:
    data[name]=bounds(points([o for o in bpy.context.scene.objects if filter_fn(o)]))
c.loadout('base');dg=bpy.context.evaluated_depsgraph_get();ps=points(bpy.context.scene.objects);data['base']=bounds(ps)
data['base_triangles']=sum(len(p.vertices)-2 for o in bpy.context.scene.objects if o.type=='MESH' and not o.hide_render and not any(g.hide_render for g in o.users_collection) for p in o.data.polygons)
data['body_bands']={str(z):bounds([p for p in ps if abs(p.z-z)<.018]) for z in [.39,.63,.95,1.03,1.34,1.40]}
(OUT/f'pass_{n:02}_proportion_audit.json').write_text(json.dumps(data,indent=2))
print(json.dumps({k:v.get('size',v) for k,v in data.items() if isinstance(v,dict) and k!='body_bands'}))
