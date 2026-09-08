"""Low schist ledges with a recessed downstream joint, unit footprints."""
import sys, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
start=time.perf_counter(); reset()
for i in range(2):
    verts=[]; faces=[]
    # Three touching plates with a narrow, recessed joint along downstream +X.
    for x0,x1 in [(-.5,.28),(.30,.42),(.44,.5)]:
        base=len(verts)
        for z in [-.06,.06]:
            verts.extend([(x0,-.5,z),(x1,-.5,z),(x1,.5,z),(x0,.5,z)])
        faces.extend([tuple(base+j for j in q) for q in [(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)]])
    obj=mesh_object('ledge_%02d'%(i+1),verts,faces,materials=[material('Schist',(.16,.18,.18))])
    bevel=obj.modifiers.new('Water rounded joints','BEVEL'); bevel.width=.012; bevel.segments=2
    bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=bevel.name)
    export(obj,'bedrock/'+obj.name+'.glb'); obj.location.x=i*2
save('build_bedrock'); print('BEDROCK_SECONDS',time.perf_counter()-start)
