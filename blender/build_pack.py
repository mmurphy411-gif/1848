"""Soft canvas knapsack with sewn gussets, closure straps and shoulder harness."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
reset()
canvas=material('Pack canvas',(.29,.235,.145))
leather=material('Pack leather',(.105,.059,.029))
thread=material('Pack stitching',(.44,.35,.21))
iron=material('Pack buckles',(.14,.13,.10))
parts=[]

def cord(name,points,r,mat):
    v=[];f=[];u=[];c=[];s=[]
    tube(v,f,u,c,s,points,[r]*len(points),6)
    obj=mesh_object(name,v,f,u,materials=[mat]);parts.append(obj);return obj

def strap(name,points,width,mat):
    v=[];f=[];u=[]
    for j,p in enumerate(points):
        for x in [-1,1]:v.append(Vector(p)+Vector((x*width*.5,0,0)));u.append(((x+1)*.5,j/(len(points)-1)))
    for j in range(len(points)-1):a=j*2;f.append((a,a+1,a+3,a+2))
    obj=mesh_object(name,v,f,u,materials=[mat]);parts.append(obj)
    mod=obj.modifiers.new('Leather thickness','SOLIDIFY');mod.thickness=.003
    bpy.context.view_layer.objects.active=obj;bpy.ops.object.modifier_apply(modifier=mod.name)

v=[];f=[];u=[]
profile=[(-.235,.10,.035),(-.22,.16,.08),(-.18,.18,.102),(-.10,.185,.106),
         (0,.176,.095),(.10,.165,.079),(.17,.145,.063),(.20,.12,.044),(.21,.075,.02)]
for j,(z,w,d) in enumerate(profile):
    for k in range(48):
        a=k*math.tau/48
        x=w*math.copysign(abs(math.cos(a))**.58,math.cos(a))
        y=d*math.copysign(abs(math.sin(a))**.65,math.sin(a))
        folds=.004*math.sin(a*9+j*.7)+.003*math.cos(a*5-j)
        v.append((x+folds,y+folds,z+.004*math.sin(a*3+j*.6)));u.append((k/48,j/8))
for j in range(8):
    for k in range(48):a=j*48+k;b=j*48+(k+1)%48;f.append((a,b,b+48,a+48))
f.extend([tuple(reversed(range(48))),tuple(384+i for i in range(48))])
parts.append(mesh_object('Filled canvas body',v,f,u,materials=[canvas]))
# Broad overlapping flap follows the bag's outer face, with an uneven rounded hem.
v=[];f=[];u=[]
for j in range(9):
    t=j/8
    for k in range(17):
        x=(k/16*2-1)*(.137+.021*math.sin(t*math.pi))
        y=.040+.074*math.sin(t*math.pi*.62)
        z=.218-.255*t+.020*(abs(x)/.16)**3*t
        v.append((x,y+.003*math.sin(k*.8+t*4),z));u.append((k/16,t))
for j in range(8):
    for k in range(16):a=j*17+k;f.append((a,a+1,a+18,a+17))
flap=mesh_object('Overlapping canvas flap',v,f,u,materials=[canvas]);parts.append(flap)
mod=flap.modifiers.new('Flap hem thickness','SOLIDIFY');mod.thickness=.004
bpy.context.view_layer.objects.active=flap;bpy.ops.object.modifier_apply(modifier=mod.name)
cord('Bound flap hem',[v[136+i] for i in range(17)],.002,thread)
for s in [-1,1]:
    cord('Gusset seam',[(s*w,.014,z) for z,w,d in profile],.002,thread)
    strap('Closure strap',[(s*.09,.060,.20),(s*.09,.105,.12),(s*.09,.122,.01),(s*.09,.108,-.08),(s*.09,.114,-.13)],.021,leather)
    # Harness bends over the shoulder and returns down the chest to the lower bag.
    strap('Shoulder harness',[(s*.10,-.02,.13),(s*.15,-.12,.16),(s*.16,-.24,.13),
          (s*.155,-.31,.02),(s*.16,-.30,-.10),(s*.175,-.19,-.20),(s*.145,0,-.20)],.033,leather)
    x=s*.09;y=.127;z=-.062
    cord('Forged buckle',[(x-.015,y,z-.018),(x+.015,y,z-.018),(x+.015,y,z+.018),(x-.015,y,z+.018),(x-.015,y,z-.018)],.0025,iron)
    cord('Buckle tongue',[(x,y,z-.018),(x,y-.002,z+.006)],.002,iron)
    for j in range(10):
        z=.10-j*.020
        cord('Harness stitch',[(s*.145-.012,-.309,z),(s*.145-.012,-.309,z-.007)],.0008,thread)
cord('Top carry loop',[(-.044,-.012,.20),(-.037,-.02,.255),(0,-.02,.27),(.037,-.02,.255),(.044,-.012,.20)],.008,leather)
bpy.ops.object.select_all(action='DESELECT')
for obj in parts:obj.select_set(True)
bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join()
pack=parts[0];pack.name='Canvas knapsack';export(pack,'miner/pack.glb');save('build_pack')
