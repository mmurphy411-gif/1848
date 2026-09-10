"""1848 working miner: lofted anatomy, four procedural cloth swatches and IK rig.
Blender coordinates: Z up, -Y forward. All authored dimensions are meters.
"""
import sys, math
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
from mathutils import Matrix
reset()
OUT=ASSETS/'miner'; OUT.mkdir(parents=True,exist_ok=True)

def bake_body():
    scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=1
    scene.render.bake.margin=4; scene.view_settings.view_transform='Standard'
    try:
        prefs=bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type='OPTIX'; prefs.get_devices()
        for d in prefs.devices: d.use=d.type!='CPU'
        scene.cycles.device='GPU'
    except Exception: pass
    low=[]; high=[]; materials=[]
    palette=[('Linen',(.54,.46,.33)),('Wool',(.105,.12,.115)),('Leather',(.11,.052,.023)),('Skin',(.42,.245,.14))]
    for i,(name,color) in enumerate(palette):
        m=material(name,color); materials.append(m); n=m.node_tree.nodes; l=m.node_tree.links; p=n.get('Principled BSDF')
        tex=n.new('ShaderNodeTexNoise'); tex.inputs['Scale'].default_value=110 if i<2 else 38; tex.inputs['Detail'].default_value=2
        broad=n.new('ShaderNodeTexNoise'); broad.inputs['Scale'].default_value=3
        mix=n.new('ShaderNodeMixRGB'); mix.blend_type='MULTIPLY'; mix.inputs[0].default_value=.38
        mix.inputs[1].default_value=(*color,1); l.new(tex.outputs['Fac'],mix.inputs[2])
        sweat=n.new('ShaderNodeMixRGB'); sweat.blend_type='MULTIPLY'; sweat.inputs[0].default_value=.32
        l.new(mix.outputs[0],sweat.inputs[1]); l.new(broad.outputs['Fac'],sweat.inputs[2]); l.new(sweat.outputs[0],p.inputs['Base Color'])
        emitter=n.new('ShaderNodeEmission'); l.new(sweat.outputs[0],emitter.inputs[0]); l.new(emitter.outputs[0],n.get('Material Output').inputs[0])
        x=i%2; y=i//2
        obj=mesh_object('Swatch low '+name,[(x,y,0),(x+1,y,0),(x+1,y+1,0),(x,y+1,0)],[(0,1,2,3)],uvs=[(x*.5,y*.5),((x+1)*.5,y*.5),((x+1)*.5,(y+1)*.5),(x*.5,(y+1)*.5)],materials=[m]); low.append(obj)
        v=[]; f=[]; steps=128
        for row in range(steps+1):
            for col in range(steps+1):
                u=col/steps; w=row/steps
                fold=(math.sin(w*35+math.sin(u*9)*2)*.007+math.sin(w*79-u*17)*.002)*(.9 if i<2 else .08)
                v.append((x+u,y+w,fold))
        for row in range(steps):
            for col in range(steps):
                a=row*(steps+1)+col; f.append((a,a+1,a+steps+2,a+steps+1))
        h=mesh_object('High resolution folded '+name,v,f,materials=[m]); high.append(h); h.hide_render=True
    bpy.ops.object.select_all(action='DESELECT')
    for o in low:o.select_set(True)
    bpy.context.view_layer.objects.active=low[0]; bpy.ops.object.join(); low_obj=bpy.context.object
    images={}
    for suffix in ['albedo','normal']:
        im=bpy.data.images.new('Body '+suffix,1024,1024,alpha=False); im.colorspace_settings.name='sRGB' if suffix=='albedo' else 'Non-Color'; images[suffix]=im
        for m in materials:
            n=m.node_tree.nodes; target=n.new('ShaderNodeTexImage'); target.image=im; n.active=target
        bpy.ops.object.select_all(action='DESELECT'); low_obj.select_set(True); bpy.context.view_layer.objects.active=low_obj
        if suffix=='normal':
            for h in high: h.hide_render=False; h.select_set(True)
            bpy.ops.object.bake(type='NORMAL',use_selected_to_active=True,cage_extrusion=.04,max_ray_distance=.08)
        else:bpy.ops.object.bake(type='EMIT')
        im.filepath_raw=str(OUT/('body_'+suffix+'.png')); im.file_format='PNG'; im.save()
    collection=bpy.data.collections.new('Inspectable high resolution cloth bake');scene.collection.children.link(collection)
    for o in [low_obj]+high:
        for c in list(o.users_collection):c.objects.unlink(o)
        collection.objects.link(o)
    collection.hide_render=True;collection.hide_viewport=True
    for m in materials:
        n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF');l.new(p.outputs[0],n.get('Material Output').inputs[0])
        for suffix in images:
            node=n.new('ShaderNodeTexImage');node.image=images[suffix]
            if suffix=='albedo':l.new(node.outputs['Color'],p.inputs['Base Color'])
            else:
                normal=n.new('ShaderNodeNormalMap');l.new(node.outputs[0],normal.inputs['Color']);l.new(normal.outputs[0],p.inputs['Normal'])
    return materials

