"""Continue the reference study with independent loadouts and uncluttered body reviews."""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector, Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence as base
ROOT=base.ROOT;OUT=base.OUT
STAGE=int(sys.argv[sys.argv.index('--')+1])
VIEWS=['front','side','back','three_quarter']
GEAR={'wear_pack':['GEAR | backpack','GEAR | bedroll'],'wear_satchel':['GEAR | satchel'],'wear_canteen':['GEAR | canteen'],'carry_pickaxe':['GEAR | pickaxe'],'carry_pan':['GEAR | pan']}

def driver(o,path,prop,expression,index=None):
    try:o.driver_remove(path) if index is None else o.driver_remove(path,index)
    except Exception:pass
    fc=o.driver_add(path) if index is None else o.driver_add(path,index)
    d=fc.driver;d.type='SCRIPTED';v=d.variables.new();v.name='enabled';v.type='SINGLE_PROP'
    v.targets[0].id=bpy.data.objects['MinerRig'];v.targets[0].data_path='["'+prop+'"]';d.expression=expression

def setup_loadouts():
    rig=bpy.data.objects['MinerRig']
    for prop,groups in GEAR.items():
        rig[prop]=True;rig.id_properties_ui(prop).update(description=prop.replace('_',' ').capitalize()+' independently; shoulder straps belong to pack')
        for group in groups:
            c=bpy.data.collections.get(group)
            if not c:continue
            for o in c.objects:
                if o.hide_render:continue
                driver(o,'hide_render',prop,'not enabled');driver(o,'hide_viewport',prop,'not enabled')
    # Hands relax when the corresponding carried object is absent.
    for side,prop in [('Left','carry_pan'),('Right','carry_pickaxe')]:
        for digit in ['Index','Middle','Ring','Little']:
            for seg,relaxed in [('Proximal',.13),('Intermediate',.19),('Distal',.12)]:
                p=rig.pose.bones[side+digit+seg];p.rotation_mode='XYZ';grip=p.rotation_euler.x
                driver(p,'rotation_euler',prop,f'{relaxed} + enabled * {grip-relaxed}',0)

def loadout(name):
    rig=bpy.data.objects['MinerRig']
    for prop in GEAR:rig[prop]=name=='expedition' or (name=='field' and prop in ['wear_satchel','wear_canteen'])
    rig.update_tag();bpy.context.view_layer.update()

def render_set(stage,kit,black=False):
    loadout(kit);scene=bpy.context.scene
    if black:
        m=base.material('REVIEW silhouette',(0,0,0),1);m.node_tree.nodes['Principled BSDF'].inputs['Specular IOR Level'].default_value=0
        bpy.context.view_layer.material_override=m
    for view in VIEWS:
        scene.camera=bpy.data.objects['Review '+view]
        scene.render.filepath=str(OUT/f'pass_{stage:02}_{kit}_{"silhouette_" if black else ""}{view}.png');bpy.ops.render.render(write_still=True)
    bpy.context.view_layer.material_override=None

def finish(stage):
    loadout('expedition');bpy.context.scene.camera=bpy.data.objects['Review three_quarter']
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'pass_{stage:02}.blend'))
    for kit in ['base','expedition']:
        render_set(stage,kit);render_set(stage,kit,True)
    loadout('expedition')

def archive(o):
    for p in ['hide_render','hide_viewport']:
        try:o.driver_remove(p)
        except Exception:pass
    o.hide_render=True;o.hide_set(True);base.move(o,'ARCHIVE | superseded convergence surfaces')

def garment_weight(p):
    if p.z<1.14:
        t=max(0,min(1,(p.z-1.01)/.13));return {'Hips':1-t,'Spine':t}
    t=max(0,min(1,(p.z-1.17)/.15));return {'Spine':1-t,'Chest':t}

