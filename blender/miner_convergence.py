"""Incremental reference convergence. Run with Blender background --python, -- stage."""
import bpy, math, json, sys
from pathlib import Path
from mathutils import Vector, Matrix
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'artifacts'/'miner-convergence'
OUT.mkdir(parents=True,exist_ok=True)
STAGE=int(sys.argv[sys.argv.index('--')+1]) if '--' in sys.argv else 0

def setup_review():
    scene=bpy.context.scene
    scene.render.engine='CYCLES';scene.cycles.samples=24
    try:
        prefs=bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type='OPTIX';prefs.get_devices()
        for d in prefs.devices:d.use=d.type!='CPU'
        scene.cycles.device='GPU'
    except Exception:pass
    scene.render.resolution_x=650;scene.render.resolution_y=900;scene.render.resolution_percentage=100
    scene.render.image_settings.file_format='PNG'
    scene.view_settings.view_transform='AgX'
    scene.world.color=(.25,.25,.25)
    world=bpy.data.worlds.new('Review neutral world');world.use_nodes=True
    world.node_tree.nodes['Background'].inputs[0].default_value=(.45,.45,.45,1)
    world.node_tree.nodes['Background'].inputs[1].default_value=.65;scene.world=world
    col=bpy.data.collections.new('REVIEW | cameras and neutral lighting');scene.collection.children.link(col)
    for name,loc,energy,size in [('Key',(-3,-4,5),450,4),('Fill',(4,-2,3),280,3),('Back',(1,4,4),380,3)]:
        data=bpy.data.lights.new(name,'AREA');data.energy=energy;data.shape='DISK';data.size=size
        o=bpy.data.objects.new(name,data);col.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,1))-o.location).to_track_quat('-Z','Y').to_euler()
    for name,loc in [('front',(0,-7,.95)),('side',(-7,0,.95)),('back',(0,7,.95)),('three_quarter',(4,-7,.95))]:
        data=bpy.data.cameras.new(name);data.type='ORTHO';data.ortho_scale=2.12
        o=bpy.data.objects.new('Review '+name,data);col.objects.link(o);o.location=loc;o.rotation_euler=(Vector((0,0,.90))-o.location).to_track_quat('-Z','Y').to_euler()
    scene.render.film_transparent=False

def render(stage):
    scene=bpy.context.scene
    for view in ['front','side','back','three_quarter']:
        scene.camera=bpy.data.objects['Review '+view]
        scene.render.filepath=str(OUT/f'pass_{stage:02}_{view}.png');bpy.ops.render.render(write_still=True)

def split_body():
    bpy.ops.object.select_all(action='DESELECT');body=bpy.data.objects['Miner'];body.hide_set(False);body.select_set(True);bpy.context.view_layer.objects.active=body
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
    parts=list(bpy.context.selected_objects)
    for i,o in enumerate(sorted(parts,key=lambda o:min(v.co.z for v in o.data.vertices))):
        vs=o.data.vertices;lo=[min(v.co[k] for v in vs) for k in range(3)];hi=[max(v.co[k] for v in vs) for k in range(3)]
        slot=o.data.polygons[0].material_index;mat=o.data.materials[slot].name
        o.name=f'Part_{i:03}_{mat}'
        print(o.name,len(vs),[round(x,4) for x in lo],[round(x,4) for x in hi])
    return parts

def collection(name):
    c=bpy.data.collections.get(name)
    if not c:c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c)
    return c

def move(o,name):
    for c in list(o.users_collection):c.objects.unlink(o)
    collection(name).objects.link(o)

def material(name,color,rough=.8,metal=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name);m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    for socket in ['Base Color','Normal','Roughness']:
        for l in list(p.inputs[socket].links):m.node_tree.links.remove(l)
    p.inputs['Base Color'].default_value=(*color,1);p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal
    m.diffuse_color=(*color,1);return m

def assign(o,mat):
    o.data.materials.clear();o.data.materials.append(mat)
    for p in o.data.polygons:p.material_index=0

def mesh(name,v,f,mat,group='COSTUME',bone=None):
    data=bpy.data.meshes.new(name);data.from_pydata(v,[],f);data.update()
    o=bpy.data.objects.new(name,data);collection(group).objects.link(o);data.materials.append(mat)
    if bone:bind(o,bone)
    return o

def bind(o,bone):
    rig=bpy.data.objects['MinerRig'];o.parent=rig
    vg=o.vertex_groups.get(bone) or o.vertex_groups.new(name=bone);vg.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('Rig deformation','ARMATURE');mod.object=rig

def thickness(o,t):
    m=o.modifiers.new('Constructed thickness','SOLIDIFY');m.thickness=t

def ribbon(name,points,width,mat,group='COSTUME',bone=None):
    v=[];f=[]
    for p in points:v.extend([(p[0]-width/2,p[1],p[2]),(p[0]+width/2,p[1],p[2])])
    for i in range(len(points)-1):a=i*2;f.append((a,a+1,a+3,a+2))
    o=mesh(name,v,f,mat,group,bone);thickness(o,.003);return o

def tube(name,points,radii,mat,group='GEAR',sides=8,bone=None):
    pts=[Vector(p) for p in points];v=[];f=[]
    for j,p in enumerate(pts):
        d=(pts[min(j+1,len(pts)-1)]-pts[max(0,j-1)]).normalized()
        a=Vector((1,0,0)) if abs(d.x)<.9 else Vector((0,1,0));a=(a-d*a.dot(d)).normalized();b=d.cross(a)
        for k in range(sides):v.append(p+(a*math.cos(k*math.tau/sides)+b*math.sin(k*math.tau/sides))*radii[j])
    for j in range(len(pts)-1):
        for k in range(sides):a=j*sides+k;b=j*sides+(k+1)%sides;f.append((a,b,b+sides,a+sides))
    f.extend([tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+k for k in range(sides))])
    return mesh(name,v,f,mat,group,bone)

def finish(stage):
    bpy.context.view_layer.update()
    bpy.context.scene.camera=bpy.data.objects['Review three_quarter']
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'pass_{stage:02}.blend'))
    render(stage)
    # Material override is solely a diagnostic; authored materials remain intact.
    black=material('REVIEW silhouette',(0,0,0),1)
    p=black.node_tree.nodes.get('Principled BSDF');p.inputs['Specular IOR Level'].default_value=0
    bpy.context.view_layer.material_override=black
    for view in ['front','side','back','three_quarter']:
        bpy.context.scene.camera=bpy.data.objects['Review '+view]
        bpy.context.scene.render.filepath=str(OUT/f'pass_{stage:02}_silhouette_{view}.png');bpy.ops.render.render(write_still=True)
    bpy.context.view_layer.material_override=None

