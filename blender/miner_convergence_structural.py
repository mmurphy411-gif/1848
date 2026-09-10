"""Measured structural continuation. Each numbered stage modifies three priority groups."""
import bpy,sys,math,json,bmesh
from pathlib import Path
from mathutils import Vector,Matrix
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence_continue as c
b=c.base;ROOT=c.ROOT;OUT=c.OUT;STAGE=int(sys.argv[sys.argv.index('--')+1])

def load_previous(n):
    bpy.ops.wm.open_mainfile(filepath=str(OUT/f'pass_{n-1:02}.blend'));c.loadout('expedition')
    return {o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}

def active_meshes(group):return [o for o in b.collection(group).objects if o.type=='MESH' and not o.hide_render]

def skin_matrix(o,v):
    rig=bpy.data.objects['MinerRig'];M=o.matrix_world.copy()
    if any(m.type=='ARMATURE' for m in o.modifiers):
        transform=Matrix(((0,0,0,0),)*4);total=0
        for g in v.groups:
            name=o.vertex_groups[g.group].name
            if name not in rig.pose.bones:continue
            transform+=(rig.pose.bones[name].matrix@rig.data.bones[name].matrix_local.inverted())*g.weight;total+=g.weight
        if total>.99:M=rig.matrix_world@transform@rig.matrix_world.inverted()@M
    return M

def deform_world(o,fn):
    for v in o.data.vertices:
        m=skin_matrix(o,v);p=m@v.co;v.co=m.inverted()@Vector(fn(p))
    o.data.update()

def rotate_bone(name,axis,degrees):
    rig=bpy.data.objects['MinerRig'];p=rig.pose.bones[name];pivot=p.head.copy()
    p.matrix=Matrix.Translation(pivot)@Matrix.Rotation(math.radians(degrees),4,axis)@Matrix.Translation(-pivot)@p.matrix
    bpy.context.view_layer.update()

def section(profile,z):
    for a,bb in zip(profile,profile[1:]):
        if a[0]<=z<=bb[0]:
            t=(z-a[0])/(bb[0]-a[0]);return [a[k]+(bb[k]-a[k])*t for k in range(1,len(a))]
    return profile[0][1:] if z<profile[0][0] else profile[-1][1:]

def tear(leg,center=-.11):
    bm=bmesh.new();bm.from_mesh(leg.data);cut=[]
    for f in bm.faces:
        p=f.calc_center_median()
        if p.y<-.035 and ((p.x-center)/.045)**2+((p.z-.573-.14*(p.x-center))/.020)**2<1:cut.append(f)
    bmesh.ops.delete(bm,geom=cut,context='FACES')
    for v in bm.verts:
        p=v.co
        if .535<p.z<.61 and p.y<-.035 and any(e.is_boundary for e in v.link_edges):
            a=math.atan2((p.z-.573)/.020,(p.x-center)/.045);r=1+.045*math.sin(a*7+.3)
            p.x=center+.045*math.cos(a)*r;p.z=.573+.020*math.sin(a)*r+.14*(p.x-center)
    bm.to_mesh(leg.data);bm.free();leg['intentional_open_knee_faces_removed']=len(cut)

