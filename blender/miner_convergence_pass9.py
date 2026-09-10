"""Pass 9: fitted clothing layers, adult facial structure, distinct tool grips.

Run with Blender --background --python this_file -- 9.
The saved pass-8 working scene is preserved as the repeatable input checkpoint.
"""
import bpy, sys, math, json
from pathlib import Path
from mathutils import Vector, Matrix
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence_continue as c
b=c.base;ROOT=c.ROOT;OUT=c.OUT

def grid_faces(rows,cols):
    return [(j*cols+k,j*cols+k+1,(j+1)*cols+k+1,(j+1)*cols+k) for j in range(rows-1) for k in range(cols-1)]

def tree(o):
    return BVHTree.FromPolygons([v.co.copy() for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])

def surface(o,vs,fs,mat,weight):
    b.replace_surface(o,vs,fs,mat,weight)
    o.data.name=o.name+' | pass 9 surface'

def continuous_vest(shirt_tree,vest):
    # A sewn armhole is an opening in a continuous garment, not a detached shoulder cap.
    for o in list(b.collection('COSTUME | vest and scarf').objects):
        if not o.hide_render and o.name.startswith(('Vest | tailored','Vest | integrated','Vest | sewn shoulder')):c.archive(o)
    for s in [-1,1]:
        rows=49;cols=49;params=[];faces=[]
        for j in range(rows):
            z=1.024+j/(rows-1)*.421
            start=.28-.09*min(1,(z-1.024)/.166)+(max(0,z-1.19)/.255)**1.25*.95
            for k in range(cols):params.append([start+(math.pi-start)*k/(cols-1),z])
        def hole(a,z):return ((a-math.pi/2)/.44)**2+((z-1.34)/.067)**2
        for f in grid_faces(rows,cols):
            a=sum(params[i][0] for i in f)/4;z=sum(params[i][1] for i in f)/4
            if hole(a,z)>=1:faces.append(f)
        edge_counts={}
        for f in faces:
            for a,bb in zip(f,f[1:]+f[:1]):
                key=tuple(sorted((a,bb)));edge_counts[key]=edge_counts.get(key,0)+1
        boundary={i for e,n in edge_counts.items() if n==1 for i in e}
        for i in boundary:
            a,z=params[i]
            if i%cols not in [0,cols-1] and i//cols not in [0,rows-1]:
                theta=math.atan2((z-1.34)/.067,(a-math.pi/2)/.44)
                params[i]=[math.pi/2+.44*math.cos(theta),1.34+.067*math.sin(theta)]
        vs=[]
        for i,(a,z) in enumerate(params):
            direction=Vector((s*math.sin(a),-math.cos(a),0))
            hit,normal,idx,dist=shirt_tree.ray_cast(Vector((0,0,z)),direction,.4)
            if hit is None:raise RuntimeError('Continuous vest missed shirt')
            p=hit+direction*.009
            if i//cols<3:p.z-=.020*(1-(i%cols)/(cols-1))**2*(1-i//cols/3)
            vs.append(p)
        # Remove unused vertices left by the armhole cut so export stays compact.
        used=sorted({i for f in faces for i in f});remap={v:i for i,v in enumerate(used)}
        vertices=[vs[i] for i in used];faces=[tuple(remap[i] for i in f) for f in faces]
        o=b.mesh('Vest | continuous armhole panel '+str(s),vertices,faces,vest,'COSTUME | vest and scarf','Chest')
        surface(o,vertices,faces,vest,c.garment_weight);b.thickness(o,.003)
        lap=[]
        for j in range(21,rows):
            p=Vector(vs[j*cols]);q=Vector(vs[j*cols+1]);p.y-=.001;q.y-=.003
            lap.extend([p,q])
        o=b.mesh('Vest | continuous front facing '+str(s),lap,grid_faces(rows-21,2),vest,'COSTUME | vest and scarf','Chest');b.thickness(o,.0015)
        for p in o.data.polygons:p.use_smooth=True

