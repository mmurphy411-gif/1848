"""Editable low-poly expedition props. Local +Y is tool length; export maps to Godot +Z."""
import bpy, math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'assets'/'expedition';OUT.mkdir(parents=True,exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
def mat(name,color,metal=0,rough=.8):
    m=bpy.data.materials.new(name);m.diffuse_color=(*color,1);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*color,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
    return m
wood=mat('Dark worn walnut',(.20,.085,.032));iron=mat('Forged iron',(.095,.10,.105),.8,.48);brass=mat('Dull brass',(.32,.22,.075),.7,.5);canvas=mat('Oiled canvas',(.42,.36,.25));hide=mat('Dried hide',(.25,.14,.065))
def mesh(name,verts,faces,m):
    data=bpy.data.meshes.new(name);data.from_pydata(verts,[],faces);data.update()
    o=bpy.data.objects.new(name,data);bpy.context.collection.objects.link(o);data.materials.append(m);return o
def beam(name,a,b,r,m,vertices=8):
    a,b=Vector(a),Vector(b);bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=r,radius2=r*.88,depth=(b-a).length,location=(a+b)*.5)
    o=bpy.context.object;o.name=name;o.rotation_euler=(b-a).to_track_quat('Z','Y').to_euler();o.data.materials.append(m);return o
def box(name,pos,size,m):
    bpy.ops.mesh.primitive_cube_add(size=1,location=pos);o=bpy.context.object;o.name=name;o.scale=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m);return o
def export(name,objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.select_set(True)
    bpy.ops.export_scene.gltf(filepath=str(OUT/(name+'.glb')),export_format='GLB',use_selection=True,export_yup=True)
def group(name,builder):
    before=set(bpy.data.objects);builder();objects=list(set(bpy.data.objects)-before)
    c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c)
    for o in objects:
        for old in list(o.users_collection):old.objects.unlink(o)
        c.objects.link(o)
    export(name,objects)
def spear():
    beam('Ash shaft',(0,-.65,0),(0,1.25,0),.021,wood)
    beam('Iron socket',(0,1.1,0),(0,1.36,0),.026,iron)
    for x in [-.09,0,.09]:
        beam('Fork root',(0,1.28,0),(x,1.42,0),.008,iron)
        mesh('Forged barbed tine',[(x-.008,1.4,-.009),(x+.008,1.4,-.009),(x+.008,1.4,.009),(x-.008,1.4,.009),(x,1.73,0),(x+.035,1.54,0)],[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(1,5,4)],iron)
def rifle():
    # Side-profile stock with a dropped comb, wrist, fore-end and butt plate.
    profile=[(-.36,-.09),(-.36,.10),(-.16,.115),(.01,.03),(.18,.02),(.78,.045),(.81,-.005),(.18,-.035),(.04,-.06),(-.12,-.04)]
    verts=[(x,y,z) for x in [-.025,.025] for y,z in profile];n=len(profile)
    faces=[tuple(range(n-1,-1,-1)),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
    mesh('Shaped walnut stock',verts,faces,wood)
    beam('Octagonal barrel',(0,.10,.058),(0,1.05,.058),.015,iron)
    beam('Ramrod',(0,.2,-.019),(0,.94,-.019),.005,iron)
    for y in [.27,.68]:box('Barrel band',(0,y,.032),(.063,.014,.082),iron)
    box('Lock plate',(.029,.07,.025),(.006,.13,.042),iron)
    beam('Percussion hammer',(.036,.07,.04),(.036,.11,.10),.009,iron)
    box('Rear sight',(0,.25,.08),(.025,.013,.012),iron);box('Front sight',(0,1.0,.08),(.009,.015,.012),brass)
    beam('Trigger',(0,.08,-.025),(0,.075,-.07),.006,iron)
    for a,b in [((0,.02,-.045),(0,.035,-.092)),((0,.035,-.092),(0,.13,-.092)),((0,.13,-.092),(0,.15,-.032))]:beam('Trigger guard',a,b,.004,brass)
    box('Butt plate',(0,-.362,.005),(.056,.008,.195),iron)
def tent():
    # Two sagged cloth slopes, open riverward doorway, rear panel.
    for side in [-1,1]:
        verts=[]
        for y in [-1.35,0,1.35]:
            for i in range(7):
                t=i/6;verts.append((side*(1-t)*1.12,y,.08+1.62*t-.12*math.sin(t*math.pi)))
        faces=[(r*7+i,r*7+i+1,(r+1)*7+i+1,(r+1)*7+i) for r in range(2) for i in range(6)]
        o=mesh('Canvas slope',verts,faces,canvas);o.modifiers.new('Cloth thickness','SOLIDIFY').thickness=.004
        beam('Hem rope',(side*1.12,-1.35,.08),(side*1.12,1.35,.08),.009,wood)
    mesh('Rear canvas',[(-1.12,1.35,.08),(1.12,1.35,.08),(0,1.35,1.7)],[(0,1,2)],canvas)
    beam('Ridge pole',(0,-1.45,1.7),(0,1.45,1.7),.031,wood)
    for y in [-1.35,1.35]:beam('Upright',(0,y,0),(0,y,1.72),.029,wood)
    for x in [-1.12,1.12]:
        for y in [-1.35,1.35]:beam('Peg',(x,y,-.04),(x,y,.18),.02,wood)
def pelt():
    points=[(-.20,-.48,0),(.18,-.45,.015),(.31,-.28,0),(.5,-.35,0),(.56,-.25,0),(.31,-.09,.02),(.30,.25,0),(.45,.45,0),(.36,.51,0),(.18,.33,.01),(0,.52,0),(-.16,.33,.01),(-.38,.48,0),(-.47,.4,0),(-.27,.2,0),(-.30,-.1,.02),(-.52,-.25,0),(-.49,-.35,0),(-.29,-.25,0)]
    o=mesh('Dressed hide',[(0,0,.045)]+points,[(0,i+1,(i+1)%len(points)+1) for i in range(len(points))],hide);o.modifiers.new('Hide thickness','SOLIDIFY').thickness=.007
group('spear',spear);group('rifle',rifle);group('tent',tent);group('hide',pelt)
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender'/'expedition_props.blend'))