def heavy_trousers(lookup):
    mat=bpy.data.materials['Convergence | heavy umber trousers']
    profile=[(.33,.072,.066),(.35,.077,.072),(.38,.081,.075),(.43,.071,.071),(.49,.069,.074),(.55,.078,.085),(.61,.080,.086),(.69,.085,.097),(.77,.095,.104),(.86,.097,.107),(.95,.092,.101)]
    for idx,s,side in [(8,1,'Left'),(9,-1,'Right')]:
        vs=[];n=48;rows=65
        for j in range(rows):
            z=.33+j/(rows-1)*.62;w,d=section(profile,z)
            cx=s*(.109+.006*math.exp(-((z-.4)/.09)**2));cy=-.015*math.exp(-((z-.55)/.16)**2)
            for k in range(n):
                a=k*math.tau/n;ca=math.cos(a);sa=math.sin(a)
                x=cx+w*math.copysign(abs(ca)**.86,ca);y=cy+d*math.copysign(abs(sa)**.88,sa)
                front=max(0,-sa)**2;back=max(0,sa)**3;u=(x-cx)*s
                # Discrete tension and compression folds, each anchored to a knee, cuff or crotch.
                fold=0
                for zc,slope,amp,width in [(.368,.4,.014,.009),(.397,-.6,.011,.010),(.441,.7,.008,.011),(.526,-.48,.012,.012),(.595,.55,.011,.012),(.643,-.6,.007,.016),(.805,-1.05,.006,.018)]:
                    center=zc+slope*u+.007*s
                    fold+=amp*math.exp(-((z-center)/width)**2)-amp*.48*math.exp(-((z-center-width*1.1)/(width*.7))**2)
                y-=front*fold
                y+=back*(.014*math.exp(-((z-(.505+.5*u))/.012)**2)+.011*math.exp(-((z-(.388-.65*u))/.010)**2))
                sidefold=.007*math.exp(-((z-(.39+.5*cy))/.018)**2)*abs(ca)**5
                x+=math.copysign(sidefold,ca)
                zz=z+.0035*math.sin(a*3+s)*math.exp(-((z-.35)/.03)**2)
                vs.append((x,y,zz))
        def weights(p,side=side):
            t=max(0,min(1,(p.z-.455)/.15));return {side+'UpperLeg':t,side+'LowerLeg':1-t}
        b.replace_surface(lookup[idx],vs,b.ring_faces(rows,n),mat,weights)
    tear(lookup[9])
    # Existing separate knee skin remains under the opening.
    knee=bpy.data.objects.get('Body | knee beneath trouser tear')
    if knee:
        for v in knee.data.vertices:v.co.y+=.006

def built_boots(lookup):
    leather=bpy.data.materials['Convergence | worn leather']
    profile=[(.05,.068,.076),(.10,.065,.075),(.15,.061,.065),(.20,.059,.061),(.26,.063,.063),(.32,.068,.069),(.351,.073,.072)]
    for idx,s,side in [(6,1,'Left'),(7,-1,'Right')]:
        vs=[];n=40;rows=39
        for j in range(rows):
            z=.05+j/(rows-1)*.301;w,d=section(profile,z)
            for k in range(n):
                a=k*math.tau/n;ca=math.cos(a);sa=math.sin(a);u=w*ca
                x=s*.11+u;y=d*math.copysign(abs(sa)**.83,sa)
                comp=0
                for zc,slope,amp in [(.105,.55,.010),(.137,-.6,.014),(.171,.4,.011),(.204,-.4,.007)]:
                    comp+=amp*math.exp(-((z-zc-slope*u*s)/.009)**2)-amp*.4*math.exp(-((z-zc-.010-slope*u*s)/.006)**2)
                x+=comp*ca*.55;y+=comp*sa
                vs.append((x,y,z+.004*ca*math.exp(-((z-.14)/.08)**2)))
        b.replace_surface(lookup[idx],vs,b.ring_faces(rows,n),leather,lambda p,side=side:{side+'Foot':1})
    # Longitudinal vamp construction, with a low toe box and a rising instep.
    stations=[(-.217,.012,.047),(-.207,.043,.060),(-.19,.062,.071),(-.15,.075,.079),(-.11,.077,.093),(-.07,.074,.119),(-.02,.064,.133),(.025,.057,.116),(.062,.049,.086),(.069,.018,.064)]
    for idx,s,side in [(0,1,'Left'),(1,-1,'Right')]:
        vs=[];n=32
        for y,w,top in stations:
            for k in range(n):
                a=k*math.tau/n;x=s*.11+w*math.cos(a);z=.034+(top-.034)*(max(0,math.sin(a))**.60 if math.sin(a)>0 else .055*math.sin(a))
                vs.append((x,y,z))
        b.replace_surface(lookup[idx],vs,b.ring_faces(len(stations),n),leather,lambda p,side=side:{side+'Foot':1})

