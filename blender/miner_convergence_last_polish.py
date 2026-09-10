"""Pass 17: natural hair boundary, battered felt, and purposefully folded sleeves."""
import bpy,sys,math,bmesh
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence_structural as s
import miner_convergence_identity_polish as identity
import miner_convergence_materials as m
b=s.b;c=s.c;OUT=s.OUT

def hair(lookup):
    for o in list(b.collection('IDENTITY | groomed hair curves').objects):
        if not o.hide_render:c.archive(o)
    for o in list(s.active_meshes('IDENTITY | facial hair')):
        if o.name.startswith('Beard | grouped'):c.archive(o)
    head=lookup[52];tree=BVHTree.FromPolygons([v.co.copy() for v in head.data.vertices],[tuple(p.vertices) for p in head.data.polygons])
    vs=[];fs=[];rows=16;cols=81
    for j in range(rows):
        t=j/(rows-1)
        for k in range(cols):
            a=-1.42+k/(cols-1)*2.84;side=abs(math.sin(a));top=1.552+.038*side**1.4+.0007*math.sin(k*2.3)
            bottom=1.503+.027*(max(0,side-.55)/.45)**1.8
            z=top*(1-t)+bottom*t;direction=Vector((math.sin(a),-math.cos(a),0));hit,normal,idx,dist=tree.ray_cast(Vector((0,.002,z)),direction,.3)
            if hit is None:hit=Vector((.045*math.sin(a),-.05*math.cos(a),z))
            vs.append(hit+direction*(.0008+.0014*math.sin(t*math.pi)))
    for j in range(rows-1):
        for k in range(cols-1):
            a=j*cols+k;f=(a,a+1,a+cols+1,a+cols);p=sum((vs[i] for i in f),Vector())/4
            if not ((p.x/.027)**2+((p.z-1.546)/.0065)**2<1 and p.y<0):fs.append(f)
    mat=b.material('FINISH | broken-density beard',(.025,.014,.007),.88);b.replace_surface(lookup[51],vs,fs,mat,lambda p:{'Head':1})
    layer=lookup[51].data.color_attributes.new(name='beard_density_tone',type='FLOAT_COLOR',domain='POINT')
    for v in lookup[51].data.vertices:
        t=(v.index//cols)/(rows-1);edge=math.exp(-t/.14)
        layer.data[v.index].color=(.020+.047*edge,.011+.021*edge,.006+.010*edge,1)
    n=mat.node_tree.nodes;l=mat.node_tree.links;a=n.new('ShaderNodeAttribute');a.attribute_name='beard_density_tone';l.new(a.outputs['Color'],n['Principled BSDF'].inputs['Base Color'])
    for o in s.active_meshes('IDENTITY | hair and beard'):
        if not o.name.startswith('Hair | swept clump'):continue
        i=int(o.name.rsplit(' ',1)[1])
        for v in o.data.vertices:
            p=v.co;t=max(0,min(1,(1.66-p.z)/.14));radial=Vector((p.x,p.y-.01,0)).normalized()
            p+=radial*(.004*math.sin(i*1.37+t*math.pi*1.5)*t)
    identity.groom(lookup,head_density=24,beard_count=1400,head_radius=.00030,beard_radius=.00027)

def hat(lookup):
    o=lookup[71]
    for v in o.data.vertices:
        p=v.co;a=math.atan2(p.y,p.x);radius=math.sqrt((p.x/.204)**2+(p.y/.192)**2)
        if v.index<384:
            edge=max(0,min(1,(radius-.55)/.45));p.z+=edge*(.005*math.exp(-((a+.5)/.35)**2)-.007*math.exp(-((a+2.1)/.33)**2))
        elif p.z>1.70:
            t=max(0,min(1,(p.z-1.70)/.05));p.z-=.006*math.exp(-((p.x+.012)/.028)**2)*t
            if p.y<0:p.y+=.004*math.exp(-((p.x+.045)/.016)**2)*math.sin(t*math.pi)
    mat=bpy.data.materials['FINISH | felt'];ramp=next(n for n in mat.node_tree.nodes if n.label=='Restrained base palette')
    ramp.color_ramp.elements[0].color=(.018,.009,.004,1);ramp.color_ramp.elements[1].color=(.073,.042,.018,1)
    m.attributes(o,'felt')

def sleeves(lookup):
    for idx,side in [(36,1),(37,-1)]:
        o=lookup[idx];bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.subdivide_edges(bm,edges=list(bm.edges),cuts=1,use_grid_fill=True);bm.to_mesh(o.data);bm.free()
        for v in o.data.vertices:
            p=v.co;cx=side*(.21+.42*(1.4-p.z));u=(p.x-cx)*side;a=math.atan2(p.y,u);front=max(0,-math.sin(a))**2
            fold=0
            for z,slope,amp,w in [(1.172,-.45,.005,.006),(1.211,.60,.006,.008),(1.255,-.70,.007,.009),(1.322,.95,.004,.013)]:
                center=z+slope*u+.004*side;fold+=amp*math.exp(-((p.z-center)/w)**2)-amp*.42*math.exp(-((p.z-center-.008)/(w*.65))**2)
            p.y-=front*fold
        m.attributes(o,'linen')
    for idx in [39,40]:
        o=lookup[idx]
        if o.hide_render:continue
        center=sum((v.co for v in o.data.vertices),Vector())/len(o.data.vertices)
        for v in o.data.vertices:
            p=v.co;a=math.atan2(p.y-center.y,p.x-center.x);p.z+=.004*math.sin(a*2+idx)
        m.attributes(o,'linen')

def run():
    lookup=s.load_previous(17);hair(lookup);hat(lookup);sleeves(lookup);s.finish(17)

if __name__=='__main__':run()