def pass_six():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'loadout_baseline.blend'))
    loadout('expedition');rig=bpy.data.objects['MinerRig']
    lookup={o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}
    cloth=bpy.data.materials['Convergence | dirty cream linen'];vest=bpy.data.materials['Convergence | charcoal brown vest']
    leather=bpy.data.materials['Convergence | worn leather'];iron=bpy.data.materials['Convergence | forged iron']
    # 1. A complete, tapered body costume that reads without equipment.
    for idx in [35,43,44,45,46,47,48,49,38,41,42,34,8,9]:
        o=lookup[idx]
        for v in o.data.vertices:
            p=v.co
            lift=.035*max(0,1-abs(p.z-1.0)/(.3 if p.z>1 else .28))
            p.z+=lift
            if idx in [35,43,44,45,46,47,48,49,38,41,42]:
                p.x*=.91;p.y*=.9
    for idx in [36,37]:
        o=lookup[idx];s=1 if idx==36 else -1
        for v in o.data.vertices:
            p=v.co;cx=s*(.21+.42*(1.4-p.z));p.x=cx+(p.x-cx)*.9;p.y*=.91
    # Inward shoulder placement follows the original rig, including hands and carried props.
    for s,side in [(1,'Left'),(-1,'Right')]:
        pb=rig.pose.bones[side+'UpperArm'];m=pb.matrix.copy();m.translation.x-=s*.012;pb.matrix=m
    for o in list(base.collection('COSTUME | vest and scarf').objects):
        if o.name.startswith('Vest |'):archive(o)
    rows=[(1.01,.180,.137,.11),(1.04,.180,.14,.10),(1.105,.184,.142,.12),(1.17,.190,.144,.20),(1.24,.205,.148,.32),(1.30,.212,.140,.48),(1.355,.210,.120,.68),(1.422,.164,.082,.88)]
    for s in [-1,1]:
        vertices=[];cols=25
        for j,(z,w,d,start) in enumerate(rows):
            for k in range(cols):
                t=k/(cols-1);a=start+(math.pi-start)*t
                zz=z
                if j>=5:zz-=(.12 if j==7 else .037 if j==6 else .006)*math.sin(a)**8
                if j==0:zz-=.028*(1-t)**3;zz+=.005*math.sin(a*2+s)
                x=s*w*math.sin(a);y=-d*math.cos(a)
                # Cloth planes shaped by chest fullness, back taper and a lower front dart.
                y+=.0025*math.sin(a*5+j*.4)*math.exp(-((z-1.09)/.10)**2)
                vertices.append((x,y,zz))
        faces=[]
        for j in range(len(rows)-1):
            for k in range(cols-1):a=j*cols+k;faces.append((a,a+1,a+cols+1,a+cols))
        o=base.mesh('Vest | fitted '+('left' if s>0 else 'right')+' front and back',vertices,faces,vest,'COSTUME | vest and scarf')
        base.bind(o,'Chest');base.replace_surface(o,vertices,faces,vest,garment_weight);base.thickness(o,.004)
        # Narrow turned edge belongs to the garment, not to detachable gear.
        edge=[vertices[j*cols] for j in range(len(rows))]
        base.ribbon('Vest | narrow turned edge '+str(s),[(x,y-.002,z) for x,y,z in edge],.007,vest,'COSTUME | vest and scarf','Chest')
        # Small lapel turn following the open V; no broad floating collar triangles.
        v=[(s*.035,-.147,1.231),(s*.079,-.147,1.322),(s*.118,-.109,1.395),(s*.14,-.096,1.408),(s*.109,-.139,1.344),(s*.056,-.157,1.251)]
        o=base.mesh('Vest | restrained lapel '+str(s),v,[(0,1,4,5),(1,2,3,4)],vest,'COSTUME | vest and scarf','Chest');base.thickness(o,.003)
    # The back remains a finished garment when the backpack is removed.
    base.ribbon('Vest | rear waist adjustment',[(0,.137,1.088),(0,.146,1.103)],.24,leather,'COSTUME | vest and scarf','Spine')
    # Keep all belt-mounted items attached at the new clothing waist height.
    for group in ['GEAR | satchel','GEAR | canteen','COSTUME | belt']:
        for o in base.collection(group).objects:
            if o.type=='MESH':
                for v in o.data.vertices:v.co.z+=.031
    # 2. Slouch hat: a thin warped brim around a pinched, inclined crown.
    hat=lookup[71];felt=bpy.data.materials['Convergence | battered brown felt']
    vertices=[];n=64
    brim=[(.113,.102,1.663),(.165,.15,1.652),(.235,.212,1.647),(.235,.212,1.644),(.165,.15,1.649),(.113,.102,1.660)]
    for rx,ry,z in brim:
        for k in range(n):
            a=k*math.tau/n;ca=math.cos(a);sa=math.sin(a);r=(rx-.113)/.122
            x=rx*ca*(1+.012*math.sin(3*a+.4));y=ry*sa
            # One side turns up; the opposite slouches, with a lifted front eyebrow opening.
            zz=z+r*(.023*ca-.012*sa+.008*math.cos(2*a+.6))+.003*r*math.sin(7*a)
            vertices.append((x,y,zz))
    faces=base.ring_faces(len(brim),n)[:-2]
    # Close the thin brim at its inner opening, keeping the crown separate in same mesh.
    for k in range(n):faces.append((k,(k+1)%n,5*n+(k+1)%n,5*n+k))
    offset=len(vertices);crown=[(.114,.102,1.661),(.112,.10,1.683),(.104,.092,1.729),(.092,.077,1.758),(.060,.05,1.766),(.006,.004,1.755)]
    for j,(rx,ry,z) in enumerate(crown):
        for k in range(n):
            a=k*math.tau/n;x=rx*math.cos(a);y=ry*math.sin(a);t=j/(len(crown)-1)
            x-=.008*t;y+=.004*t
            pinch=.008*math.exp(-((a-4.15)/.45)**2)+.008*math.exp(-((a-5.25)/.45)**2)
            y+=pinch*math.sin(t*math.pi)
            zz=z+.027*x-.011*math.exp(-(x/.032)**2)*t**3
            vertices.append((x,y,zz))
    faces.extend(tuple(offset+i for i in f) for f in base.ring_faces(len(crown),n))
    base.replace_surface(hat,vertices,faces,felt,lambda p:{'Head':1})
    for v in lookup[72].data.vertices:v.co.z+=.027*v.co.x
    # 3. Load-bearing pack: flatter sewn body, broad overlapping flap, seated bedroll.
    pack=bpy.data.objects['Backpack | original constructed piece 0'];canvas=bpy.data.materials['Convergence | earth olive canvas']
    profile=[(-.213,.158,.064),(-.19,.183,.085),(-.135,.191,.088),(-.06,.196,.087),(.02,.190,.08),(.10,.183,.077),(.17,.171,.07),(.196,.145,.061)]
    vertices=[];n=32
    for j,(z,w,d) in enumerate(profile):
        for k in range(n):
            a=k*math.tau/n;ca=math.cos(a);sa=math.sin(a)
            x=w*math.copysign(abs(ca)**.37,ca);y=.005+d*math.copysign(abs(sa)**.38,sa)
            if sa>0:y-=.009*(math.exp(-((x-.12)/.025)**2)+math.exp(-((x+.12)/.025)**2))
            zz=z-.013*(1-abs(x)/.196)*(max(0,sa))+.004*math.sin(a*3+.8)
            vertices.append((x,y,zz))
    base.replace_surface(pack,vertices,base.ring_faces(len(profile),n),canvas,lambda p:{'Chest':1})
    flap=bpy.data.objects['Backpack | original constructed piece 1'];v=[];f=[]
    for j,(z,y,w) in enumerate([(.198,.00,.15),(.176,.083,.172),(.117,.105,.18),(.06,.11,.175),(.035,.112,.164)]):
        for k in range(17):
            t=k/16;x=(2*t-1)*w;zz=z+(.029*abs(2*t-1)-.012*(1-abs(2*t-1)) if j==4 else 0)
            v.append((x,y-.006*(math.exp(-((x-.12)/.025)**2)+math.exp(-((x+.12)/.025)**2)),zz))
    for j in range(4):
        for k in range(16):a=j*17+k;f.append((a,a+1,a+18,a+17))
    base.replace_surface(flap,v,f,canvas,lambda p:{'Chest':1});base.thickness(flap,.004)
    for o in list(base.collection('GEAR | backpack').objects):
        if o.name.startswith('Backpack | original constructed piece') and o not in [pack,flap]:archive(o)
        elif o.name.startswith(('Pack | load bearing','Backpack | lower attachment')):archive(o)
    for s in [-1,1]:
        x=s*.12
        base.ribbon('Pack | continuous closure '+str(s),[(x,.317,1.43),(x,.355,1.37),(x,.363,1.31),(x,.363,1.25),(x,.38,1.18),(x,.381,1.12),(x,.363,1.041)],.024,leather,'GEAR | backpack','Chest')
        base.buckle('Pack | closure frame '+str(s),(x,.385,1.17),.030,.036,iron,'GEAR | backpack')
    for o in base.collection('GEAR | bedroll').objects:
        if o.type=='MESH':
            for v in o.data.vertices:
                p=v.co;p.z-=.018;p.z-=.006*math.exp(-((p.x+.07)/.12)**2)
    # Fit garment layers against the actual shirt surface rather than assumed ellipses.
    from mathutils.bvhtree import BVHTree
    bpy.context.view_layer.update();tree=BVHTree.FromObject(lookup[35],bpy.context.evaluated_depsgraph_get())
    def fit(p,clearance,only_out=True):
        radial=Vector((p.x,p.y,0));r=radial.length
        if r<.01:return
        hit,normal,face,distance=tree.ray_cast(Vector((0,0,p.z)),radial/r,.5)
        if hit is not None:
            target=distance+clearance
            if not only_out or target>r:p.x*=target/r;p.y*=target/r
    for o in base.collection('COSTUME | vest and scarf').objects:
        if o.name.startswith('Vest | fitted') or o.name.startswith('Vest | narrow') or o.name.startswith('Vest | restrained'):
            for v in o.data.vertices:fit(v.co,.006)
    for idx in [41,42]:
        o=lookup[idx]
        for v in o.data.vertices:fit(v.co,.002,False)
    # Seat the pack on the back and the front harness on the garment.
    for group in ['GEAR | backpack','GEAR | bedroll']:
        for o in base.collection(group).objects:
            if o.type!='MESH' or o.hide_render:continue
            for v in o.data.vertices:
                if o.name.startswith('Pack | fitted shoulder'):
                    if v.co.y<0:fit(v.co,.012,False)
                    else:v.co.y-=.025
                else:v.co.y-=.025
    setup_loadouts();finish(6)