def clothing(lookup):
    cloth=bpy.data.materials['Convergence | dirty cream linen'];vest=bpy.data.materials['Convergence | charcoal brown vest']
    # Continuous shirt shoulder slope and a loose front held at the belt.
    profile=[(.982,.161,.109),(1.025,.165,.114),(1.05,.175,.123),(1.075,.177,.128),(1.10,.181,.126),(1.14,.181,.122),(1.19,.185,.125),(1.24,.194,.128),(1.29,.203,.129),(1.33,.207,.123),(1.365,.208,.113),(1.39,.200,.098),(1.411,.180,.083),(1.43,.139,.069),(1.445,.083,.059),(1.452,.059,.048)]
    vs=[];n=64
    for j,(z,w,d) in enumerate(profile):
        for k in range(n):
            a=k*math.tau/n;sa=math.sin(a);ca=math.cos(a)
            x=w*ca;y=d*sa
            front=max(0,-sa)**4
            # Long tension folds originate at the open collar and terminate in belt compression.
            fold=.007*math.exp(-((x-(.022+.10*(1.4-z)))/.011)**2)
            fold+=.006*math.exp(-((x-(-.027-.15*(1.4-z)))/.014)**2)
            fold-=.004*math.exp(-((x+.002)/.017)**2)
            y-=front*fold*min(1,max(0,(1.435-z)/.05))
            y-=front*.006*math.exp(-((z-1.068-.25*x)/.018)**2)
            zz=z+.003*math.sin(a*3+.8)*math.exp(-((z-1.07)/.06)**2)
            vs.append((x,y,zz))
    fs=b.ring_faces(len(profile),n)[:-1] # open collar; the neck is a separate anatomical surface
    surface(lookup[35],vs,fs,cloth,c.garment_weight)
    shirt_tree=tree(lookup[35])
    def fit(p,clearance=.007):
        d=Vector((p.x,p.y,0));r=d.length
        if r<.001:return p
        hit,normal,idx,dist=shirt_tree.ray_cast(Vector((0,0,p.z)),d.normalized(),.4)
        if hit is not None:p.x=d.x*(dist+clearance)/r;p.y=d.y*(dist+clearance)/r
        return p
    # Existing suspenders remain on the shirt and under the vest.
    for idx,s in [(41,-1),(42,1)]:
        vs=[]
        path=[(s*.088,-.13,1.025),(s*.09,-.13,1.20),(s*.105,-.10,1.34),(s*.12,-.055,1.416),(s*.12,0,1.435),(s*.12,.055,1.416),(s*.10,.11,1.33),(s*.08,.13,1.17),(s*.065,.13,1.025)]
        for a,bb in zip(path,path[1:]):
            for step in range(8):
                p=Vector(a).lerp(Vector(bb),step/8)
                for side in [-1,0,1]:vs.append(fit(p+Vector((side*.009,0,0)),.003))
        surface(lookup[idx],vs,grid_faces(64,3),bpy.data.materials['Convergence | worn leather'],c.garment_weight)
    for o in list(b.collection('COSTUME | vest and scarf').objects):
        if o.name.startswith(('Vest | fitted','Vest | narrow','Vest | restrained')):c.archive(o)
    # Replace the four-point paper-like collars with bent cloth following the neckline.
    for idx,s in [(48,-1),(49,1)]:
        vs=[]
        for j in range(6):
            t=j/5
            for k in range(5):
                u=k/4
                x=s*((.028+.023*u)*(1-t)+(.034+.034*u)*t)
                z=1.441-.058*t+.013*u*t
                y=-.072-.049*t-.004*math.sin(t*math.pi)+.004*u
                vs.append((x,y,z))
        surface(lookup[idx],vs,grid_faces(6,5),cloth,lambda p:{'Chest':1})
        if not any(m.type=='SOLIDIFY' for m in lookup[idx].modifiers):b.thickness(lookup[idx],.0018)
    # Give the existing sleeves long hanging planes and local compression above the rolls.
    for idx,s in [(36,1),(37,-1)]:
        for v in lookup[idx].data.vertices:
            p=v.co;z=p.z;cx=s*(.21+.42*(1.4-z));a=math.atan2(p.y,(p.x-cx)*s)
            lower=math.exp(-((z-1.19)/.065)**2)
            fold=.007*math.sin(a*3+z*17+s*.8)*lower
            p.y+=fold*math.sin(a)
            p.x+=s*fold*math.cos(a)*.5
            # Suppress regular biceps bulge; cloth falls from the shoulder instead.
            if 1.29<z<1.40:p.y*=.94
    continuous_vest(shirt_tree,vest)
    # Re-seat detachable shoulder straps on the new vest in rest coordinates.
    vs=[];fs=[]
    for o in b.collection('COSTUME | vest and scarf').objects:
        if o.name.startswith('Vest | continuous armhole'):
            off=len(vs);vs.extend(v.co.copy() for v in o.data.vertices);fs.extend(tuple(off+i for i in p.vertices) for p in o.data.polygons)
    vt=BVHTree.FromPolygons(vs,fs)
    for o in b.collection('GEAR | backpack').objects:
        if not o.name.startswith('Pack | fitted shoulder'):continue
        for v in o.data.vertices:
            p=v.co;d=Vector((p.x,p.y,0));r=d.length
            if p.z<1.411 and r>.01:
                hit,normal,idx,dist=vt.ray_cast(Vector((0,0,p.z)),d.normalized(),.4)
                if hit is not None:p.x=d.x*(dist+.005)/r;p.y=d.y*(dist+.005)/r