def pass_one():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_00_baseline.blend'))
    parts=split_body();lookup={int(o.name.split('_')[1]):o for o in parts}
    for idx,o in lookup.items():
        o['source_component']=idx;move(o,'BODY | original weighted components')
    cloth=material('Convergence | dirty cream linen',(.53,.45,.32),.92)
    vestmat=material('Convergence | charcoal brown vest',(.052,.042,.032),.88)
    red=material('Convergence | oxblood cotton',(.22,.040,.026),.9)
    leather=material('Convergence | worn leather',(.105,.053,.024),.73)
    felt=material('Convergence | battered brown felt',(.115,.078,.044),.96)
    # Recontour the ORIGINAL weighted sleeve rings; no subdivision or replacement body.
    for idx in [36,37,39,40]:
        o=lookup[idx];s=1 if idx in [36,39] else -1
        a0=Vector((s*.21,0,1.4));axis=Vector((s*.169,-.0045,-.4145))
        for v in o.data.vertices:
            p=v.co.copy();t=max(0,min(1,(p-a0).dot(axis)/axis.length_squared));c=a0+axis*t
            if idx in [36,37]:
                d=p-c;factor=.82+.05*t*t
                v.co=c+d*factor
                v.co.z-=.024*max(0,1-t*3)
                v.co.x-=s*.006*max(0,1-t*2)
            else:
                c=Vector((s*.38,-.0045,.991));d=p-c;v.co=c+Vector((d.x*.86,d.y*.86,d.z))
                angle=math.atan2(d.y,d.x);v.co.z+=.005*math.sin(angle*2+s*.8)
        for p in o.data.polygons:p.use_smooth=len(p.vertices)<5
        assign(o,cloth);o.name=('Shirt | sleeve ' if idx<39 else 'Shirt | compressed rolled cuff ')+('L' if s>0 else 'R')
    for idx in [35,43,48,49]:assign(lookup[idx],cloth)
    lookup[35].name='Shirt | hanging torso'
    # Unround the torso cross sections and establish a weighted, irregular tucked hem.
    for v in lookup[35].data.vertices:
        p=v.co;a=math.atan2(p.y/.145,p.x/.2);t=max(0,min(1,(p.z-.96)/.47))
        p.y*=.93
        p.z+=.009*math.sin(a*3+.7)*max(0,1-t*4)
        p.y+=.009*math.sin(a*7+t*2)*math.exp(-((t-.12)/.16)**2)
    # Broader shoulder bridge closes the old disconnected cap silhouettes.
    for v in lookup[35].data.vertices:
        if 1.36<v.co.z<1.44:v.co.x*=1.06
    # Hat retains original UV topology and Head weights, with slouch and crown dents.
    hat=lookup[71];hat.name='Hat | asymmetric slouch brim and dented crown';assign(hat,felt)
    for v in hat.data.vertices:
        x,y,z=v.co;a=math.atan2(y/.238,x/.27);r=math.sqrt((x/.27)**2+(y/.238)**2)
        if z<1.666:
            v.co.x*=.90;v.co.y*=.92
            v.co.z+=r**2*(-.005+.014*math.cos(a*2+.5)+.010*math.sin(a+.3)+.014*max(0,-math.sin(a)))+.002*r*math.sin(a*7)
        else:
            t=(z-1.665)/.115
            v.co.z=1.665+t*.106-.015*math.exp(-(x/.038)**2)*t**3+.010*x/.11*t
            v.co.x-=.009*t*t;v.co.y+=.006*t
    lookup[72].name='Hat | leather crown band';assign(lookup[72],leather)
    # Open vest: elliptical body panels, cut away beneath the arms, independent cloth thickness.
    for s in [-1,1]:
        v=[];f=[];rows=[(.987,.197,.148,.17),(1.055,.201,.155,.13),(1.15,.204,.16,.23),(1.26,.224,.164,.35),(1.35,.235,.145,.55),(1.425,.185,.088,.90)]
        for j,(z,w,d,start) in enumerate(rows):
            for k in range(17):
                t=k/16;a=start+(math.pi-start)*t
                # Cut side armholes at the upper two rows.
                zz=z-(.12 if j==5 else .035 if j==4 else 0)*math.sin(a)**6
                yy=-math.cos(a)*(d+.010);xx=s*math.sin(a)*(w+.006)
                zz-=.016*(1-t)**3 if j==0 else 0
                v.append((xx,yy,zz))
        for j in range(5):
            for k in range(16):a=j*17+k;f.append((a,a+1,a+18,a+17))
        o=mesh('Vest | '+('left' if s>0 else 'right')+' tailored panel',v,f,vestmat,'COSTUME | vest and scarf','Chest');thickness(o,.005)
        # Torso blend weights suitable for later deformation refinement.
        chest=o.vertex_groups['Chest'];chest.remove(list(range(len(v))))
        for i,p in enumerate(v):
            z=p[2];weights={'Hips':1} if z<1.04 else {'Spine':1} if z<1.21 else {'Chest':1}
            for b,wgt in weights.items():(o.vertex_groups.get(b) or o.vertex_groups.new(name=b)).add([i],wgt,'REPLACE')
        ribbon('Vest | turned front edge '+str(s),[v[j*17] for j in range(6)],.012,vestmat,'COSTUME | vest and scarf','Chest')
    # Draped triangular scarf wrap, with folded tails, not a tubular torus.
    v=[];f=[]
    for j in range(4):
        for k in range(33):
            a=k*math.tau/32;front=max(0,-math.sin(a));r=.068+.012*j
            v.append((r*math.cos(a),r*math.sin(a)-.007,1.47-j*.017-front*j*.009+.003*math.sin(a*3+j)))
    for j in range(3):
        for k in range(32):a=j*33+k;f.append((a,a+1,a+34,a+33))
    o=mesh('Neckerchief | folded wrap',v,f,red,'COSTUME | vest and scarf','Neck');thickness(o,.002)
    for s in [-1,1]:
        v=[];f=[]
        for j,(z,w) in enumerate([(1.429,.025),(1.395,.027),(1.35,.026),(1.295+s*.014,.003)]):
            for k in range(5):
                t=k/4;v.append((s*(.012+j*.009)+(t-.5)*w*2,-.114-j*.014-.009*math.sin(t*math.pi*2),z+.006*math.cos(t*math.pi)))
        for j in range(3):
            for k in range(4):a=j*5+k;f.append((a,a+1,a+6,a+5))
        o=mesh('Neckerchief | hanging tail '+str(s),v,f,red,'COSTUME | vest and scarf','Chest');thickness(o,.002)
    ribbon('Neckerchief | flattened knot',[(-.004,-.120,1.444),(.005,-.134,1.425),(.008,-.131,1.414)],.039,red,'COSTUME | vest and scarf','Neck')
    for idx in [38,41,42]:assign(lookup[idx],leather)
    # Review stance is a reversible rig pose; rest joints and existing actions survive.
    rig=bpy.data.objects['MinerRig'];rig.data.pose_position='POSE'
    for pb in rig.pose.bones:pb.matrix_basis.identity()
    bpy.context.view_layer.update()
    for s,side in [(1,'Left'),(-1,'Right')]:
        pb=rig.pose.bones[side+'UpperArm'];pivot=pb.head.copy();pb.matrix=Matrix.Translation(pivot)@Matrix.Rotation(s*math.radians(13),4,'Y')@Matrix.Translation(-pivot)@pb.matrix
        pb.scale.y*=.80;rig.pose.bones[side+'LowerArm'].scale.y=.79
    finish(1)

def box_loft(name,profile,mat,group='GEAR',bone=None,sides=24):
    # Profile tuples: center-x, center-y, z, half-width, half-depth. Squared textile sections.
    v=[];f=[]
    for j,(x,y,z,w,d) in enumerate(profile):
        for k in range(sides):
            a=k*math.tau/sides;ca=math.cos(a);sa=math.sin(a)
            xx=math.copysign(abs(ca)**.48,ca)*w;yy=math.copysign(abs(sa)**.5,sa)*d
            v.append((x+xx,y+yy,z+.003*math.sin(a*3+j*.7)))
    for j in range(len(profile)-1):
        for k in range(sides):a=j*sides+k;b=j*sides+(k+1)%sides;f.append((a,b,b+sides,a+sides))
    f.extend([tuple(reversed(range(sides))),tuple((len(profile)-1)*sides+k for k in range(sides))])
    return mesh(name,v,f,mat,group,bone)

def buckle(name,c,w,h,mat,group='GEAR'):
    x,y,z=c
    return tube(name,[(x-w/2,y,z-h/2),(x+w/2,y,z-h/2),(x+w/2,y,z+h/2),(x-w/2,y,z+h/2),(x-w/2,y,z-h/2)],[.0025]*5,mat,group,6)

