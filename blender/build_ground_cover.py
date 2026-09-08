"""Small grass fans and three June flower silhouettes for instancing."""
import sys, random, math, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
start=time.perf_counter(); reset()
for index,name in enumerate(['grass','lupine','poppy','yarrow']):
    rng=random.Random(700+index); verts=[]; faces=[]; colors=[]; uvs=[]
    for j in range(7 if index==0 else 3):
        angle=rng.random()*math.tau; h=rng.uniform(.2,.5); base=len(verts)
        side=Vector((math.cos(angle),math.sin(angle),0))*(.13 if index==0 else .035)
        root=Vector((rng.uniform(-.15,.15),rng.uniform(-.15,.15),0))
        tip=root+Vector((.08*math.sin(angle),.08*math.cos(angle),h))
        if index==0:
            verts.extend([root-side,root+side,tip+side,tip-side]);faces.append((base,base+1,base+2,base+3));colors.extend([(0,1,0,1),(.1,1,0,1),(1,1,0,1),(1,1,0,1)]);uvs.extend([(0,0),(1,0),(1,1),(0,1)])
        else:
            verts.extend([root-side,root+side,tip]); faces.append((base,base+1,base+2)); colors.extend([(0,1,0,1),(.1,1,0,1),(1,1,0,1)]);uvs.extend([(0,0),(1,0),(.5,1)])
        if index:
            for petal in range(6):
                a=petal*math.tau/6; b=len(verts)
                verts.extend([tip,tip+Vector((math.cos(a),math.sin(a),.15 if index==1 else .02))*.1,tip+Vector((math.cos(a+.8),math.sin(a+.8),.02))*.1])
                faces.append((b,b+1,b+2)); colors.extend([(1,1,index/3,1)]*3);uvs.extend([(0,0),(1,0),(.5,1)])
    obj=mesh_object(name,verts,faces,uvs=uvs,colors=colors,materials=[material(name,[(.1,.25,.05),(.14,.15,.48),(.8,.22,.015),(.8,.8,.66)][index])])
    export(obj,'plants/'+name+'.glb'); obj.location.x=index
save('build_ground_cover'); print('COVER_SECONDS',time.perf_counter()-start)
