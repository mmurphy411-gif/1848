"""Anatomical retopology over the original trout's length and orientation."""
import bpy, math, random
from mathutils import Vector

PROFILE=[(-.18,-.008,.004,.008),(-.169,-.002,.013,.013),(-.151,.002,.024,.020),(-.13,.002,.035,.025),(-.10,0,.043,.028),(-.05,-.001,.045,.029),(0,-.001,.043,.026),(.05,-.003,.035,.021),(.095,-.004,.025,.015),(.13,-.002,.017,.009),(.153,0,.016,.007),(.17,0,.022,.006)]

def profile(x):
    for a,b in zip(PROFILE,PROFILE[1:]):
        if a[0]<=x<=b[0]:
            t=(x-a[0])/(b[0]-a[0]);t=t*t*(3-2*t)
            return tuple(a[j]*(1-t)+b[j]*t for j in [1,2,3])
    return PROFILE[0][1:] if x<PROFILE[0][0] else PROFILE[-1][1:]

def fin(h,name,root,outline,material):
    # Radial membrane sections curve out of the body and support later fin rays.
    root=Vector(root);points=[Vector(p) for p in outline];vs=[];fs=[]
    for i,p in enumerate(points):
        for j in range(7):
            t=j/6;v=root.lerp(p,t)
            v.y+=.0012*math.sin(t*math.pi)*math.sin(i*1.9);vs.append(v)
    for i in range(len(points)-1):
        for j in range(6):a=i*7+j;fs.append((a,a+7,a+8,a+1))
    o=h.mesh(name,vs,fs,material)
    o['fin_root']=list(root);o['fin_outline']=[list(p) for p in points]
    sol=o.modifiers.new('Membrane thickness','SOLIDIFY');sol.thickness=.00035
    return o

def stage1(h):
    original=bpy.data.objects['trout'];original.name='ARCHIVE | original trout';original.hide_render=True;original.hide_set(True)
    silver=h.mat('Trout structural silver',(.32,.37,.33),.36,.2)
    fins=h.mat('Trout fin structure',(.28,.21,.13),.48,.08)
    # 1. Long fusiform body with rounded snout and a distinct narrow peduncle.
    vs=[];fs=[];uv=[];rings=101;sides=64
    for i in range(rings):
        x=-.18+.35*i/(rings-1);cz,rz,ry=profile(x)
        for j in range(sides):
            a=j*math.tau/sides;vs.append((x,math.cos(a)*ry,cz+math.sin(a)*rz));uv.append((i/(rings-1),j/sides))
    for i in range(rings-1):
        for j in range(sides):
            a=i*sides+j;b=i*sides+(j+1)%sides;fs.append((a,a+sides,b+sides,b))
    fs.extend([tuple(reversed(range(sides))),tuple((rings-1)*sides+j for j in range(sides))])
    body=h.mesh('Trout body',vs,fs,silver)
    layer=body.data.uv_layers.new(name='Anatomical UV')
    for p in body.data.polygons:
        for li in p.loop_indices:layer.data[li].uv=uv[body.data.loops[li].vertex_index]
    # 2. Complete fin inventory and rounded shallow-fork caudal silhouette.
    fin(h,'Caudal fin',(.145,0,0),[(.156,0,.016),(.178,0,.032),(.209,0,.049),(.218,0,.048),(.215,0,.025),(.209,0,0),(.215,0,-.025),(.218,0,-.048),(.207,0,-.048),(.177,0,-.029),(.156,0,-.016)],fins)
    fin(h,'Dorsal fin',(-.008,0,.039),[(-.03,0,.041),(-.014,0,.054),(.005,0,.066),(.02,0,.067),(.026,0,.053),(.035,0,.035)],fins)
    fin(h,'Adipose fin',(.106,0,.019),[(.095,0,.022),(.105,0,.030),(.116,0,.032),(.12,0,.028),(.117,0,.017)],fins)
    fin(h,'Anal fin',(.097,0,-.024),[(.071,0,-.032),(.086,0,-.045),(.118,0,-.059),(.122,0,-.055),(.121,0,-.024)],fins)
    for s in [-1,1]:
        fin(h,'Pectoral '+str(s),(-.10,s*.023,-.028),[(-.104,s*.023,-.028),(-.075,s*.040,-.038),(-.049,s*.048,-.061),(-.055,s*.046,-.068),(-.077,s*.031,-.059),(-.10,s*.019,-.035)],fins)
        fin(h,'Pelvic '+str(s),(.016,s*.013,-.038),[(.012,s*.013,-.038),(.042,s*.027,-.050),(.054,s*.032,-.069),(.043,s*.029,-.07),(.023,s*.020,-.056),(.012,s*.009,-.042)],fins)
    # 3. Establish the head volume, opercula and properly sized lateral eyes.
    dark=h.mat('Trout pupil',(.003,.004,.003),.13)
    gold=h.mat('Trout iris',(.31,.215,.058),.3,.35)
    for s in [-1,1]:
        h.ell('Operculum '+str(s),(-.113,s*.018,-.004),(.022,.009,.032),silver)
        h.ell('Eye socket '+str(s),(-.148,s*.020,.013),(.010,.005,.010),silver)
        h.ell('Iris '+str(s),(-.148,s*.024,.013),(.0071,.003,.0071),gold)
        h.ell('Pupil '+str(s),(-.148,s*.026,.013),(.0049,.0018,.0049),dark)

