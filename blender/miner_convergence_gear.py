"""Pass 13: sewn load-bearing equipment, keeping the original component objects."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector,Matrix
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence_structural as s
b=s.b;c=s.c;OUT=s.OUT

def grid(rows,cols):return [(j*cols+k,j*cols+k+1,(j+1)*cols+k+1,(j+1)*cols+k) for j in range(rows-1) for k in range(cols-1)]

def reuse(o,vs,fs,mat,bone):
    o.parent=bpy.data.objects['MinerRig'];o.parent_type='OBJECT';o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.Identity(4)
    for m in list(o.modifiers):o.modifiers.remove(m)
    b.replace_surface(o,vs,fs,mat,lambda p:{bone:1});b.bind(o,bone)
    return o

def loft(profile,n=48):
    vs=[]
    for j,(cx,cy,z,w,d) in enumerate(profile):
        for k in range(n):
            a=k*math.tau/n;ca=math.cos(a);sa=math.sin(a)
            x=cx+w*math.copysign(abs(ca)**.34,ca);y=cy+d*math.copysign(abs(sa)**.36,sa)
            zz=z-.008*max(0,sa)*max(0,1-abs((x-cx)/w))
            vs.append((x,y,zz))
    return vs,b.ring_faces(len(profile),n)

def backpack():
    mat=bpy.data.materials['Convergence | earth olive canvas'];leather=bpy.data.materials['Convergence | worn leather'];iron=bpy.data.materials['Convergence | forged iron']
    body=bpy.data.objects['Backpack | original constructed piece 0'];flap=bpy.data.objects['Backpack | original constructed piece 1']
    for o in list(s.active_meshes('GEAR | backpack')):
        if o not in [body,flap]:c.archive(o)
    vs,fs=loft([(-.008,.237,1.00,.132,.056),(-.008,.241,1.025,.158,.078),(-.005,.245,1.08,.175,.089),(0,.242,1.19,.174,.086),(.003,.239,1.30,.166,.079),(.005,.232,1.385,.155,.065),(.005,.228,1.42,.136,.057)])
    for i,p in enumerate(vs):
        x,y,z=p
        if y>.25:y-=.008*(math.exp(-((x-.111)/.023)**2)+math.exp(-((x+.111)/.023)**2))
        vs[i]=(x,y,z)
    reuse(body,vs,fs,mat,'Chest')
    # A broad flap folds over the top and hangs under its own weight.
    vs=[]
    rows=[(1.425,.218,.14),(1.405,.292,.163),(1.37,.324,.171),(1.32,.337,.169),(1.282,.343,.158)]
    for j,(z,y,w) in enumerate(rows):
        for k in range(25):
            u=k/24*2-1;x=.004+u*w;zz=z+(.023*abs(u)-.006*(1-u*u) if j==4 else 0)
            yy=y-.006*(math.exp(-((x-.11)/.025)**2)+math.exp(-((x+.11)/.025)**2))
            vs.append((x,yy,zz))
    reuse(flap,vs,grid(5,25),mat,'Chest');b.thickness(flap,.0035)
    # Broad lower pocket and side gussets, rather than two miniature backpack-shaped pockets.
    pocketmat=bpy.data.materials.get('Convergence | pack pocket canvas') or mat
    p=b.box_loft('Backpack | broad lower sewn pocket',[(-.005,.327,1.028,.103,.007),(-.005,.341,1.045,.126,.020),(-.003,.343,1.13,.128,.024),(0,.329,1.164,.122,.010)],pocketmat,'GEAR | backpack','Chest',32)
    b.ribbon('Backpack | pocket folded mouth',[(0,.351,1.157),(0,.354,1.146)],.246,mat,'GEAR | backpack','Chest')
    for side in [-1,1]:
        b.box_loft('Backpack | side gusset pocket '+str(side),[(side*.166,.235,1.057,.009,.044),(side*.184,.238,1.081,.016,.048),(side*.181,.235,1.22,.013,.043),(side*.164,.232,1.24,.006,.035)],mat,'GEAR | backpack','Chest',24)
    # Fit closure straps to the entire back surface including flap and lower pocket.
    verts=[];faces=[]
    for obj in [body,flap,p]:
        off=len(verts);verts.extend(v.co.copy() for v in obj.data.vertices);faces.extend(tuple(off+i for i in f.vertices) for f in obj.data.polygons)
    tree=BVHTree.FromPolygons(verts,faces)
    for x in [-.11,.11]:
        vs=[]
        for j in range(33):
            z=1.01+j/32*.405
            for k in range(3):
                xx=x+(k-1)*.012;hit,normal,idx,dist=tree.ray_cast(Vector((xx,.6,z)),Vector((0,-1,0)),.5)
                y=hit.y+.004 if hit is not None else .31;vs.append((xx,y,z))
        o=b.mesh('Pack | fitted vertical closure '+str(x),vs,grid(33,3),leather,'GEAR | backpack','Chest');b.thickness(o,.0025)
        o=b.buckle('Pack | closure adjustment '+str(x),(x,.35,1.296),.032,.037,iron,'GEAR | backpack');b.bind(o,'Chest')
    # Harness follows the actual underlying garment, including the top of each shoulder.
    verts=[];faces=[]
    for obj in bpy.context.scene.objects:
        if obj.hide_render or obj.type!='MESH':continue
        if obj.name=='Shirt | hanging torso' or obj.name.startswith('Vest | continuous armhole'):
            off=len(verts);verts.extend(v.co.copy() for v in obj.data.vertices);faces.extend(tuple(off+i for i in f.vertices) for f in obj.data.polygons)
    clothing=BVHTree.FromPolygons(verts,faces)
    for side in [-1,1]:
        vs=[]
        for j in range(32):
            z=1.045+j/31*.337
            for k in range(3):
                x=side*(.123+.014*(k-1));hit,normal,idx,dist=clothing.ray_cast(Vector((x,-.4,z)),Vector((0,1,0)),.6)
                y=hit.y-.006 if hit is not None else -.10;vs.append((x,y,z))
        for j in range(26):
            y=-.103+j/25*.206
            for k in range(3):
                x=side*(.123+.014*(k-1));hit,normal,idx,dist=clothing.ray_cast(Vector((x,y,1.6)),Vector((0,0,-1)),.35)
                z=hit.z+.006 if hit is not None else 1.40;vs.append((x,y,z))
        for j in range(1,7):
            t=j/6
            for k in range(3):vs.append((side*(.123+.014*(k-1)),.103+t*.072,1.385+.007*t))
        o=b.mesh('Pack | sewn continuous shoulder harness '+str(side),vs,grid(64,3),leather,'GEAR | backpack','Chest');b.thickness(o,.003)
        for p in o.data.polygons:p.use_smooth=True
        hit,normal,idx,dist=clothing.ray_cast(Vector((side*.123,-.4,1.31)),Vector((0,1,0)),.6)
        y=hit.y-.010 if hit is not None else -.135
        o=b.buckle('Pack | front harness adjuster '+str(side),(side*.123,y,1.31),.037,.035,iron,'GEAR | backpack');b.bind(o,'Chest')

def satchel():
    mat=bpy.data.materials['Convergence | worn leather'];iron=bpy.data.materials['Convergence | forged iron']
    body=bpy.data.objects['Satchel | hanging gusseted body'];flap=bpy.data.objects['Satchel | overlapping flap']
    for o in list(s.active_meshes('GEAR | satchel')):
        if o not in [body,flap]:c.archive(o)
    vs,fs=loft([(-.257,.024,.734,.062,.025),(-.26,.022,.753,.085,.043),(-.265,.025,.813,.092,.051),(-.260,.026,.918,.091,.046),(-.246,.027,.982,.073,.032)],40)
    reuse(body,vs,fs,mat,'Hips')
    vs=[]
    for j,(z,y,w) in enumerate([(.984,.024,.075),(.972,-.029,.087),(.918,-.037,.093),(.866,-.040,.085)]):
        for k in range(19):
            u=k/18*2-1;vs.append((-.255+w*u,y-.004*(1-u*u),z+(.012*abs(u)-.007*(1-u*u) if j==3 else 0)))
    reuse(flap,vs,grid(4,19),mat,'Hips');b.thickness(flap,.0035)
    for x in [-.30,-.22]:
        anchor=-.172 if x<-.25 else -.155
        b.ribbon('Satchel | belt loop and closure '+str(x),[(anchor,-.07,1.029),(-.20,-.044,1.004),(x,-.041,.972),(x,-.049,.932),(x,-.05,.867),(x,-.049,.834)],.019,mat,'GEAR | satchel','Hips')
        o=b.buckle('Satchel | closure frame '+str(x),(x,-.054,.893),.027,.031,iron,'GEAR | satchel');b.bind(o,'Hips')
    # Correct the canteen's excessive puck-like depth, preserving separate cap and seam.
    objs=s.active_meshes('GEAR | canteen');pts=[s.skin_matrix(o,v)@v.co for o in objs for v in o.data.vertices]
    cy=(min(p.y for p in pts)+max(p.y for p in pts))/2
    for o in objs:s.deform_world(o,lambda p:Vector((p.x,cy+(p.y-cy)*.57,p.z)))

def bedroll():
    mat=bpy.data.materials['Convergence | bedroll wool'];edge=bpy.data.materials['Convergence | roll exposed edge'];leather=bpy.data.materials['Convergence | worn leather']
    roll=bpy.data.objects['Bedroll | compressed wrapped blanket']
    for o in list(s.active_meshes('GEAR | bedroll')):
        if o!=roll:c.archive(o)
    vs=[];rows=31;cols=49
    for j in range(rows):
        x=-.203+j/(rows-1)*.406;compression=1-.15*(math.exp(-((x-.11)/.019)**2)+math.exp(-((x+.11)/.019)**2))
        for k in range(cols):
            a=k/(cols-1)*math.tau*1.055;r=.064*compression*(1+.035*math.sin(a*3+x*12))
            vs.append((x,.235+r*math.cos(a),1.485+.062*x+.88*r*math.sin(a)))
    reuse(roll,vs,grid(rows,cols),mat,'Chest');b.thickness(roll,.003)
    for side in [-1,1]:
        vs=[];rows=161
        for j in range(rows):
            t=j/(rows-1);a=t*math.tau*3.8;r=.003+.060*t
            for k in range(2):
                rr=r+k*.0036;xx=side*(.203-.002*t)+.001*math.cos(a*3)
                vs.append((xx,.235+rr*math.cos(a)*(1+.035*math.cos(a*3)),1.485+.062*side*.203+rr*.88*math.sin(a)))
        o=b.mesh('Bedroll | compressed cloth spiral '+str(side),vs,grid(rows,2),edge,'GEAR | bedroll','Chest');b.thickness(o,.001)
        disk=[(side*.201,.235,1.485+.062*side*.203)]
        for k in range(48):
            a=k*math.tau/48;disk.append((side*.201,.235+.061*math.cos(a),1.485+.062*side*.203+.054*math.sin(a)))
        b.mesh('Bedroll | recessed cloth end '+str(side),disk,[(0,k+1,(k+1)%48+1) for k in range(48)],mat,'GEAR | bedroll','Chest')
    for x in [-.11,.11]:
        points=[]
        for j in range(49):
            a=j*math.tau/48;points.append((x,.235+.0556*math.cos(a),1.485+.062*x+.0495*math.sin(a)))
        b.ribbon('Bedroll | tight leather binding '+str(x),points,.027,leather,'GEAR | bedroll','Chest')

def run():
    s.load_previous(13);backpack();satchel();bedroll()
    for group in ['GEAR | backpack','GEAR | bedroll']:
        for o in s.active_meshes(group):
            for v in o.data.vertices:
                p=v.co
                if 'shoulder harness' in o.name:
                    if p.y>0:p.y-=.022*min(1,p.y/.15)
                elif 'front harness adjuster' not in o.name:p.y-=.022
                if group.endswith('bedroll'):p.z-=.028
    # Apply loadout drivers to every new component without changing the hand pose drivers.
    for prop,groups in c.GEAR.items():
        for group in groups:
            for o in s.active_meshes(group):c.driver(o,'hide_render',prop,'not enabled');c.driver(o,'hide_viewport',prop,'not enabled')
    s.finish(13)

if __name__=='__main__':run()