if STAGE==6:pass_six()

def face_render(stage):
    scene=bpy.context.scene;c=bpy.data.objects.get('Review face')
    if not c:
        d=bpy.data.cameras.new('Review face');d.type='ORTHO';d.ortho_scale=.40
        c=bpy.data.objects.new('Review face',d);base.collection('REVIEW | cameras and neutral lighting').objects.link(c)
        c.location=(1.5,-7,1.62);c.rotation_euler=(Vector((0,-.005,1.584))-c.location).to_track_quat('-Z','Y').to_euler()
    scene.camera=c;scene.render.filepath=str(OUT/f'pass_{stage:02}_face.png');bpy.ops.render.render(write_still=True)

if STAGE==70:
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_06.blend'));loadout('base');face_render(6)

def pass_seven():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_06.blend'));loadout('expedition')
    lookup={o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}
    # 1. Correct upper garment coverage and harness depth using the actual vest surface.
    from mathutils.bvhtree import BVHTree
    verts=[];faces=[]
    for o in base.collection('COSTUME | vest and scarf').objects:
        if o.name.startswith('Vest | fitted'):
            for v in o.data.vertices:
                p=v.co
                if p.z>1.35 and p.y>0 and abs(p.x)>.055:p.y+=.016*min(1,(p.z-1.35)/.05)
            off=len(verts);verts.extend(v.co.copy() for v in o.data.vertices);faces.extend(tuple(off+i for i in p.vertices) for p in o.data.polygons)
    tree=BVHTree.FromPolygons(verts,faces)
    for o in base.collection('GEAR | backpack').objects:
        if not o.name.startswith('Pack | fitted shoulder'):continue
        for v in o.data.vertices:
            p=v.co
            if p.y<0 and p.z<1.42:
                d=Vector((p.x,p.y,0));r=d.length
                hit,normal,face,dist=tree.ray_cast(Vector((0,0,p.z)),d.normalized(),.5)
                if hit is not None:p.x*=(dist+.007)/r;p.y*=(dist+.007)/r
    # Seat the belt frame on the belt face, which was narrowed in pass 6.
    for o in base.collection('COSTUME | belt').objects:
        if o.type=='MESH':
            for v in o.data.vertices:v.co.y+=.017
    # 2. Reconstruct the face surface on the SAME head object and Head bone.
    head=lookup[52];skin=bpy.data.materials['Convergence | warm weathered skin']
    profile=[(1.474,.034,.038),(1.487,.051,.05),(1.502,.063,.058),(1.519,.071,.064),(1.537,.078,.068),(1.551,.083,.071),(1.563,.087,.074),(1.573,.089,.076),(1.582,.091,.079),(1.593,.089,.079),(1.604,.086,.080),(1.615,.085,.080),(1.627,.085,.081),(1.641,.086,.082),(1.660,.086,.081),(1.679,.076,.074),(1.695,.053,.058),(1.706,.008,.018)]
    def section(z):
        for (za,wa,da),(zb,wb,db) in zip(profile,profile[1:]):
            if za<=z<=zb:
                t=(z-za)/(zb-za);return wa+(wb-wa)*t,da+(db-da)*t
        return profile[0][1:] if z<profile[0][0] else profile[-1][1:]
    vertices=[];n=80
    for z,w,d in profile:
        for k in range(n):
            a=k*math.tau/n;x=w*math.cos(a);y=.002+d*math.sin(a)
            if y<0:
                front=max(0,-math.sin(a))**3
                def g(cx,cz,sx,sz):return math.exp(-((x-cx)/sx)**2-((z-cz)/sz)**2)
                # Nasal bridge and tip with narrow sides; recessed eye sockets and broad cheek planes.
                displacement=.025*g(0,1.588,.016,.022)+.014*g(0,1.613,.014,.031)
                displacement+=.013*g(0,1.578,.021,.010)
                displacement+=.008*(g(.019,1.574,.009,.010)+g(-.019,1.574,.009,.010))
                displacement+=.010*(g(.050,1.591,.024,.019)+g(-.050,1.591,.024,.019))
                displacement+=.009*(g(.036,1.633,.026,.009)+g(-.036,1.633,.026,.009))
                displacement-=.009*(g(.035,1.615,.024,.008)+g(-.035,1.615,.024,.008))
                displacement+=.013*g(0,1.547,.035,.018)+.005*g(0,1.503,.031,.013)
                y-=displacement*front
            vertices.append((x,y,z))
    base.replace_surface(head,vertices,base.ring_faces(len(profile),n),skin,lambda p:{'Head':1})
    # The source neck was a full-width cylinder penetrating the jaw. Taper it into the skull.
    neckverts=[];neckprofile=[(1.415,.061,.056),(1.44,.058,.051),(1.459,.051,.045),(1.48,.043,.037),(1.51,.041,.039),(1.54,.045,.044)]
    for z,w,d in neckprofile:
        for k in range(32):
            a=k*math.tau/32;neckverts.append((w*math.cos(a),.012+d*math.sin(a),z))
    base.replace_surface(lookup[50],neckverts,base.ring_faces(len(neckprofile),32),skin,lambda p:{'Neck':1})
    # Small inset nostril surfaces articulate underside of nose; no ball-shaped nasal pieces.
    shadow=base.material('Identity | nostril shadow',(.048,.019,.011),.9)
    for s in [-1,1]:
        v=[(s*.009,-.110,1.570),(s*.016,-.115,1.572),(s*.023,-.107,1.572),(s*.017,-.108,1.567)]
        base.mesh('Face | nostril inset '+str(s),v,[(0,1,2,3)],shadow,'BODY | head and face','Head')
    for idx in [53,54,55,56]:
        for v in lookup[idx].data.vertices:v.co.y-=.006
    # Eyes and lids are smaller, less protruding; brows follow a slanted adult supraorbital line.
    for idx in [61,62,63,64,65,66,67,68]:
        o=lookup[idx]
        for v in o.data.vertices:
            p=v.co;p.z=1.616+(p.z-1.616)*.72;p.y+=.0015
    for idx in [69,70]:
        for v in lookup[idx].data.vertices:
            p=v.co;p.z=1.631+(p.z-1.633)*.9-.045*(abs(p.x)-.02);p.y-=.003
    hair=bpy.data.materials['Convergence | dark brown hair']
    # A short beard shell closely follows the new cheek/jaw cross sections.
    beard=lookup[51];v=[];f=[];cols=49;rows=9
    for j in range(rows):
        t=j/(rows-1)
        for k in range(cols):
            a=-1.48+k*2.96/(cols-1);side=abs(math.sin(a))
            top=1.538+.060*side**1.7;bottom=1.469+.045*side**1.4+.0015*math.sin(k*2.2)
            z=top*(1-t)+bottom*t;w,d=section(max(1.474,z));x=(w+.0035)*math.sin(a);y=-(d+.0045)*math.cos(a)+.001
            v.append((x,y,z))
    for j in range(rows-1):
        for k in range(cols-1):a=j*cols+k;f.append((a,a+cols,a+cols+1,a+1))
    base.replace_surface(beard,v,f,hair,lambda p:{'Head':1})
    bpy.context.view_layer.update();headtree=BVHTree.FromObject(head,bpy.context.evaluated_depsgraph_get())
    for vertex in beard.data.vertices:
        p=vertex.co;d=Vector((p.x,p.y-.002,0));r=d.length
        hit,normal,index,distance=headtree.ray_cast(Vector((0,.002,max(1.475,p.z))),d.normalized(),.3)
        if hit is not None:
            p.x=d.x/r*(distance+.003);p.y=.002+d.y/r*(distance+.003)
    # Replace the straight hanging hair slabs with short curved locks around the ears and nape.
    for o in list(base.collection('IDENTITY | hair and beard').objects):archive(o)
    v=[];f=[]
    for j in range(7):
        t=j/6
        for k in range(41):
            a=-.32+(math.pi+.64)*k/40;r=.087+.009*math.sin(t*math.pi)
            z=1.686-t*(.135+.016*math.sin(a)**2)+.007*math.sin(a*5)*t
            v.append((r*math.cos(a),.008+(r+.009*t)*math.sin(a),z))
    for j in range(6):
        for k in range(40):a=j*41+k;f.append((a,a+1,a+42,a+41))
    o=base.mesh('Hair | curved scalp and nape',v,f,hair,'IDENTITY | hair and beard','Head');base.thickness(o,.003)
    for i in range(23):
        a=-.28+(math.pi+.56)*i/22;v=[];f=[];end=1.526+.014*math.sin(i*1.8)
        for j in range(7):
            t=j/6;ang=a+.12*math.sin(t*math.pi+i*.5);r=.091+.014*math.sin(t*math.pi)
            cx=r*math.cos(ang);cy=.011+r*math.sin(ang)+.013*t*t;z=1.653*(1-t)+end*t
            width=.013*math.sin(math.pi*(.14+.85*t))
            for k in range(5):
                u=k/4*2-1;bulge=.004*(1-u*u)
                v.append((cx-u*width*math.sin(ang)+bulge*math.cos(ang),cy+u*width*math.cos(ang)+bulge*math.sin(ang),z+.005*u*math.sin(i+t*2)))
        for j in range(6):
            for k in range(4):idx=j*5+k;f.append((idx,idx+1,idx+6,idx+5))
        o=base.mesh('Hair | swept clump '+str(i),v,f,hair,'IDENTITY | hair and beard','Head');base.thickness(o,.002)
    # 3. Human wrist-to-knuckle transition; preserve original finger bones and individual fingers.
    for idx in [28,29]:
        o=lookup[idx];s=1 if idx==28 else -1;side='Left' if s>0 else 'Right';vertices=[];n=24
        sections=[(0,.026,.022),(.2,.031,.024),(.42,.037,.024),(.64,.041,.022),(.84,.042,.019),(1,.04,.015)]
        for t,w,d in sections:
            for k in range(n):
                a=k*math.tau/n;yy=math.cos(a)*w;xx=math.sin(a)*d
                x=s*(.45+.041*t+xx+yy*.37*t);y=-.015+.0075*t+yy;z=.765-.070*t
                z+=.003*math.sin(a*2)*t
                vertices.append((x,y,z))
        base.replace_surface(o,vertices,base.ring_faces(len(sections),n),skin,lambda p,side=side:{side+'Hand':1})
    # Shorter, broader lower face matches adult jaw proportions better than the old pointed chin.
    for idx in [52,51,53,54,55,56]:
        for vertex in lookup[idx].data.vertices:
            p=vertex.co;t=max(0,min(1,(1.57-p.z)/.10));p.z+=.022*t;p.x*=1+.14*t
    finish(7);loadout('base');face_render(7)

