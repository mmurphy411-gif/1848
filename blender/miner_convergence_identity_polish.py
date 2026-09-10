"""Pass 14: eye/lip integration, scruffy hair growth and weathered skin material."""
import bpy,sys,math,random,bisect,bmesh
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence_structural as s
b=s.b;c=s.c;OUT=s.OUT

def grid(rows,cols):return [(j*cols+k,j*cols+k+1,(j+1)*cols+k+1,(j+1)*cols+k) for j in range(rows-1) for k in range(cols-1)]

def features(lookup):
    head=lookup[52];tree=BVHTree.FromPolygons([v.co.copy() for v in head.data.vertices],[tuple(p.vertices) for p in head.data.polygons])
    skin=bpy.data.materials['Convergence | warm weathered skin']
    def face(x,z,offset=.001):
        hit,normal,idx,d=tree.ray_cast(Vector((x,-.3,z)),Vector((0,1,0)),.5)
        return hit.y-offset if hit is not None else -.07
    for idx,side,upper in [(61,-1,False),(62,1,False),(67,-1,True),(68,1,True)]:
        vs=[];rows=6;cols=21;cx=side*.036
        for j in range(rows):
            t=j/(rows-1)
            for k in range(cols):
                u=k/(cols-1)*2-1;x=cx+u*.017
                arch=math.sqrt(max(0,1-u*u));innerz=1.616+(.0055 if upper else -.0039)*arch+.0006*u*side
                outerz=innerz+(.006 if upper else -.006)*(.65+.35*arch)
                z=innerz*(1-t)+outerz*t;inner_y=-.0762-.001*arch
                y=inner_y*(1-t)+face(x,z,-.0005)*t-.00035*math.sin(t*math.pi)*arch
                vs.append((x,y,z))
        b.replace_surface(lookup[idx],vs,grid(rows,cols),skin,lambda p:{'Head':1})
    # Actual small nostril openings sit on the nose surface, rather than floating triangles.
    nostrilmat=b.material('Identity | nostril shadow',(.030,.009,.004),.85)
    for side in [-1,1]:
        o=bpy.data.objects['Face | nostril inset '+str(side)];vs=[];cx=side*.015;cz=1.574
        for k in range(16):
            a=k*math.tau/16;x=cx+.004*math.cos(a);z=cz+.0016*math.sin(a)-side*.15*(x-cx)
            vs.append((x,face(x,z,.00045),z))
        b.replace_surface(o,vs,[tuple(range(16))],nostrilmat,lambda p:{'Head':1})
    for o in [lookup[51]]+[o for o in s.active_meshes('IDENTITY | facial hair') if o.name.startswith('Beard | grouped')]:
        bm=bmesh.new();bm.from_mesh(o.data)
        cut=[f for f in bm.faces if (lambda p: p.y<0 and (p.x/.027)**2+((p.z-1.546)/.0065)**2<1)(f.calc_center_median())]
        bmesh.ops.delete(bm,geom=cut,context='FACES');bm.to_mesh(o.data);bm.free()
    lip=b.material('Identity | natural lip',(.275,.115,.070),.6);vs=[]
    for j in range(6):
        t=j/5
        for k in range(21):
            u=k/20*2-1;x=u*.024;z=(1.549+.0005*math.cos(u*math.pi))*(1-t)+(1.541+.007*abs(u)**1.5)*t
            offset=(.002+.0015*math.sin(t*math.pi))*(1-u*u)*(1-.8*t)
            vs.append((x,face(x,z,offset),z))
    b.replace_surface(lookup[53],vs,grid(6,21),lip,lambda p:{'Head':1})
    vs=[]
    for k in range(21):
        u=k/20*2-1;x=u*.024;z=1.549+.0005*math.cos(u*math.pi)
        vs.extend([(x,face(x,z,.0026),z),(x,face(x,z,.0026),z-.0008)])
    b.replace_surface(lookup[54],vs,grid(21,2),nostrilmat,lambda p:{'Head':1})
    # Brown iris and small pupil, with the same subtle upward gaze in each eye.
    iris=b.material('Identity | dark hazel iris',(.072,.040,.014),.32)
    pupil=b.material('Identity | pupil',(.002,.0015,.001),.22)
    whites=b.material('Identity | warm sclera',(.34,.31,.26),.36)
    for idx in [63,64]:
        b.assign(lookup[idx],whites)
        for v in lookup[idx].data.vertices:v.co.y+=.002
    for idx,side in [(65,-1),(66,1)]:
        vs=[];n=32
        for r in [.0037,.00165,0]:
            for k in range(n):
                a=k*math.tau/n;vs.append((side*.0355+r*math.cos(a),-.0772-.0005*(1-r/.004),1.617+r*math.sin(a)))
        fs=b.ring_faces(3,n)[:-2];b.replace_surface(lookup[idx],vs,fs,iris,lambda p:{'Head':1});lookup[idx].data.materials.append(pupil)
        for p in lookup[idx].data.polygons:p.material_index=1 if p.index>=n else 0