def pack_weight():
    for group in ['GEAR | backpack','GEAR | bedroll']:
        for o in active_meshes(group):
            def fn(p):
                if 'fitted shoulder' in o.name:
                    if p.y>0:p.y-=.047*min(1,p.y/.15)
                    return p
                if group.endswith('bedroll'):
                    p.x*=.93;p.y-=.045;p.z+=.065*p.x
                    p.z=1.482+(p.z-1.482)*.92
                else:
                    low=max(0,min(1,(1.35-p.z)/.32));p.x*=.95-.055*low
                    p.y-=.047
                    p.z-=.017*low*max(0,1-(p.x/.2)**2)
                    if 'original constructed piece 0' in o.name:
                        p.y-=.009*math.exp(-((p.x-.115)/.026)**2)+.009*math.exp(-((p.x+.115)/.026)**2)
                return p
            deform_world(o,fn)

def weighted_stance():
    rig=bpy.data.objects['MinerRig']
    for s,side in [(1,'Left'),(-1,'Right')]:
        rotate_bone(side+'UpperArm','Y',-s*6)
        rig.pose.bones[side+'UpperArm'].scale.y*=1.045
        rig.pose.bones[side+'LowerArm'].scale.y*=1.035
        bpy.context.view_layer.update()
        rotate_bone(side+'UpperLeg','Y',-s*3)
        rotate_bone(side+'Foot','Y',s*3)
        rotate_bone(side+'Foot','Z',32 if s>0 else -12)
    rotate_bone('Spine','X',2)
    rotate_bone('Chest','Y',3)
    rotate_bone('Head','X',-4)
    rotate_bone('Head','Z',5)
    # Store the pose in the working file without altering the source rest skeleton/actions.
    rig['review_pose_note']='Pass 10: outward feet, wider arm clearance, slight torso counterbalance; source rest rig retained.'

def finish(n):
    c.finish(n);c.loadout('base');c.face_render(n);c.loadout('expedition')

def pass10():
    lookup=load_previous(10)
    heavy_trousers(lookup);built_boots(lookup);pack_weight();weighted_stance();finish(10)

def hat_proportions(lookup):
    # Reference front: approximately 170-pixel brim / 815-pixel figure height.
    # Reduce the oversized brim without losing the slouch silhouette or fitted crown.
    for idx in [71,72]:
        for v in lookup[idx].data.vertices:
            p=v.co
            if idx==71:
                brim=p.z<1.681
                p.x*=.86 if brim else .90;p.y*=.89 if brim else .92
                if p.z>1.677:p.z=1.677+(p.z-1.677)*.86
            else:p.x*=.91;p.y*=.92;p.z=1.677+(p.z-1.677)*.86

