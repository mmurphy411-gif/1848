"""Retained deer edits, three ranked repairs per pass."""
import bpy, math, random
from mathutils import Vector

def separate(o,h):
    # Connected islands recover the original sculpt and authored feature pieces.
    d=o.data;adj=[[] for v in d.vertices]
    for e in d.edges:
        a,b=e.vertices;adj[a].append(b);adj[b].append(a)
    seen=set();groups=[]
    for i in range(len(d.vertices)):
        if i in seen:continue
        todo=[i];seen.add(i);group=[]
        while todo:
            j=todo.pop();group.append(j)
            for k in adj[j]:
                if k not in seen:seen.add(k);todo.append(k)
        if len(group)>15:groups.append(group)
    results=[]
    for n,g in enumerate(sorted(groups,key=len,reverse=True)):
        ids={v:i for i,v in enumerate(g)}
        polys=[p for p in d.polygons if p.vertices[0] in ids]
        v=[o.matrix_world@d.vertices[i].co for i in g]
        part=h.mesh(o.name+' form '+str(n),v,[tuple(ids[i] for i in p.vertices) for p in polys],d.materials[polys[0].material_index])
        part['original_component']=o.name;results.append(part)
    return results

def archive(o):
    o.hide_render=True;o.hide_set(True);o.name='ARCHIVE | '+o.name

def ear(h,s):
    coat=h.mat('Deer tawny',(.24,.125,.058),.92)
    velvet=h.mat('Ear soft inner',(.32,.245,.17),.97)
    # Pointed, outward-splayed cupped pinna, not an oval stuck on the skull.
    base=Vector((s*.084,.598,1.64));tip=Vector((s*.327,.558,1.895))
    axis=tip-base;across=Vector((s*.72,0,-.69))
    vs=[];fs=[]
    for i in range(17):
        t=i/16;w=.082*math.sin(math.pi*t)**.78
        for j in range(13):
            u=(j/12-.5)*2
            p=base+axis*t+across*w*u;p.y+=.045*(1-u*u)*math.sin(math.pi*t)
            vs.append(p)
    for i in range(16):
        for j in range(12):a=i*13+j;fs.append((a,a+1,a+14,a+13))
    o=h.mesh('Ear pinna '+str(s),vs,fs,coat)
    sol=o.modifiers.new('Pinna thickness','SOLIDIFY');sol.thickness=.004
    sub=o.modifiers.new('Pinna softness','SUBSURF');sub.levels=1
    iv=[];ifaces=[]
    for i in range(15):
        t=.08+i/14*.82;w=.061*math.sin(math.pi*t)**.78
        for j in range(11):
            u=(j/10-.5)*2;p=base+axis*t+across*w*u
            p.y+=.047*(1-(u*.77)**2)*math.sin(math.pi*t)+.003;iv.append(p)
    for i in range(14):
        for j in range(10):a=i*11+j;ifaces.append((a,a+1,a+12,a+11))
    h.mesh('Ear velvet '+str(s),iv,ifaces,velvet)

def antlers(h):
    horn=h.mat('Antler base',(.24,.155,.085),.73)
    for s in [-1,1]:
        paths=[([(s*.071,.60,1.66),(s*.10,.573,1.77),(s*.18,.555,1.865),(s*.28,.57,1.96),(s*.34,.63,2.07),(s*.36,.685,2.15)], [.029,.031,.027,.019,.009,.001]),
          ([(s*.127,.566,1.81),(s*.143,.645,1.875),(s*.141,.68,1.96)],[.017,.012,.001]),
          ([(s*.195,.558,1.88),(s*.207,.52,1.99),(s*.205,.526,2.15)],[.02,.015,.001]),
          ([(s*.274,.57,1.956),(s*.287,.52,2.06),(s*.27,.52,2.20)],[.016,.011,.001])]
        for j,(pts,r) in enumerate(paths):
            o=h.tube('Antler '+str(s)+' branch '+str(j),pts,r,horn,16)
            sub=o.modifiers.new('Organic horn','SUBSURF');sub.levels=2

