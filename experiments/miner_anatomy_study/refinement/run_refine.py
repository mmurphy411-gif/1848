"""Refine the retained miner study; preserve the previous scene as the input."""
import bpy,math,random,sys,json
import numpy as np
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT.parent));import run as previous
b=previous.b

def clamp(x):return max(0,min(1,x))
def smooth(x):x=clamp(x);return x*x*(3-2*x)
def grid(rows,cols):return [(j*cols+k,j*cols+k+1,(j+1)*cols+k+1,(j+1)*cols+k) for j in range(rows-1) for k in range(cols-1)]
def image(name):
    im=bpy.data.images.load(str(OUT/name),check_existing=True);im.pack();return im
def skin(o,fn):
    o.vertex_groups.clear();names=set()
    for v in o.data.vertices:
        weights=fn(v.co)
        for name,w in weights.items():
            g=o.vertex_groups.get(name) or o.vertex_groups.new(name=name);g.add([v.index],w,'REPLACE')
def garment(p):
    if p.z<1.14:
        t=clamp((p.z-1.01)/.13);return {'Hips':1-t,'Spine':t}
    t=clamp((p.z-1.17)/.15);return {'Spine':1-t,'Chest':t}
def smooth_object(o,sub=0,thickness=0):
    for p in o.data.polygons:p.use_smooth=True
    if sub:
        m=o.modifiers.new('Soft sewn surface','SUBSURF');m.levels=sub
    if thickness:b.thickness(o,thickness)
    return o

def textile(role,atlas):
    mat=bpy.data.materials.new('REFINE | '+role);mat.use_nodes=True
    n=mat.node_tree.nodes;l=mat.node_tree.links;n.clear()
    out=n.new('ShaderNodeOutputMaterial');bs=n.new('ShaderNodeBsdfPrincipled');l.new(bs.outputs[0],out.inputs['Surface'])
    bs.inputs['Roughness'].default_value=.89 if role!='leather' else .67
    bs.inputs['Specular IOR Level'].default_value=.22
    if role!='leather':bs.inputs['Sheen Weight'].default_value=.12
    uv=n.new('ShaderNodeUVMap');uv.uv_map='REFINE material coordinates'
    mult=n.new('ShaderNodeVectorMath');mult.operation='SCALE';mult.inputs['Scale'].default_value={'linen':11,'scarf':10,'vest':9,'leather':6}[role];l.new(uv.outputs[0],mult.inputs[0])
    fract=n.new('ShaderNodeVectorMath');fract.operation='FRACTION';l.new(mult.outputs[0],fract.inputs[0])
    half=n.new('ShaderNodeVectorMath');half.operation='SCALE';half.inputs['Scale'].default_value=.496;l.new(fract.outputs[0],half.inputs[0])
    offset=n.new('ShaderNodeVectorMath');offset.operation='ADD';l.new(half.outputs[0],offset.inputs[0]);offset.inputs[1].default_value={'linen':(.002,.502,0),'scarf':(.502,.502,0),'vest':(.002,.002,0),'leather':(.502,.002,0)}[role]
    tex=n.new('ShaderNodeTexImage');tex.image=atlas;l.new(offset.outputs[0],tex.inputs['Vector'])
    tint=n.new('ShaderNodeMixRGB');tint.blend_type='MULTIPLY';tint.inputs[0].default_value=1;l.new(tex.outputs['Color'],tint.inputs[1]);tint.inputs[2].default_value={'linen':(.93,.88,.78,1),'scarf':(.52,.36,.32,1),'vest':(.35,.33,.31,1),'leather':(.62,.48,.34,1)}[role]
    attr=n.new('ShaderNodeAttribute');attr.attribute_name='REFINE wear'
    mix=n.new('ShaderNodeMixRGB');l.new(attr.outputs['Fac'],mix.inputs[0]);l.new(tint.outputs[0],mix.inputs[1]);mix.inputs[2].default_value={'linen':(.12,.078,.035,1),'scarf':(.055,.015,.009,1),'vest':(.018,.013,.008,1),'leather':(.025,.014,.006,1)}[role];l.new(mix.outputs[0],bs.inputs['Base Color'])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.16;bump.inputs['Distance'].default_value=.00011;l.new(tex.outputs['Color'],bump.inputs['Height']);l.new(bump.outputs[0],bs.inputs['Normal'])
    return mat