def run(step,h):
    if step==1:stage1(h)
    elif step==2:stage2(h)
    elif step==3:stage3(h)
    elif step==4:stage4(h)
    elif step==5:stage5(h)
    elif step==6:stage6(h)
    elif step==7:stage7(h)
    elif step==8:stage8(h)
    elif step==9:stage9(h)
    elif step==10:stage10(h)
    elif step==11:stage11(h)
    elif step==12:stage12(h)
    elif step==13:stage13(h)
    else:raise ValueError(step)

def smooth_profile(x):
    for i,(a,b) in enumerate(zip(PROFILE,PROFILE[1:])):
        if a[0]<=x<=b[0]+1e-7:
            t=(x-a[0])/(b[0]-a[0]);prev=PROFILE[max(0,i-1)];nxt=PROFILE[min(len(PROFILE)-1,i+2)]
            result=[]
            for j in [1,2,3]:
                ma=(b[j]-prev[j])/(b[0]-prev[0]);mb=(nxt[j]-a[j])/(nxt[0]-a[0]);d=b[0]-a[0]
                result.append((2*t**3-3*t*t+1)*a[j]+(t**3-2*t*t+t)*ma*d+(-2*t**3+3*t*t)*b[j]+(t**3-t*t)*mb*d)
            return result
    return profile(x)