def pass_two():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_01.blend'))
    lookup={o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}
    leather=bpy.data.materials['Convergence | worn leather']
    canvas=material('Convergence | earth olive canvas',(.18,.145,.078),.96)
    rollmat=material('Convergence | bedroll wool',(.16,.135,.075),.98)
    iron=material('Convergence | forged iron',(.095,.103,.106),.55,.75)
    wood=material('Convergence | hickory shaft',(.22,.107,.037),.79)
    trouser=material('Convergence | heavy umber trousers',(.135,.104,.07),.94)
    # 1. Existing pack: flatten broad faces, square its bottom, draw harness onto shoulders.
    pack=bpy.data.objects['Canvas knapsack'];pack.name='Backpack | reshaped original canvas and flap';move(pack,'GEAR | backpack')
    for v in pack.data.vertices:
        p=v.co
        if p.y<-.1:p.y*=1.30
        if p.y>.045:p.y=.045+(p.y-.045)*.8
        p.z*=.88
        p.x*=1.08
        # Broad sag away from closures, not indiscriminate surface noise.
        if p.y>.025:p.z-=.012*max(0,1-abs(p.x)/.19)
    pack.location=(0,.245,1.21)
    for m in pack.data.materials:
        if 'canvas' in m.name.lower():material(m.name,(.18,.14,.074),.94)
        elif 'leather' in m.name.lower():material(m.name,(.085,.043,.019),.8)
    # Tightly compressed roll along X. Uneven elliptical cross sections and recessed ends.
    v=[];f=[];xs=[-.215,-.207,-.19,-.145,-.126,-.112,-.095,0,.095,.112,.126,.145,.19,.207,.215]
    for j,x in enumerate(xs):
        compression=1-.14*(math.exp(-((x-.12)/.018)**2)+math.exp(-((x+.12)/.018)**2))
        for k in range(32):
            a=k*math.tau/32;r=.066*compression*(1+.04*math.cos(a*3+x*5))
            v.append((x,.276+math.cos(a)*r,1.474+math.sin(a)*r*.91-.006*(1-abs(x)/.215)))
    for j in range(len(xs)-1):
        for k in range(32):a=j*32+k;b=j*32+(k+1)%32;f.append((a,b,b+32,a+32))
    roll=mesh('Bedroll | compressed wrapped blanket',v,f,rollmat,'GEAR | bedroll','Chest');thickness(roll,.004)
    # Layered spiral ends remain actual geometry with a cloth-edge thickness.
    edge=material('Convergence | roll exposed edge',(.23,.191,.104),.98)
    for s in [-1,1]:
        points=[]
        for i in range(121):
            t=i/120;a=t*math.tau*3.25;r=.007+t*.055
            points.append((s*(.217-.003*t),.276+r*math.cos(a),1.474+r*.91*math.sin(a)))
        tube('Bedroll | wound end '+str(s),points,[.0033]*len(points),edge,'GEAR | bedroll',5,'Chest')
    for x in [-.12,.12]:
        points=[]
        for i in range(33):
            a=i*math.tau/32;points.append((x,.276+.0585*math.cos(a),1.471+.053*math.sin(a)))
        ribbon('Bedroll | binding '+str(x),points,.025,leather,'GEAR | bedroll','Chest')
        buckle('Bedroll | buckle '+str(x),(x,.335,1.477),.030,.034,iron,'GEAR | bedroll')
        ribbon('Pack | load bearing strap '+str(x),[(x,.307,1.43),(x,.344,1.35),(x,.347,1.23),(x,.338,1.11),(x,.33,1.055)],.025,leather,'GEAR | backpack','Chest')
    for s in [-1,1]:
        ribbon('Pack | shoulder harness '+str(s),[(s*.13,.23,1.405),(s*.158,.09,1.444),(s*.16,-.067,1.437),(s*.147,-.145,1.36),(s*.135,-.17,1.23),(s*.137,-.16,1.07),(s*.17,-.12,1.00)],.033,leather,'GEAR | backpack','Chest')
    # 2. Hanging equipment. Scale and side allocation follow the turnaround front/back.
    bag=box_loft('Satchel | hanging gusseted body',[(-.235,-.045,.69,.059,.039),(-.25,-.048,.714,.086,.047),(-.258,-.040,.81,.094,.052),(-.253,-.036,.899,.086,.043),(-.243,-.032,.93,.069,.035)],leather,'GEAR | satchel','Hips')
    v=[];f=[]
    for j,(z,y,w) in enumerate([(.932,-.031,.072),(.921,-.089,.084),(.859,-.103,.089),(.819,-.107,.080)]):
        for k in range(9):
            t=k/8;v.append((-.25+(t-.5)*w*2,y-.004*math.sin(t*math.pi),z+(.022*abs(t-.5) if j==3 else 0)))
    for j in range(3):
        for k in range(8):a=j*9+k;f.append((a,a+1,a+10,a+9))
    flap=mesh('Satchel | overlapping flap',v,f,leather,'GEAR | satchel','Hips');thickness(flap,.005)
    for x in [-.29,-.21]:
        ribbon('Satchel | belt hanger '+str(x),[(x,-.111,1.001),(x,-.1,.943),(x,-.108,.893),(x,-.114,.809),(x,-.106,.777)],.019,leather,'GEAR | satchel','Hips')
        buckle('Satchel | closure '+str(x),(x,-.118,.817),.026,.032,iron,'GEAR | satchel')
    # Mechanically pressed metal canteen with distinct rim and screw neck.
    v=[];f=[];cx=-.133;cz=.806
    rings=[(.001,-.191),(.065,-.186),(.082,-.173),(.087,-.15),(.087,-.126),(.080,-.116),(.05,-.106),(.001,-.102)]
    for r,y in rings:
        for k in range(48):a=k*math.tau/48;v.append((cx+r*math.cos(a),y,cz+r*math.sin(a)))
    for j in range(len(rings)-1):
        for k in range(48):a=j*48+k;b=j*48+(k+1)%48;f.append((a,b,b+48,a+48))
    o=mesh('Canteen | pressed steel halves',v,f,iron,'GEAR | canteen','Hips')
    tube('Canteen | rolled seam',[(cx+.088*math.cos(i*math.tau/48),-.15,cz+.088*math.sin(i*math.tau/48)) for i in range(49)],[.002]*49,iron,'GEAR | canteen',6,'Hips')
    tube('Canteen | capped neck',[(cx,-.143,.885),(cx,-.143,.905),(cx,-.143,.913)],[.014,.012,.016],iron,'GEAR | canteen',12,'Hips')
    ribbon('Canteen | leather hanger',[(cx,-.143,.91),(cx+.007,-.145,.95),(cx+.012,-.142,.991)],.014,leather,'GEAR | canteen','Hips')
    # Use the existing pan, with a thinner spun profile, and present its interior.
    pan=bpy.data.objects['Pan'];pan.hide_render=False;pan.hide_set(False);pan.name='Gold pan | original spun mesh reprofiled';move(pan,'GEAR | pan')
    for v in pan.data.vertices:v.co*=.80;v.co.z*=.62
    pan.location=(.405,-.005,.679);pan.rotation_euler=(math.radians(72),math.radians(-18),math.radians(-12))
    # Real tapered pick head around the shaft eye, forged points curve down toward their tips.
    shaftpts=[(-.388,.0,.06),(-.375,-.014,.22),(-.354,-.027,.47),(-.334,-.040,.72),(-.325,-.042,.84)]
    tube('Pickaxe | tapered hickory shaft',shaftpts,[.017,.016,.0145,.016,.019],wood,'GEAR | pickaxe',12)
    box_loft('Pickaxe | forged central eye',[(-.386,0,.074,.026,.027),(-.382,0,.125,.024,.025)],iron,'GEAR | pickaxe',sides=12)
    tube('Pickaxe | forged pick and adze',[(-.604,0,.054),(-.558,0,.067),(-.48,0,.089),(-.383,0,.115),(-.303,0,.123),(-.235,0,.142),(-.202,0,.16)],[.001,.009,.013,.020,.014,.008,.001],iron,'GEAR | pickaxe',8)
    # Substantial belt sits over the tuck and carries the hanging equipment.
    belt=lookup[38];belt.name='Belt | broad leather waist belt'
    for v in belt.data.vertices:v.co.x*=1.075;v.co.y*=1.19;v.co.z=.984+(v.co.z-.976)*1.24
    buckle('Belt | rectangular forged buckle',(0,-.161,.99),.067,.046,iron,'COSTUME | belt')
    # 3. Rework ORIGINAL trouser vertices into knee/ankle sections; retain skin weights.
    for idx in [8,9]:
        o=lookup[idx];s=1 if idx==8 else -1;o.name='Trousers | weighted leg '+str(s);assign(o,trouser)
        for v in o.data.vertices:
            p=v.co;z=p.z;cx=s*(.11-.005*max(0,(z-.53)/.41));cy=-.022*max(0,1-abs(z-.53)/.42)
            dx=p.x-cx;dy=p.y-cy;a=math.atan2(dy,dx)
            factor=1-.08*math.exp(-((z-.56)/.11)**2)
            factor+=.16*math.exp(-((z-.34)/.065)**2)
            fold=.006*math.sin(a*3+z*27+s)*math.exp(-((z-.38)/.12)**2)+.004*math.sin(a*4-z*19)*math.exp(-((z-.57)/.095)**2)
            p.x=cx+dx*factor+math.cos(a)*fold;p.y=cy+dy*factor+math.sin(a)*fold
            if z<.34:p.z=.325+(z-.225)*.25+.009*math.sin(a*3+s)
        for p in o.data.polygons:p.use_smooth=True
    assign(lookup[34],trouser);lookup[34].name='Trousers | original weighted seat'
    # Extend boot shafts and reduce bulbous toe domes; welt remains independent.
    for idx in [6,7]:
        o=lookup[idx];s=1 if idx==6 else -1;assign(o,leather);o.name='Boot | tall shaft '+str(s)
        for v in o.data.vertices:
            p=v.co;z=p.z;cx=s*.11;a=math.atan2(p.y,p.x-cx)
            p.z=.045+(z-.045)*1.17
            p.x=cx+(p.x-cx)*(1+.07*math.exp(-((z-.17)/.05)**2))
            p.y+=.005*math.sin(a*2+z*53)*math.exp(-((z-.13)/.06)**2)
    for idx in [0,1]:
        o=lookup[idx];assign(o,leather);o.name='Boot | structured toe '+str(idx)
        for v in o.data.vertices:
            p=v.co
            if p.y<-.055:p.z=.027+(p.z-.027)*.72
    sole=material('Convergence | boot sole',(.035,.023,.014),.91)
    for idx in [2,3,4,5]:assign(lookup[idx],sole);lookup[idx].name='Boot | welt and outsole '+str(idx)
    finish(2)