materials=bake_body()
materials += [material('Felt',(.12,.09,.056)),material('Beard',(.085,.045,.018)),material('Suspenders',(.15,.10,.054)),material('Buckle',(.25,.22,.16))]
materials += [material('Ivory',(.54,.49,.40))]
# Bake a strand-height field to the beard's own UVs. Its shaped mesh supplies
# the jaw silhouette; these fine strands only describe the hair surface.
import numpy as np
from png_helpers import png
yy,xx=np.mgrid[:512,:512]/512
strand=np.sin((xx+.013*np.sin(yy*15+xx*7))*math.tau*110)
strand+=.45*np.sin(xx*math.tau*193+yy*8)+.25*np.sin(xx*math.tau*47-yy*11)
hair_height=strand*.0012
dx=(np.roll(hair_height,-1,1)-np.roll(hair_height,1,1))*256
dy=(np.roll(hair_height,-1,0)-np.roll(hair_height,1,0))*256
hair_normal=np.stack([-dx,-dy,np.ones_like(dx)],axis=2);hair_normal/=np.linalg.norm(hair_normal,axis=2)[:,:,None]
hair_value=.29+.035*strand+.045*yy
png(OUT/'beard_albedo.png',np.stack([hair_value,hair_value*.73,hair_value*.53],axis=2)*255)
png(OUT/'beard_normal.png',(hair_normal*.5+.5)*255)
beard_material=materials[5];p=beard_material.node_tree.nodes.get('Principled BSDF')
for suffix in ['albedo','normal']:
    tex=beard_material.node_tree.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/('beard_'+suffix+'.png')))
    if suffix=='albedo':beard_material.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color'])
    else:
        tex.image.colorspace_settings.name='Non-Color';normal=beard_material.node_tree.nodes.new('ShaderNodeNormalMap')
        beard_material.node_tree.links.new(tex.outputs['Color'],normal.inputs['Color']);beard_material.node_tree.links.new(normal.outputs[0],p.inputs['Normal'])