def material_uv(o,role):
    layer=o.data.uv_layers.get('REFINE material coordinates') or o.data.uv_layers.new(name='REFINE material coordinates')
    for poly in o.data.polygons:
        axis=0 if abs(poly.normal.y)>=abs(poly.normal.x) else 1
        if abs(poly.normal.z)>.8:axis=2
        for li in poly.loop_indices:
            p=o.data.vertices[o.data.loops[li].vertex_index].co
            layer.data[li].uv=(p.x,p.z) if axis==0 else (p.y,p.z) if axis==1 else (p.x,p.y)
    attr=o.data.color_attributes.get('REFINE wear') or o.data.color_attributes.new(name='REFINE wear',type='FLOAT_COLOR',domain='POINT')
    for v in o.data.vertices:
        x,y,z=v.co
        dirt=.035
        if role=='linen':dirt+=.23*math.exp(-((z-1.092)/.036)**2)+.12*math.exp(-((z-1.437)/.022)**2)
        elif role=='scarf':dirt+=.09*clamp((1.4-z)/.12)
        elif role=='leather':dirt+=.08
        attr.data[v.index].color=(dirt,dirt,dirt,1)

def make_hair():
    previous.hide(bpy.data.objects['STUDY | swept wavy hair'])
    mat=bpy.data.materials.new('REFINE | fine hair cards');mat.use_nodes=True
    n=mat.node_tree.nodes;l=mat.node_tree.links;bs=n.get('Principled BSDF')
    tex=n.new('ShaderNodeTexImage');tex.image=image('hair_atlas.png');tex.interpolation='Linear'
    tone=n.new('ShaderNodeMixRGB');tone.blend_type='MULTIPLY';tone.inputs[0].default_value=1;tone.inputs[2].default_value=(.62,.52,.44,1);l.new(tex.outputs['Color'],tone.inputs[1]);l.new(tone.outputs[0],bs.inputs['Base Color']);l.new(tex.outputs['Alpha'],bs.inputs['Alpha'])
    bs.inputs['Roughness'].default_value=.74;bs.inputs['Specular IOR Level'].default_value=.18
    mat.diffuse_color=(.045,.022,.010,1)
    rng=random.Random(1849);vs=[];fs=[];uvs=[];rows=21;cols=5
    for layer,count in [(0,32),(1,34),(2,28)]:
        for i in range(count):
            a=-.24+(math.pi+.48)*(i+.15*rng.random())/(count-1)
            endness=abs(a-math.pi/2)/(math.pi/2+.24)
            end=1.519+.064*endness**3+rng.uniform(-.007,.007)
            start=1.689-layer*.010+rng.uniform(-.002,.002)
            width=rng.uniform(.025,.033)*(1-.10*layer)
            phase=rng.random()*math.tau;off=len(vs);tile=(i+layer)%4
            for j in range(rows):
                t=j/(rows-1);ang=a+.075*math.sin(t*5+phase)*t+.08*t*math.copysign(1,math.cos(a))
                r=.087+layer*.0035+.005*math.sin(t*math.pi)+.0025*math.sin(t*8+phase)*t
                z=start*(1-t)+end*t+.003*math.sin(t*7+phase)*t
                for k in range(cols):
                    u=k/(cols-1)*2-1
                    bulb=.002*(1-u*u);xx=(r+bulb)*math.cos(ang)-u*width*.5*math.sin(ang);yy=.011+(r+.010*t+bulb)*math.sin(ang)+u*width*.5*math.cos(ang)
                    vs.append((xx,yy,z+.002*u*math.sin(t*4+phase)));uvs.append(((tile+(u+1)*.5)/4,1-t))
            fs.extend(tuple(off+x for x in f) for f in grid(rows,cols))
    hair=b.mesh('REFINE | layered fine hair cards',vs,fs,mat,'REFINE | hair','Head');uv=hair.data.uv_layers.new(name='Hair atlas')
    for poly in hair.data.polygons:
        for li in poly.loop_indices:uv.data[li].uv=uvs[hair.data.loops[li].vertex_index]
    smooth_object(hair)
    # A close undercoat prevents scalp gaps through several transparent card layers.
    under=mat;vs=[];fs=[];rows=14;cols=65
    for j in range(rows):
        t=j/(rows-1)
        for k in range(cols):
            a=-.12+(math.pi+.24)*k/(cols-1);endness=abs(a-math.pi/2)/(math.pi/2+.12)
            r=.084+.004*math.sin(t*math.pi);end=1.533+.055*endness**3
            vs.append((r*math.cos(a),.010+(r+.006*t)*math.sin(a),1.687*(1-t)+end*t))
    cap=b.mesh('REFINE | close hair undercoat',vs,grid(rows,cols),under,'REFINE | hair','Head');smooth_object(cap)
    uv=cap.data.uv_layers.new(name='Hair atlas')
    for p in cap.data.polygons:
        for li in p.loop_indices:
            idx=cap.data.loops[li].vertex_index;j,k=divmod(idx,cols);uv.data[li].uv=(k/(cols-1)*3,1-j/(rows-1))