def subdivide_once(o):
    bpy.context.view_layer.objects.active=o
    m=o.modifiers.new('Extra control for structural cloth folds','SUBSURF');m.subdivision_type='SIMPLE';m.levels=1
    # Place ahead of the armature to retain the authored rest shape.
    bpy.ops.object.modifier_move_to_index(modifier=m.name,index=0);bpy.ops.object.modifier_apply(modifier=m.name)

def pass_three():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_02.blend'))
    lookup={o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}
    leather=bpy.data.materials['Convergence | worn leather'];cloth=bpy.data.materials['Convergence | dirty cream linen'];iron=bpy.data.materials['Convergence | forged iron']
    # 1. Clothing landmarks: raise rolls to elbows, lengthen exposed forearms, carve fold planes.
    for idx in [36,37,39,40]:
        o=lookup[idx];s=1 if idx in [36,39] else -1
        for v in o.data.vertices:
            p=v.co;t=max(0,min(1,(1.40-p.z)/.414))
            amount=.108*t**2 if idx<39 else .108
            p.z+=amount;p.x-=s*amount*.31
        subdivide_once(o)
        if idx<39:
            a0=Vector((s*.21,0,1.39));axis=Vector((s*.135,-.004,-.305))
            for v in o.data.vertices:
                p=v.co;t=max(0,min(1,(p-a0).dot(axis)/axis.length_squared));c=a0+axis*t;d=p-c
                a=math.atan2(d.y,d.x*s);rad=math.sqrt(d.x*d.x+d.y*d.y)
                if rad<.008:continue
                # Three oblique compressed pleats, strongest near elbow, broad shoulder tension.
                delta=0
                for z0,amp,width,tilt in [(1.115,.014,.014,.23),(1.155,-.009,.016,-.26),(1.20,.009,.020,.3),(1.295,-.006,.027,-.32)]:
                    distance=p.z-z0-tilt*d.x*s-.13*d.y
                    delta+=amp*math.exp(-(distance/width)**2)*(.4+.6*abs(math.sin(a+.4)))
                delta+=.004*math.sin(a*5+.7)*math.exp(-((p.z-1.11)/.065)**2)
                p.x+=d.x/rad*delta;p.y+=d.y/rad*delta
        for p in o.data.polygons:p.use_smooth=True
    for idx in [32,33]:
        o=lookup[idx];s=1 if idx==32 else -1;o.name='Body | tapered forearm '+str(s)
        for v in o.data.vertices:
            p=v.co;t=max(0,min(1,(p.z-.765)/.25));p.z+=.108*t;p.x-=s*.034*t
            p.y*=.88
    # Rebuild vest boundary positions from a tailored surface outside the shirt envelope.
    for o in list(bpy.data.objects):
        if o.name.startswith('Vest |'):
            if 'tailored panel' in o.name:
                for v in o.data.vertices:
                    p=v.co;p.x*=1.025;p.y*=1.085
                for p in o.data.polygons:p.use_smooth=True
            else:o.hide_render=True;o.hide_set(True)
    # Shoulder portions of the original shirt were never covered by the old vest panels.
    vest=bpy.data.materials['Convergence | charcoal brown vest']
    for s in [-1,1]:
        v=[(s*.042,-.163,1.298),(s*.074,-.169,1.353),(s*.106,-.144,1.40),(s*.125,-.070,1.441),(s*.184,-.067,1.428),(s*.204,-.12,1.366),(s*.178,-.16,1.326),(s*.105,-.173,1.28)]
        o=mesh('Vest | shoulder and lapel '+str(s),v,[(0,1,6,7),(1,2,5,6),(2,3,4,5)],vest,'COSTUME | vest and scarf','Chest');thickness(o,.005)
    # Heavy trousers: knee planes, crotch tension and stacked angular boot-top compression.
    for idx in [8,9]:
        o=lookup[idx];s=1 if idx==8 else -1;subdivide_once(o)
        for v in o.data.vertices:
            p=v.co;cx=s*.11;dx=p.x-cx;dy=p.y+.013;a=math.atan2(dy,dx);r=max(.02,math.hypot(dx,dy));delta=0
            for z0,amp,width,tilt in [(.365,.014,.012,.30),(.396,-.010,.015,-.35),(.43,.011,.017,.28),(.49,-.006,.018,.35),(.554,.009,.019,-.22),(.615,-.009,.026,.38),(.77,.008,.023,-.3),(.84,-.007,.020,.35)]:
                d=p.z-z0-tilt*dx*s-.13*dy
                delta+=amp*math.exp(-(d/width)**2)*(.35+.65*abs(math.sin(a)))
            p.x+=dx/r*delta;p.y+=dy/r*delta
            # More planar knee front and a relaxed offset to the outside of each ankle.
            if p.y<-.07:p.y+=.006*math.exp(-((p.z-.56)/.08)**2)
            p.x+=s*.008*math.exp(-((p.z-.4)/.08)**2)
    for idx in [6,7]:
        o=lookup[idx];s=1 if idx==6 else -1;subdivide_once(o)
        for v in o.data.vertices:
            p=v.co;dx=p.x-s*.11;dy=p.y;r=max(.01,math.hypot(dx,dy));delta=0
            for z0,amp,w,tilt in [(.105,.008,.012,.25),(.14,-.006,.013,-.3),(.18,.007,.012,.32),(.22,-.005,.019,.2),(.318,.004,.011,0)]:delta+=amp*math.exp(-((p.z-z0-tilt*dx)/w)**2)
            p.x+=dx/r*delta;p.y+=dy/r*delta
        for p in o.data.polygons:p.use_smooth=True
    # 2. Equipment contact. Separate original pack loose pieces to remove floating harness/loop.
    pack=bpy.data.objects['Backpack | reshaped original canvas and flap'];bpy.ops.object.select_all(action='DESELECT');pack.select_set(True);bpy.context.view_layer.objects.active=pack
    bpy.ops.object.mode_set(mode='EDIT');bpy.ops.mesh.select_all(action='SELECT');bpy.ops.mesh.separate(type='LOOSE');bpy.ops.object.mode_set(mode='OBJECT')
    for i,o in enumerate(list(bpy.context.selected_objects)):
        vs=o.data.vertices;cy=sum(v.co.y for v in vs)/len(vs);zmin=min(v.co.z for v in vs);zmax=max(v.co.z for v in vs)
        if cy<-.06 or zmax>.20:
            o.hide_render=True;o.hide_set(True);o.name='ARCHIVE | original pack harness '+str(i);move(o,'ARCHIVE | superseded attachments')
        else:
            o.name='Backpack | original constructed piece '+str(i)
            for m in o.data.materials:
                if 'canvas' in m.name.lower():
                    p=m.node_tree.nodes.get('Principled BSDF')
                    for link in list(p.inputs['Base Color'].links):m.node_tree.links.remove(link)
                    p.inputs['Base Color'].default_value=(.18,.14,.075,1)
    for o in list(bpy.data.objects):
        if o.name.startswith('Pack | shoulder harness'):
            o.hide_render=True;o.hide_set(True);move(o,'ARCHIVE | superseded attachments')
    for s in [-1,1]:
        ribbon('Pack | fitted shoulder strap '+str(s),[(s*.13,.23,1.405),(s*.14,.12,1.448),(s*.15,.03,1.455),(s*.153,-.071,1.451),(s*.144,-.144,1.41),(s*.134,-.184,1.335),(s*.124,-.187,1.25),(s*.123,-.182,1.15),(s*.13,-.177,1.044)],.028,leather,'GEAR | backpack','Chest')
    # Thicken the blanket itself behind the spiral: a roll is not an open metal tube.
    rollmat=bpy.data.materials['Convergence | bedroll wool']
    for s in [-1,1]:
        v=[(s*.216,.276,1.474)]+[(s*.216,.276+.06*math.cos(k*math.tau/32),1.474+.055*math.sin(k*math.tau/32)) for k in range(32)]
        mesh('Bedroll | cloth end backing '+str(s),v,[(0,k+1,(k+1)%32+1) for k in range(32)],rollmat,'GEAR | bedroll','Chest')
    # Move satchel toward rear hip to leave the working hand and canteen unobstructed.
    for o in collection('GEAR | satchel').objects:
        if o.type=='MESH':
            for v in o.data.vertices:v.co.y+=.115
    # A slight wrist turn presents the backs of the hands; curl fingers with existing bones.
    rig=bpy.data.objects['MinerRig'];bpy.context.view_layer.update()
    for s,side in [(1,'Left'),(-1,'Right')]:
        pb=rig.pose.bones[side+'Hand'];pivot=pb.head.copy()
        pb.matrix=Matrix.Translation(pivot)@Matrix.Rotation(s*math.radians(48),4,'Z')@Matrix.Translation(-pivot)@pb.matrix
        pb.scale*=1.17
        for label in ['Index','Middle','Ring','Little']:
            for segment,angle in [('Proximal',42),('Intermediate',50),('Distal',24)]:
                finger=rig.pose.bones[side+label+segment];finger.rotation_mode='XYZ';finger.rotation_euler.x=math.radians(angle)
    bpy.context.view_layer.update()
    # Position pan rim by the evaluated hand, with a tilted presentation matching the sheet.
    pan=bpy.data.objects['Gold pan | original spun mesh reprofiled']
    pan.rotation_euler=(math.radians(72),math.radians(-12),math.radians(-20))
    contact=Vector((.302,-.038,.845));rim=Vector((-.065,.146,.035))
    pan.location=contact-pan.rotation_euler.to_matrix()@rim
    # Align the top grip of the shaft to the right palm while retaining groundward head.
    for o in collection('GEAR | pickaxe').objects:
        for v in o.data.vertices:
            p=v.co;t=max(0,min(1,(p.z-.06)/.78));p.x+=.046*t;p.y-=.052*t
    # 3. Character identity: original head and beard reshaped, with separate dark hair masses.
    head=lookup[52];head.name='Body | original sculpted head'
    skin=material('Convergence | warm weathered skin',(.36,.205,.115),.72);assign(head,skin)
    for o in lookup.values():
        if o.data.materials and any(m and m.name=='Skin' for m in o.data.materials):assign(o,skin)
    for v in head.data.vertices:
        p=v.co
        if p.z<1.57:p.x*=1.07
        if p.y<-.045 and 1.57<p.z<1.64:p.y+=.006*math.exp(-(p.x/.025)**2)
    hair=material('Convergence | dark brown hair',(.033,.020,.012),.92)
    beard=lookup[51];beard.name='Facial hair | shortened jaw-following beard';assign(beard,hair)
    for v in beard.data.vertices:
        p=v.co;t=max(0,min(1,(1.54-p.z)/.09));p.z+=.043*t;p.x*=1+.36*t
        if p.y<-.02:p.y+=.004*t
    for idx in [54,55,56,65,66,69,70]:assign(lookup[idx],hair)
    # Scalp curtain follows sides and occiput; small locks change silhouette with gravity.
    v=[];f=[]
    for j in range(7):
        t=j/6
        for k in range(33):
            a=-.18+(math.pi+.36)*k/32
            z=1.675-t*(.17+.014*math.sin(a*3))
            x=math.cos(a)*(.087+.012*math.sin(t*math.pi));y=math.sin(a)*(.085+.013*t)+.005
            x+=.004*math.sin(a*13+t*4);y+=.004*math.cos(a*11-t*3)
            v.append((x,y,z))
    for j in range(6):
        for k in range(32):a=j*33+k;f.append((a,a+1,a+34,a+33))
    o=mesh('Hair | medium length side and nape mass',v,f,hair,'IDENTITY | hair and beard','Head');thickness(o,.003)
    for i in range(19):
        a=-.12+(math.pi+.24)*i/18;x=math.cos(a);y=math.sin(a)
        z=1.535+.012*math.sin(i*2.1)
        points=[(x*.092,y*.09,1.615),(x*.10,y*.10,1.574),(x*.104,y*.105,z),(x*.10+.006*math.sin(i),y*.112,z-.027),(x*.094,y*.105,z-.037)]
        tube('Hair | gravity lock '+str(i),points,[.014,.016,.013,.008,.001],hair,'IDENTITY | hair and beard',6,'Head')
    for p in head.data.polygons:p.use_smooth=True
    finish(3)