def stage2(h):
    import bmesh
    body=bpy.data.objects['Trout body']
    # 1. Smooth longitudinal curvature and a larger, less pinched head.
    for v in body.data.vertices:
        x,y,z=v.co;old=profile(x);new=smooth_profile(x)
        widen=1+.16*math.exp(-((x+.163)/.02)**2)
        v.co=(x,y/old[2]*new[2]*widen,(z-old[0])/old[1]*new[1]+new[0])
    # 2. Open a wedge-shaped gape in the original front rings and line its interior.
    bm=bmesh.new();bm.from_mesh(body.data);remove=[]
    for f in bm.faces:
        c=f.calc_center_median();x,y,z=c
        if x<-.14:
            t=max(0,min(1,(-.14-x)/.04));top=-.018+.013*t;bottom=-.018-.006*t
            if bottom<z<top or (x<-.179 and z<top):remove.append(f)
    bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(body.data);bm.free()
    silver=bpy.data.materials['Trout structural silver'];dark=h.mat('Trout mouth cavity',(.041,.017,.012),.72)
    pink=h.mat('Trout inner mouth',(.25,.125,.085),.6)
    h.ell('Mouth cavity',(-.16,0,-.016),(.020,.014,.009),dark)
    h.ell('Lower jaw',(-.158,0,-.025),(.026,.015,.007),silver)
    h.ell('Mouth lining',(-.164,0,-.022),(.016,.011,.0025),pink)
    for s in [-1,1]:
        h.tube('Upper lip '+str(s),[(-.18,0,-.006),(-.176,s*.010,-.008),(-.161,s*.018,-.015),(-.14,s*.020,-.018)],[.0015,.0015,.0013,.0007],silver)
        h.tube('Lower lip '+str(s),[(-.182,0,-.024),(-.177,s*.009,-.026),(-.16,s*.016,-.028),(-.14,s*.020,-.018)],[.0013,.0014,.0015,.0007],silver)
        # Seat operculum in the head, tracing its characteristic curved rear edge.
        o=bpy.data.objects['Operculum '+str(s)];o.scale.y=.65
        h.tube('Gill cover rim '+str(s),[(-.126,s*.022,.025),(-.118,s*.027,.018),(-.109,s*.030,.006),(-.105,s*.027,-.010),(-.114,s*.020,-.027),(-.129,s*.010,-.031)],[.001]*6,silver)
    # 3. Softer, fuller fin margins and a seamless peduncle/caudal root.
    for o in list(bpy.context.scene.objects):
        if 'fin_root' not in o:continue
        active=bpy.context.view_layer.objects.active
        sub=o.modifiers.new('Rounded fin margins','SUBSURF');sub.subdivision_type='CATMULL_CLARK';sub.levels=2
        # Increase body-side overlap to prevent a visible disconnected tail root.
        if o.name=='Caudal fin':
            for v in o.data.vertices:
                if v.co.x<.167:v.co.x-=.005

def stage3(h):
    # 1. Proper fan area: retain the drawn perimeter instead of shrinking sparse fins.
    for o in list(bpy.context.scene.objects):
        if 'fin_root' not in o:continue
        pts=[Vector(p) for p in o['fin_outline']];root=Vector(o['fin_root']);curve=[]
        for i in range(len(pts)):
            a,b,c,d=[pts[j%len(pts)] for j in [i-1,i,i+1,i+2]]
            for k in range(6):
                t=k/6;curve.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
        center=sum(curve,Vector())/len(curve);vs=[center]+curve;fs=[]
        for i in range(len(curve)):fs.append((0,1+i,1+(i+1)%len(curve)))
        nd=bpy.data.meshes.new(o.name+' expanded membrane');nd.from_pydata(vs,[],fs);nd.update();nd.materials.append(o.data.materials[0]);o.data=nd
        for p in o.data.polygons:p.use_smooth=True
        for mod in list(o.modifiers):o.modifiers.remove(mod)
        sol=o.modifiers.new('Thin fin membrane','SOLIDIFY');sol.thickness=.00025
        if o.name.startswith('Pectoral'):
            for v in o.data.vertices:
                v.co.y=root.y+(v.co.y-root.y)*1.45
                v.co.z=root.z+(v.co.z-root.z)*.8
    # 2. Broader head at the eye and smoother opercular volume.
    body=bpy.data.objects['Trout body']
    for v in body.data.vertices:
        x,y,z=v.co
        v.co.y*=1+.10*math.exp(-((x+.146)/.028)**2)
    for s in [-1,1]:
        o=bpy.data.objects['Operculum '+str(s)];o.hide_render=True;o.hide_set(True)
    # 3. Basic species color zones, needed to judge anatomy before fine surfacing.
    colors=body.data.color_attributes.new(name='Species color',type='FLOAT_COLOR',domain='POINT')
    for i,v in enumerate(body.data.vertices):
        x,y,z=v.co;cz,rz,ry=smooth_profile(x);vnorm=(z-cz)/rz
        if vnorm>.30:
            t=min(1,(vnorm-.30)/.70);c=[.36*(1-t)+.09*t,.39*(1-t)+.12*t,.33*(1-t)+.068*t]
        else:
            t=min(1,max(0,(.30-vnorm)/1.3));c=[.36*(1-t)+.63*t,.39*(1-t)+.60*t,.33*(1-t)+.49*t]
        stripe=.65*math.exp(-((vnorm-.05)/.23)**2)*min(1,max(0,(x+.145)/.035))
        c=[c[k]*(1-stripe)+[.46,.13,.15][k]*stripe for k in range(3)]
        if -.139<x<-.101:
            rose=.38*math.exp(-((vnorm+.1)/.70)**2);c=[c[k]*(1-rose)+[.48,.19,.19][k]*rose for k in range(3)]
        colors.data[i].color=(*c,1)
    m=h.mat('Trout species zones',(.4,.4,.4),.36,.28);p=m.node_tree.nodes.get('Principled BSDF')
    attr=m.node_tree.nodes.new('ShaderNodeVertexColor');attr.layer_name='Species color';m.node_tree.links.new(attr.outputs['Color'],p.inputs['Base Color']);h.assign(body,m)

