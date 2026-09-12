"""A human anatomical base fitted to the existing miner. Non-destructive study."""
import bpy,sys,json,math,random,hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix

OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[1]
sys.path.insert(0,str(ROOT/'blender'))
_original_argv=sys.argv[:]
sys.argv=['miner_study','--','-100']
import miner_convergence as b
sys.argv=_original_argv

def source_mesh():
    verts=[];uv=[];faces=[];groups={};group=''
    for line in (OUT/'source/base.obj').read_text().splitlines():
        s=line.split()
        if not s:continue
        if s[0]=='v':verts.append(list(map(float,s[1:])))
        elif s[0]=='vt':uv.append(list(map(float,s[1:3])))
        elif s[0]=='g':group=s[1]
        elif s[0]=='f':
            f=[tuple(int(i)-1 for i in t.split('/')[:2]) for t in s[1:]]
            groups.setdefault(group,[]).append(f)
    a=np.array(verts)
    for name,w in [('caucasian-male-young',.78),('caucasian-male-old',.22),('head-rectangular',.18)]:
        for line in (OUT/('source/'+name+'.target')).read_text().splitlines():
            if not line or line.startswith('#'):continue
            s=line.split();a[int(s[0])]+=np.array(list(map(float,s[1:])))*w
    return a,uv,groups

def fit(v):
    x,y,z=v
    p=Vector((x*.102,-z*.100+.057,(y-8.1366)*.092+1.615))
    # Blend the cut neck into the existing scarf opening, eliminating shoulder remnants.
    t=max(0,min(1,(1.514-p.z)/.009))
    neck_width=float(np.interp(p.z,[1.43,1.47,1.51],[.052,.049,.057]))
    rr=math.sqrt((p.x/neck_width)**2+((p.y-.013)/.044)**2)
    if rr>1:
        p.x*=1-t+t/rr;p.y=.013+(p.y-.013)*(1-t+t/rr)
    # The crown sits low. Ease the forehead under its front band.
    t=max(0,min(1,(p.z-1.651)/.021))
    if p.y<-.060:p.y+=t*.023
    return p

def hide(o):
    for prop in ['hide_render','hide_viewport']:
        try:o.driver_remove(prop)
        except:pass
    o.hide_render=True;o.hide_set(True)

def build_head():
    a,uv,groups=source_mesh()
    fs=[f for f in groups['body'] if min(a[v,1] for v,t in f)>6.15]
    ids=sorted({v for f in fs for v,t in f});lookup={v:i for i,v in enumerate(ids)}
    skin=b.material('STUDY | weathered face',(.37,.20,.125),.58)
    o=b.mesh('STUDY | anatomical head and neck',[fit(a[i]) for i in ids],[[lookup[v] for v,t in f] for f in fs],skin,'STUDY | head','Head')
    # Preserve the anatomical base's seam layout for subsequent production baking.
    layer=o.data.uv_layers.new(name='MakeHuman UV')
    for poly,src in zip(o.data.polygons,fs):
        for li,(v,t) in zip(poly.loop_indices,src):layer.data[li].uv=uv[t]
    o['source_license']='MakeHuman core graphical asset, CC0 1.0'
    o['source_commit']='a8bc2d54ff0ac92e78ff71431b1023eda42bf482'
    o['source_vertex_ids']=ids
    neck=o.vertex_groups.new(name='Neck');hv=o.vertex_groups['Head']
    for v in o.data.vertices:
        w=max(0,min(1,(v.co.z-1.465)/.065))
        hv.add([v.index],w,'REPLACE');neck.add([v.index],1-w,'REPLACE')
    sub=o.modifiers.new('Anatomical surface subdivision','SUBSURF');sub.levels=2
    bpy.context.view_layer.objects.active=o
    bpy.ops.object.modifier_move_up(modifier=sub.name)
    for p in o.data.polygons:p.use_smooth=True
    for old in list(bpy.context.scene.objects):
        if old==o:continue
        if any(c.name in ['BODY | head and face','IDENTITY | facial hair','IDENTITY | groomed hair curves'] for c in old.users_collection):hide(old)
    # Eye spheres sit within the eyelid topology of the source, at its landmark centers.
    sclera=b.material('STUDY | ivory sclera',(.49,.44,.37),.32)
    iris=b.material('STUDY | hazel iris',(.075,.047,.021),.3)
    pupil=b.material('STUDY | pupil',(.002,.0015,.001),.23)
    for side in ['l','r']:
        ii=sorted({v for f in groups['joint-'+side+'-eye'] for v,t in f})
        center=fit(a[ii].mean(0));r=.0115
        bpy.ops.mesh.primitive_uv_sphere_add(segments=40,ring_count=24,radius=r,location=center)
        eye=bpy.context.object;eye.name='STUDY | '+side+' eye';b.move(eye,'STUDY | head');b.assign(eye,sclera)
        bpy.ops.object.transform_apply(location=True,rotation=True,scale=True);b.bind(eye,'Head')
        for p in eye.data.polygons:p.use_smooth=True
        vs=[];fs=[];n=48
        for rad in [0,.0018,.0046,.0051]:
            for k in range(n):
                ang=k*math.tau/n
                vs.append((center.x+rad*math.cos(ang),center.y-math.sqrt(r*r-rad*rad)-.00008,center.z+rad*math.sin(ang)))
        fs=b.ring_faces(4,n)[:-2]
        disc=b.mesh('STUDY | '+side+' iris',vs,fs,iris,'STUDY | head','Head');disc.data.materials.append(pupil)
        for p in disc.data.polygons:p.material_index=1 if p.index<n or p.index>=2*n else 0
    return o