# Rig rest joints; arms relaxed slightly away from the body.
joints={'Hips':((0,0,.94),(0,0,1.06),None),'Spine':((0,0,1.06),(0,0,1.24),'Hips'),'Chest':((0,0,1.24),(0,0,1.43),'Spine'),'Neck':((0,0,1.43),(0,0,1.51),'Chest'),'Head':((0,0,1.51),(0,0,1.69),'Neck')}
for side,sign in [('Left',1),('Right',-1)]:
    hip=(sign*.105,0,.94);knee=(sign*.11,-.022,.53);ankle=(sign*.11,0,.11)
    shoulder=(sign*.21,0,1.40);elbow=(sign*.35,0,1.08);wrist=(sign*.45,-.015,.765)
    joints[side+'Shoulder']=((0,0,1.4),shoulder,'Chest')
    joints[side+'UpperArm']=(shoulder,elbow,side+'Shoulder');joints[side+'LowerArm']=(elbow,wrist,side+'UpperArm');joints[side+'Hand']=(wrist,tuple(Vector(wrist)+Vector((sign*.025,0,-.085))),side+'LowerArm')
    joints[side+'UpperLeg']=(hip,knee,'Hips');joints[side+'LowerLeg']=(knee,ankle,side+'UpperLeg');joints[side+'Foot']=(ankle,(sign*.11,-.17,.07),side+'LowerLeg')
    for f in range(5):
        start=Vector(wrist)+Vector((sign*(.018+f*.01),-.035+f*.017,-.07 if f else -.02))
        prefix=side+['Thumb','Index','Middle','Ring','Little'][f]
        lengths=[.0246,.0314,.0381]
        parent=side+'Hand'
        for segment,length in zip(['Proximal','Intermediate','Distal'],lengths):
            end=start+Vector((sign*.003,0,-length))
            joints[prefix+segment]=(tuple(start),tuple(end),parent)
            start=end;parent=prefix+segment
joints['pan_socket']=(joints['RightHand'][0],tuple(Vector(joints['RightHand'][0])+Vector((0,0,.1))),'RightHand')
bpy.ops.object.armature_add();rig=bpy.context.object;rig.name='MinerRig';bpy.ops.object.mode_set(mode='EDIT');rig.data.edit_bones.remove(rig.data.edit_bones[0])
for name,(a,b,parent) in joints.items():
    bone=rig.data.edit_bones.new(name);bone.head=a;bone.tail=b
    if parent:bone.parent=rig.data.edit_bones[parent]
bpy.ops.object.mode_set(mode='OBJECT')
verts=[];faces=[];uvs=[];slots=[];weights=[]
def loft(name,points,radii,depths,slot,bone,sides=24,across_axis=(1,0,0)):
    base=len(verts); points=[Vector(p) for p in points]
    for j,p in enumerate(points):
        direction=(points[min(j+1,len(points)-1)]-points[max(0,j-1)]).normalized()
        across=Vector(across_axis)
        if abs(direction.dot(across))>.9:across=Vector((0,1,0))
        across=(across-direction*across.dot(direction)).normalized();other=direction.cross(across).normalized()
        for k in range(sides):
            a=k*math.tau/sides
            gather=1.0
            if slot==0:
                # Folds gather at the tuck and elbow, fading across taut cloth.
                edge=math.exp(-((j/(len(points)-1)-.08)/.20)**2)
                gather+=(.012+.042*edge)*math.sin(a*7+j*.31)+.010*math.sin(a*11-j*.6)
            if slot==1:
                gather+=.028*math.sin(a*5+j*.85)+.018*math.cos(a*8-j*.7)
            if slot==5:gather+=.024*math.sin(a*5+j*.9)
            verts.append(p+(across*math.cos(a)*radii[j]+other*math.sin(a)*depths[j])*gather)
            x=slot%2 if slot<4 else 0;y=slot//2 if slot<4 else 0
            uv=(k/sides,j/max(1,len(points)-1)) if slot==5 else ((x+.04+.92*k/sides)*.5,(y+.04+.92*j/max(1,len(points)-1))*.5)
            uvs.append(uv);weights.append(bone(p) if callable(bone) else {bone:1})
    for j in range(len(points)-1):
        for k in range(sides):
            a=base+j*sides+k;b=base+j*sides+(k+1)%sides;faces.append((a,b,b+sides,a+sides));slots.append(slot)
    faces.extend([tuple(base+k for k in reversed(range(sides))),tuple(base+(len(points)-1)*sides+k for k in range(sides))]);slots.extend([slot,slot])