if STAGE==7:pass_seven()

def pass_eight():
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'pass_07.blend'));loadout('expedition')
    lookup={o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}
    cloth=bpy.data.materials['Convergence | dirty cream linen'];red=bpy.data.materials['Convergence | oxblood cotton'];leather=bpy.data.materials['Convergence | worn leather'];iron=bpy.data.materials['Convergence | forged iron']
    # 1. Scarf is an overlapping folded cloth, with gravity-driven unequal tails.
    for o in list(base.collection('COSTUME | vest and scarf').objects):
        if o.name.startswith('Neckerchief |'):archive(o)
    vertices=[];faces=[];n=64
    for j in range(6):
        t=j/5
        for k in range(n):
            a=k*math.tau/n;front=max(0,-math.sin(a));r=.062+.018*t+.002*math.sin(t*math.pi*3)
            z=1.462-.038*t-.026*t*front+.006*math.cos(a+.3)
            vertices.append((r*math.cos(a),.003+r*math.sin(a)-.007*t*front,z))
    for j in range(5):
        for k in range(n):a=j*n+k;b=j*n+(k+1)%n;faces.append((a,b,b+n,a+n))
    o=base.mesh('Neckerchief | overlapping neck folds',vertices,faces,red,'COSTUME | vest and scarf','Neck');base.thickness(o,.002)
    for p in o.data.polygons:p.use_smooth=True
    for s in [-1,1]:
        v=[];f=[];length=.122 if s>0 else .098
        for j in range(8):
            t=j/7;z=1.416-length*t;w=.019*(1-.77*t**3)
            cx=.006+s*.025*t+.004*math.sin(t*4+s);cy=-.10-.058*math.sin(t*math.pi*.62)
            for k in range(7):
                u=k/6*2-1;v.append((cx+w*u,cy+.008*math.sin(u*math.pi+t*.6),z+.009*u*t))
        for j in range(7):
            for k in range(6):a=j*7+k;f.append((a,a+1,a+8,a+7))
        o=base.mesh('Neckerchief | draped tail '+str(s),v,f,red,'COSTUME | vest and scarf','Chest');base.thickness(o,.002)
        for p in o.data.polygons:p.use_smooth=True
    # Twisted, flattened knot with creased surface, integrated into the wrap.
    v=[];f=[]
    for j in range(5):
        t=j/4
        for k in range(7):
            u=k/6*2-1;v.append((.005+.022*u*(.88+.12*math.sin(t*math.pi)),-.105-.009*math.sin(t*math.pi)-.003*math.cos(u*math.pi),1.432-.034*t+.006*u*(t-.5)))
    for j in range(4):
        for k in range(6):a=j*7+k;f.append((a,a+1,a+8,a+7))
    o=base.mesh('Neckerchief | tied cloth knot',v,f,red,'COSTUME | vest and scarf','Neck');base.thickness(o,.003)
    for p in o.data.polygons:p.use_smooth=True
    torso=lookup[35]
    for vertex in torso.data.vertices:
        p=vertex.co
        if p.y<0:
            center=math.exp(-(p.x/.08)**2)
            p.y-=.007*math.exp(-((p.z-1.095-.5*p.x)/.028)**2)*center
            p.y+=.004*math.exp(-((p.z-1.145+.6*p.x)/.022)**2)*center
            p.y-=.004*math.exp(-((p.z-1.235-.4*p.x)/.04)**2)*center
    # 2. Construction of trousers: fly overlap and an actual open tear at the right knee.
    trouser=bpy.data.materials['Convergence | heavy umber trousers']
    o=base.ribbon('Trousers | overlapping fly',[(.01,-.115,1.025),(.008,-.123,.983),(.004,-.122,.932),(-.003,-.112,.89)],.014,trouser,'COSTUME | trousers','Hips')
    from mathutils.bvhtree import BVHTree
    bpy.context.view_layer.update();seat_tree=BVHTree.FromObject(lookup[34],bpy.context.evaluated_depsgraph_get())
    for vertex in o.data.vertices:
        p=vertex.co;hit,normal,face,distance=seat_tree.ray_cast(Vector((p.x,0,p.z)),Vector((0,-1,0)),.3)
        if hit is not None:p.y=hit.y-.002
    for face in o.data.polygons:face.use_smooth=True
    import bmesh
    leg=lookup[9];old=leg.data.copy();old.name='Trousers R | intact pre-tear';old.use_fake_user=True
    bm=bmesh.new();bm.from_mesh(leg.data)
    edges=[e for e in bm.edges if all(.49<v.co.z<.65 and v.co.y<-.025 for v in e.verts)]
    bmesh.ops.subdivide_edges(bm,edges=edges,cuts=2,use_grid_fill=True)
    cut=[]
    for f in bm.faces:
        p=f.calc_center_median();shape=((p.x+.11)/.052)**2+((p.z-.568-.10*(p.x+.11))/.016)**2
        if p.y<-.060 and shape<1:cut.append(f)
    bmesh.ops.delete(bm,geom=cut,context='FACES')
    boundary=[v for v in bm.verts if .53<v.co.z<.61 and v.co.y<-.055 and any(e.is_boundary for e in v.link_edges)]
    for vertex in boundary:
        p=vertex.co;theta=math.atan2((p.z-.568)/.016,(p.x+.11)/.052);irregular=1+.06*math.sin(theta*5+.4)
        p.x=-.11+.052*math.cos(theta)*irregular;p.z=.568+.016*math.sin(theta)*irregular+.10*(p.x+.11)
        p.y-=.002*max(0,math.sin(theta))
    leg['intentional_knee_boundary_vertices']=len(boundary)
    bm.to_mesh(leg.data);bm.free();leg.data.update()
    leg['intentional_open_knee_faces_removed']=len(cut)
    # Underlying knee skin is a separate shallow anatomical patch, not a dark painted spot.
    skin=bpy.data.materials['Convergence | warm weathered skin'];v=[];f=[]
    for j in range(5):
        z=.54+j*.014
        for k in range(9):
            u=k/8*2-1;v.append((-.11+u*.057,-.086+.027*u*u,z+.004*u))
    for j in range(4):
        for k in range(8):a=j*9+k;f.append((a,a+1,a+10,a+9))
    o=base.mesh('Body | knee beneath trouser tear',v,f,skin,'BODY | clothed anatomy');base.bind(o,'RightUpperLeg')
    def weight(p):
        t=max(0,min(1,(p.z-.455)/.15));return {'RightUpperLeg':t,'RightLowerLeg':1-t}
    base.replace_surface(o,v,f,skin,weight)
    # 3. Built boot shafts and insteps: collars, diagonal straps, separate stacked heels.
    for s,side in [(1,'Left'),(-1,'Right')]:
        v=[];f=[];n=40
        for j in range(2):
            for k in range(n):
                a=k*math.tau/n;v.append((s*.11+.075*math.cos(a),.075*math.sin(a),.335+j*.017+.004*math.sin(a+s)))
        for k in range(n):a=k;b=(k+1)%n;f.append((a,b,b+n,a+n))
        o=base.mesh('Boot | separate shaft collar '+side,v,f,leather,'COSTUME | boots',side+'Foot');base.thickness(o,.003)
        # Instep strap follows the vamp diagonally and turns down onto the side.
        v=[];f=[]
        points=[(s*.042,-.084,.066),(s*.06,-.087,.10),(s*.095,-.10,.12),(s*.14,-.115,.112),(s*.177,-.124,.072)]
        for x,y,z in points:v.extend([(x,y-.011,z),(x,y+.011,z)])
        for j in range(4):a=j*2;f.append((a,a+1,a+3,a+2))
        o=base.mesh('Boot | diagonal instep strap '+side,v,f,leather,'COSTUME | boots',side+'Foot');base.thickness(o,.003)
        o=base.buckle('Boot | instep buckle '+side,(s*.152,-.130,.108),.028,.025,iron,'COSTUME | boots');base.bind(o,side+'Foot')
        sole=bpy.data.materials['Convergence | boot sole']
        o=base.box_loft('Boot | stacked heel '+side,[(s*.11,.019,.012,.061,.044),(s*.11,.019,.039,.062,.045)],sole,'COSTUME | boots',side+'Foot',16)
    finish(8);loadout('base');face_render(8)