def setup():
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=40;scene.cycles.use_denoising=True
    try:
        p=bpy.context.preferences.addons['cycles'].preferences;p.compute_device_type='OPTIX';p.get_devices()
        for d in p.devices:d.use=d.type!='CPU'
        scene.cycles.device='GPU'
    except:pass
    scene.view_settings.view_transform='AgX'
    scene.render.image_settings.file_format='PNG';scene.render.film_transparent=False
    for name,loc,target,scale in [
        ('face_front',(0,-4,1.63),(0,-.005,1.606),.41),
        ('face_quarter',(2.5,-4,1.67),(0,0,1.605),.41),
        ('face_side',(4,-.3,1.63),(0,0,1.605),.41),
        ('full',(3.5,-6,2.2),(0,0,.92),2.12),
        ('back',(3.5,6,2.2),(0,0,.92),2.12)]:
        data=bpy.data.cameras.new('Study '+name);data.type='ORTHO';data.ortho_scale=scale
        cam=bpy.data.objects.new('Study '+name,data);b.collection('STUDY | cameras').objects.link(cam)
        cam.location=loc;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler()

def face_uv(x,z):
    # Measured feature rows of the generated frontal projection source (1254 square).
    zz=[1.425,1.485,1.506,1.531,1.554,1.574,1.615,1.635,1.665,1.705]
    yy=[1254,1090,974,870,753,646,490,435,280,118]
    sy=float(np.interp(z,zz,yy))
    sx=float(np.interp(z,[1.49,1.53,1.555,1.575,1.615,1.66],[3500,3650,3650,3700,4200,3550]))
    return ((627+x*sx)/1254,1-sy/1254)