def line(a,b,count):return [Vector(a).lerp(Vector(b),i/(count-1)) for i in range(count)]
def blend(p,a,b,joint,width=.10):
    t=max(0,min(1,(p.z-joint)/width+.5));return {a:t,b:1-t}
def shirt_weight(p):
    return blend(p,'Spine','Hips',1.065,.12) if p.z<1.13 else blend(p,'Chest','Spine',1.24,.20)
# Closed shirt torso, with overlapping sleeve seams and shaped shoulders.
heights=[.93,.97,1.02,1.08,1.14,1.20,1.26,1.32,1.38,1.42,1.445]
loft('Shirt',[(0,0,z) for z in heights],[.16,.183,.19,.185,.181,.193,.21,.223,.224,.18,.073],[.112,.132,.141,.137,.144,.15,.15,.145,.121,.091,.062],0,shirt_weight,40)
loft('Trouser seat',[(0,.01,z) for z in [.82,.87,.92,.97,1.0]],[.16,.18,.177,.167,.158],[.10,.125,.124,.118,.112],1,'Hips',28)
for side,sign in [('Left',1),('Right',-1)]:
    hip,knee,ankle=[Vector(joints[side+n][0]) for n in ['UpperLeg','LowerLeg','Foot']]
    pts=line(ankle+Vector((0,0,.12)),knee,7)+line(knee,hip,8)[1:]
    rs=[.066,.068,.069,.073,.078,.084,.090,.095,.099,.105,.108,.109,.103,.096]
    loft('Trouser leg',pts,rs,rs,1,lambda p,s=side:blend(p,s+'UpperLeg',s+'LowerLeg',.53,.15),24)
    loft('Boot upper',[(sign*.11,0,z) for z in [.045,.08,.14,.23,.29]],[.072,.071,.065,.063,.069],[.09,.085,.072,.069,.074],2,side+'Foot',24)
    loft('Boot toe',[(sign*.11,y,.063) for y in [.05,0,-.07,-.16,-.22]],[.063,.077,.081,.075,.054],[.05,.063,.061,.048,.025],2,side+'Foot',24)
    a,b,c=[Vector(joints[side+n][0]) for n in ['UpperArm','LowerArm','Hand']]
    pts=[a+Vector((-sign*.035,0,.030))]+line(a,b,7)+line(b,b.lerp(c,.35),4)[1:]
    rs=[.057,.093,.102,.100,.093,.086,.082,.078,.081,.079,.075]
    loft('Rolled sleeve',pts,rs,rs,0,lambda p,s=side:blend(p,s+'UpperArm',s+'LowerArm',1.12,.13),24)
    cuff=b.lerp(c,.3);loft('Sleeve roll',[cuff+Vector((0,0,z)) for z in [.028,.016,.006,-.009,-.018]],[.076,.084,.087,.083,.074],[.076,.084,.087,.083,.074],0,side+'LowerArm',28)
    pts=line(b.lerp(c,.25),c,9);rs=[.050,.050,.049,.047,.044,.040,.035,.031,.028]
    loft('Forearm',pts,rs,rs,3,side+'LowerArm',32)
    # The broad palm axis follows the finger row, including in the rest mesh.
    # A radial broad axis made the outer fingers appear disconnected in close-up.
    loft('Palm',line(c,c+Vector((sign*.025,0,-.085)),6),[.028,.039,.049,.054,.053,.051],[.024,.025,.024,.022,.020,.018],3,side+'Hand',32,across_axis=(0,1,0))
    thumb_start=Vector(joints[side+'ThumbProximal'][0])
    web_start=c+Vector((sign*.022,-.018,-.040))
    web_points=line(web_start,thumb_start,5)
    def thumb_web_weight(p,s=side,a=web_start,b=thumb_start):
        t=max(0,min(1,(p-a).dot(b-a)/(b-a).length_squared))
        return {s+'Hand':1-t,s+'ThumbProximal':t}
    loft('Thumb web',web_points,[.018,.019,.017,.013,.010],[.018,.018,.016,.012,.010],3,thumb_web_weight,20)
    for f in range(5):
        prefix=side+['Thumb','Index','Middle','Ring','Little'][f]
        pts=[]
        for j,segment in enumerate(['Proximal','Intermediate','Distal']):
            a,b,_=joints[prefix+segment]
            pts+=line(a,b,4)[0 if j==0 else 1:]
        def finger_weight(p,prefix=prefix):
            mid=joints[prefix+'Intermediate'][0][2];tip=joints[prefix+'Distal'][0][2]
            if p.z>mid-.004:return blend(p,prefix+'Proximal',prefix+'Intermediate',mid,.008)
            return blend(p,prefix+'Intermediate',prefix+'Distal',tip,.008)
        taper=[1.03,1.,1.02,.93,.80][f]
        rr=[r*taper for r in [.009,.010,.009,.0095,.0085,.008,.0085,.0075,.0065,.0025]]
        loft('Continuous finger',pts,rr,rr,3,finger_weight,12)