def leg_landmarks(lookup):
    # Raise the boot termination and the knee while retaining the hip and ground positions.
    keys=[(0,0),(.11,0),(.35,.042),(.57,.054),(.74,.025),(.93,0),(1.10,0)]
    def lift(p):
        p.z+=section(keys,p.z)[0];return p
    for group in ['COSTUME | trousers','COSTUME | boots']:
        for o in active_meshes(group):
            for v in o.data.vertices:v.co=lift(v.co)
    knee=bpy.data.objects.get('Body | knee beneath trouser tear')
    if knee:
        for v in knee.data.vertices:v.co=lift(v.co)
    # Resolve the existing leg and hip surfaces into one continuous trouser shell.
    # A local voxel union removes internal overlap; it is not a smoothing/detail pass.
    cloth=bpy.data.materials['Convergence | heavy umber trousers']
    profile=[(.891,.062,.071),(.925,.155,.105),(.968,.182,.114),(1.038,.169,.111)]
    v=[];n=48
    for z,w,d in profile:
        for k in range(n):
            a=k*math.tau/n;v.append((w*math.cos(a),d*math.sin(a),z))
    b.replace_surface(lookup[34],v,b.ring_faces(len(profile),n),cloth,lambda p:{'Hips':1})
    for idx in [8,9]:
        for vertex in lookup[idx].data.vertices:
            p=vertex.co;p.z+=.044*max(0,min(1,(p.z-.88)/.07))
    vs=[];fs=[]
    for idx in [8,9,34]:
        o=lookup[idx];off=len(vs);vs.extend(v.co.copy() for v in o.data.vertices);fs.extend(tuple(off+i for i in p.vertices) for p in o.data.polygons)
    o=b.mesh('Trousers | continuous work-cloth shell',vs,fs,cloth,'COSTUME | trousers')
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o
    bm=bmesh.new();bm.from_mesh(o.data)
    bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
    bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces));bm.to_mesh(o.data);bm.free()
    o.data.remesh_voxel_size=.0045;bpy.ops.object.voxel_remesh()
    mod=o.modifiers.new('Controlled union reduction','DECIMATE');mod.ratio=.25;bpy.ops.object.modifier_apply(modifier=mod.name)
    vs=[v.co.copy() for v in o.data.vertices];fs=[tuple(p.vertices) for p in o.data.polygons]
    def weights(p):
        side='Left' if p.x>0 else 'Right'
        hip=max(0,min(1,(p.z-.925)/.095));knee=max(0,min(1,(p.z-.48)/.18))
        return {'Hips':hip,side+'UpperLeg':(1-hip)*knee,side+'LowerLeg':(1-hip)*(1-knee)}
    b.bind(o,'Hips');b.replace_surface(o,vs,fs,cloth,weights)
    # Recut the intentional knee opening after the union operation.
    bm=bmesh.new();bm.from_mesh(o.data)
    cut=[f for f in bm.faces if (lambda p: p.y<-.045 and ((p.x+.11)/.043)**2+((p.z-.626-.14*(p.x+.11))/.018)**2<1)(f.calc_center_median())]
    bmesh.ops.delete(bm,geom=cut,context='FACES');bm.to_mesh(o.data);bm.free();o['intentional_open_knee_faces_removed']=len(cut)
    for idx in [8,9,34]:c.archive(lookup[idx])


def gear_alignment():
    shaft=bpy.data.objects['Pickaxe | tapered hickory shaft']
    pts=[skin_matrix(shaft,v)@v.co for v in shaft.data.vertices]
    upper=sum(pts[-12:],Vector())/12;lower=sum(pts[:12],Vector())/12
    before=lower-upper;desired=Vector((.105,.012,.065-upper.z));ratio=desired.length/before.length
    q=before.rotation_difference(desired);axis=before.normalized()
    for o in active_meshes('GEAR | pickaxe'):
        def fn(p):
            v=p-upper;return upper+q@(v+axis*(v.dot(axis)*(ratio-1)))
        deform_world(o,fn)
    # Keep the forged head transverse to the shaft; inherited wrist roll had tilted it upright.
    head=bpy.data.objects['Pickaxe | forged pick and adze'];center=upper+desired
    points=[(-.20,-.018,.001,.002),(-.15,-.019,.008,.010),(-.075,-.010,.012,.017),(0,.010,.019,.023),(.075,.028,.012,.018),(.145,.056,.004,.027),(.175,.072,.001,.025)]
    vs=[];n=8
    for x,z,rz,ry in points:
        for k in range(n):
            a=k*math.tau/n;world=center+Vector((x,ry*math.sin(a),z+rz*math.cos(a)))
            vs.append(head.matrix_world.inverted()@world)
    b.replace_surface(head,vs,b.ring_faces(len(points),n),bpy.data.materials['Convergence | forged iron'],lambda p:{'RightHand':1})
    pan=bpy.data.objects['Gold pan | original spun mesh reprofiled']
    pts=[pan.matrix_world@v.co for v in pan.data.vertices];pivot=max(pts,key=lambda p:p.z)
    normal=(pan.matrix_world.to_3x3().inverted().transposed()@Vector((0,0,1))).normalized()
    wanted=Vector((.40,-.86,.31)).normalized()
    if normal.dot(wanted)<0:normal=-normal
    q=normal.rotation_difference(wanted)
    original_center=sum(pts,Vector())/len(pts)
    down=Vector((.42,0,-1));down=(down-wanted*down.dot(wanted)).normalized()
    desired_center=pivot+down*.148
    deform_world(pan,lambda p:desired_center+q@((p-original_center)*.94))
    # All canteen parts move together: scale the mechanical assembly, not just its body.
    objs=active_meshes('GEAR | canteen');pts=[skin_matrix(o,v)@v.co for o in objs for v in o.data.vertices]
    center=Vector(tuple((min(p[k] for p in pts)+max(p[k] for p in pts))/2 for k in range(3)))
    for o in objs:deform_world(o,lambda p:center+(p-center)*.88+Vector((.030,0,.025)))

