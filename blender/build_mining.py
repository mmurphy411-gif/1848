"""Milestone 11: a working cradle and full-size hand tools. Blender Z is up."""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
reset()
wood=material('Split pine',(.31,.20,.105))
end=material('Pale worn edges',(.43,.31,.17))
iron=material('Forged iron',(.09,.095,.085))
horn=material('Horn spoon',(.38,.28,.14))

def box(name,p,size,mat=wood):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p)
    o=bpy.context.object;o.name=name;o.scale=size;o.data.materials.append(mat)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    bevel=o.modifiers.new('Worn arris','BEVEL');bevel.width=.006;bevel.segments=1
    bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=bevel.name)
    return o

def pole(name,a,b,r,mat=wood):
    a,b=Vector(a),Vector(b)
    bpy.ops.mesh.primitive_cylinder_add(vertices=10,radius=r,depth=(b-a).length,location=(a+b)*.5)
    o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(mat)
    return o

def join(name,parts):
    bpy.ops.object.select_all(action='DESELECT')
    for o in parts:o.select_set(True)
    bpy.context.view_layer.objects.active=parts[0];bpy.ops.object.join();o=parts[0];o.name=name
    bpy.context.scene.cursor.location=(0,0,0);bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    return o

# A tilted trough, open discharge, removable hopper, riffles and iron fastenings.
parts=[]
for x in [-.27,.27]:
    for j in range(2):parts.append(box('Side plank',(x,0,.26+j*.105),(.045,1.40,.10),wood if j else end))
for i in range(5):
    o=box('Floor board',(-.21+i*.105,0,.20),(.101,1.4,.045));o.rotation_euler.x=math.radians(-5);parts.append(o)
for y in [-.40,-.14,.13]:parts.append(box('Riffle',(0,y,.24),(.50,.025,.035),iron))
for y in [-.42,.42]:
    verts=[]
    for i in range(13):
        x=-.40+i/12*.8;z=.045+.26*(x/.40)**2
        for yy,zz in [(y-.045,z),(y+.045,z),(y-.045,z+.065),(y+.045,z+.065)]:verts.append((x,yy,zz))
    faces=[]
    for i in range(12):
        a=i*4
        for q in [(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)]:faces.append(tuple(a+j for j in q))
    faces.extend([(0,2,3,1),(48,49,51,50)])
    parts.append(mesh_object('Curved runner',verts,faces,materials=[wood]))
for x in [-.22,.22]:parts.append(box('Hopper side',(x,.33,.49),(.035,.52,.19),end))
for y in [.07,.59]:parts.append(box('Hopper end',(0,y,.49),(.45,.035,.19),end))
for i in range(11):parts.append(pole('Screen rod',(-.21,.095+i*.044,.405),(.21,.095+i*.044,.405),.006,iron))
parts.append(pole('Rocking handle',(.27,.05,.31),(.55,.05,.85),.024,end))
parts.append(pole('Two-hand grip',(.55,-.065,.85),(.55,.165,.85),.025,end))
for x in [-.294,.294]:
    for y in [-.6,.5]:parts.append(pole('Square nail',(x,y,.31),(x*1.02,y,.31),.012,iron))
rocker=join('Cradle',parts);export(rocker,'mining/rocker.glb')

crowbar=join('Crowbar',[pole('Shaft',(0,0,0),(0,0,1.05),.018,iron),pole('Bent toe',(0,0,0),(0,-.09,-.025),.022,iron)])
export(crowbar,'mining/crowbar.glb')
shovel=join('Shovel',[pole('Ash handle',(0,0,.22),(0,0,1.18),.021,end),box('Blade',(0,0,.10),(.23,.025,.29),iron)])
export(shovel,'mining/shovel.glb')
pick=join('Pick',[pole('Ash handle',(0,0,0),(0,0,.9),.025,end),pole('Head',(-.29,0,.90),(.29,0,.85),.03,iron)])
export(pick,'mining/pick.glb')
spoon=join('Horn spoon',[pole('Handle',(0,0,0),(0,0,.20),.012,horn),box('Bowl',(0,-.013,.24),(.07,.025,.10),horn)])
export(spoon,'mining/spoon.glb')
save('build_mining')