loft('Neck',[(0,0,z) for z in [1.415,1.46,1.51,1.54]],[.065]*4,[.061]*4,3,'Neck',32)
from miner_detail import detail
detail(loft,verts,faces,uvs,slots,weights,shirt_weight)
# Felt brim shaped down at its edge; low crown defines the silhouette.
loft('Hat',[(0,0,z) for z in [1.637,1.645,1.657,1.665,1.68,1.73,1.768,1.78]],[.25,.27,.17,.115,.112,.108,.091,.063],[.218,.238,.15,.102,.099,.094,.081,.057],4,'Head',48)
loft('Hat band',[(0,0,z) for z in [1.667,1.69]],[.115,.114],[.103,.101],2,'Head',40)
loft('Belt',[(0,0,z) for z in [.956,.977,.995]],[.182,.181,.174],[.13,.129,.125],2,'Hips',32)
# Narrow straps follow the torso front/back, never floating above shoulders.
for sign in [-1,1]:
    front=[(sign*x,-y,z) for x,y,z in [(.075,.134,.98),(.081,.142,1.08),(.089,.151,1.20),(.100,.148,1.32),(.102,.112,1.40),(.095,.075,1.432)]]
    points=front+[(sign*.091,0,1.446)]+[(x,-y,z) for x,y,z in reversed(front)]
    loft('Suspender',points,[.014]*len(points),[.003]*len(points),6,shirt_weight,8)
body=mesh_object('Miner',verts,faces,uvs=uvs,materials=materials,slots=slots)
for name in joints:body.vertex_groups.new(name=name)
for i,weight in enumerate(weights):
    for name,w in weight.items():
        if w>0:body.vertex_groups[name].add([i],w,'REPLACE')
tri=body.modifiers.new('Export triangles','TRIANGULATE');bpy.context.view_layer.objects.active=body;bpy.ops.object.modifier_apply(modifier=tri.name)
mod=body.modifiers.new('Skin','ARMATURE');mod.object=rig;body.parent=rig
print('MINER_TRIANGLES',sum(len(f)-2 for f in faces))

# Hollow spun steel pan. Origin is the bottom's inside, local +Y is rear.
pv=[];pf=[];pu=[];ps=[];segments=64
rings=[(0.001,-.004),(.145,-.004),(.158,-.002),(.171,.008),(.2,.075),(.2,.08),(.195,.08),(.166,.012),(.157,.006),(.148,.01),(.001,.01)]
for r,z in rings:
    for i in range(segments):
        a=i*math.tau/segments;pv.append((r*math.sin(a),r*math.cos(a),z));pu.append((i/segments,z/.08))