def pass11():
    lookup=load_previous(11);hat_proportions(lookup);leg_landmarks(lookup);gear_alignment();finish(11)

def upper_clothing(lookup):
    from mathutils.bvhtree import BVHTree
    for group in ['COSTUME | shirt','COSTUME | vest and scarf','COSTUME | belt and suspenders']:
        for o in active_meshes(group):
            if o.get('source_component') in [36,37,39,40]:continue
            for v in o.data.vertices:
                p=v.co;t=max(0,min(1,(p.z-1.10)/.25));p.x*=1-.075*t
    shirt=lookup[35]
    for v in shirt.data.vertices:
        p=v.co
        if p.y<0:
            front=max(0,1-(p.x/.20)**2)
            p.y-=front*.007*math.exp(-((p.z-(1.078+.36*p.x))/.011)**2)
            p.y+=front*.004*math.exp(-((p.z-(1.103-.4*p.x))/.015)**2)
    tree=BVHTree.FromPolygons([v.co.copy() for v in shirt.data.vertices],[tuple(p.vertices) for p in shirt.data.polygons])
    for o in active_meshes('COSTUME | vest and scarf'):
        if not o.name.startswith('Vest |'):continue
        if 'rear waist' in o.name:continue
        for v in o.data.vertices:
            p=v.co;front=max(0,-p.y/.14)
            p.z+=.048*max(0,min(1,(1.16-p.z)/.14))*(.45+.55*front)
            if p.y<0:
                a=math.atan2(abs(p.x),-p.y);newa=a+.19*max(0,1-a/1.57)**2
                direction=Vector((math.copysign(math.sin(newa),p.x),-math.cos(newa),0))
            else:direction=Vector((p.x,p.y,0)).normalized()
            hit,normal,idx,dist=tree.ray_cast(Vector((0,0,p.z)),direction,.4)
            if hit is not None:p.x=hit.x+direction.x*.009;p.y=hit.y+direction.y*.009
    for idx,s in [(36,1),(37,-1)]:
        for v in lookup[idx].data.vertices:
            p=v.co;cx=s*(.21+.42*(1.4-p.z));p.x=cx+(p.x-cx)*.90;p.y*=.91
            a=math.atan2(p.y,(p.x-cx)*s)
            longfold=.005*math.cos(a*3+.5*s)*math.exp(-((p.z-1.30)/.10)**2)
            p.y+=longfold*math.sin(a)
        rig=bpy.data.objects['MinerRig'];pb=rig.pose.bones[('Left' if s>0 else 'Right')+'UpperArm'];m=pb.matrix.copy();m.translation.x-=s*.012;pb.matrix=m
        bpy.context.view_layer.update()
    # The neckerchief sits lower at the front instead of reading as a straight collar band.
    for o in active_meshes('COSTUME | vest and scarf'):
        if o.name.startswith('Neckerchief | overlapping'):
            for v in o.data.vertices:v.co.z-=.010*max(0,-v.co.y/.08)

def forearm_structure(lookup):
    skin=bpy.data.materials['Convergence | warm weathered skin']
    for idx,s,side in [(32,1,'Left'),(33,-1,'Right')]:
        top=Vector((s*.337,.0,1.147));wrist=Vector((s*.45,-.015,.765));axis=(wrist-top).normalized()
        across=Vector((s,0,0));across=(across-axis*across.dot(axis)).normalized();depth=axis.cross(across).normalized()
        vs=[];rows=25;n=32
        profile=[(0,.044,.041),(.16,.049,.046),(.32,.050,.046),(.48,.044,.040),(.67,.035,.032),(.85,.027,.027),(1,.025,.023)]
        for j in range(rows):
            t=j/(rows-1);w,d=section(profile,t);center=top.lerp(wrist,t)
            for k in range(n):
                a=k*math.tau/n;ca=math.cos(a);sa=math.sin(a)
                lateral=w*math.copysign(abs(ca)**.88,ca);forward=d*math.copysign(abs(sa)**.86,sa)
                ridge=.0035*math.exp(-((a-2.25+.7*t)/.22)**2)*math.sin(t*math.pi)
                p=center+across*(lateral+ridge*ca)+depth*(forward+ridge*sa)
                vs.append(p)
        b.replace_surface(lookup[idx],vs,b.ring_faces(rows,n),skin,lambda p,side=side:{side+'LowerArm':1})