def stage4(h):
    import bmesh
    # 1. Clean the open-gape border and reduce the protruding lower jaw.
    body=bpy.data.objects['Trout body'];bm=bmesh.new();bm.from_mesh(body.data)
    for v in bm.verts:
        if not v.is_boundary or v.co.x>-.14:continue
        x,y,z=v.co;t=max(0,min(1,(-.14-x)/.04));top=-.018+.013*t;bottom=-.018-.006*t
        v.co.z=top if z>-.017 else bottom
    bm.to_mesh(body.data);bm.free()
    jaw=bpy.data.objects['Lower jaw'];jaw.scale.z=.65;jaw.location.z+=.0015
    cavity=bpy.data.objects['Mouth cavity'];cavity.scale.x=.87;cavity.location.x+=.001;cavity.scale.z=.8
    for s in [-1,1]:
        o=bpy.data.objects['Eye socket '+str(s)];o.scale.y=.65
        for name in ['Iris','Pupil']:bpy.data.objects[name+' '+str(s)].location.y-=s*.001
    # 2. Fin/body attachment thickness is in the membrane, not an exposed tube end.
    for v in body.data.vertices:
        if v.co.x>.152:
            t=(v.co.x-.152)/.018;v.co.y*=1-.86*t;v.co.z*=1-.28*t
    for o in list(bpy.context.scene.objects):
        if 'fin_root' not in o:continue
        # All median fins are planar across their width, without shading twists.
        if o.name in ['Caudal fin','Dorsal fin','Adipose fin','Anal fin']:
            for v in o.data.vertices:v.co.y=0
        o.data.update()
        # Recompute the fan's normals consistently.
        bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    # 3. Reference fan widths: broaden pectorals and pelvic fins, lower dorsal crest.
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(('Pectoral','Pelvic')):
            root=Vector(o['fin_root'])
            for v in o.data.vertices:
                v.co.x=root.x+(v.co.x-root.x)*.9
                v.co.z=root.z+(v.co.z-root.z)*1.10
        if o.name=='Dorsal fin':
            for v in o.data.vertices:v.co.z=.040+(v.co.z-.040)*1.10

def stage5(h):
    # 1. Reference head wedge: flatter snout and fuller lower opercular contour.
    body=bpy.data.objects['Trout body']
    for v in body.data.vertices:
        x,y,z=v.co
        if x<-.135 and z>-.006:
            v.co.z+=.0035*math.exp(-((x+.168)/.016)**2)*max(0,min(1,(z+.006)/.013))
    jaw=bpy.data.objects['Lower jaw'];jaw.scale.x=.91;jaw.location.x+=.002
    # 2. Reference caudal fork: broaden fin base and retain a clean trailing notch.
    finobj=bpy.data.objects['Caudal fin']
    for v in finobj.data.vertices:
        x,y,z=v.co
        if x<.176:v.co.x-=.006;v.co.z*=1.12
        if x>.2:v.co.x+=.003*(abs(z)/.048)
    # Match its base value to the peduncle, avoiding a cut-off visual seam.
    fm=bpy.data.materials['Trout fin structure'];fm.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.31,.28,.20,1)
    # 3. Pectoral fan silhouette (broad, gently swept, rather than narrow paddles).
    for o in list(bpy.context.scene.objects):
        if not o.name.startswith('Pectoral'):continue
        root=Vector(o['fin_root'])
        for v in o.data.vertices:
            dx=v.co.x-root.x;t=max(0,min(1,dx/.05))
            v.co.z-=.007*math.sin(t*math.pi)
    # Supplemental dorsal camera matches the illustration labelled "back", which
    # actually shows the top of the fish. Keep the real rear diagnostic unchanged.
    from mathutils import Matrix
    d=bpy.data.cameras.new('Dorsal reference');d.type='ORTHO';d.ortho_scale=.46
    o=bpy.data.objects.new('Review dorsal',d);bpy.context.scene.collection.objects.link(o);o.location=(.08,0,3)
    direction=(Vector((.02,0,0))-o.location).normalized();up=Vector((-1,0,0));right=direction.cross(up).normalized();up=right.cross(direction)
    o.rotation_euler=Matrix((right,up,-direction)).transposed().to_euler()