for j in range(len(rings)-1):
    for i in range(segments):
        a=j*segments+i;b=j*segments+(i+1)%segments;pf.append((a,b,b+segments,a+segments));ps.append(2 if j in [4,5] else 1 if j>5 else 0)
steel=[material('Dark oxidized steel',(.065,.074,.078)),material('Scuffed pan interior',(.24,.265,.27)),material('Rust at rim',(.19,.09,.04))]
for i,m in enumerate(steel):
    p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Metallic'].default_value=.65 if i<2 else .1;p.inputs['Roughness'].default_value=.47 if i==1 else .8
    if i==1:
        # Bake a procedural scuff swatch, with intersecting circular rub marks
        # and shorter abrasions; the physical crease remains modeled geometry.
        import numpy as np
        from png_helpers import png
        rng=np.random.default_rng(184806);yy,xx=np.mgrid[:512,:512]/512
        rub=np.zeros_like(xx)
        for mark in range(35):
            v=rng.random();phase=rng.random()*math.tau
            distance=abs(yy-v-.014*np.sin(xx*math.tau*rng.integers(1,5)+phase))
            rub+=np.exp(-(distance/.0018)**2)*(.5+.5*np.sin(xx*math.tau*3+phase))*.10
        value=np.clip(.48+rub+rng.normal(0,.014,xx.shape),0,1)
        png(OUT/'pan_scuffs.png',np.stack([value*.94,value*.98,value],axis=2)*255)
        texture=m.node_tree.nodes.new('ShaderNodeTexImage');texture.image=bpy.data.images.load(str(OUT/'pan_scuffs.png'))
        m.node_tree.links.new(texture.outputs['Color'],p.inputs['Base Color'])
pan=mesh_object('Pan',pv,pf,pu,materials=steel,slots=ps);export(pan,'miner/pan.glb');pan.hide_render=True;pan.hide_set(True)
# Tied poke, five explicit scale keys are applied on the hips attachment.
sv=[];sf=[];su=[]
for j,(z,r) in enumerate([(-.23,.025),(-.21,.072),(-.17,.087),(-.08,.080),(-.025,.032),(0,.025),(.018,.04)]):
    for i in range(20):
        a=i*math.tau/20
        fold=1+.10*math.sin(a*5+j*.5)+.045*math.cos(a*9-j)
        sv.append((math.cos(a)*r*fold,math.sin(a)*r*.65*fold,z));su.append((i/20,j/6))
for j in range(6):
    for i in range(20):
        a=j*20+i;b=j*20+(i+1)%20;sf.append((a,b,b+20,a+20))
sf.append(tuple(reversed(range(20))));sf.append(tuple(120+i for i in range(20)))
# A thin leather tie loops around the gathered neck and has two loose tails.
def sack_cord(points,radius=.004):
    vv=[];ff=[];uu=[];cc=[];ss=[]
    tube(vv,ff,uu,cc,ss,points,[radius]*len(points),6)
    base=len(sv);sv.extend(vv);su.extend(uu);sf.extend([tuple(base+i for i in face) for face in ff])
sack_cord([(math.cos(i*math.tau/24)*.029,math.sin(i*math.tau/24)*.021,-.009) for i in range(25)])
sack_cord([(.005,-.024,-.006),(.018,-.029,-.027),(.031,-.033,-.067)])
sack_cord([(.005,-.024,-.006),(-.012,-.029,-.029),(-.017,-.032,-.053)])
sack=mesh_object('Tied poke',sv,sf,su,materials=[material('Worn canvas poke',(.30,.225,.125))]);sack.shape_key_add(name='Basis')
for stage in range(1,5):
    key=sack.shape_key_add(name='stage_'+str(stage))
    for v in key.data:v.co.x*=1+stage*.10;v.co.y*=1+stage*.15;v.co.z*=1+stage*.04
export(sack,'miner/sack.glb');sack.hide_render=True;sack.hide_set(True)
from build_miner_animation import animate
animate(rig,body,joints)