def hair_curves(name,paths,mats,radius):
    data=bpy.data.curves.new(name,'CURVE');data.dimensions='3D';data.resolution_u=1;data.bevel_depth=radius;data.bevel_resolution=0;data.resolution_u=2
    for i,path in enumerate(paths):
        spline=data.splines.new('POLY');spline.points.add(len(path)-1)
        for j,(p,r) in enumerate(path):spline.points[j].co=(*p,1);spline.points[j].radius=r
        spline.material_index=i%len(mats)
    for mat in mats:data.materials.append(mat)
    o=bpy.data.objects.new(name,data);b.collection('IDENTITY | groomed hair curves').objects.link(o)
    rig=bpy.data.objects['MinerRig'];world=rig.matrix_world@rig.pose.bones['Head'].matrix@rig.data.bones['Head'].matrix_local.inverted()
    o.parent=rig;o.parent_type='BONE';o.parent_bone='Head';o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.Identity(4);bpy.context.view_layer.update()
    o.matrix_parent_inverse=o.matrix_world.inverted();o.matrix_basis=world
    o['production_note']='Editable Head-bound groom curves. Bake/convert selectively for game LOD; not included in base-mesh triangle totals.'
    return o

def groom(lookup,head_density=9,beard_count=1050,head_radius=.00048,beard_radius=.00036):
    rng=random.Random(1848)
    mats=[b.material('Identity | hair fiber '+str(i),col,.71) for i,col in enumerate([(.015,.009,.006),(.026,.015,.009),(.040,.026,.015),(.020,.013,.008),(.058,.043,.025)])]
    paths=[]
    for o in s.active_meshes('IDENTITY | hair and beard'):
        if not o.name.startswith('Hair | swept clump'):continue
        vs=o.data.vertices
        if len(vs)!=35:continue
        for h in range(head_density):
            offset=rng.uniform(-.8,.8);path=[]
            for j in range(7):
                center=vs[j*5+2].co.copy();edge=vs[j*5+(0 if offset<0 else 4)].co.copy();p=center.lerp(edge,abs(offset))
                radial=Vector((p.x,p.y-.01,0)).normalized();p+=radial*(.0006+rng.uniform(0,.0006))
                p.z+=rng.uniform(-.001,.001)+(.004*math.sin(h*1.7) if j==6 else 0)
                path.append((p,.15 if j==6 else .55+math.sin(j/6*math.pi)*.55))
            paths.append(path)
    hair_curves('Hair | swept strand groups',paths,mats,head_radius)
    # Sample the fitted beard shell by triangle area, keeping roots attached to the skin.
    beard=lookup[51];mesh=beard.data;mesh.calc_loop_triangles();tris=list(mesh.loop_triangles);weights=[];total=0
    for tri in tris:
        a,bb,cc=[mesh.vertices[i].co for i in tri.vertices];total+=(bb-a).cross(cc-a).length/2;weights.append(total)
    paths=[]
    for i in range(beard_count):
        tri=tris[bisect.bisect_left(weights,rng.random()*total)];a,bb,cc=[mesh.vertices[j].co for j in tri.vertices]
        u=math.sqrt(rng.random());v=rng.random();p=(1-u)*a+u*(1-v)*bb+u*v*cc
        normal=Vector((p.x,p.y-.002,0)).normalized();flow=Vector((.15*p.x,-.08,-1)).normalized()
        length=rng.uniform(.0025,.0065);root=p+normal*.0004
        mid=root+flow*length*.55+normal*.0008;tip=root+flow*length+normal*rng.uniform(.0006,.002)
        paths.append([(root,.75),(mid,.55),(tip,.05)])
    # Short moustache growth joins the beard instead of leaving two graphic wedges.
    for side in [-1,1]:
        for i in range(70):
            x=side*rng.uniform(.003,.032);z=1.563-.17*abs(x)+rng.uniform(-.003,.003)
            root=Vector((x,-.097+abs(x)*.30,z));tip=root+Vector((side*.003,-.001,-rng.uniform(.003,.006)))
            paths.append([(root,.65),(root.lerp(tip,.5)+Vector((0,-.0006,0)),.45),(tip,.04)])
    hair_curves('Beard | short scruffy growth',paths,mats,beard_radius)

def skin_material(lookup):
    mat=bpy.data.materials['Convergence | warm weathered skin'];mat.use_nodes=True;n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
    for socket in ['Base Color','Roughness','Normal']:
        for link in list(p.inputs[socket].links):l.remove(link)
    p.inputs['Roughness'].default_value=.60;p.inputs['Specular IOR Level'].default_value=.32;p.inputs['Subsurface Weight'].default_value=.07;p.inputs['Subsurface Radius'].default_value=(1,.45,.25);p.inputs['Subsurface Scale'].default_value=.008
    attr=n.new('ShaderNodeAttribute');attr.attribute_name='skin_color';l.new(attr.outputs['Color'],p.inputs['Base Color'])
    tex=n.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=240;tex.inputs['Detail'].default_value=2
    coord=n.new('ShaderNodeTexCoord');l.new(coord.outputs['Object'],tex.inputs['Vector'])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.16;bump.inputs['Distance'].default_value=.00017;l.new(tex.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
    for obj in bpy.context.scene.objects:
        if obj.type!='MESH' or obj.hide_render or mat not in list(obj.data.materials):continue
        layer=obj.data.color_attributes.get('skin_color') or obj.data.color_attributes.new(name='skin_color',type='FLOAT_COLOR',domain='POINT')
        for v in obj.data.vertices:
            x,y,z=v.co
            cheek=math.exp(-((abs(x)-.054)/.027)**2-((z-1.589)/.024)**2) if z>1.4 else .05
            nose=math.exp(-(x/.024)**2-((z-1.581)/.025)**2) if z>1.4 else 0
            tan=.025*max(0,-y/.12);red=min(1,cheek*.7+nose*.35)
            layer.data[v.index].color=(.32+red*.045-tan,.151+red*.008-tan*.6,.079-tan*.25,1)

def run():
    lookup=s.load_previous(14);features(lookup);groom(lookup);skin_material(lookup);s.finish(14)

if __name__=='__main__':run()