def texture_head(o):
    mat=o.data.materials[0];nodes=mat.node_tree.nodes;links=mat.node_tree.links;bs=nodes.get('Principled BSDF')
    img=bpy.data.images.load(str(OUT/'face_projection_source.png'));img.pack()
    layer=o.data.uv_layers.new(name='Frontal identity projection')
    for poly in o.data.polygons:
        for li in poly.loop_indices:
            v=o.data.vertices[o.data.loops[li].vertex_index];layer.data[li].uv=face_uv(v.co.x,v.co.z)
    tex=nodes.new('ShaderNodeTexImage');tex.image=img;tex.extension='EXTEND'
    uv=nodes.new('ShaderNodeUVMap');uv.uv_map=layer.name;links.new(uv.outputs['UV'],tex.inputs['Vector'])
    side_layer=o.data.uv_layers.new(name='Profile identity projection')
    for poly in o.data.polygons:
        for li in poly.loop_indices:
            x,y,z=o.data.vertices[o.data.loops[li].vertex_index].co
            py=float(np.interp(z,[1.425,1.45,1.485,1.507,1.531,1.554,1.574,1.615,1.635,1.67,1.705],[1254,1170,1040,935,840,735,621,474,423,240,95]))
            side_layer.data[li].uv=((690+y*4450)/1254,1-py/1254)
    simg=bpy.data.images.load(str(OUT/'side_projection_source.png'));simg.pack()
    stex=nodes.new('ShaderNodeTexImage');stex.image=simg;stex.extension='EXTEND'
    suv=nodes.new('ShaderNodeUVMap');suv.uv_map=side_layer.name;links.new(suv.outputs['UV'],stex.inputs['Vector'])
    side_factor=o.data.color_attributes.new(name='profile_blend',type='FLOAT_COLOR',domain='POINT')
    attr=o.data.color_attributes.new(name='identity_blend',type='FLOAT_COLOR',domain='POINT')
    base=o.data.color_attributes.new(name='head_base_color',type='FLOAT_COLOR',domain='POINT')
    for v in o.data.vertices:
        x,y,z=v.co
        # Side and rear faces keep a continuous base color, without repeated facial features.
        w=max(0,min(1,(.072-y)/.035))
        attr.data[v.index].color=(w,w,w,1)
        angle=math.atan2(abs(x),max(.002,-y+.015));side=max(0,min(1,(angle-.48)/.55));side=side*side*(3-2*side)
        side_factor.data[v.index].color=(side,side,side,1)
        beard=max(0,min(1,(1.578+.26*abs(x)-z)/.011))*max(0,min(1,(z-1.488)/.02))*max(0,min(1,(-y+.008)/.03))
        base.data[v.index].color=tuple((.37,.19,.111)[i]*(1-beard*.79) for i in range(3))+(1,)
    aa=nodes.new('ShaderNodeAttribute');aa.attribute_name=attr.name
    ab=nodes.new('ShaderNodeAttribute');ab.attribute_name=base.name
    af=nodes.new('ShaderNodeAttribute');af.attribute_name=side_factor.name
    face_mix=nodes.new('ShaderNodeMixRGB');links.new(af.outputs['Fac'],face_mix.inputs[0]);links.new(tex.outputs['Color'],face_mix.inputs[1]);links.new(stex.outputs['Color'],face_mix.inputs[2])
    mix=nodes.new('ShaderNodeMixRGB');links.new(aa.outputs['Fac'],mix.inputs[0]);links.new(ab.outputs['Color'],mix.inputs[1]);links.new(face_mix.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],bs.inputs['Base Color'])
    bs.inputs['Roughness'].default_value=.64;bs.inputs['Specular IOR Level'].default_value=.22
    bs.inputs['Subsurface Weight'].default_value=.04;bs.inputs['Subsurface Scale'].default_value=.008
    noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=360;noise.inputs['Detail'].default_value=2
    coords=nodes.new('ShaderNodeTexCoord');links.new(coords.outputs['Object'],noise.inputs['Vector'])
    bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.15;bump.inputs['Distance'].default_value=.00013;links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],bs.inputs['Normal'])

def hair_groom():
    rng=random.Random(1848)
    mats=[b.material('STUDY | hair '+str(i),color,.64) for i,color in enumerate([(.019,.010,.005),(.033,.020,.011),(.052,.034,.020),(.023,.014,.008)])]
    for o in list(bpy.context.scene.objects):
        if any(c.name=='IDENTITY | hair and beard' for c in o.users_collection):hide(o)
    # Each swept lock is a group of slender tapered strands with broken curled ends.
    vs=[];fs=[];mi=[];sides=5
    for lock in range(54):
        a=-.32+(math.pi+.64)*lock/53
        endness=abs(lock/53*2-1)
        bottom=1.505+.061*endness**3+rng.uniform(-.012,.010)
        lock_phase=rng.uniform(0,math.tau)
        for fiber in range(16):
            aa=a+rng.uniform(-.028,.028);phase=lock_phase+rng.uniform(-.14,.14)
            radius=rng.uniform(.0006,.00115);offset=len(vs)
            centers=[]
            for j in range(21):
                t=j/20
                ang=aa+.12*math.sin(t*8+phase)*math.sin(t*math.pi/2)+.19*t*math.copysign(1,math.cos(aa))
                curl=.009*math.sin(t*11+phase)*math.sin(t*math.pi/2)
                rx=.087+.009*math.sin(t*math.pi)+curl+rng.uniform(-.0004,.0004)
                ry=.080+.025*t+curl
                x=rx*math.cos(ang);y=.012+ry*math.sin(ang)
                z=1.690*(1-t)+bottom*t+.007*math.sin(t*11+phase)*t
                centers.append(Vector((x,y,z)))
            for j,p in enumerate(centers):
                tangent=(centers[min(20,j+1)]-centers[max(0,j-1)]).normalized()
                n=tangent.cross(Vector((0,1,0))).normalized();bb=tangent.cross(n).normalized()
                taper=(.70+.4*math.sin(j/20*math.pi))*max(.03,min(1,(20-j)/4))
                for k in range(sides):
                    ang=k*math.tau/sides;vs.append(p+radius*taper*(n*math.cos(ang)+bb*math.sin(ang)))
                if j:
                    for k in range(sides):fs.append((offset+(j-1)*sides+k,offset+(j-1)*sides+(k+1)%sides,offset+j*sides+(k+1)%sides,offset+j*sides+k));mi.append((fiber+lock)%len(mats))
    o=b.mesh('STUDY | swept wavy hair',vs,fs,mats[0],'STUDY | hair','Head')
    for m in mats[1:]:o.data.materials.append(m)
    for p,idx in zip(o.data.polygons,mi):p.use_smooth=True;p.material_index=idx