def pass_four():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_03.blend'))
    lookup={o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}
    rig=bpy.data.objects['MinerRig'];leather=bpy.data.materials['Convergence | worn leather'];iron=bpy.data.materials['Convergence | forged iron']
    # 1. Weight-bearing stance: pelvis remains over feet, ankles spread, feet return level.
    bpy.context.view_layer.update()
    for s,side in [(1,'Left'),(-1,'Right')]:
        pb=rig.pose.bones[side+'UpperLeg'];pivot=pb.head.copy();angle=-s*math.radians(4.5 if s>0 else 3.5)
        pb.matrix=Matrix.Translation(pivot)@Matrix.Rotation(angle,4,'Y')@Matrix.Translation(-pivot)@pb.matrix
        bpy.context.view_layer.update()
        foot=rig.pose.bones[side+'Foot'];pivot=foot.head.copy()
        foot.matrix=Matrix.Translation(pivot)@Matrix.Rotation(s*math.radians(-7),4,'Z')@Matrix.Rotation(-angle,4,'Y')@Matrix.Translation(-pivot)@foot.matrix
    # Relax overly narrow high-frequency folds from pass 3 with a small local smoothing step.
    for idx in [8,9,6,7]:
        o=lookup[idx];bpy.context.view_layer.objects.active=o
        mod=o.modifiers.new('Relax structural fold transitions','SMOOTH');mod.factor=.28;mod.iterations=2
        bpy.ops.object.modifier_move_to_index(modifier=mod.name,index=0);bpy.ops.object.modifier_apply(modifier=mod.name)
    # Make shirt's front open and gathered rather than a tight, perfectly straight placket.
    torso=lookup[35];subdivide_once(torso)
    for v in torso.data.vertices:
        p=v.co
        if p.y<0:
            fade=max(0,1-abs(p.x)/.14)
            p.y-=.010*math.exp(-((p.z-1.10)/.07)**2)*fade
            p.y+=.006*math.exp(-((p.z-1.04-.3*p.x)/.023)**2)*fade
            p.y-=.006*math.exp(-((p.z-1.26+.4*p.x)/.035)**2)*fade
    # Reduce vest's squared lower corners and reveal a short, uneven shirt tuck.
    for o in collection('COSTUME | vest and scarf').objects:
        if 'tailored panel' in o.name:
            for v in o.data.vertices:
                p=v.co;t=max(0,min(1,(1.18-p.z)/.20));p.x*=1-.075*t
                p.z+=.012*t*max(0,1-abs(p.x)/.2)
        if 'shoulder and lapel' in o.name:
            for v in o.data.vertices:
                p=v.co
                if p.z<1.35:p.x*=.81;p.z+=.011
    # 2. Pack construction: keep its original body, remove uniform convexity and shorten flap.
    canvas=material('Convergence | earth olive canvas',(.18,.145,.078),.96)
    for o in collection('GEAR | backpack').objects:
        if not o.name.startswith('Backpack | original constructed piece'):continue
        n=len(o.data.vertices)
        if n==432:
            assign(o,canvas)
            for v in o.data.vertices:
                p=v.co
                if p.y>.03:
                    p.y=.075+(p.y-.075)*.42
                    p.y-=.008*(math.exp(-((p.x-.12)/.025)**2)+math.exp(-((p.x+.12)/.025)**2))
                if p.z<-.13:p.x*=1.045
        elif n in [153,306]:
            assign(o,canvas)
            for v in o.data.vertices:
                p=v.co;t=max(0,min(1,(.18-p.z)/.22));p.z+=.055*t
                p.z-=.018*t*max(0,1-abs(p.x)/.17)
    # Broad sewn exterior pockets introduce weighted panel construction on the pack's rear.
    pocketmat=material('Convergence | pack pocket canvas',(.13,.096,.052),.95)
    for s in [-1,1]:
        x=s*.095
        o=box_loft('Backpack | sewn lower pocket '+str(s),[(x,.33,1.035,.063,.012),(x,.347,1.054,.068,.026),(x,.35,1.13,.070,.028),(x,.335,1.18,.067,.014)],pocketmat,'GEAR | backpack','Chest',16)
        ribbon('Backpack | pocket bound opening '+str(s),[(x,.365,1.18),(x,.369,1.17)],.132,leather,'GEAR | backpack','Chest')
        ribbon('Backpack | lower attachment '+str(s),[(s*.12,.362,1.26),(s*.12,.38,1.18),(s*.12,.38,1.095),(s*.12,.363,1.052)],.024,leather,'GEAR | backpack','Chest')
    # Collapse roll's exaggerated regular end ridges into exposed blanket layers.
    for o in collection('GEAR | bedroll').objects:
        if o.type!='MESH':continue
        if 'wound end' in o.name:
            for v in o.data.vertices:
                p=v.co;p.x=math.copysign(.219+(abs(p.x)-.217)*.48,p.x)
        if 'compressed wrapped' in o.name:
            for v in o.data.vertices:
                p=v.co;p.z+=.0025*math.sin(p.x*29)*(p.y-.276)/.066
            for p in o.data.polygons:p.use_smooth=True
    # Shaft must pass through the hand volume in profile, not merely line up in front view.
    shaft=bpy.data.objects['Pickaxe | tapered hickory shaft']
    for v in shaft.data.vertices:
        p=v.co;t=max(0,min(1,(p.z-.40)/.44));p.y+=.070*t;p.z+=.068*t
    pan=bpy.data.objects['Gold pan | original spun mesh reprofiled'];pan.location.y+=.02;pan.location.z+=.008
    for p in pan.data.polygons:p.use_smooth=True
    # 3. Head identity: fuller jaw coverage, broken swept locks instead of a straight bob.
    beard=lookup[51]
    for v in beard.data.vertices:
        p=v.co;t=max(0,min(1,(1.55-p.z)/.06));p.z-=.024*t;p.x*=1-.045*t
    hair=bpy.data.materials['Convergence | dark brown hair']
    for o in collection('IDENTITY | hair and beard').objects:
        if o.type!='MESH':continue
        if 'gravity lock' in o.name:
            num=int(o.name.rsplit(' ',1)[1]);variation=.012*math.sin(num*2.31)+.008*math.cos(num*1.7)
            for v in o.data.vertices:
                p=v.co;t=max(0,min(1,(1.61-p.z)/.13));p.z+=variation*t
                p.y+=.018*t*t;p.x+=.011*math.sin(num*.83+t*2)*t
                p.x*=1-.06*t
        elif 'nape mass' in o.name:
            for v in o.data.vertices:
                p=v.co;t=max(0,min(1,(1.64-p.z)/.13));p.y+=.012*t;p.z+=.006*math.sin(p.x*73)*t
    # Sideburns lead into beard; these are flat hair wedges, not tubular anatomy.
    for s in [-1,1]:
        v=[(s*.08,-.023,1.642),(s*.097,-.006,1.624),(s*.099,-.016,1.564),(s*.083,-.043,1.55),(s*.078,-.051,1.594)]
        o=mesh('Hair | swept temple '+str(s),v,[(0,1,2,4),(2,3,4)],hair,'IDENTITY | hair and beard','Head');thickness(o,.004)
    head=lookup[52]
    for v in head.data.vertices:
        p=v.co
        if p.y<0:
            def g(cx,cz,sx,sz):return math.exp(-((p.x-cx)/sx)**2-((p.z-cz)/sz)**2)
            p.y-=.006*(g(.048,1.593,.025,.018)+g(-.048,1.593,.025,.018))
            p.y-=.004*(g(.036,1.633,.028,.009)+g(-.036,1.633,.028,.009))
            p.y+=.004*(g(.038,1.61,.024,.009)+g(-.038,1.61,.024,.009))
    finish(4)