def stage1(h):
    # 1. Recontour original torso and head-neck skin; keep recoverable source islands.
    bodyparts=separate(bpy.data.objects['Body'],h)
    headparts=separate(bpy.data.objects['Head'],h)
    archive(bpy.data.objects['Body']);archive(bpy.data.objects['Head'])
    body=bodyparts[0];body.name='Deer body skin'
    coat=h.mat('Deer tawny',(.24,.125,.058),.92);h.assign(body,coat)
    for o in bodyparts[1:]:archive(o)
    def body_shape(p):
        x,y,z=p;return (x*(1.04+.08*math.exp(-((y-.30)/.24)**2)),y, z+.09 + .04*math.exp(-((y-.27)/.21)**2))
    h.world_edit(body,body_shape)
    head=headparts[0];head.name='Deer head neck skin';h.assign(head,coat)
    def head_shape(p):
        x,y,z=p
        t=max(0,min(1,(z-1.05)/.55))
        return (x*(1.1+.3*(1-t)),y-.07*t,z+.03*(1-t))
    for o in headparts:
        lo=min(v.co.z for v in o.data.vertices);hi=max(v.co.z for v in o.data.vertices)
        if hi>1.72:archive(o)
        else:h.world_edit(o,head_shape)
    # 2. Buck identity: broad alert ears and branched antlers.
    for s in [-1,1]:ear(h,s)
    antlers(h)
    # 3. More leg length and staggered hind stance, using original limb meshes.
    for name in ['FrontL','FrontR','HindL','HindR']:
        for nm in [name,name+'Lower']:
            o=bpy.data.objects[nm]
            def limb(p):
                x,y,z=p;z=max(0,z+.01125)*1.12
                if name.startswith('Hind'):
                    # Stifle is forward; hock rearward; hoof falls beneath haunch.
                    y+=.14*math.exp(-((z-.75)/.20)**2)
                    if name.endswith('R'):y-=.09*(1-min(1,z/1.1))
                return(x,y,z)
            h.world_edit(o,limb)

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
    else:raise ValueError(step)

def stage2(h):
    coat=bpy.data.materials['Deer tawny']
    # 1. Merge the existing skin forms into continuous anatomy, including shoulders.
    body=bpy.data.objects['Deer body skin'];head=bpy.data.objects['Deer head neck skin']
    def torso(p):
        x,y,z=p
        # Tuck the abdomen and flatten the excessive rump dome.
        lower=max(0,min(1,(1.09-z)/.31))
        z+=.105*lower*math.exp(-((y+.07)/.38)**2)
        z-=.035*max(0,min(1,(z-1.15)/.17))*math.exp(-((y+.40)/.23)**2)
        return x,y,z
    h.world_edit(body,torso)
    skin=[body,head]
    for name in ['FrontL','FrontR','HindL','HindR']:
        for nm in [name,name+'Lower']:
            o=bpy.data.objects[nm];parts=separate(o,h);archive(o)
            for p in parts:
                if 'Hoof' in p.data.materials[0].name:archive(p)
                else:skin.append(p)
    for s in [-1,1]:
        skin.append(h.ell('Shoulder transition',(s*.137,.35,1.06),(.088,.145,.245),coat))
        skin.append(h.ell('Haunch transition',(s*.15,-.38,1.035),(.101,.19,.225),coat))
    bpy.ops.object.select_all(action='DESELECT')
    for o in skin:o.select_set(True)
    bpy.context.view_layer.objects.active=body;bpy.ops.object.join();body.name='Deer continuous anatomy';h.assign(body,coat)
    rem=body.modifiers.new('Continuous original forms','REMESH');rem.mode='VOXEL';rem.voxel_size=.007
    bpy.ops.object.modifier_apply(modifier=rem.name)
    smooth=body.modifiers.new('Relax anatomical junctions','SMOOTH');smooth.factor=1.1;smooth.iterations=7;bpy.ops.object.modifier_apply(modifier=smooth.name)
    dec=body.modifiers.new('Retained sculpt resolution','DECIMATE');dec.ratio=.60;bpy.ops.object.modifier_apply(modifier=dec.name)
    for p in body.data.polygons:p.use_smooth=True
    # Remove floating throat insert; markings will follow the actual neck surface.
    archive(bpy.data.objects['Head form 3'])
    # 2. True split hooves, sloped coronets and small rear dewclaws.
    hoof=h.mat('Deer dark horn',(.029,.024,.02),.48)
    for front in [True,False]:
        for s in [-1,1]:
            x=s*(.145 if front else .16)
            y=.425 if front else -.465-(.09 if s>0 else 0)
            for c in [-1,1]:
                o=h.ell(('Fore' if front else 'Hind')+' cloven hoof '+str(s)+' '+str(c),(x+c*.018,y,.040),(.0165,.065,.043),hoof)
                def shape(p):
                    px,py,pz=p
                    return px,py+max(0,.055-pz)*.28,max(0,pz-.005)
                h.world_edit(o,shape)
                h.ell('Dewclaw',(x+c*.023,y-.059,.098),(.009,.014,.018),hoof)
    # 3. Ear/antler seating and full tapered black tail.
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(('Antler','Ear pinna','Ear velvet')):
            h.world_edit(o,lambda p:(p.x,p.y+.035,p.z-.050))
    archive(bpy.data.objects['Tail'])
    tail=h.mat('Deer black tail',(.012,.011,.010),.95)
    h.tube('Black tail',[(0,-.612,1.24),(0,-.693,1.17),(0,-.739,1.055),(0,-.744,.93),(0,-.731,.885)],[.055,.067,.058,.035,.003],tail,24)