def face_transition():
    head=bpy.data.objects['STUDY | anatomical head and neck'];layer=head.data.color_attributes['profile_blend']
    for v in head.data.vertices:
        x,y,z=v.co
        if z>1.609:
            w=smooth((abs(x)-.043)/.022)*smooth((z-1.609)/.022)
            old=layer.data[v.index].color[0];w=max(old,w);layer.data[v.index].color=(w,w,w,1)

def scarf(mat,linen):
    from mathutils.bvhtree import BVHTree
    shirt=next(o for o in bpy.context.scene.objects if o.get('source_component')==35)
    shirt_tree=BVHTree.FromPolygons([v.co.copy() for v in shirt.data.vertices],[tuple(p.vertices) for p in shirt.data.polygons])
    for o in list(bpy.context.scene.objects):
        if not o.hide_render and (o.name.startswith('Neckerchief |') or o.get('source_component') in [48,49]):previous.hide(o)
    vs=[];rows=17;n=96
    for j in range(rows):
        t=j/(rows-1)
        for k in range(n):
            a=k*math.tau/n;front=max(0,-math.sin(a));fold=.0055*math.sin(t*math.pi*6+.8*math.sin(a))
            rx=.061+.016*t+fold;ry=.050+.029*t+.054*t*front**3+fold
            z=1.485-.051*t-.034*front*t-.004*front+.003*math.cos(a*2+.2)+.003*math.sin(t*math.pi*4+a)
            vs.append((rx*math.cos(a),.010+ry*math.sin(a),z))
    o=b.mesh('REFINE | gathered neckerchief wrap',vs,b.ring_faces(rows,n)[:-2],mat,'REFINE | scarf','Neck');skin(o,lambda p:{'Neck':smooth((p.z-1.439)/.042),'Chest':1-smooth((p.z-1.439)/.042)});smooth_object(o,1,.001);material_uv(o,'scarf')
    for s in [-1,1]:
        vs=[];rows=27;cols=11
        for j in range(rows):
            t=j/(rows-1);cx=.009+s*(.006+.027*t);cy=-.158-.015*math.sin(t*math.pi*.71);zz=1.421-t*(.144 if s==1 else .101)
            for k in range(cols):
                u=k/(cols-1)*2-1;w=(.007+(.017 if s==1 else .010)*math.sin(t*math.pi*.7))*(1-.48*t**5)
                vs.append((cx+u*w,cy-.0035*math.sin(u*math.pi*2+t*1.8)*math.sin(t*math.pi),zz+.011*u*t+.009*t**8*(u*u)))
        for idx,p in enumerate(vs):
            t=(idx//cols)/(rows-1);hit,normal,face,distance=shirt_tree.ray_cast(Vector((p[0],-.4,p[2])),Vector((0,1,0)),.5)
            if hit is not None:
                mix=smooth((t-.12)/.40);rest_y=hit.y-.009-.002*math.sin(t*math.pi)
                vs[idx]=(p[0],p[1]*(1-mix)+rest_y*mix,p[2])
        o=b.mesh('REFINE | folded scarf tail '+str(s),vs,grid(rows,cols),mat,'REFINE | scarf','Chest');skin(o,garment);smooth_object(o,1,.001);material_uv(o,'scarf')
    vs=[];rows=13;n=32
    for j in range(rows):
        t=j/(rows-1);w=.011+.007*math.sin(t*math.pi)
        for k in range(n):
            a=k*math.tau/n;vs.append((.008+w*math.cos(a)+.007*(t-.5),-.147+(.012+.003*math.sin(t*math.pi*3+a))*math.sin(a),1.400+t*.039))
    o=b.mesh('REFINE | folded scarf knot',vs,b.ring_faces(rows,n),mat,'REFINE | scarf','Chest');smooth_object(o,1);material_uv(o,'scarf')
    for s in [-1,1]:
        corners=[Vector((s*.042,-.061,1.452)),Vector((s*.089,-.031,1.442)),Vector((s*.063,-.151,1.387)),Vector((s*.105,-.119,1.375))];vs=[];rows=13;cols=9
        for j in range(rows):
            t=j/(rows-1)
            for k in range(cols):
                u=k/(cols-1);p=corners[0].lerp(corners[1],u).lerp(corners[2].lerp(corners[3],u),t);p.y-=.006*math.sin(t*math.pi)*math.sin(u*math.pi);p.z+=.003*math.sin(u*math.pi*2)*t
                vs.append(p)
        o=b.mesh('REFINE | soft turned shirt collar '+str(s),vs,grid(rows,cols),linen,'REFINE | shirt','Chest');skin(o,garment);smooth_object(o,1,.0012);material_uv(o,'linen')

def sleeves(mat):
    data=json.loads((OUT/'sleeve_drape.json').read_text())
    for s in [-1,1]:
        side='Left' if s==1 else 'Right';d=data['sleeves'][str(s)]
        start=Vector((s*.205,0,1.419));end=Vector((s*.347,0,1.099));axis=(end-start).normalized();cross=Vector((s,0,0));cross=(cross-axis*cross.dot(axis)).normalized();depth=Vector((0,1,0))
        rows=data['rows'];n=data['sides'];delta=[]
        for j in range(rows):
            t=j/(rows-1);center=start.lerp(end,t);radius=.065+.018*math.sin(t*math.pi)-.007*t
            for k in range(n):
                a=k*math.tau/n;radial=radius+.0013*math.sin(a*7+t*9+s)*math.sin(t*math.pi)
                init=center+(cross*math.cos(a)+depth*math.sin(a))*radial
                delta.append(Vector(d['vertices'][j*n+k])-init)
        # Keep the fitted garment's volume. Transfer wrinkles without the test tube's bulk shrinkage.
        for j in range(rows):
            avg=sum(delta[j*n:(j+1)*n],Vector())/n
            radial_mean=sum((delta[j*n+k]-avg).dot(cross*math.cos(k*math.tau/n)+depth*math.sin(k*math.tau/n)) for k in range(n))/n
            for k in range(n):
                direction=cross*math.cos(k*math.tau/n)+depth*math.sin(k*math.tau/n)
                delta[j*n+k]-=avg*.75+direction*radial_mean*.85
        original=next(o for o in bpy.context.scene.objects if o.get('source_component')==(36 if s==1 else 37))
        o=original.copy();o.data=original.data.copy();b.collection('REFINE | shirt').objects.link(o);o.name='REFINE | fitted drape sleeve '+side
        if 'source_component' in o:del o['source_component']
        previous.hide(original)
        for v in o.data.vertices:
            p=v.co;relative=p-start;t=clamp(relative.dot(axis)/(end-start).length);center=start.lerp(end,t);radial=p-center
            a=math.atan2(radial.dot(depth),radial.dot(cross))%math.tau;rr=t*(rows-1);kk=a/math.tau*n;j=min(rows-2,int(rr));k=int(kk)%n;u=rr-j;w=kk-int(kk)
            dd=delta[j*n+k].lerp(delta[j*n+(k+1)%n],w).lerp(delta[(j+1)*n+k].lerp(delta[(j+1)*n+(k+1)%n],w),u)
            strength=smooth((t-.16)/.18)*smooth((.95-t)/.14)
            v.co+=dd*strength*.80
        o.data.update();smooth_object(o,1);b.assign(o,mat);material_uv(o,'linen');o['construction']='64-frame physical drape displacement transferred to fitted sleeve; shoulder and cuff joins preserved'
    for o in list(bpy.context.scene.objects):
        if o.name.startswith('Shirt | sleeve seam'):previous.hide(o)

def felt_hat():
    mat=b.material('REFINE | worn brown felt',(.075,.038,.016),.94)
    n=mat.node_tree.nodes;l=mat.node_tree.links;bs=n.get('Principled BSDF');bs.inputs['Specular IOR Level'].default_value=.16;bs.inputs['Sheen Weight'].default_value=.18
    coord=n.new('ShaderNodeAttribute');coord.attribute_name='REFINE hat coordinates'
    noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=45;noise.inputs['Detail'].default_value=3;l.new(coord.outputs['Vector'],noise.inputs['Vector'])
    ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[0].color=(.031,.015,.007,1);ramp.color_ramp.elements[1].position=.85;ramp.color_ramp.elements[1].color=(.100,.060,.027,1);l.new(noise.outputs['Fac'],ramp.inputs[0])
    age=n.new('ShaderNodeAttribute');age.attribute_name='REFINE felt edge'
    mix=n.new('ShaderNodeMixRGB');l.new(age.outputs['Fac'],mix.inputs[0]);l.new(ramp.outputs[0],mix.inputs[1]);mix.inputs[2].default_value=(.16,.098,.042,1);l.new(mix.outputs[0],bs.inputs['Base Color'])
    fine=n.new('ShaderNodeTexNoise');fine.inputs['Scale'].default_value=1100;fine.inputs['Detail'].default_value=2;l.new(coord.outputs['Vector'],fine.inputs['Vector'])
    bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.24;bump.inputs['Distance'].default_value=.00025;l.new(fine.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs[0],bs.inputs['Normal'])
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or o.hide_render or o.name not in ['Hat | asymmetric slouch brim and dented crown','Hat | battered bound brim']:continue
        b.assign(o,mat);coords=o.data.attributes.new(name='REFINE hat coordinates',type='FLOAT_VECTOR',domain='POINT');age=o.data.color_attributes.new(name='REFINE felt edge',type='FLOAT_COLOR',domain='POINT')
        for v in o.data.vertices:
            p=v.co;coords.data[v.index].vector=p;r=math.sqrt((p.x/.204)**2+(p.y/.192)**2);w=.5*smooth((r-.74)/.25)*(.7+.3*math.sin(math.atan2(p.y,p.x)*11))
            age.data[v.index].color=(w,w,w,1)

def apply_materials(mats):
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or o.hide_render:continue
        role=None;groups=[c.name for c in o.users_collection];idx=o.get('source_component',-1)
        if 'COSTUME | shirt' in groups and idx not in [44,45,46,47] and 'seam' not in o.name:role='linen'
        elif o.name.startswith('Vest | continuous') or o.name.startswith('Vest | rear waist'):role='vest'
        elif any(g in groups for g in ['GEAR | satchel','COSTUME | belt and suspenders']) and not any(s in o.name for s in ['buckle','frame','adjust','stitch']):role='leather'
        elif o.name.startswith('Hat | leather crown band'):role='leather'
        if role:b.assign(o,mats[role]);material_uv(o,role)

def setup():
    scene=bpy.context.scene;scene.cycles.samples=48;scene.cycles.transparent_max_bounces=16
    cam=bpy.data.cameras.new('Study torso');cam.type='ORTHO';cam.ortho_scale=.79
    o=bpy.data.objects.new('Study torso',cam);b.collection('STUDY | cameras').objects.link(o);o.location=(2.1,-5,1.87);o.rotation_euler=(Vector((0,0,1.30))-o.location).to_track_quat('-Z','Y').to_euler()
    previous.OUT=OUT

def main():
    bpy.ops.wm.open_mainfile(filepath=str(OUT.parent/'miner_anatomy_candidate.blend'));setup()
    if '--baseline' in sys.argv:previous.render('prior',['face_quarter','torso','full','back']);return
    atlas=image('fabric_atlas.png');mats={r:textile(r,atlas) for r in ['linen','scarf','vest','leather']}
    make_hair();face_transition();scarf(mats['scarf'],mats['linen']);apply_materials(mats)
    if (OUT/'sleeve_drape.json').exists():sleeves(mats['linen'])
    felt_hat()
    bpy.context.scene.camera=bpy.data.objects['Study torso'];bpy.context.scene.render.resolution_x=900;bpy.context.scene.render.resolution_y=1100
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'miner_refined.blend'))
    previous.render('refined',['face_quarter','torso','full','back'])

if __name__=='__main__':main()