def replace_surface(o,vertices,faces,mat,weight_fn):
    # The replaced mesh remains in the .blend datablocks as a named editable checkpoint.
    previous=o.data;previous.name=o.name+' | pre-pass-5 mesh';previous.use_fake_user=True
    data=bpy.data.meshes.new(o.name+' | landmark cross sections');data.from_pydata(vertices,[],faces);data.update();data.materials.append(mat);o.data=data
    for vg in list(o.vertex_groups):o.vertex_groups.remove(vg)
    for i,p in enumerate(vertices):
        for bone,w in weight_fn(Vector(p)).items():
            if w>0:(o.vertex_groups.get(bone) or o.vertex_groups.new(name=bone)).add([i],w,'REPLACE')
    for p in data.polygons:p.use_smooth=len(p.vertices)<=4
    # Explicit UV surface for subsequent baking, one seam on the inner/back face.
    uv=data.uv_layers.new(name='Convergence surface UV')
    for p in data.polygons:
        for li in p.loop_indices:
            v=data.vertices[data.loops[li].vertex_index].co;uv.data[li].uv=(v.x*2+.5,v.z/1.8)

def ring_faces(rows,sides):
    f=[]
    for j in range(rows-1):
        for k in range(sides):a=j*sides+k;b=j*sides+(k+1)%sides;f.append((a,b,b+sides,a+sides))
    f.extend([tuple(reversed(range(sides))),tuple((rows-1)*sides+k for k in range(sides))]);return f