def beard_groom(head):
    rng=random.Random(9418);head.data.calc_loop_triangles()
    triangles=[];weights=[];total=0
    for tri in head.data.loop_triangles:
        pts=[head.data.vertices[i].co for i in tri.vertices];p=sum(pts,Vector())/3
        if p.y>-.018 or p.z<1.493 or p.z>1.573+.22*abs(p.x):continue
        if abs(p.x)<.029 and abs(p.z-1.554)<.006:continue
        area=(pts[1]-pts[0]).cross(pts[2]-pts[0]).length/2
        if not area:continue
        total+=area;weights.append(total);triangles.append(tri)
    mats=[b.material('STUDY | beard dark',(.025,.014,.008),.77),b.material('STUDY | beard warm',(.055,.035,.020),.78),b.material('STUDY | beard grey',(.17,.15,.12),.82)]
    vs=[];fs=[];mis=[]
    import bisect
    for i in range(3000):
        tri=triangles[bisect.bisect_left(weights,rng.random()*total)]
        vv=[head.data.vertices[j] for j in tri.vertices];u=math.sqrt(rng.random());v=rng.random()
        coeff=[1-u,u*(1-v),u*v];p=sum((vv[k].co*coeff[k] for k in range(3)),Vector());normal=sum((vv[k].normal*coeff[k] for k in range(3)),Vector()).normalized()
        length=rng.uniform(.0009,.0028);direction=Vector((p.x*.7,-.1,-1)).normalized()
        root=p+normal*.0007;tip=root+direction*length+normal*.0004
        tangent=direction.cross(normal).normalized()*rng.uniform(.00008,.00016)
        start=len(vs);vs.extend([root-tangent,root+tangent,tip]);fs.append((start,start+1,start+2));mis.append(2 if rng.random()<.075 else i%2)
    o=b.mesh('STUDY | short irregular beard growth',vs,fs,mats[0],'STUDY | hair','Head')
    for m in mats[1:]:o.data.materials.append(m)
    for p,i in zip(o.data.polygons,mis):p.material_index=i


def render(prefix,views):
    scene=bpy.context.scene
    for view in views:
        scene.camera=bpy.data.objects['Study '+view]
        scene.render.resolution_x=900 if view.startswith('face') else 800
        scene.render.resolution_y=900 if view.startswith('face') else 1100
        scene.render.resolution_percentage=100
        scene.render.filepath=str(OUT/(prefix+'_'+view+'.png'))
        bpy.ops.render.render(write_still=True)

def main():
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/miner_convergence_working.blend'))
    setup()
    if '--baseline' in sys.argv:render('baseline',['face_front','face_quarter','face_side','full']);return
    head=build_head()
    if '--textured' in sys.argv:
        texture_head(head);hair_groom();beard_groom(head)
    bpy.context.scene.camera=bpy.data.objects['Study face_quarter']
    bpy.context.scene.render.resolution_x=900;bpy.context.scene.render.resolution_y=900
    bpy.context.scene.render.resolution_percentage=100
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'miner_anatomy_candidate.blend'))
    render('textured' if '--textured' in sys.argv else 'anatomy',['face_front','face_quarter','face_side','full'])

if __name__=='__main__':main()