def stage3(h):
    skin=bpy.data.objects['Deer continuous anatomy'];coat=bpy.data.materials['Deer tawny']
    # 1. Longer upright neck over a less barrel-shaped trunk.
    for o in list(bpy.context.scene.objects):
        if o.type!='MESH' or o.hide_render:continue
        def shape(p):
            x,y,z=p
            z+=.135*max(0,min(1,(z-1.25)/.28))
            if z>1.28 and y>.32:y-=.035*max(0,min(1,(z-1.28)/.30))
            return x,y*.94,z
        h.world_edit(o,shape)
    # 2. Hind stance and pasterns that actually join the hoof coronets.
    def stance(p):
        x,y,z=p
        if y<-.1 and z<.72:
            shift=(-.11 if x>0 else .14)*max(0,1-z/.72)
            y+=shift
        return x,y,z
    for o in list(bpy.context.scene.objects):
        if o.type=='MESH' and not o.hide_render:h.world_edit(o,stance)
    extras=[]
    for front in [True,False]:
        for s in [-1,1]:
            x=s*(.145 if front else .16)
            y=.3995 if front else (-.465-(.09 if s>0 else 0))*.94+(-.104 if s>0 else .132)
            starty=.387 if front else (-.48-(.085 if s>0 else 0))*.94+(-.09 if s>0 else .113)
            extras.append(h.tube('Pastern join',[(x,starty,.17),(x,y-.020,.10),(x,y-.01,.052)],[.022,.022,.029],coat,16))
    h.active(skin)
    for o in extras:o.select_set(True)
    bpy.ops.object.join()
    rem=skin.modifiers.new('Pastern continuity','REMESH');rem.mode='VOXEL';rem.voxel_size=.006;bpy.ops.object.modifier_apply(modifier=rem.name)
    sm=skin.modifiers.new('Anatomical blending','SMOOTH');sm.factor=.8;sm.iterations=4;bpy.ops.object.modifier_apply(modifier=sm.name)
    for p in skin.data.polygons:p.use_smooth=True
    # 3. Three-dimensional antler forks and larger eyes in anatomical sockets.
    for o in list(bpy.context.scene.objects):
        if o.name.startswith('Antler'):
            branch=int(o.name.split()[-1])
            def antler(p):
                t=max(0,min(1,(p.z-1.86)/.38));return p.x,p.y+({0:.13,1:.14,2:-.13,3:-.02}[branch])*t,p.z
            h.world_edit(o,antler)
    dark=h.mat('Deer eyelid',(.045,.026,.012),.79)
    eye=h.mat('Deer amber iris',(.105,.052,.012),.3)
    black=h.mat('Deer wet pupil',(.003,.003,.002),.12)
    for nm in ['Head form 4','Head form 5','Head form 6','Head form 7']:archive(bpy.data.objects[nm])
    for s in [-1,1]:
        center=(s*.11,.638,1.686)
        h.ell('Eye orbit '+str(s),center,(.017,.029,.025),coat)
        h.ell('Eyelid '+str(s),(s*.123,.645,1.687),(.009,.023,.019),dark)
        h.ell('Deer iris '+str(s),(s*.130,.648,1.687),(.006,.018,.015),eye)
        h.ell('Deer pupil '+str(s),(s*.134,.649,1.687),(.003,.012,.011),black)