if STAGE==8:pass_eight()

def package_loadouts(stage=8,packaging_stage=9,quality_status=None):
    bpy.ops.wm.open_mainfile(filepath=str(OUT/f'pass_{stage:02}.blend'));loadout('expedition')
    rig=bpy.data.objects['MinerRig'];scene=bpy.context.scene
    # New closure frames are rigid objects: attach them to the chest before export preparation.
    for group in ['GEAR | backpack','GEAR | bedroll']:
        for o in base.collection(group).objects:
            if o.type=='MESH' and o.parent is None:
                world=o.matrix_world.copy();o.parent=rig;o.parent_type='BONE';o.parent_bone='Chest'
                o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.Identity(4);bpy.context.view_layer.update()
                o.matrix_parent_inverse=o.matrix_world.inverted();o.matrix_basis=world;bpy.context.view_layer.update()
    errors=[];cases=[]
    core=[o for o in scene.objects if o.type in {'MESH','CURVE'} and not o.hide_render and not any(c.name.startswith('GEAR |') for c in o.users_collection) and not any(c.hide_render for c in o.users_collection)]
    for mask in range(32):
        state={prop:bool(mask&(1<<i)) for i,prop in enumerate(GEAR)}
        for prop,value in state.items():rig[prop]=value
        rig.update_tag();bpy.context.view_layer.update()
        for prop,groups in GEAR.items():
            for group in groups:
                for o in base.collection(group).objects:
                    if o.type!='MESH':continue
                    for path in ['hide_render','hide_viewport']:
                        if getattr(o,path)!=(not state[prop]):errors.append({'case':mask,'object':o.name,'property':path})
        for o in core:
            if o.hide_render:errors.append({'case':mask,'core_hidden':o.name})
        cases.append({'mask':mask,'state':state,'visible_gear_objects':sum(not o.hide_render for groups in GEAR.values() for g in groups for o in base.collection(g).objects if o.type=='MESH')})
    if errors:raise RuntimeError('Loadout checks failed: '+json.dumps(errors[:10]))
    metrics={};loadout('expedition')
    nonfinite=[];weight_errors=[]
    geometry=[o for o in scene.objects if o.type in {'MESH','CURVE'} and not o.hide_render and not any(c.hide_render for c in o.users_collection)]
    groom=[]
    for o in geometry:
        if o.type=='CURVE':
            points=[p for s in o.data.splines for p in s.points]
            if any(not all(math.isfinite(c) for c in p.co) for p in points):nonfinite.append(o.name)
            groom.append({'object':o.name,'splines':len(o.data.splines),'control_points':len(points),'parent_bone':o.parent_bone})
            continue
        for v in o.data.vertices:
            if not all(math.isfinite(c) for c in v.co):nonfinite.append(o.name)
        if any(m.type=='ARMATURE' for m in o.modifiers):
            for v in o.data.vertices:
                total=sum(g.weight for g in v.groups if o.vertex_groups[g.group].name in rig.data.bones)
                if abs(total-1)>.001:weight_errors.append((o.name,v.index,total))
    for kit in ['base','field','expedition']:
        loadout(kit)
        visible=[o for o in scene.objects if o.type=='MESH' and not o.hide_render and not any(c.hide_render for c in o.users_collection)]
        metrics[kit]={'mesh_objects':len(visible),'base_triangles':sum(len(p.vertices)-2 for o in visible for p in o.data.polygons)}
        curves=[o for o in scene.objects if o.type=='CURVE' and not o.hide_render and not any(c.hide_render for c in o.users_collection)]
        metrics[kit]['curve_objects']=len(curves)
        deps=bpy.context.evaluated_depsgraph_get();evaluated_triangles=0
        for o in visible+curves:
            evaluated=o.evaluated_get(deps);mesh=evaluated.to_mesh()
            if mesh:evaluated_triangles+=sum(len(p.vertices)-2 for p in mesh.polygons)
            evaluated.to_mesh_clear()
        metrics[kit]['evaluated_triangles_including_groom']=evaluated_triangles
    audit={'loadout_combinations_checked':32,'visibility_errors':errors,'nonfinite_vertices':nonfinite,'weight_errors':weight_errors[:30],'states':metrics,'preserved_actions':[a.name for a in bpy.data.actions],'cases':cases}
    audit['modeling_pass']=stage
    audit['groom']=groom
    (OUT/'loadout_verification.json').write_text(json.dumps(audit,indent=2))
    (OUT/f'pass_{stage:02}_loadout_verification.json').write_text(json.dumps(audit,indent=2))
    if nonfinite or weight_errors:raise RuntimeError('Geometry/weight check failed: '+str(weight_errors[:5]))
    block=bpy.data.texts.get('START HERE | convergence status') or bpy.data.texts.new('START HERE | convergence status');block.clear()
    block.write('1848 — The Intrepid Miner | Pass 8 working asset\n\nINTERMEDIATE ART: large-form/identity match still below final acceptance.\n\nLOADOUT CONTROLS\nSelect MinerRig in the Outliner, then Object Properties > Custom Properties.\nwear_pack: backpack, fitted shoulder harness, hardware and bedroll together.\nwear_satchel / wear_canteen / carry_pickaxe / carry_pan: independent checkboxes.\nHands relax when the corresponding carried item is disabled.\nAll five controls affect viewport and rendering and persist without a custom add-on.\n\nQUICK START FILES\nminer_convergence_base.blend: no travel equipment.\nminer_convergence_field.blend: satchel and canteen only.\nminer_convergence_working.blend: full expedition equipment.\nAll three are snapshots of the same modular asset; do subsequent modeling in working.blend.\n\nReferences are packed and named PRIMARY/SECONDARY.\nOriginal skeleton and 21 action datablocks retained; review pose is not a finalized animation/export solution.\nReport: MINER_CONVERGENCE_REVIEW.md.\n')
    block.from_string(block.as_string().replace('Pass 8 working asset',f'Pass {stage} working asset'))
    if quality_status:
        block.from_string(block.as_string().replace('INTERMEDIATE ART: large-form/identity match still below final acceptance.',quality_status))
        block.write('\nProcedural surface materials need baking for game export. Editable hair curves need conversion/LOD planning. Mesh triangle counts exclude thickness and groom; evaluated counts include both.\n')
    scene.camera=bpy.data.objects['Review three_quarter']
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=='VIEW_3D':area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
    for kit,suffix in [('base','base'),('field','field'),('expedition','working')]:
        loadout(kit);bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/f'blender/miner_convergence_{suffix}.blend'))
    render_set(stage,'field')
    # Re-render base and expedition after parenting the new frames.
    for kit in ['base','expedition']:render_set(packaging_stage,kit)
    print('LOADOUT_AUDIT',json.dumps({k:v for k,v in audit.items() if k!='cases'}))

if STAGE==98:package_loadouts()

if STAGE==60:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/miner_convergence_working.blend'))
    setup_loadouts()
    for kit in ['base','expedition']:render_set(50,kit)
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'loadout_baseline.blend'))
    for o in bpy.context.scene.objects:
        if 'Backpack | original' in o.name:
            print(o.name,len(o.data.vertices),[round(x,3) for x in o.dimensions],o.hide_render)