def pass_five():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_04.blend'))
    lookup={o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}
    cloth=bpy.data.materials['Convergence | dirty cream linen'];trouser=bpy.data.materials['Convergence | heavy umber trousers'];leather=bpy.data.materials['Convergence | worn leather']
    # 1. Shoulder-hung sleeves with flattened inside plane, elbow tension and compressed roll.
    for idx in [36,37]:
        s=1 if idx==36 else -1;side='Left' if s>0 else 'Right';o=lookup[idx]
        rows=[(1.441,.182,.025,.035),(1.422,.203,.067,.067),(1.394,.223,.085,.084),(1.359,.24,.086,.082),(1.326,.254,.080,.078),(1.291,.266,.077,.074),(1.263,.279,.075,.07),(1.241,.290,.068,.075),(1.219,.298,.079,.080),(1.201,.307,.070,.074),(1.182,.317,.075,.072),(1.165,.324,.068,.068),(1.151,.328,.075,.078),(1.131,.337,.074,.074),(1.112,.343,.071,.069),(1.099,.35,.070,.068)]
        vertices=[]
        for j,(z,cx,w,d) in enumerate(rows):
            for k in range(24):
                a=k*math.tau/24;ca=math.cos(a);sa=math.sin(a);t=j/(len(rows)-1)
                xx=math.copysign(abs(ca)**.80,ca)*w;yy=math.copysign(abs(sa)**.83,sa)*d
                # Fold ridges move diagonally across the front; inside sleeve is compressed.
                zz=z+.016*ca*math.sin(j*.93)*t+.007*sa*math.cos(j*.71)*t
                xx+=.004*math.cos(a*3+.6)*t;yy+=.004*math.sin(a*3+j*.7)*t
                vertices.append((s*(cx+xx),yy,zz))
        def wt(p,side=side):
            t=max(0,min(1,(p.z-1.045)/.13));return {side+'UpperArm':t,side+'LowerArm':1-t}
        replace_surface(o,vertices,ring_faces(len(rows),24),cloth,wt)
    # 2. Heavy work trousers: asymmetric compressed ankle, articulated knee and broad thigh.
    for idx in [8,9]:
        s=1 if idx==8 else -1;side='Left' if s>0 else 'Right';o=lookup[idx]
        rows=[(.326,.071,.068),(.346,.08,.076),(.368,.088,.083),(.39,.076,.074),(.412,.081,.078),(.439,.072,.07),(.474,.074,.074),(.505,.078,.087),(.539,.087,.092),(.57,.084,.087),(.604,.089,.091),(.644,.097,.098),(.69,.104,.106),(.735,.108,.11),(.779,.108,.116),(.825,.103,.115),(.87,.098,.11),(.913,.096,.106),(.945,.093,.10)]
        vertices=[]
        for j,(z,w,d) in enumerate(rows):
            for k in range(24):
                a=k*math.tau/24;ca=math.cos(a);sa=math.sin(a)
                cx=s*(.107+.011*math.exp(-((z-.38)/.09)**2));cy=-.021*math.exp(-((z-.54)/.18)**2)+.01*max(0,(z-.8)/.15)
                xx=math.copysign(abs(ca)**.83,ca)*w;yy=math.copysign(abs(sa)**.84,sa)*d
                comp=math.exp(-((z-.38)/.095)**2)+.5*math.exp(-((z-.55)/.065)**2)
                zz=z+(.016*ca*math.cos(j*.88+s)+.012*sa*math.sin(j*.83))*comp
                # A single angled ridge leads from crotch into inner thigh, not repeated noise.
                yy+=.006*math.sin(a*3+.5)*math.exp(-((z-.79)/.08)**2)
                vertices.append((cx+xx,cy+yy,zz))
        def wt(p,side=side):
            t=max(0,min(1,(p.z-.455)/.15));return {side+'UpperLeg':t,side+'LowerLeg':1-t}
        replace_surface(o,vertices,ring_faces(len(rows),24),trouser,wt)
    seat=lookup[34]
    for v in seat.data.vertices:
        p=v.co;t=max(0,min(1,(.9-p.z)/.08));center=math.exp(-(p.x/.08)**2)
        p.z+=.035*t*center
        if p.y<0:p.y+=.022*t*center
    # 3. Boots have calf, ankle collapse, instep, toe box and outsole as distinct forms.
    for idx in [6,7]:
        s=1 if idx==6 else -1;side='Left' if s>0 else 'Right';o=lookup[idx];vertices=[]
        rows=[(.049,.070,.085),(.08,.067,.082),(.107,.073,.078),(.13,.063,.067),(.15,.068,.071),(.174,.058,.062),(.198,.067,.066),(.225,.061,.063),(.27,.063,.065),(.311,.068,.070),(.337,.073,.074),(.350,.074,.073)]
        for j,(z,w,d) in enumerate(rows):
            for k in range(24):
                a=k*math.tau/24;ca=math.cos(a);sa=math.sin(a);comp=math.exp(-((z-.155)/.07)**2)
                xx=math.copysign(abs(ca)**.86,ca)*w;yy=math.copysign(abs(sa)**.81,sa)*d
                zz=z+.015*ca*math.sin(j*1.47+s)*comp+.008*sa*math.cos(j*.81)*comp
                vertices.append((s*.11+xx,yy,zz))
        replace_surface(o,vertices,ring_faces(len(rows),24),leather,lambda p,side=side:{side+'Foot':1})
    for idx in [0,1]:
        s=1 if idx==0 else -1;side='Left' if s>0 else 'Right';o=lookup[idx];vertices=[]
        for j,(scale,z) in enumerate([(1,.028),(1,.042),(.98,.065),(.90,.082),(.72,.095),(.15,.102)]):
            for k in range(32):
                a=k*math.tau/32;ca=math.cos(a);sa=math.sin(a)
                y=-.074+math.copysign(abs(sa)**.74,sa)*.144*scale
                w=.075 if y<-.02 else .064
                x=s*.11+math.copysign(abs(ca)**.73,ca)*w*scale
                zz=z+.033*max(0,min(1,(y+.16)/.18))*(j/5)
                vertices.append((x,y,zz))
        replace_surface(o,vertices,ring_faces(6,32),leather,lambda p,side=side:{side+'Foot':1})
    finish(5)