def stage4(h):
    # 1. Repair antler branch joins exposed by the side camera, shorten the rack.
    horns=[]
    for o in list(bpy.context.scene.objects):
        if not o.name.startswith('Antler') or o.type!='MESH':continue
        branch=int(o.name.split()[-1]);lo=min(v.co.z for v in o.data.vertices);hi=max(v.co.z for v in o.data.vertices)
        def repair(p):
            oldt=max(0,min(1,(p.z-1.86)/.38));delta={0:.13,1:.14,2:-.13,3:-.02}[branch]
            t=max(0,min(1,(p.z-lo)/(hi-lo)));y=p.y-delta*oldt+delta*t*.7
            return p.x,y,1.78+(p.z-1.78)*.81
        h.world_edit(o,repair);h.active(o)
        for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
        horns.append(o)
    for s in [-1,1]:
        pieces=[o for o in bpy.context.scene.objects if ('Antler '+str(s)+' ') in o.name]
        h.active(pieces[0])
        for o in pieces:o.select_set(True)
        bpy.ops.object.join();o=pieces[0];o.name='Buck antler '+str(s)
        rem=o.modifiers.new('Fused horn branches','REMESH');rem.mode='VOXEL';rem.voxel_size=.0025;bpy.ops.object.modifier_apply(modifier=rem.name)
        sm=o.modifiers.new('Horn junction smoothing','SMOOTH');sm.factor=.9;sm.iterations=3;bpy.ops.object.modifier_apply(modifier=sm.name)
        for p in o.data.polygons:p.use_smooth=True
    # 2. Recontour round shoulder/haunch caps and elongate the facial bridge.
    skin=bpy.data.objects['Deer continuous anatomy']
    def anatomy(p):
        x,y,z=p
        bulge=math.exp(-((y+.36)/.20)**2-((z-1.08)/.25)**2)
        x*=1-.20*bulge
        # Raise top of rump to remove saddle-like scallop, taper brisket.
        if z>1.12 and y<.18:z+=.045*math.exp(-((y+.18)/.27)**2)*min(1,(z-1.12)/.10)
        if y>.31 and z<1.08:y-=.038*math.exp(-((z-.91)/.15)**2)
        if z>1.56 and y>.70:y+=.060*max(0,min(1,(y-.7)/.17))
        return x,y,z
    h.world_edit(skin,anatomy)
    h.active(skin);sm=skin.modifiers.new('Shoulder flow','SMOOTH');sm.factor=.9;sm.iterations=12;bpy.ops.object.modifier_apply(modifier=sm.name)
    for nm in ['Head form 1','Head form 2']:
        o=bpy.data.objects[nm];h.world_edit(o,lambda p:(p.x*.84,p.y+.047,p.z))
    # Eyes sit within the skull instead of protruding like beads.
    for o in list(bpy.context.scene.objects):
        if o.name.startswith(('Eye orbit','Eyelid','Deer iris','Deer pupil')):
            s=-1 if '-1' in o.name else 1;o.location.y+=.030;o.location.x-=s*.016
    # 3. Major coat fields follow continuous skin rather than floating white inserts.
    attr=skin.data.color_attributes.get('Coat fields') or skin.data.color_attributes.new(name='Coat fields',type='FLOAT_COLOR',domain='POINT')
    for i,v in enumerate(skin.data.vertices):
        x,y,z=skin.matrix_world@v.co
        dark=.24*max(0,min(1,(z-1.15)/.2)) if y<.3 else 0
        c=[.27*(1-dark),.135*(1-dark),.062*(1-dark)]
        throat=math.exp(-((z-1.40)/.28)**4-((x)/.12)**4)*max(0,min(1,(y-.43)/.15))
        belly=math.exp(-((z-.89)/.09)**2)*math.exp(-((y+.04)/.42)**6)
        rump=max(0,min(1,(-y-.46)/.12))*math.exp(-(x/.18)**4)*math.exp(-((z-1.075)/.19)**4)
        muzzle=math.exp(-((z-1.575)/.06)**2)*max(0,min(1,(y-.73)/.15))
        pale=max(throat*.84,belly*.75,rump*.90,muzzle*.70)
        c=[c[k]*(1-pale)+[.57,.51,.40][k]*pale for k in range(3)]
        forehead=math.exp(-((z-1.765)/.09)**2-((y-.60)/.17)**2)
        c=[a*(1-.25*forehead) for a in c];attr.data[i].color=(*c,1)
    m=h.mat('Deer anatomical coat',(.27,.135,.062),.9);nodes=m.node_tree.nodes;links=m.node_tree.links
    n=nodes.new('ShaderNodeVertexColor');n.layer_name='Coat fields';links.new(n.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color']);h.assign(skin,m)
    h.assign(bpy.data.objects['Head form 1'],h.mat('Deer muzzle pale',(.40,.34,.25),.9))
    tail=bpy.data.objects['Black tail'];sub=tail.modifiers.new('Tail rounded section','SUBSURF');sub.levels=2

def stage5(h):
    # 1. Continuous rack: sample curved branches densely without shrinking their roots.
    for o in list(bpy.context.scene.objects):
        if o.name.startswith('Buck antler'):archive(o)
    horn=bpy.data.materials['Antler base']
    for s in [-1,1]:
        paths=[([(s*.067,.55,1.735),(s*.095,.535,1.80),(s*.17,.535,1.89),(s*.27,.565,1.975),(s*.34,.62,2.06),(s*.37,.66,2.13)],[.032,.032,.030,.024,.014,.0007]),
          ([(s*.12,.535,1.83),(s*.13,.58,1.89),(s*.13,.63,1.98)],[.021,.013,.0007]),
          ([(s*.187,.54,1.905),(s*.205,.51,1.99),(s*.19,.48,2.14)],[.026,.017,.0007]),
          ([(s*.274,.565,1.98),(s*.284,.565,2.045),(s*.277,.59,2.17)],[.021,.015,.0007])]
        pieces=[]
        for j,(pts,rs) in enumerate(paths):
            pts=[Vector(p) for p in pts];curve=[];r=[]
            for i in range(len(pts)-1):
                a=pts[max(0,i-1)];b=pts[i];c=pts[i+1];d=pts[min(len(pts)-1,i+2)]
                for k in range(8):
                    t=k/8;curve.append(.5*((2*b)+(-a+c)*t+(2*a-5*b+4*c-d)*t*t+(-a+3*b-3*c+d)*t*t*t));r.append(rs[i]*(1-t)+rs[i+1]*t)
            curve.append(pts[-1]);r.append(rs[-1]);pieces.append(h.tube('Continuous rack branch',curve,r,horn,16))
        h.active(pieces[0])
        for o in pieces:o.select_set(True)
        bpy.ops.object.join();o=pieces[0];o.name='Buck antler '+str(s)
        rem=o.modifiers.new('Solid branched horn','REMESH');rem.mode='VOXEL';rem.voxel_size=.002;bpy.ops.object.modifier_apply(modifier=rem.name)
        sm=o.modifiers.new('Horn joins','SMOOTH');sm.factor=.8;sm.iterations=3;bpy.ops.object.modifier_apply(modifier=sm.name)
        for p in o.data.polygons:p.use_smooth=True
    # 2. Facial plane and ear continuity, followed by local smoothing of the neck root.
    for s in [-1,1]:
        archive(bpy.data.objects['Ear velvet '+str(s)])
        earobj=bpy.data.objects['Ear pinna '+str(s)]
        earobj.data.materials.append(h.mat('Deer ear interior',(.33,.27,.20),.94))
        for i,p in enumerate(earobj.data.polygons):
            row=i//12;col=i%12;p.material_index=1 if 2<=row<=13 and 2<=col<=9 else 0
        for prefix in ['Eye orbit','Eyelid','Deer iris','Deer pupil']:
            o=bpy.data.objects[prefix+' '+str(s)];o.location.x-=s*.006
        h.assign(bpy.data.objects['Deer iris '+str(s)],h.mat('Deer dark amber',(.038,.019,.006),.22))
    skin=bpy.data.objects['Deer continuous anatomy']
    vg=skin.vertex_groups.new(name='Neck root smoothing')
    for v in skin.data.vertices:
        x,y,z=skin.matrix_world@v.co
        w=math.exp(-((z-1.16)/.17)**4)*max(0,min(1,(y-.25)/.2))
        if w>.001:vg.add([v.index],w,'REPLACE')
    h.active(skin);sm=skin.modifiers.new('Remove neck cap ridge','SMOOTH');sm.factor=1.2;sm.iterations=35;sm.vertex_group=vg.name;bpy.ops.object.modifier_apply(modifier=sm.name)
    # 3. Sloped hard hoof capsules with flatter planted soles; restrained dewclaws.
    for o in list(bpy.context.scene.objects):
        if o.hide_render or o.type!='MESH':continue
        if 'cloven hoof' in o.name:
            center=o.location.copy()
            for v in o.data.vertices:
                v.co.y*=.83;v.co.z=max(-center.z,v.co.z)
                # Lower toe, high rear coronet.
                v.co.z-=max(0,v.co.y)*.24
        elif o.name.startswith('Dewclaw'):o.scale*=.65

def stage6(h):
    # 1. Refit all four hoof pairs to the actual retained limb endpoints.
    skin=bpy.data.objects['Deer continuous anatomy'];coat=bpy.data.materials['Deer tawny'];hoof=bpy.data.materials['Deer dark horn']
    for o in list(bpy.context.scene.objects):
        if not o.hide_render and ('cloven hoof' in o.name or o.name.startswith('Dewclaw')):archive(o)
    for front in [True,False]:
        for s in [-1,1]:
            pts=[skin.matrix_world@v.co for v in skin.data.vertices if (skin.matrix_world@v.co).x*s>.05 and ((skin.matrix_world@v.co).y>0)==front and (skin.matrix_world@v.co).z<.18]
            low=min(p.z for p in pts);bottom=[p for p in pts if p.z<low+.013];center=sum(bottom,Vector())/len(bottom)
            x,y=center.x,center.y
            h.tube('Coronet bridge '+str(front)+' '+str(s),[(x,y,low+.025),(x,y,.075),(x,y+.01,.049)],[.023,.024,.028],coat,16)
            for toe in [-1,1]:
                cx=x+toe*.016
                vs=[(cx-.014,y-.021,0),(cx+.014,y-.021,0),(cx+.015,y+.070,0),(cx-.015,y+.070,0),
                    (cx-.015,y-.025,.066),(cx+.015,y-.025,.066),(cx+.013,y+.051,.027),(cx-.013,y+.051,.027)]
                fs=[(0,3,2,1),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(4,5,6,7)]
                o=h.mesh('Planted split hoof '+str(front)+' '+str(s)+' '+str(toe),vs,fs,hoof)
                bevel=o.modifiers.new('Horn edge rounding','BEVEL');bevel.width=.004;bevel.segments=3
                for p in o.data.polygons:p.use_smooth=False
    # 2. More graceful brisket and hock-to-thigh taper in the retained surface.
    def shape(p):
        x,y,z=p
        if y>.15 and .80<z<1.13:
            x*=1-.10*math.exp(-((z-.91)/.13)**2)
        if y<-.14 and .58<z<.94:
            x*=1-.09*math.exp(-((z-.80)/.14)**2)
        return x,y,z
    h.world_edit(skin,shape)
    # 3. Flatten and widen the nose's upper plane; give the muzzle a real lip line.
    nose=bpy.data.objects['Head form 2'];pts=[nose.matrix_world@v.co for v in nose.data.vertices]
    center=sum(pts,Vector())/len(pts)
    h.world_edit(nose,lambda p:(center.x+(p.x-center.x)*1.08,p.y,center.z+(p.z-center.z)*.76))
    dark=h.mat('Deer lip',(.026,.016,.009),.62)
    for s in [-1,1]:
        h.tube('Muzzle lip '+str(s),[(0,.961,1.582),(s*.040,.948,1.578),(s*.061,.918,1.577),(s*.064,.883,1.583)],[.003,.003,.0025,.001],dark)

def stage7(h):
    # Repair local edit boundaries before declaring the form checkpoint.
    skin=bpy.data.objects['Deer continuous anatomy']
    def smooth_taper(p):
        x,y,z=p
        if y>.15 and .80<z<1.13:x/=1-.10*math.exp(-((z-.91)/.13)**2)
        if y<-.14 and .58<z<.94:x/=1-.09*math.exp(-((z-.80)/.14)**2)
        chest=.08*math.exp(-((z-.91)/.13)**2)*(.5+.5*math.tanh((y-.20)/.08))
        haunch=.06*math.exp(-((z-.80)/.14)**2)*(.5-.5*math.tanh((y+.19)/.08))
        return x*(1-chest-haunch),y,z
    h.world_edit(skin,smooth_taper)
    # The previous lip sweep protruded beyond the muzzle; place it on the jaw.
    for o in list(bpy.context.scene.objects):
        if o.name.startswith('Muzzle lip'):archive(o)
    jaw=bpy.data.objects['Head form 1'];pts=[jaw.matrix_world@v.co for v in jaw.data.vertices];c=sum(pts,Vector())/len(pts)
    for s in [-1,1]:
        h.tube('Seated lip '+str(s),[(0,c.y+.122,c.z+.009),(s*.035,c.y+.095,c.z+.006),(s*.055,c.y+.049,c.z+.004),(s*.058,c.y+.018,c.z+.010)],[.0015,.002,.002,.0006],bpy.data.materials['Deer lip'])
    # Fit the front pastern to the retained leg's lower end without a silhouette step.
    for o in list(bpy.context.scene.objects):
        if o.name.startswith('Coronet bridge'):
            h.active(o);sub=o.modifiers.new('Pastern taper','SUBSURF');sub.levels=2
    bpy.context.scene['form_gate']='Pass 7: silhouette/proportions reviewed before polish'

def stage8(h):
    # POLISH 1: groomed short coat, richer tawny fields, and horn grain.
    skin=bpy.data.objects['Deer continuous anatomy'];colors=skin.data.color_attributes['Coat fields']
    for item in colors.data:
        r,g,b,a=item.color;item.color=(r*.70,g*.66,b*.60,1)
    m=bpy.data.materials['Deer anatomical coat'];nodes=m.node_tree.nodes;links=m.node_tree.links;p=nodes.get('Principled BSDF')
    tex=nodes.new('ShaderNodeTexNoise');tex.inputs['Scale'].default_value=240;tex.inputs['Detail'].default_value=2
    geo=nodes.new('ShaderNodeNewGeometry');mapping=nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(2,2,.4)
    links.new(geo.outputs['Position'],mapping.inputs[0]);links.new(mapping.outputs[0],tex.inputs['Vector'])
    bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.23;bump.inputs['Distance'].default_value=.0015;links.new(tex.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],p.inputs['Normal'])
    p.inputs['Roughness'].default_value=.91;p.inputs['Sheen Weight'].default_value=.25
    # Geometric fibers are rooted on the actual retained surface, with anatomical
    # direction and pigment interpolated from the coat fields.
    groom(h,skin,95000,.018,colors)
    tail=bpy.data.objects['Black tail'];groom(h,tail,6500,.025,None)
    for s in [-1,1]:groom(h,bpy.data.objects['Ear pinna '+str(s)],3500,.010,None)
    for name in ['Antler base','Deer dark horn']:
        m=bpy.data.materials[name];n=m.node_tree.nodes;l=m.node_tree.links;p=n.get('Principled BSDF')
        coord=n.new('ShaderNodeTexCoord');mapping=n.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(4,4,.3)
        l.new(coord.outputs['Generated'],mapping.inputs[0]);noise=n.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=40;noise.inputs['Detail'].default_value=3;l.new(mapping.outputs[0],noise.inputs[0])
        bump=n.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.3;bump.inputs['Distance'].default_value=.002;l.new(noise.outputs['Fac'],bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])