def identity(lookup):
    head=lookup[52];skin=bpy.data.materials['Convergence | warm weathered skin'];hair=bpy.data.materials['Convergence | dark brown hair']
    # Refine the existing head rather than introduce separate nasal/cheek primitives.
    for v in head.data.vertices:
        p=v.co
        if p.y<0:
            def g(cx,cz,sx,sz):return math.exp(-((p.x-cx)/sx)**2-((p.z-cz)/sz)**2)
            front=max(0,-p.y)/.11
            p.y-=.010*g(0,1.588,.014,.019)+.004*g(0,1.609,.012,.027)
            p.y-=.005*(g(.048,1.593,.02,.015)+g(-.048,1.593,.02,.015))
            p.y+=.006*(g(.054,1.56,.018,.018)+g(-.054,1.56,.018,.018))
            p.y-=.008*g(0,1.513,.031,.016)
            p.y-=.003*(g(.031,1.63,.025,.01)+g(-.031,1.63,.025,.01))
            p.x*=1+.035*g(0,1.525,.09,.020)
    ht=tree(head)
    def front_surface(x,z,offset=.002):
        hit,normal,idx,dist=ht.ray_cast(Vector((x,-.25,z)),Vector((0,1,0)),.5)
        return Vector((x,hit.y-offset if hit is not None else -.06,z))
    # A short beard conforms to the face, with a shaped cheek boundary and chin volume.
    vs=[];rows=13;cols=65
    for j in range(rows):
        t=j/(rows-1)
        for k in range(cols):
            u=k/(cols-1)*2-1;a=u*1.42;side=abs(math.sin(a))
            top=1.552+.047*side**1.65+.002*math.sin(k*1.7)
            bottom=1.496+.035*side**1.25+.0017*math.sin(k*2.2)
            z=top*(1-t)+bottom*t
            # Radial casts stay on the jaw at every height; no flat hanging beard apron.
            radial=Vector((math.sin(a),-math.cos(a),0))
            hit,normal,idx,dist=ht.ray_cast(Vector((0,.002,z)),radial,.3)
            if hit is None:hit=Vector((.039*math.sin(a),-.055*math.cos(a),z))
            offset=.0012+.003*math.sin(t*math.pi)*(.45+.55*(1-side))
            offset+=.0008*math.sin(k*2.3+j*.65)*math.sin(t*math.pi)
            vs.append(hit+radial*offset)
    surface(lookup[51],vs,grid_faces(rows,cols),hair,lambda p:{'Head':1})
    # Broad, shallow locks give beard growth direction without a dense strand system.
    warm=b.material('Identity | beard warm planes',(.043,.027,.017),.94)
    for k in range(3,cols-4,2):
        vs2=[]
        for j in range(4):
            row=4+j*2;center=Vector(vs[row*cols+k]);left=Vector(vs[row*cols+k-1]);right=Vector(vs[row*cols+k+1])
            center.y-=.0003*math.sin(j*math.pi/3)
            width=.8*(1-j/4)
            vs2.extend([center+(left-center)*width,center+Vector((0,-.0003,0)),center+(right-center)*width])
        o=b.mesh('Beard | short directional lock '+str(k),vs2,grid_faces(4,3),warm,'IDENTITY | facial hair','Head')
        for p in o.data.polygons:p.use_smooth=True
    # These share one material, transform and Head weighting; keep the small growth planes
    # as one editable facial-hair component rather than dozens of Outliner entries.
    locks=[o for o in bpy.context.scene.objects if o.name.startswith('Beard | short directional lock') and not o.hide_render]
    bpy.ops.object.select_all(action='DESELECT')
    for o in locks:o.select_set(True)
    bpy.context.view_layer.objects.active=locks[0];bpy.ops.object.join()
    locks[0].name='Beard | grouped short growth planes'
    # Less graphic, split moustache following the upper lip with downward corners.
    for idx,s in [(55,1),(56,-1)]:
        vs=[]
        for j in range(5):
            t=j/4
            for k in range(9):
                u=k/8;x=s*(.002+.032*u)
                z=1.572-.008*u-.009*t+.001*math.sin(u*math.pi)
                p=front_surface(x,z,.003+.002*math.sin(t*math.pi));vs.append(p)
        surface(lookup[idx],vs,grid_faces(5,9),hair,lambda p:{'Head':1})
    # More alert eye opening, subtle brow asymmetry. Keep restrained human eye scale.
    for idx in [61,62,63,64,65,66,67,68]:
        for v in lookup[idx].data.vertices:
            p=v.co;p.z=1.616+(p.z-1.616)*1.14
    for idx in [69,70]:
        for v in lookup[idx].data.vertices:
            p=v.co;p.z-=.0025;p.z+=.0015*(p.x>0)