def package():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_05.blend'))
    rig=bpy.data.objects['MinerRig'];scene=bpy.context.scene
    # Rigid equipment follows the appropriate bone while preserving this reviewed placement.
    def parent_rigid(o,bone):
        if o.type!='MESH' or o.hide_render:return
        if any(m.type=='ARMATURE' for m in o.modifiers):return
        matrix=o.matrix_world.copy();o.parent=rig;o.parent_type='BONE';o.parent_bone=bone
        o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.Identity(4)
        bpy.context.view_layer.update()
        # Preserve a full inverse matrix: decomposing a nonuniformly scaled hand parent
        # into local rotation/scale would introduce shear and move the carried gear.
        o.matrix_parent_inverse=o.matrix_world.inverted();o.matrix_basis=matrix
        bpy.context.view_layer.update()
    for group,bone in [('GEAR | backpack','Chest'),('GEAR | bedroll','Chest'),('GEAR | satchel','Hips'),('GEAR | canteen','Hips'),('GEAR | pickaxe','RightHand'),('GEAR | pan','LeftHand'),('COSTUME | belt','Hips')]:
        for o in collection(group).objects:parent_rigid(o,bone)
    lookup={o['source_component']:o for o in scene.objects if 'source_component' in o}
    names={10:'Middle finger L',11:'Middle finger R',12:'Index finger L',13:'Index finger R',14:'Ring finger L',15:'Ring finger R',16:'Little finger L',17:'Little finger R',26:'Thumb L',27:'Thumb R',28:'Palm L',29:'Palm R',30:'Thumb web L',31:'Thumb web R',41:'Suspender R',42:'Suspender L',43:'Shirt placket',48:'Shirt collar R',49:'Shirt collar L',50:'Neck',53:'Lower lip',54:'Mouth line',55:'Moustache L',56:'Moustache R',57:'Ear R',58:'Ear L',59:'Ear inset R',60:'Ear inset L',61:'Lower eyelid R',62:'Lower eyelid L',63:'Eye R',64:'Eye L',65:'Iris R',66:'Iris L',67:'Upper eyelid R',68:'Upper eyelid L',69:'Brow L',70:'Brow R'}
    for idx,o in lookup.items():
        if idx in names:o.name=names[idx]
        if 18<=idx<=25:o.name='Fingernail | original '+str(idx)
        if 44<=idx<=47:o.name='Shirt | horn button '+str(idx)
        if idx<8:group='COSTUME | boots'
        elif idx in [8,9,34]:group='COSTUME | trousers'
        elif idx in list(range(10,34)):group='BODY | hands and forearms'
        elif idx in [35,36,37,39,40,43,44,45,46,47,48,49]:group='COSTUME | shirt'
        elif idx in [38,41,42]:group='COSTUME | belt and suspenders'
        elif idx>=71:group='COSTUME | hat'
        elif idx in [51,54,55,56,69,70]:group='IDENTITY | facial hair'
        else:group='BODY | head and face'
        move(o,group)
    move(rig,'RIG | original skeleton and animation clips')
    # References are packed and accessible in Blender's Image Editor, without entering renders.
    for p in sorted((ROOT/'characters/miner').glob('*.png')):
        im=bpy.data.images.load(str(p),check_existing=True);im.pack()
        im.name=('REFERENCE PRIMARY | turnaround' if '(1)' in p.name else 'REFERENCE SECONDARY | pitch' if '(2)' in p.name else 'REFERENCE SECONDARY | hero')
        im.use_fake_user=True
    for o in scene.objects:
        if o.type=='MESH' and o.name.startswith('ARCHIVE'):o.hide_render=True;o.hide_set(True)
    # Inventory excludes hidden bake swatches and archives; evaluated bounds include the review pose.
    dg=bpy.context.evaluated_depsgraph_get()
    def visible(o):return o.type=='MESH' and not o.hide_render and not any(c.hide_render for c in o.users_collection)
    def bounds(objects):
        pts=[]
        for o in objects:
            ev=o.evaluated_get(dg);me=ev.to_mesh();pts.extend(ev.matrix_world@v.co for v in me.vertices);ev.to_mesh_clear()
        if not pts:return None
        lo=[min(p[k] for p in pts) for k in range(3)];hi=[max(p[k] for p in pts) for k in range(3)]
        return dict(min=lo,max=hi,size=[hi[k]-lo[k] for k in range(3)])
    metrics={'units':'meters','pose':'reversible reference review pose, original rest rig unchanged','components':{}}
    for c in bpy.data.collections:
        os=[o for o in c.objects if visible(o)]
        if os:metrics['components'][c.name]=bounds(os)
    inventory=[];total=0
    for o in scene.objects:
        if not visible(o):continue
        tris=sum(len(p.vertices)-2 for p in o.data.polygons);total+=tris
        inventory.append(dict(name=o.name,vertices=len(o.data.vertices),base_triangles=tris,armature=any(m.type=='ARMATURE' for m in o.modifiers),bone_parent=o.parent_bone if o.parent_type=='BONE' else None))
    metrics['visible_base_triangles']=total;metrics['visible_mesh_objects']=len(inventory)
    metrics['preserved_actions']=[a.name for a in bpy.data.actions]
    metrics['inventory']=inventory
    (OUT/'working_asset_metrics.json').write_text(json.dumps(metrics,indent=2))
    textblock=bpy.data.texts.new('START HERE | convergence status')
    textblock.write('1848 — The Intrepid Miner. Five structural convergence passes.\nPRIMARY: packed turnaround image. SECONDARY: packed pitch and hero images.\nThis is an INTERMEDIATE working asset, not accepted final art.\nReview cameras and neutral lighting are in REVIEW collection. Original rig actions remain; NLA tracks muted.\nRest joints retained. Review pose changes arm length and stance reversibly. Animation/export compatibility is NOT validated.\nMajor next work: more convincing cloth and pack construction; face/hair anatomy and likeness.\nRead MINER_CONVERGENCE_REVIEW.md in project root for scores, measurements and per-pass findings.\n')
    bpy.ops.object.select_all(action='DESELECT');lookup[35].select_set(True);bpy.context.view_layer.objects.active=lookup[35]
    scene.camera=bpy.data.objects['Review three_quarter']
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':
                area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender/miner_convergence_working.blend'))
    # One final four-view verification catches packaging/parenting changes.
    render(6)

if STAGE==-1:
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_00_baseline.blend'));split_body()

if STAGE==-2:
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_02.blend'))
    dg=bpy.context.evaluated_depsgraph_get()
    for o in bpy.context.scene.objects:
        if 'source_component' in o and o['source_component'] in [10,11,28,29,32,33,36,37,39,40]:
            ev=o.evaluated_get(dg);vs=[ev.matrix_world@v.co for v in ev.data.vertices]
            print(o.name,'MIN',[round(min(v[k] for v in vs),4) for k in range(3)],'MAX',[round(max(v[k] for v in vs),4) for k in range(3)])

if STAGE==1:pass_one()
if STAGE==2:pass_two()
if STAGE==3:pass_three()
if STAGE==4:pass_four()
if STAGE==5:pass_five()
if STAGE==99:package()

if STAGE==0:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/build_miner.blend'))
    rig=bpy.data.objects['MinerRig'];rig.data.pose_position='REST'
    if rig.animation_data:
        rig.animation_data.action=None
        for track in rig.animation_data.nla_tracks:track.mute=True
    with bpy.data.libraries.load(str(ROOT/'blender/build_pack.blend'),link=False) as (src,dst):
        dst.objects=[n for n in src.objects if n=='Canvas knapsack']
    for o in dst.objects:
        if o:bpy.context.scene.collection.objects.link(o);o.location=(0,.24,1.23)
    setup_review()
    inventory=[]
    for o in bpy.context.scene.objects:
        inventory.append(dict(name=o.name,type=o.type,location=list(o.location),dimensions=list(o.dimensions),hide_render=o.hide_render,vertices=len(o.data.vertices) if o.type=='MESH' else 0,materials=[m.name if m else None for m in o.data.materials] if o.type=='MESH' else []))
    (OUT/'baseline_inventory.json').write_text(json.dumps(inventory,indent=2))
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'pass_00_baseline.blend'))
    render(0)