def groom(h,o,count,length,colors):
    rng=random.Random(1848+count);bpy.context.view_layer.update();o.data.calc_loop_triangles()
    tris=list(o.data.loop_triangles);weights=[t.area for t in tris];vs=[];fs=[];pigments=[]
    for t in rng.choices(tris,weights=weights,k=count):
        ids=list(t.vertices);pts=[o.matrix_world@o.data.vertices[i].co for i in ids]
        u,v=rng.random(),rng.random()
        if u+v>1:u=1-u;v=1-v
        pos=pts[0]*(1-u-v)+pts[1]*u+pts[2]*v
        normal=(pts[1]-pts[0]).cross(pts[2]-pts[0]).normalized()
        if normal.length<.5:continue
        if 'Ear pinna' in o.name:direction=Vector((pos.x*.6,0,-1));ln=length
        elif o.name=='Black tail':direction=Vector((0,-.2,-1));ln=length
        elif pos.z>1.52:direction=Vector((0,-.45,-.8));ln=.006
        elif pos.z>1.20 and pos.y>.25:direction=Vector((0,-.15,-1));ln=.024
        elif pos.z<.70:direction=Vector((0,-.12,-1));ln=.010
        else:direction=Vector((0,-1,-.30));ln=length
        tangent=direction-normal*direction.dot(normal)
        if tangent.length<.01:tangent=normal.cross(Vector((1,0,0)))
        tangent.normalize();side=normal.cross(tangent).normalized()
        ln*=rng.uniform(.55,1.45);width=ln*rng.uniform(.018,.045)
        a=pos+normal*.00025;mid=pos+tangent*ln*.5+normal*ln*.17;tip=pos+tangent*ln+normal*ln*.13
        start=len(vs);vs.extend([a-side*width,a+side*width,mid+side*width*.65,tip,mid-side*width*.65]);fs.extend([(start,start+1,start+2,start+4),(start+4,start+2,start+3)])
        if colors:
            c=[colors.data[ids[0]].color[k]*(1-u-v)+colors.data[ids[1]].color[k]*u+colors.data[ids[2]].color[k]*v for k in range(3)]
        elif o.name=='Black tail':c=[.012,.01,.008]
        else:c=[.22,.15,.088]
        tone=rng.uniform(.55,1.4)
        pigments.extend([(*(max(.003,min(.9,c[k]*tone)) for k in range(3)),1)]*5)
    material=h.mat('Deer fiber pigment',(.2,.1,.05),.92);nodes=material.node_tree.nodes;links=material.node_tree.links
    if not nodes.get('Pigment'):
        node=nodes.new('ShaderNodeVertexColor');node.name='Pigment';node.layer_name='Fiber color';links.new(node.outputs['Color'],nodes.get('Principled BSDF').inputs['Base Color']);nodes.get('Principled BSDF').inputs['Sheen Weight'].default_value=.35
    fibers=h.mesh('Groom | '+o.name,vs,fs,material);attr=fibers.data.color_attributes.new(name='Fiber color',type='FLOAT_COLOR',domain='POINT')
    attr.data.foreach_set('color',[v for c in pigments for v in c])
    for p in fibers.data.polygons:p.use_smooth=False