def stage6(h):
    # 1. Continuous peduncle silhouette: end the body inside the caudal membrane.
    body=bpy.data.objects['Trout body']
    for v in body.data.vertices:
        if v.co.x>.13:
            t=(v.co.x-.13)/.04;v.co.x=.13+.023*t
            cz,rz,ry=smooth_profile(.13+.04*t)
            # Keep an anatomically narrow base, including the very last ring.
            angle=math.atan2(v.co.z, v.co.y*2)
            v.co.z=math.sin(angle)*(.017-.002*t)
            v.co.y=math.cos(angle)*(.009*(1-t)+.0008*t)
    # 2. Remove the shoulder notch introduced during the previous tail widening.
    o=bpy.data.objects['Caudal fin'];pts=[Vector((x,0,z)) for x,z in [(.146,.014),(.166,.022),(.2,.044),(.215,.048),(.213,.024),(.207,0),(.213,-.024),(.215,-.048),(.2,-.044),(.166,-.022),(.146,-.014)]]
    curve=[]
    for i in range(len(pts)):
        a,b,c,d=[pts[j%len(pts)] for j in [i-1,i,i+1,i+2]]
        for k in range(8):
            t=k/8;curve.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t))
    center=sum(curve,Vector())/len(curve);vs=[center]+curve;fs=[(0,1+i,1+(i+1)%len(curve)) for i in range(len(curve))]
    d=bpy.data.meshes.new('Clean caudal fan');d.from_pydata(vs,[],fs);d.update();d.materials.append(o.data.materials[0]);o.data=d
    o['fin_outline']=[list(p) for p in pts]
    # 3. Flat membranes avoid inflated edge normals; the ray structure comes later.
    for o in bpy.context.scene.objects:
        if 'fin_root' in o:
            for p in o.data.polygons:p.use_smooth=False

def stage7(h):
    # Restore smooth elliptical tail rings. Last pass's angle recovery exaggerated
    # narrow-axis vertices and created a shallow ridge near the adipose fin.
    body=bpy.data.objects['Trout body'];sides=64
    for v in body.data.vertices:
        if v.co.x>.13:
            t=(v.co.x-.13)/.023;a=(v.index%sides)*math.tau/sides
            v.co.y=math.cos(a)*(.009*(1-t)+.0008*t)
            v.co.z=math.sin(a)*(.017-.002*t)-.002*(1-t)
    # Opaque, thin dorsal silhouette is now structurally retained; surface detail next.
    bpy.context.scene['form_gate']='Pass 7: silhouette/proportions reviewed before polish'

def stage8(h):
    body=bpy.data.objects['Trout body'];angles={}
    # Boundary cleanup reindexed mesh vertices. Recover angular position from
    # authored UVs, which survive those edits, rather than assuming index modulo 64.
    uv=body.data.uv_layers[0]
    for loop in body.data.loops:angles[loop.vertex_index]=uv.data[loop.index].uv.y*math.tau
    for v in body.data.vertices:
        if v.co.x>.13:
            t=max(0,min(1,(v.co.x-.13)/.023));a=angles[v.index]
            v.co.y=math.cos(a)*(.009*(1-t)+.0008*t)
            v.co.z=math.sin(a)*(.017-.002*t)-.002*(1-t)
    body.data.update()
    bpy.context.scene['form_gate']='Pass 8: review the repaired tail root before polish'