def detail_camera(name,loc,target,scale,path):
    scene=bpy.context.scene;o=bpy.data.objects.get(name)
    if not o:
        data=bpy.data.cameras.new(name);data.type='ORTHO';o=bpy.data.objects.new(name,data);b.collection('REVIEW | cameras and neutral lighting').objects.link(o)
    o.data.ortho_scale=scale;o.location=loc;o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    scene.camera=o;scene.render.filepath=str(OUT/path);bpy.ops.render.render(write_still=True)

def grips():
    # The heavy shaft and thin pan rim need different finger poses, and both relax with gear off.
    rig=bpy.data.objects['MinerRig']
    lookup={o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}
    # Extend the palm's wrist transition into the forearm rather than leaving two touching caps.
    for idx,s in [(28,1),(29,-1)]:
        for v in lookup[idx].data.vertices:
            p=v.co;t=max(0,min(1,(p.z-.742)/.023));p.z+=.012*t;p.x-=s*.006*t
            # A rounded heel of the palm overlaps the metacarpal roots instead of a sharp cuff edge.
            lower=max(0,min(1,(.71-p.z)/.018));p.z-=.005*lower
    for side,prop in [('Right','carry_pickaxe'),('Left','carry_pan')]:
        for i,digit in enumerate(['Index','Middle','Ring','Little']):
            values=[.35,.78,.65] if side=='Right' else [.12,.48,.40]
            for seg,value,relaxed in zip(['Proximal','Intermediate','Distal'],values,[.13,.19,.12]):
                p=rig.pose.bones[side+digit+seg];value+=i*.035
                c.driver(p,'rotation_euler',prop,f'{relaxed}+enabled*{value-relaxed}',0)
    c.loadout('expedition')
    # Place the upper shaft between palm and fingers, preserving the forged head assembly.
    shaft=bpy.data.objects['Pickaxe | tapered hickory shaft']
    target=Vector((-.263,.026,.874))
    world=[shaft.matrix_world@v.co for v in shaft.data.vertices]
    upper=sum(world[-12:],Vector())/12
    delta=target-upper
    for o in b.collection('GEAR | pickaxe').objects:
        if o.type!='MESH':continue
        inv=o.matrix_world.inverted().to_3x3()
        for v in o.data.vertices:
            p=o.matrix_world@v.co;t=max(0,min(1,(p.z-.22)/.61))
            v.co+=inv@(delta*t)
    # Reposition the pan by its actual upper rim, leaving its thin spun profile untouched.
    pan=bpy.data.objects['Gold pan | original spun mesh reprofiled']
    points=[pan.matrix_world@v.co for v in pan.data.vertices]
    top=max(points,key=lambda p:p.z)
    delta=Vector((.269,.019,.857))-top
    inv=pan.matrix_world.inverted().to_3x3()
    for v in pan.data.vertices:v.co+=inv@delta
    bpy.context.view_layer.update()
    # Oppose the thumb around each actual carried surface; restore its source pose without gear.
    for side,prop,target in [('Right','carry_pickaxe',(-.245,.027,.863)),('Left','carry_pan',(.285,-.01,.858))]:
        p=rig.pose.bones[side+'ThumbProximal'];p.rotation_mode='XYZ';rest=p.rotation_euler.copy()
        start=p.head.copy();tip=rig.pose.bones[side+'ThumbDistal'].tail.copy()
        q=(tip-start).rotation_difference(Vector(target)-start)
        if side=='Right':q=q.slerp(q.__class__((1,0,0,0)),.25)
        rotation=q.to_matrix().to_4x4()
        p.matrix=Matrix.Translation(start)@rotation@Matrix.Translation(-start)@p.matrix
        bpy.context.view_layer.update();grip=p.rotation_euler.copy()
        for i in range(3):c.driver(p,'rotation_euler',prop,f'{rest[i]}+enabled*{grip[i]-rest[i]}',i)
    bpy.context.view_layer.update()

def run():
    source=OUT/'pass_09_input.blend'
    if not source.exists():
        bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/miner_convergence_working.blend'))
        bpy.ops.wm.save_as_mainfile(filepath=str(source))
    else:bpy.ops.wm.open_mainfile(filepath=str(source))
    c.loadout('expedition')
    lookup={o['source_component']:o for o in bpy.context.scene.objects if 'source_component' in o}
    clothing(lookup);identity(lookup);grips()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'pass_09_draft.blend'))
    c.loadout('base');c.face_render(9)
    detail_camera('Review clothing',(2,-6,1.34),(0,0,1.25),.65,'pass_09_clothing.png')
    c.loadout('expedition')
    detail_camera('Review right grip',(-1,-2,1.0),(-.27,.015,.87),.24,'pass_09_right_grip.png')
    detail_camera('Review left grip',(1,-2,1.0),(.28,.015,.84),.28,'pass_09_left_grip.png')

if __name__=='__main__':run()