def adult_face(lookup):
    from mathutils.bvhtree import BVHTree
    head=lookup[52];old=BVHTree.FromPolygons([v.co.copy() for v in head.data.vertices],[tuple(p.vertices) for p in head.data.polygons])
    lo=min(v.co.z for v in head.data.vertices);hi=max(v.co.z for v in head.data.vertices);vs=[];rows=43;n=80
    for j in range(rows):
        z=lo+.0001+(hi-lo-.0002)*j/(rows-1)
        for k in range(n):
            a=k*math.tau/n;direction=Vector((math.cos(a),math.sin(a),0));hit,normal,idx,dist=old.ray_cast(Vector((0,.002,z)),direction,.3)
            p=hit if hit is not None else Vector((.003*math.cos(a),.002+.003*math.sin(a),z))
            x=p.x
            if p.y<0:
                def g(cx,cz,sx,sz):return math.exp(-((x-cx)/sx)**2-((z-cz)/sz)**2)
                # Orbital rims, malar planes, muzzle and jaw: anatomical forms, not surface wrinkles.
                p.y-=.003*(g(.042,1.602,.022,.010)+g(-.042,1.602,.022,.010))
                p.y+=.004*(g(.057,1.566,.017,.017)+g(-.057,1.566,.017,.017))
                p.y-=.004*g(0,1.534,.028,.012)
                p.y-=.004*(g(.019,1.578,.009,.006)+g(-.019,1.578,.009,.006))
                nasolabial=.021+.65*max(0,1.577-z)
                p.y+=.0025*(g(nasolabial,1.560,.004,.019)+g(-nasolabial,1.560,.004,.019))
            vs.append(p)
    b.replace_surface(head,vs,b.ring_faces(rows,n),bpy.data.materials['Convergence | warm weathered skin'],lambda p:{'Head':1})
    for idx in [53,54,55,56]:
        for v in lookup[idx].data.vertices:v.co.z-=.004
    for idx in [69,70]:
        for v in lookup[idx].data.vertices:
            p=v.co;p.z-=.003*max(0,1-abs(p.x)/.053)
    new=BVHTree.FromPolygons([v.co.copy() for v in head.data.vertices],[tuple(p.vertices) for p in head.data.polygons])
    for o in [lookup[51]]+[o for o in active_meshes('IDENTITY | facial hair') if o.name.startswith('Beard | grouped')]:
        for v in o.data.vertices:
            p=v.co;direction=Vector((p.x,p.y-.002,0)).normalized();hit,normal,idx,dist=new.ray_cast(Vector((0,.002,p.z)),direction,.3)
            if hit is not None:p.x=hit.x+direction.x*.0025;p.y=hit.y+direction.y*.0025
    # Expose the ears and break the straight bob silhouette with swept, unequal locks.
    for o in active_meshes('IDENTITY | hair and beard'):
        if not o.name.startswith('Hair | swept clump'):continue
        i=int(o.name.rsplit(' ',1)[1]);front=i<3 or i>19
        for v in o.data.vertices:
            p=v.co;t=max(0,min(1,(1.66-p.z)/.14))
            p.y+=.019*t*t;p.x+=.005*math.sin(i*1.7+t*5)*t
            if front:p.z+=.035*t*t;p.y+=.012*t

def pass12():
    lookup=load_previous(12);upper_clothing(lookup);forearm_structure(lookup);adult_face(lookup);finish(12)

if __name__=='__main__' and STAGE==10:pass10()
if __name__=='__main__' and STAGE==11:pass11()
if __name__=='__main__' and STAGE==12:pass12()