def stage9(h):
    # POLISH 2: soften the face/neck hair boundary and add restrained eye/nose detail.
    skin=bpy.data.objects['Deer continuous anatomy'];colors=skin.data.color_attributes['Coat fields']
    # Surface detail on the head follows geometry, and softly darkens the forehead.
    for i,v in enumerate(skin.data.vertices):
        x,y,z=skin.matrix_world@v.co
        if z>1.53:
            r,g,b,a=colors.data[i].color
            dark=.32*math.exp(-((z-1.72)/.13)**2)*max(0,min(1,(y-.42)/.18))
            colors.data[i].color=(r*(1-dark),g*(1-dark),b*(1-dark),1)
    # Localized face groom from the exact retained head triangles.
    faces=[];used=set()
    for p in skin.data.polygons:
        if all((skin.matrix_world@skin.data.vertices[i].co).z>1.48 for i in p.vertices):faces.append(p);used.update(p.vertices)
    ids={old:i for i,old in enumerate(sorted(used))};vs=[skin.matrix_world@skin.data.vertices[i].co for i in sorted(used)]
    temp=h.mesh('Face groom sampling surface',vs,[tuple(ids[i] for i in p.vertices) for p in faces],skin.data.materials[0]);attr=temp.data.color_attributes.new(name='Coat fields',type='FLOAT_COLOR',domain='POINT')
    for old,i in ids.items():attr.data[i].color=colors.data[old].color
    groom(h,temp,19000,.007,attr);bpy.data.objects.remove(temp,do_unlink=True)
    for s in [-1,1]:
        o=bpy.data.objects['Ear pinna '+str(s)]
        # Duplicate sampling with outward-facing normals for the mirrored ear.
        if s<0:
            import bmesh
            bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.reverse_faces(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
            groom(h,o,4500,.009,None)
    nose=bpy.data.objects['Head form 2'];pts=[nose.matrix_world@v.co for v in nose.data.vertices];c=sum(pts,Vector())/len(pts)
    nostril=h.mat('Deer nostril',(.003,.003,.002),.5)
    for s in [-1,1]:h.ell('Nostril '+str(s),(s*.041,c.y+.031,c.z+.004),(.016,.006,.010),nostril)
    bpy.context.scene['form_gate']='Pass 7: subjective silhouette 8/10, proportions 8/10; polish begins at pass 8'

def stage10(h):
    # POLISH 3: deepen tawny/horn values, restrain nose inserts, break fiber uniformity.
    skin=bpy.data.objects['Deer continuous anatomy']
    for item in skin.data.color_attributes['Coat fields'].data:
        r,g,b,a=item.color;item.color=(r*.75,g*.72,b*.68,1)
    rng=random.Random(184810)
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or o.hide_render:continue
        attr=o.data.color_attributes.get('Fiber color')
        if attr:
            for item in attr.data:
                r,g,b,a=item.color;item.color=(r*.73,g*.69,b*.64,1)
        if o.name.startswith('Nostril'):o.location.y-=.007
    p=bpy.data.materials['Antler base'].node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.105,.060,.028,1)
    # Ear interiors retain warm pale values while the rims stay dark.
    bpy.data.materials['Deer ear interior'].node_tree.nodes.get('Principled BSDF').inputs['Base Color'].default_value=(.25,.20,.145,1)