def stage9(h):
    # POLISH 1: spots and scales, wet color hierarchy, fine articulated fin rays.
    body=bpy.data.objects['Trout body'];colors=body.data.color_attributes['Species color']
    for item in colors.data:
        r,g,b,a=item.color;item.color=(r*.78,g*.77,b*.72,1)
    m=bpy.data.materials['Trout species zones'];nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
    base=next(n for n in nodes if n.bl_idname=='ShaderNodeVertexColor')
    pos=nodes.new('ShaderNodeNewGeometry');split=nodes.new('ShaderNodeSeparateXYZ');links.new(pos.outputs['Position'],split.inputs[0])
    spots=nodes.new('ShaderNodeTexVoronoi');spots.inputs['Scale'].default_value=305;spots.inputs['Randomness'].default_value=1;links.new(pos.outputs['Position'],spots.inputs['Vector'])
    ramp=nodes.new('ShaderNodeValToRGB');ramp.color_ramp.elements[0].position=.14;ramp.color_ramp.elements[0].color=(1,1,1,1);ramp.color_ramp.elements[1].position=.23;ramp.color_ramp.elements[1].color=(0,0,0,1);links.new(spots.outputs['Distance'],ramp.inputs[0])
    depth=nodes.new('ShaderNodeMapRange');depth.inputs['From Min'].default_value=-.030;depth.inputs['From Max'].default_value=.009;depth.inputs['To Min'].default_value=0;depth.inputs['To Max'].default_value=1;depth.clamp=True;links.new(split.outputs['Z'],depth.inputs['Value'])
    mult=nodes.new('ShaderNodeMath');mult.operation='MULTIPLY';links.new(ramp.outputs[0],mult.inputs[0]);links.new(depth.outputs[0],mult.inputs[1])
    mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MIX';links.new(mult.outputs[0],mix.inputs[0]);links.new(base.outputs['Color'],mix.inputs[1]);mix.inputs[2].default_value=(.008,.012,.009,1);links.new(mix.outputs[0],p.inputs['Base Color'])
    # Microscopic scale relief, aligned longitudinally, without changing silhouette.
    mapping=nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(1.1,1.9,1.8);links.new(pos.outputs['Position'],mapping.inputs[0])
    scale=nodes.new('ShaderNodeTexVoronoi');scale.feature='DISTANCE_TO_EDGE';scale.inputs['Scale'].default_value=980;scale.inputs['Randomness'].default_value=.22;links.new(mapping.outputs[0],scale.inputs['Vector'])
    bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.22;bump.inputs['Distance'].default_value=.00035;links.new(scale.outputs['Distance'],bump.inputs['Height']);links.new(bump.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Roughness'].default_value=.30;p.inputs['Metallic'].default_value=.5;p.inputs['Coat Weight'].default_value=.22;p.inputs['Coat Roughness'].default_value=.18
    # Spotted median fins and faintly warm paired membranes.
    fm=h.mat('Trout spotted fins',(.26,.23,.14),.41,.18);n=fm.node_tree.nodes;l=fm.node_tree.links;fp=n.get('Principled BSDF')
    g=n.new('ShaderNodeNewGeometry');v=n.new('ShaderNodeTexVoronoi');v.inputs['Scale'].default_value=300;l.new(g.outputs['Position'],v.inputs['Vector'])
    r=n.new('ShaderNodeValToRGB');r.color_ramp.elements[0].position=.15;r.color_ramp.elements[0].color=(.007,.010,.007,1);r.color_ramp.elements[1].position=.24;r.color_ramp.elements[1].color=(.31,.265,.17,1);l.new(v.outputs['Distance'],r.inputs[0]);l.new(r.outputs[0],fp.inputs['Base Color'])
    fp.inputs['Transmission Weight'].default_value=.12
    warm=h.mat('Trout warm paired fins',(.28,.19,.13),.43,.12);warm.node_tree.nodes.get('Principled BSDF').inputs['Transmission Weight'].default_value=.15
    ray=h.mat('Trout fin rays',(.40,.33,.22),.48,.08)
    for o in list(bpy.context.scene.objects):
        if 'fin_root' not in o:continue
        h.assign(o,warm if o.name.startswith(('Pectoral','Pelvic','Anal')) else fm)
        root=Vector(o['fin_root']);outline=[Vector(p) for p in o['fin_outline']]
        # Current deformed mesh perimeter gives the retained fin contour.
        boundary=[];edge_counts={}
        for poly in o.data.polygons:
            ids=list(poly.vertices)
            for a,b in zip(ids,ids[1:]+ids[:1]):
                key=tuple(sorted((a,b)));edge_counts[key]=edge_counts.get(key,0)+1
        ids=set(i for e,num in edge_counts.items() if num==1 for i in e)
        perimeter=sorted(ids)
        for j,idx in enumerate(perimeter[::max(1,len(perimeter)//24)]):
            end=o.data.vertices[idx].co.copy()
            if (end-root).length<.014:continue
            # Median rays offset to both sides, paired rays follow their membrane.
            for side in [-1,1]:
                offset=Vector((0,side*.00019,0));a=root.lerp(end,.08)+offset;b=root.lerp(end,.55)+offset;c=root.lerp(end,.96)+offset
                h.tube('Ray | '+o.name+' '+str(j)+' '+str(side),[a,b,c],[.00017,.00012,.000025],ray,5)
    bpy.context.scene['form_gate']='Pass 8: subjective silhouette 8/10, proportions 8/10; polish begins at pass 9'

def stage10(h):
    # POLISH 2: markings were too fine in the neutral renders. Enlarge spots,
    # strengthen the olive/pink/silver hierarchy and separate the fin rays.
    body=bpy.data.objects['Trout body'];attr=body.data.color_attributes['Species color']
    for i,v in enumerate(body.data.vertices):
        x,y,z=v.co;cz,rz,ry=smooth_profile(x);q=max(-1,min(1,(z-cz)/rz))
        t=max(0,min(1,(q-.18)/.82))
        c=[.29*(1-t)+.065*t,.32*(1-t)+.082*t,.25*(1-t)+.039*t]
        belly=max(0,min(1,(-q+.10)/1.1));c=[c[k]*(1-belly)+[.52,.51,.43][k]*belly for k in range(3)]
        stripe=.74*math.exp(-((q-.02)/.23)**2)*min(1,max(0,(x+.14)/.035))
        c=[c[k]*(1-stripe)+[.43,.075,.095][k]*stripe for k in range(3)]
        rose=.50*math.exp(-((x+.117)/.018)**4-((q+.1)/.8)**2)
        c=[c[k]*(1-rose)+[.43,.12,.13][k]*rose for k in range(3)];attr.data[i].color=(*c,1)
    for name in ['Trout species zones','Trout spotted fins']:
        m=bpy.data.materials[name]
        for n in m.node_tree.nodes:
            if n.bl_idname=='ShaderNodeTexVoronoi' and n.feature!='DISTANCE_TO_EDGE':n.inputs['Scale'].default_value=230
            if n.bl_idname=='ShaderNodeValToRGB':n.color_ramp.elements[0].position=.26;n.color_ramp.elements[1].position=.34
        p=m.node_tree.nodes.get('Principled BSDF')
        p.inputs['Roughness'].default_value=.27 if name=='Trout species zones' else .44
    ray=bpy.data.materials['Trout fin rays'];ray.node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.16,.12,.065,1)
    # A finer, subtle scale glint remains in shader relief rather than extra polygons.
    bpy.data.materials['Trout species zones'].node_tree.nodes.get('Principled BSDF').inputs['Metallic'].default_value=.58

def stage11(h):
    # Close-up review: seat eyes and gills and soften scale relief.
    rim=h.mat('Trout natural gill edge',(.13,.15,.105),.48,.2)
    socket=h.mat('Trout eye surround',(.13,.16,.095),.4,.3)
    bpy.data.materials['Trout iris'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.14,.11,.035,1)
    for s in [-1,1]:
        h.assign(bpy.data.objects['Eye socket '+str(s)],socket)
        bpy.data.objects['Eye socket '+str(s)].location.y=s*.019
        bpy.data.objects['Iris '+str(s)].location.y=s*.0208;bpy.data.objects['Iris '+str(s)].scale.y=.6
        bpy.data.objects['Pupil '+str(s)].location.y=s*.0224;bpy.data.objects['Pupil '+str(s)].scale.y=.6
        old=bpy.data.objects['Gill cover rim '+str(s)];old.hide_render=True;old.hide_set(True)
        pts=[Vector(p) for p in [(-.126,0,.025),(-.118,0,.018),(-.109,0,.006),(-.105,0,-.010),(-.114,0,-.027),(-.129,0,-.031)]]
        curve=[]
        for i in range(len(pts)-1):
            a,b,c,d=[pts[min(len(pts)-1,max(0,j))] for j in [i-1,i,i+1,i+2]]
            for k in range(8):
                t=k/8;v=.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t)
                cz,rz,ry=smooth_profile(v.x);q=min(.99,abs((v.z-cz)/rz));v.y=s*(ry*math.sqrt(1-q*q)+.00015);curve.append(v)
        h.tube('Seated opercular edge '+str(s),curve,[.00042]*len(curve),rim,8)
    p=bpy.data.materials['Trout mouth cavity'].node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.004,.002,.001,1);p.inputs['Roughness'].default_value=1;p.inputs['Specular IOR Level'].default_value=0
    for o in bpy.context.scene.objects:
        if o.name.startswith(('Upper lip','Lower lip')):h.assign(o,h.mat('Trout lip tissue',(.20,.22,.17),.5,.2))
    for n in bpy.data.materials['Trout species zones'].node_tree.nodes:
        if n.bl_idname=='ShaderNodeTexVoronoi' and n.feature=='DISTANCE_TO_EDGE':n.inputs['Randomness'].default_value=.70
        if n.bl_idname=='ShaderNodeBump':n.inputs['Strength'].default_value=.14;n.inputs['Distance'].default_value=.00018

def stage12(h):
    from mathutils.bvhtree import BVHTree
    body=bpy.data.objects['Trout body'];tree=BVHTree.FromObject(body,bpy.context.evaluated_depsgraph_get())
    for s in [-1,1]:
        for prefix in ['Eye socket','Iris','Pupil']:
            o=bpy.data.objects[prefix+' '+str(s)];o.hide_render=True;o.hide_set(True)
        point,normal,idx,distance=tree.ray_cast(Vector((-.148,s*.1,.013)),Vector((0,-s,0)))
        assert point is not None
        for name,offset,scale,material in [
          ('Recessed eye surround',.0002,(.008,.001,.008),bpy.data.materials['Trout eye surround']),
          ('Natural iris',.0012,(.0064,.0013,.0064),bpy.data.materials['Trout iris']),
          ('Natural pupil',.0023,(.0047,.0008,.0047),bpy.data.materials['Trout pupil'])]:
            o=h.ell(name+' '+str(s),point+normal*offset,scale,material);o.rotation_euler=normal.to_track_quat('Y','Z').to_euler()

def stage13(h):
    # The open body's raycast normal pointed inward, hiding the pupil layers.
    # Choose the outward hemisphere explicitly; verify in the final close-up.
    for s in [-1,1]:
        for name,offset in [('Recessed eye surround',.0002),('Natural iris',.0012),('Natural pupil',.0023)]:
            o=bpy.data.objects[name+' '+str(s)];normal=o.rotation_euler.to_matrix()@Vector((0,1,0))
            if normal.y*s<0:
                o.location-=normal*(2*offset);o.rotation_euler=(-normal).to_track_quat('Y','Z').to_euler()
            assert ((o.rotation_euler.to_matrix()@Vector((0,1,0))).y*s)>0