def stage11(h):
    # The topology audit found one eight-vertex remesh speck per tine tip.
    import bmesh
    for s in [-1,1]:
        o=bpy.data.objects['Buck antler '+str(s)];bm=bmesh.new();bm.from_mesh(o.data);seen=set();remove=[]
        for v in bm.verts:
            if v in seen:continue
            todo=[v];seen.add(v);group=[]
            while todo:
                a=todo.pop();group.append(a)
                for e in a.link_edges:
                    b=e.other_vert(a)
                    if b not in seen:seen.add(b);todo.append(b)
            if len(group)<20:remove+=group
        bmesh.ops.delete(bm,geom=remove,context='VERTS');bm.to_mesh(o.data);bm.free()

def stage12(h):
    from mathutils.bvhtree import BVHTree
    skin=bpy.data.objects['Deer continuous anatomy'];tree=BVHTree.FromObject(skin,bpy.context.evaluated_depsgraph_get());inv=skin.matrix_world.inverted()
    for s in [-1,1]:
        for prefix in ['Eye orbit','Eyelid','Deer iris','Deer pupil']:archive(bpy.data.objects[prefix+' '+str(s)])
        local,normal,idx,distance=tree.ray_cast(inv@Vector((s*.5,.670,1.687)),Vector((-s,0,0)))
        assert local is not None;point=skin.matrix_world@local;normal=skin.matrix_world.to_3x3()@normal
        for name,offset,scale,material in [
          ('Natural eyelid',.001,(.024,.002,.020),h.mat('Deer orbital dark',(.025,.014,.007),.74)),
          ('Natural iris',.0025,(.0185,.003,.0155),bpy.data.materials['Deer dark amber']),
          ('Natural pupil',.005,(.013,.002,.011),bpy.data.materials['Deer wet pupil'])]:
            o=h.ell(name+' '+str(s),point+normal*offset,scale,material);o.rotation_euler=normal.to_track_quat('Y','Z').to_euler()
    for o in list(bpy.context.scene.objects):
        if o.name.startswith('Nostril'):archive(o)
    nose=bpy.data.objects['Head form 2'];h.active(nose);sub=nose.modifiers.new('Nasal surface','SUBSURF');sub.levels=2;bpy.ops.object.modifier_apply(modifier=sub.name)
    for s in [-1,1]:
        bpy.context.view_layer.update();tree=BVHTree.FromObject(nose,bpy.context.evaluated_depsgraph_get());inv=nose.matrix_world.inverted()
        p,n,idx,d=tree.ray_cast(inv@Vector((s*.037,1.04,1.585)),Vector((0,-1,0)))
        assert p is not None;p=nose.matrix_world@p;n=nose.matrix_world.to_3x3()@n
        cutter=h.ell('Nostril cutting volume',p-n*.006,(.013,.018,.009),bpy.data.materials['Deer nostril']);cutter.rotation_euler=n.to_track_quat('Y','Z').to_euler()
        h.active(nose);mod=nose.modifiers.new('Inset nostril','BOOLEAN');mod.operation='DIFFERENCE';mod.solver='EXACT';mod.object=cutter;bpy.ops.object.modifier_apply(modifier=mod.name);bpy.data.objects.remove(cutter,do_unlink=True)
