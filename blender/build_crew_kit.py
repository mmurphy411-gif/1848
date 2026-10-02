"""Crew kit: the Intrepid Miner's game meshes re-cut so fourteen hired hands and Lambert
can each be told apart (visual upgrade Stage 5, crew and Lambert).

Blender --background --python blender/build_crew_kit.py [-- --prepared <prepared.blend>]

Inputs
  blender/miner_game_export.blend   the exact exported game meshes, GameUV atlases and rig
  artifacts/miner-game/prepared.blend   same topology with the per-face source materials
                                        (regenerate: export_intrepid_miner.py -- prepare)
Outputs
  assets/crew/crew_kit.glb   geometry and skin only: Body, Hat, Skin, Hair on MinerRig.
                             Textures, clips and the pack, satchel and canteen come from the
                             miner at runtime, so the kit adds no atlas and no animation data.
  assets/store/shopkeeper.glb   stripped to Lambert's five store clips on the same rig.
  artifacts/crew-kit/report.json

Vertex channels (glTF TEXCOORD_n; Godot: UV, UV2, CUSTOM0)
  TEXCOORD_0  GameUV atlas coordinates (unchanged; normalised shorts)
  TEXCOORD_1  (part / 255, 1 - trim) as normalised bytes: the source garment of each face;
              trim = buttons, thread and hardware that keep their colour and follow their
              host garment's visibility
  TEXCOORD_2  (pattern u, rest z), Body and Skin only: arc length round the body (or the
              arm on sleeves) and height, for woven checks and the sash; on the beard
              shell u is instead the fray (0 at the shell's edge, 1 two rings in)
  TEXCOORD_3  (rest x, rest y), Body and Skin only: Blender rest position, +y is the back
All variants are procedural: shape keys of the existing geometry, and a beard shell lifted
off the face's own lower-face triangles (no hand-placed vertices).
"""
import bpy,bmesh,sys,json,math,struct
import numpy as np
from pathlib import Path
from mathutils import Vector,Matrix,kdtree
ROOT=Path(__file__).resolve().parents[1]
ARGS=sys.argv[sys.argv.index('--')+1:] if '--' in sys.argv else []
def option(name,default):
    return ARGS[ARGS.index(name)+1] if name in ARGS else default
PREPARED=Path(option('--prepared',str(ROOT/'artifacts/miner-game/prepared.blend')))
SOURCE=ROOT/'blender/miner_game_export.blend'
OUT=ROOT/'assets/crew/crew_kit.glb'
REPORT=ROOT/'artifacts/crew-kit';REPORT.mkdir(parents=True,exist_ok=True)

# Part ids written to TEXCOORD_1.x. Keep in step with shaders/crew.gdshader.
SHIRT,VEST,TROUSERS,BOOTS,SCARF,LEATHER,HAT,BAND=1,2,3,4,5,6,7,8
FACE,HANDS,EYES,SCALP,MOUSTACHE,CHIN,JAW,CHEEK=9,10,11,12,13,14,15,16
STRAPS,KNEE=17,18
BODY_PARTS={'REFINE | vest':VEST,'REFINE | linen':SHIRT,'FINISH | heavy umber cotton drill':TROUSERS,
    'FINISH | oiled and scuffed boot leather':BOOTS,'REFINE | worn brown felt':HAT,'REFINE | scarf':SCARF,'REFINE | leather':LEATHER}
TRIM={'FINISH | dark linen thread','FINISH | hardware','FINISH | buttonhole shadow','FINISH | horn'}
SKIN_PARTS={'Convergence | warm weathered skin':KNEE,'STUDY | weathered face':FACE,'STUDY | ivory sclera':EYES,
    'STUDY | hazel iris':EYES,'STUDY | pupil':EYES,'FINISH | sun-weathered working hands':HANDS}
# Rest-pose landmarks of MinerRig (metres, Blender axes: -y is the face).
HAT_AXIS=Vector((.001,0.0))
CROWN_R=.105;CROWN_BASE=1.66;HAT_TOP=1.754
MOUTH_Z=1.553
ARMS={'Left':[Vector((.21,0,1.40)),Vector((.35,0,1.08)),Vector((.45,-.015,.765))]}
ARMS['Right']=[Vector((-p.x,p.y,p.z)) for p in ARMS['Left']]

def read_source_materials():
    bpy.ops.wm.open_mainfile(filepath=str(PREPARED))
    out={}
    for name in ['Body','Skin','Hair']:
        me=bpy.data.objects[name].data
        names=[m.name for m in me.materials]
        out[name]={'faces':[names[p.material_index] for p in me.polygons],
            'verts':np.array([v.co[:] for v in me.vertices],dtype=np.float64)}
    return out

def select(objects):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects:o.hide_set(False);o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]

def face_center(me,p):
    return sum((me.vertices[i].co for i in p.vertices),Vector())/len(p.vertices)

def body_parts(me,names):
    """Garment per face; trims take the garment of the nearest non-trim face."""
    parts=[0]*len(me.polygons);trim=[0]*len(me.polygons)
    tree=kdtree.KDTree(len(me.polygons));owners=[]
    for p,name in zip(me.polygons,names):
        if name in TRIM:continue
        part=BODY_PARTS[name]
        if part==LEATHER and min(me.vertices[i].co.z for i in p.vertices)>1.55:part=BAND
        # The harness straps above the belt read as braces; they are worn or not per man.
        elif part==LEATHER and face_center(me,p).z>1.075:part=STRAPS
        parts[p.index]=part;tree.insert(face_center(me,p),len(owners));owners.append(part)
    tree.balance()
    for p,name in zip(me.polygons,names):
        if name in TRIM:
            _,index,_=tree.find(face_center(me,p));parts[p.index]=owners[index];trim[p.index]=1
    return parts,trim

def components(me):
    bm=bmesh.new();bm.from_mesh(me);bm.faces.ensure_lookup_table()
    seen=set();out=[]
    for f in bm.faces:
        if f.index in seen:continue
        stack=[f];faces=[];seen.add(f.index)
        while stack:
            g=stack.pop();faces.append(g.index)
            for v in g.verts:
                for h in v.link_faces:
                    if h.index not in seen:seen.add(h.index);stack.append(h)
        out.append(faces)
    bm.free();return out

def beard_region(c):
    """Beard part for a face point in rest space, or 0 where no beard grows."""
    if c.z<1.462 or c.z>1.627 or abs(c.x)>.092:return 0
    ax=abs(c.x)
    # Lips and the nose stay bare.
    if ax<.026 and 1.538<c.z<1.556 and c.y<-.075:return 0
    if ax<.013 and c.z>1.566:return 0
    if c.z<MOUTH_Z:
        if c.y>.03:return 0
        return CHIN if ax<.03 else JAW
    if ax<.032:
        return MOUSTACHE if c.z<1.575 and c.y<-.085 else 0
    # Side-whiskers run up in front of the ear; the cheek below the cheekbone.
    if ax>.062 and -.018<c.y<.03:return CHEEK
    if c.z<1.576 and c.y<-.018:return CHEEK
    return 0

def beard_shell(skin,skin_part):
    """A thin shell lifted off the lower face: the mass of a beard, which the sparse beard
    strands cannot give at working distance. Faces copy the face skin; the shader draws
    it as hair and frays its edge (CrewPattern.x carries the distance from the edge)."""
    me=skin.data
    bm=bmesh.new();bm.from_mesh(me);bm.faces.ensure_lookup_table();bm.normal_update()
    picked=[];regions={}
    for f in bm.faces:
        if skin_part[f.index]!=FACE:continue
        r=beard_region(f.calc_center_median())
        if r:picked.append(f);regions[f]=r
    count=len(bm.faces);vcount=len(bm.verts)
    normals={v:v.normal.copy() for f in picked for v in f.verts}
    out=bmesh.ops.duplicate(bm,geom=picked)
    vmap=out['vert_map'];fmap=out['face_map']
    for old,new in list(vmap.items()):
        if old in normals:new.co=old.co+normals[old]*.0045
    new_faces=[fmap[f] for f in picked]
    shell_parts=[regions[f] for f in picked]
    new_verts=[vmap[v] for v in {v for f in picked for v in f.verts}]
    # Rings from the shell's boundary: 0 on the edge, 1 two rings in.
    ring={}
    for e in {e for f in new_faces for e in f.edges}:
        if sum(1 for g in e.link_faces if g in set(new_faces))<2:
            for v in e.verts:ring[v]=0
    front=[v for v in ring];level=0
    shell_set=set(new_verts)
    while front and level<3:
        level+=1;nxt=[]
        for v in front:
            for e in v.link_edges:
                w=e.other_vert(v)
                if w in shell_set and w not in ring:ring[w]=level;nxt.append(w)
        front=nxt
    bm.verts.index_update();bm.faces.index_update();bm.to_mesh(me)
    edge={}
    for v in new_verts:edge[v.index]=min(1.0,ring.get(v,3)/2.0)
    bm.free()
    return shell_parts,edge,list(range(count,count+len(new_faces))),list(range(vcount,len(me.vertices)))

def shell_keys(skin,shell_faces,shell_verts):
    me=skin.data;co=[v.co.copy() for v in me.vertices];normals=[v.normal.copy() for v in me.vertices]
    vpart={}
    mask=me.uv_layers['CrewMask'].data
    for fi in shell_faces:
        poly=me.polygons[fi]
        for li,vi in zip(poly.loop_indices,poly.vertices):vpart[vi]=int(round(mask[li].uv[0]))
    def key(fn):
        out=[c.copy() for c in co]
        for i in shell_verts:out[i]=fn(co[i],normals[i],vpart.get(i,JAW))
        return out
    def long(p,n,part):
        if part==MOUSTACHE:return p.copy()
        below=max(0.0,1.545-p.z);q=p.copy()
        if below<=0:return q
        t=below/.08
        q.z-=below*3.2;q.y-=below*.9;q.x*=1-.35*min(1.0,t)
        return q
    def bushy(p,n,part):
        return p+n*(.006 if part!=MOUSTACHE else .003)
    def walrus(p,n,part):
        if part!=MOUSTACHE:return p.copy()
        w=min(1.0,abs(p.x)/.034);q=p.copy();q.x*=1.18;q.z-=.016*w*w;q.y-=.003+.004*w
        return q
    return [set_key(skin,'beard_long',key(long)),set_key(skin,'beard_bushy',key(bushy)),set_key(skin,'moustache_walrus',key(walrus))]

def hair_parts(me,names):
    parts=[0]*len(me.polygons);cards=components(me)
    for faces in cards:
        verts={i for f in faces for i in me.polygons[f].vertices}
        c=sum((me.vertices[i].co for i in verts),Vector())/len(verts)
        if any('hair cards' in names[f] for f in faces):part=SCALP
        elif c.z>=MOUTH_Z and abs(c.x)<.032 and c.y<-.085:part=MOUSTACHE
        elif c.z<MOUTH_Z and abs(c.x)<.028:part=CHIN
        elif c.z>=1.545 and abs(c.x)>=.032:part=CHEEK
        else:part=JAW
        for f in faces:parts[f]=part
    return parts,cards

def split(obj,keep,name):
    """Copy obj keeping only faces where keep(face index) is true; remove them from obj."""
    copy=obj.copy();copy.data=obj.data.copy();copy.name=name;copy.data.name=name+'Mesh'
    for c in obj.users_collection:c.objects.link(copy)
    for target,wanted in [(copy,True),(obj,False)]:
        bm=bmesh.new();bm.from_mesh(target.data);bm.faces.ensure_lookup_table()
        bmesh.ops.delete(bm,geom=[f for f in bm.faces if keep(f.index)!=wanted],context='FACES')
        bm.to_mesh(target.data);bm.free()
    return copy

def arm_coordinates(p,side):
    """Distance along the arm chain (0 shoulder, 1 elbow, 2 wrist) and angle round it."""
    best=None
    for k in range(2):
        a,b=ARMS[side][k],ARMS[side][k+1];axis=b-a;t=max(0.0,min(1.0,(p-a).dot(axis)/axis.length_squared))
        d=(p-(a+axis*t)).length
        if best is None or d<best[0]:best=(d,k+t,a,axis,t)
    _,s,a,axis,t=best
    radial=p-(a+axis*t);n=axis.normalized()
    ref=Vector((0,-1,0));ref=(ref-n*ref.dot(n)).normalized()
    angle=math.atan2(n.cross(ref).dot(radial),ref.dot(radial))
    length=s*(ARMS[side][1]-ARMS[side][0]).length if s<=1 else (ARMS[side][1]-ARMS[side][0]).length+(s-1)*(ARMS[side][2]-ARMS[side][1]).length
    return s,angle,length

def is_sleeve(p):
    return abs(p.x)>.205 and p.z>.7

def add_layers(obj,parts,trim,positions):
    """Gear gets no extra channels (part 0 reads as zero); hat and hair only need the mask."""
    me=obj.data
    if parts is None:return
    for name in ['CrewMask']+(['CrewPattern','CrewRest'] if positions else []):me.uv_layers.new(name=name)
    me.uv_layers.active=me.uv_layers['GameUV'];me.uv_layers['GameUV'].active_render=True
    mask=me.uv_layers['CrewMask'].data
    pattern,rest=(me.uv_layers['CrewPattern'].data,me.uv_layers['CrewRest'].data) if positions else (None,None)
    for poly in me.polygons:
        part=parts[poly.index] if parts else 0;t=trim[poly.index] if trim else 0
        sleeve=part==SHIRT and is_sleeve(face_center(me,poly))
        for li in poly.loop_indices:
            p=me.vertices[me.loops[li].vertex_index].co
            mask[li].uv=(part,t)
            if not positions:continue
            if sleeve:
                side='Left' if p.x>0 else 'Right'
                _,angle,length=arm_coordinates(p,side)
                pattern[li].uv=(5.0+angle*.055*(1 if side=='Left' else -1),1.40-length)
            else:
                pattern[li].uv=(math.atan2(p.x,-p.y)*.13,p.z)
            rest[li].uv=(p.x,p.y)

def set_key(obj,name,positions):
    if obj.data.shape_keys is None:obj.shape_key_add(name='Basis',from_mix=False)
    key=obj.shape_key_add(name=name,from_mix=False)
    flat=[c for v in positions for c in v]
    key.data.foreach_set('co',flat)
    moved=sum(1 for v,p in zip(obj.data.vertices,positions) if (v.co-Vector(p)).length>1e-6)
    return {'name':name,'moved':moved}

def hat_keys(hat):
    me=hat.data;co=[v.co.copy() for v in me.vertices];normals=[v.normal.copy() for v in me.vertices]
    def radial(p):
        d=Vector((p.x-HAT_AXIS.x,p.y-HAT_AXIS.y));return d.length,(d.normalized() if d.length>1e-6 else Vector((1,0)))
    brim_z=np.median([p.z for p in co if radial(p)[0]>CROWN_R+.01])
    def build(fn):return [fn(p,n) for p,n in zip(co,normals)]
    def crown(scale,taper):
        def f(p,n):
            r,d=radial(p)
            if r>CROWN_R+.004 or p.z<CROWN_BASE:return p.copy()
            t=(p.z-CROWN_BASE)/(HAT_TOP-CROWN_BASE)
            z=CROWN_BASE+(p.z-CROWN_BASE)*scale;rr=r*(1-taper*t)
            return Vector((HAT_AXIS.x+d.x*rr,HAT_AXIS.y+d.y*rr,z))
        return f
    def brim(scale,flat,droop):
        def f(p,n):
            r,d=radial(p)
            if r<=CROWN_R+.004:return p.copy()
            w=(r-CROWN_R)/.10
            rr=CROWN_R+(r-CROWN_R)*scale
            z=brim_z+(p.z-brim_z)*(1-flat)-droop*w*w
            return Vector((HAT_AXIS.x+d.x*rr,HAT_AXIS.y+d.y*rr,z))
        return f
    # Knit cap: the crown laid on an ellipsoid just over the skull, the brim rolled into a
    # cuff that sits on the brow in front and low on the nape behind.
    head=Vector((HAT_AXIS.x,.004,1.60));radii=Vector((.104,.113,.128))
    def cuff_top(d):return 1.6425-.0225*d.y
    def on_cap(d,z,grow=0.0):
        k=math.sqrt(max(0.0,1-((z-head.z)/radii.z)**2))
        return Vector((head.x+d.x*(radii.x*k+grow),head.y+d.y*(radii.y*k+grow),z))
    def cap_point(p,n):
        r,d=radial(p)
        inward=Vector((n.x,n.y)).dot(d)<-.2 or (r<.075 and n.z<-.2)
        if r>CROWN_R+.004:
            w=min(1.0,(r-CROWN_R)/.10)
            z=cuff_top(d)-.022*w
            return on_cap(d,z,.005*math.sin(w*math.pi)+(-.003 if n.z<0 else .0015))
        phi=math.atan2(max(0.0,p.z-CROWN_BASE)/(HAT_TOP-CROWN_BASE),r/CROWN_R)
        base=math.asin(max(-1.0,min(1.0,(cuff_top(d)-head.z)/radii.z)))
        e=base+(math.pi/2-base)*min(1.0,phi/(math.pi/2))
        shrink=.997 if inward else 1.0
        return Vector((head.x+d.x*math.cos(e)*radii.x*shrink,head.y+d.y*math.cos(e)*radii.y*shrink,head.z+math.sin(e)*radii.z*shrink))
    cap=build(cap_point)
    def tuque(p,n):
        q=cap_point(p,n)
        # Only the crown above the skull runs out; the lower cap stays snug on the head.
        h=max(0.0,min(1.0,(q.z-1.645)/(head.z+radii.z-1.645)))
        s=max(0.0,(h-.5)/.5)**1.2
        if s<=0:return q
        # A voyageur's long toque: the crown leans back and its end flops down behind.
        axis=Vector((head.x,head.y,q.z))
        q=axis+(q-axis)*(1-.4*s)
        return q+Vector((.05*s*s,.06*s+.22*s*s,.09*s-.12*s*s*s))
    keys=[set_key(hat,'crown_tall',build(crown(2.0,-.03))),set_key(hat,'crown_cone',build(crown(1.75,.5))),
        set_key(hat,'crown_low',build(crown(.76,-.04))),
        set_key(hat,'brim_wide',build(brim(1.55,0,0))),set_key(hat,'brim_narrow',build(brim(.5,.3,0))),
        set_key(hat,'brim_flat',build(brim(1.0,.85,0))),set_key(hat,'brim_droop',build(brim(1.0,0,.035))),
        set_key(hat,'cap',cap)]
    tuque_abs=build(tuque)
    keys.append(set_key(hat,'tuque',[c+(t-q) for c,t,q in zip(co,tuque_abs,cap)]))
    return keys,{'brim_z':float(brim_z)}

def hair_keys(hair,parts,cards):
    me=hair.data;co=[v.co.copy() for v in me.vertices]
    vpart=[0]*len(co);top={}
    for faces in cards:
        verts={i for f in faces for i in me.polygons[f].vertices}
        zt=max(co[i].z for i in verts)
        for i in verts:top[i]=zt
    for p in me.polygons:
        for i in p.vertices:vpart[i]=parts[p.index]
    def card_scale(k,flare):
        out=[]
        for i,p in enumerate(co):
            if vpart[i]!=SCALP:out.append(p.copy());continue
            zt=top[i];q=p.copy();q.z=zt-(zt-p.z)*k
            d=Vector((p.x,p.y-.005,0));q.x+=d.x*flare*(zt-p.z)*8;q.y+=d.y*flare*(zt-p.z)*8
            out.append(q)
        return out
    def under_cap():
        c=Vector((HAT_AXIS.x,.004,1.60));radii=Vector((.096,.105,.119))
        out=[]
        for i,p in enumerate(co):
            q=p.copy()
            if vpart[i]==SCALP and p.z>1.585:
                rel=Vector(((p.x-c.x)/radii.x,(p.y-c.y)/radii.y,(p.z-c.z)/radii.z))
                if rel.length>1:
                    rel.normalize();q=Vector((c.x+rel.x*radii.x,c.y+rel.y*radii.y,c.z+rel.z*radii.z))
            out.append(q)
        return out
    def beard(long,bushy):
        jaw=Vector((0,-.035,1.56));out=[]
        for i,p in enumerate(co):
            q=p.copy()
            if vpart[i] in (CHIN,JAW,CHEEK):
                below=max(0.0,MOUTH_Z+.005-p.z);fall=max(0.0,1-abs(p.x)/.085)
                q.z-=below*long*fall;q.y-=below*long*.30*fall
                q=jaw+(q-jaw)*(1+bushy*min(1.0,below*25+.25))
            out.append(q)
        return out
    def walrus():
        out=[]
        for i,p in enumerate(co):
            q=p.copy()
            if vpart[i]==MOUSTACHE:
                w=min(1.0,abs(p.x)/.03);q.x*=1.25;q.z-=.012*w*w;q.y-=.004
            out.append(q)
        return out
    return [set_key(hair,'hair_short',card_scale(.42,0)),set_key(hair,'hair_long',card_scale(1.45,.12)),
        set_key(hair,'hair_capped',under_cap()),set_key(hair,'beard_long',beard(3.0,.06)),
        set_key(hair,'beard_bushy',beard(0,.22)),set_key(hair,'moustache_walrus',walrus())]

def shirt_keys(body,parts):
    """Sleeves rolled above the elbow, or let down to the wrist."""
    me=body.data;co=[v.co.copy() for v in me.vertices];vpart=[0]*len(co)
    for p in me.polygons:
        for i in p.vertices:vpart[i]=parts[p.index]
    sleeve=[vpart[i]==SHIRT and is_sleeve(co[i]) for i in range(len(co))]
    cuff=max(arm_coordinates(co[i],'Left' if co[i].x>0 else 'Right')[0] for i in range(len(co)) if sleeve[i])
    def move(target,bunch):
        out=[]
        for i,p in enumerate(co):
            if not sleeve[i]:out.append(p.copy());continue
            side='Left' if p.x>0 else 'Right'
            s,_,_=arm_coordinates(p,side)
            if s<=.80:out.append(p.copy());continue
            k=(s-.80)/max(1e-4,cuff-.80);ns=.80+k*(target-.80)
            def axis_point(v):
                seg=0 if v<=1 else 1;a,b=ARMS[side][seg],ARMS[side][seg+1]
                return a+(b-a)*(v-seg)
            a0=axis_point(s);a1=axis_point(ns)
            out.append(a1+(p-a0)*(1+bunch*k))
        return out
    return [set_key(body,'sleeves_rolled',move(.92,.18)),set_key(body,'sleeves_down',move(1.80,-.38))],float(cuff)

def part_colours(objs,parts_by_obj):
    """Mean linear albedo and luminance per part, sampled at face corners in the atlases."""
    stats={}
    for name,atlas in [('Body','body'),('Hat','body'),('Skin','skin'),('Hair','hair')]:
        image=bpy.data.images.load(str(ROOT/'assets/miner/intrepid'/(atlas+'_albedo.png')),check_existing=True)
        w,h=image.size;px=np.empty(w*h*4,dtype=np.float32);image.pixels.foreach_get(px);px=px.reshape(h,w,4)
        lin=np.where(px[...,:3]<=.04045,px[...,:3]/12.92,((px[...,:3]+.055)/1.055)**2.4)
        me=objs[name].data;uv=me.uv_layers['GameUV'].data;parts=parts_by_obj[name]
        if name=='Skin':parts=[p if p<MOUSTACHE else -1 for p in parts]
        acc={}
        for poly in me.polygons:
            part=parts[poly.index]
            if part<0:continue
            for li in poly.loop_indices:
                u,v=uv[li].uv;x=min(w-1,max(0,int(u*w)));y=min(h-1,max(0,int(v*h)))
                if name=='Hair' and px[y,x,3]<.25:continue
                acc.setdefault(part,[]).append(lin[y,x])
        if name=='Skin':
            cheek=[]
            for poly in me.polygons:
                c=face_center(me,poly)
                if parts[poly.index]==FACE and 1.575<c.z<1.61 and .035<abs(c.x)<.07 and c.y<-.05:
                    for li in poly.loop_indices:
                        u,v=uv[li].uv;cheek.append(lin[min(h-1,max(0,int(v*h))),min(w-1,max(0,int(u*w)))])
            stats['cheek']={'mean_rgb':[round(float(c),4) for c in np.array(cheek).mean(0)],'samples':len(cheek)}
        for part,values in acc.items():
            a=np.array(values);mean=a.mean(0);lum=float((a@np.array([.2126,.7152,.0722])).mean())
            stats[str(part)]={'mean_rgb':[round(float(c),4) for c in mean],'luminance':round(lum,4),'samples':len(values),'object':name}
    return stats

def read_glb(path):
    data=path.read_bytes();length=struct.unpack('<I',data[12:16])[0]
    return json.loads(data[20:20+length]),data[20+length+8:]

def write_glb(path,doc,views):
    """Write doc with the given bufferView payloads packed into one 4-byte aligned buffer."""
    blob=bytearray();doc['bufferViews']=[]
    for payload,stride,target in views:
        while len(blob)%4:blob.append(0)
        view={'buffer':0,'byteOffset':len(blob),'byteLength':len(payload)}
        if stride:view['byteStride']=stride
        if target:view['target']=target
        doc['bufferViews'].append(view);blob.extend(payload)
    while len(blob)%4:blob.append(0)
    doc['buffers']=[{'byteLength':len(blob)}]
    text=json.dumps(doc,separators=(',',':')).encode()
    while len(text)%4:text+=b' '
    path.write_bytes(struct.pack('<III',0x46546C67,2,12+8+len(text)+8+len(blob))+struct.pack('<II',len(text),0x4E4F534A)+text+struct.pack('<II',len(blob),0x004E4942)+bytes(blob))

def quantize_kit(path):
    """Core glTF quantisation the exporter does not do: joint weights and atlas UVs as
    normalised unsigned shorts, garment ids as normalised bytes (id/255), and no morph
    normals on the hair (cards keep their facing). Halves the vertex payload on disk."""
    doc,binary=read_glb(path)
    old_views=doc['bufferViews']
    payload=lambda i:binary[old_views[i].get('byteOffset',0):old_views[i].get('byteOffset',0)+old_views[i]['byteLength']]
    views=[];remap={}
    def keep(i):
        if i not in remap:remap[i]=len(views);v=old_views[i];views.append((payload(i),v.get('byteStride'),v.get('target')))
        return remap[i]
    def add(array):
        views.append((array.tobytes(),None,34962));return len(views)-1
    def floats(a):
        acc=doc['accessors'][a];n={'VEC2':2,'VEC4':4}[acc['type']]
        bv=old_views[acc['bufferView']];off=bv.get('byteOffset',0)+acc.get('byteOffset',0)
        return np.frombuffer(binary,dtype=np.float32,count=acc['count']*n,offset=off).reshape(acc['count'],n)
    converted=set()
    for mesh in doc['meshes']:
        for prim in mesh['primitives']:
            attrs=prim['attributes']
            for key in ['WEIGHTS_0','TEXCOORD_0','TEXCOORD_1']:
                a=attrs.get(key)
                if a is None or a in converted or doc['accessors'][a]['componentType']!=5126:continue
                values=floats(a)
                if key=='WEIGHTS_0':
                    q=np.round(values*65535).astype(np.int64)
                    fix=65535-q.sum(1);top=q.argmax(1);q[np.arange(len(q)),top]+=fix
                    q=q.astype(np.uint16);ctype=5123
                elif key=='TEXCOORD_0':
                    if values.min()<0 or values.max()>1:continue
                    q=np.round(values*65535).astype(np.uint16);ctype=5123
                else:
                    q=np.round(np.stack([values[:,0]/255.0,values[:,1]],1)*255).astype(np.uint8)
                    q=np.ascontiguousarray(np.pad(q,((0,0),(0,2))));ctype=5121
                    acc=doc['accessors'][a];acc['type']='VEC2'
                acc=doc['accessors'][a]
                if key=='TEXCOORD_1':
                    # Two bytes padded to four per vertex for alignment: a strided view.
                    views.append((q.tobytes(),4,34962));acc['bufferView']=len(views)-1
                else:
                    acc['bufferView']=add(q)
                acc['byteOffset']=0;acc['componentType']=ctype;acc['normalized']=True
                acc.pop('min',None);acc.pop('max',None)
                converted.add(a)
            if mesh['name'].startswith('Hair'):
                for target in prim.get('targets',[]):target.pop('NORMAL',None)
    used_accessors=set()
    for mesh in doc['meshes']:
        for prim in mesh['primitives']:
            used_accessors.update(prim['attributes'].values());used_accessors.add(prim['indices'])
            for target in prim.get('targets',[]):used_accessors.update(target.values())
    for skin in doc.get('skins',[]):used_accessors.add(skin['inverseBindMatrices'])
    accessors=[];amap={}
    for i,acc in enumerate(doc['accessors']):
        if i not in used_accessors:continue
        amap[i]=len(accessors);acc=dict(acc)
        if i not in converted and 'bufferView' in acc:acc['bufferView']=('old',acc['bufferView'])
        if 'sparse' in acc:
            sp=acc['sparse']
            sp['indices']['bufferView']=('old',sp['indices']['bufferView']);sp['values']['bufferView']=('old',sp['values']['bufferView'])
        accessors.append(acc)
    new_views=views;views=[];remap={}
    final=[]
    def place(ref):
        if isinstance(ref,tuple):
            i=ref[1]
            if ('o',i) not in remap:remap[('o',i)]=len(final);v=old_views[i];final.append((payload(i),v.get('byteStride'),v.get('target')))
            return remap[('o',i)]
        if ('n',ref) not in remap:remap[('n',ref)]=len(final);final.append(new_views[ref])
        return remap[('n',ref)]
    for acc in accessors:
        if 'bufferView' in acc:acc['bufferView']=place(acc['bufferView'])
        if 'sparse' in acc:
            acc['sparse']['indices']['bufferView']=place(acc['sparse']['indices']['bufferView'])
            acc['sparse']['values']['bufferView']=place(acc['sparse']['values']['bufferView'])
            for part in ('indices','values'):
                view=final[acc['sparse'][part]['bufferView']];final[acc['sparse'][part]['bufferView']]=(view[0],None,None)
    for mesh in doc['meshes']:
        for prim in mesh['primitives']:
            prim['attributes']={k:amap[v] for k,v in prim['attributes'].items()};prim['indices']=amap[prim['indices']]
            prim['targets']=[{k:amap[v] for k,v in t.items()} for t in prim.get('targets',[])]
            if not prim['targets']:prim.pop('targets')
    for skin in doc.get('skins',[]):skin['inverseBindMatrices']=amap[skin['inverseBindMatrices']]
    doc['accessors']=accessors
    before=path.stat().st_size;write_glb(path,doc,final)
    return {'bytes_before':before,'bytes_after':path.stat().st_size}

def strip_meshes(path):
    """Rewrite a GLB keeping only nodes, skins and animations: Lambert's clip carrier."""
    data=path.read_bytes();length=struct.unpack('<I',data[12:16])[0]
    doc=json.loads(data[20:20+length]);binary=data[20+length+8:]
    if not doc.get('meshes'):return {'path':str(path.relative_to(ROOT)),'stripped':False}
    for node in doc['nodes']:
        for key in ['mesh','skin']:node.pop(key,None)
    keep_nodes=[i for i,n in enumerate(doc['nodes'])]
    used=set()
    for skin in doc.get('skins',[]):used.add(skin['inverseBindMatrices'])
    for anim in doc.get('animations',[]):
        for s in anim['samplers']:used.update([s['input'],s['output']])
    remap={};accessors=[];views=[];blob=bytearray()
    for old in sorted(used):
        a=dict(doc['accessors'][old]);bv=doc['bufferViews'][a['bufferView']]
        start=bv.get('byteOffset',0);chunk=binary[start:start+bv['byteLength']]
        while len(blob)%4:blob.append(0)
        view={'buffer':0,'byteOffset':len(blob),'byteLength':len(chunk)}
        if 'byteStride' in bv:view['byteStride']=bv['byteStride']
        blob.extend(chunk);a['bufferView']=len(views);views.append(view);remap[old]=len(accessors);accessors.append(a)
    for skin in doc.get('skins',[]):skin['inverseBindMatrices']=remap[skin['inverseBindMatrices']]
    for anim in doc.get('animations',[]):
        for s in anim['samplers']:s['input']=remap[s['input']];s['output']=remap[s['output']]
    for key in ['meshes','materials','textures','images','samplers']:doc.pop(key,None)
    doc['accessors']=accessors;doc['bufferViews']=views
    while len(blob)%4:blob.append(0)
    doc['buffers']=[{'byteLength':len(blob)}]
    text=json.dumps(doc,separators=(',',':')).encode()
    while len(text)%4:text+=b' '
    out=struct.pack('<III',0x46546C67,2,12+8+len(text)+8+len(blob))+struct.pack('<II',len(text),0x4E4F534A)+text+struct.pack('<II',len(blob),0x004E4942)+bytes(blob)
    path.write_bytes(out)
    return {'path':str(path.relative_to(ROOT)),'stripped':True,'bytes':len(out)}

def main():
    source=read_source_materials()
    bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
    rig=bpy.data.objects['MinerRig']
    if rig.animation_data:
        rig.animation_data.action=None
        for track in rig.animation_data.nla_tracks:track.mute=True
    for p in rig.pose.bones:p.rotation_mode='QUATERNION';p.matrix_basis=Matrix.Identity(4)
    bpy.context.view_layer.update()
    for name in ['Pickaxe','TravelPan']:bpy.data.objects.remove(bpy.data.objects[name],do_unlink=True)
    objs={n:bpy.data.objects[n] for n in ['Body','Skin','Hair','Pack','Satchel','Canteen']}
    for name in ['Body','Skin','Hair']:
        me=objs[name].data;co=np.array([v.co[:] for v in me.vertices])
        if len(me.polygons)!=len(source[name]['faces']) or np.abs(co-source[name]['verts']).max()>1e-6:
            raise RuntimeError(name+': prepared.blend does not match miner_game_export.blend')
    body_part,body_trim=body_parts(objs['Body'].data,source['Body']['faces'])
    skin_part=[SKIN_PARTS[n] for n in source['Skin']['faces']]
    shell_part,shell_edge,shell_faces,shell_verts=beard_shell(objs['Skin'],skin_part)
    skin_part=skin_part+shell_part
    hair_part,cards=hair_parts(objs['Hair'].data,source['Hair']['faces'])
    # Split the hat (felt and band) from the costume: it alone carries the hat shape keys.
    hat_faces={i for i,p in enumerate(body_part) if p in (HAT,BAND)}
    hat=split(objs['Body'],lambda i:i in hat_faces,'Hat')
    hat_part=[p for p in body_part if p in (HAT,BAND)];hat_trim=[t for p,t in zip(body_part,body_trim) if p in (HAT,BAND)]
    rest_trim=[t for p,t in zip(body_part,body_trim) if p not in (HAT,BAND)];body_part=[p for p in body_part if p not in (HAT,BAND)];body_trim=rest_trim
    objs['Hat']=hat
    parts={'Body':(body_part,body_trim),'Hat':(hat_part,hat_trim),'Skin':(skin_part,None),'Hair':(hair_part,None)}
    report={'source':str(SOURCE.relative_to(ROOT)),'objects':{},'keys':{}}
    report['part_colour']=part_colours(objs,{k:v[0] for k,v in parts.items()})
    for name,o in objs.items():
        part,trim=parts.get(name,(None,None))
        add_layers(o,part,trim,name in ('Body','Skin'))
    # The shell's CrewPattern.x carries its fray (distance from the shell edge).
    pattern=objs['Skin'].data.uv_layers['CrewPattern'].data
    for fi in shell_faces:
        poly=objs['Skin'].data.polygons[fi]
        for li,vi in zip(poly.loop_indices,poly.vertices):pattern[li].uv=(shell_edge[vi],pattern[li].uv[1])
    report['keys']['Skin']=shell_keys(objs['Skin'],shell_faces,shell_verts)
    report['beard_shell']={'faces':len(shell_faces),'vertices':len(shell_verts)}
    report['keys']['Hat'],report['hat']=hat_keys(hat)
    report['keys']['Hair']=hair_keys(objs['Hair'],hair_part,cards)
    report['keys']['Body'],report['sleeve_cuff']=shirt_keys(objs['Body'],body_part)
    for name,o in objs.items():
        material=bpy.data.materials.new('Crew_'+name);o.data.materials.clear();o.data.materials.append(material)
        counts={}
        for p in parts.get(name,([0]*len(o.data.polygons),None))[0]:counts[p]=counts.get(p,0)+1
        report['objects'][name]={'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),'vertices':len(o.data.vertices),'faces_per_part':counts}
    OUT.parent.mkdir(parents=True,exist_ok=True)
    # Gear is drawn from the hero's own pack, satchel and canteen meshes at runtime.
    select([rig]+[objs[n] for n in ['Body','Hat','Skin','Hair']])
    bpy.ops.export_scene.gltf(filepath=str(OUT),export_format='GLB',use_selection=True,export_yup=True,export_apply=False,
        export_normals=True,export_tangents=False,export_texcoords=True,export_animations=False,export_skins=True,
        export_morph=True,export_morph_normal=True,export_morph_tangent=False,export_try_sparse_sk=True,
        export_materials='EXPORT',export_image_format='NONE',export_cameras=False,export_lights=False,export_extras=False,
        export_vertex_color='NONE',export_all_vertex_colors=False)
    report['quantize']=quantize_kit(OUT)
    report['kit_bytes']=OUT.stat().st_size
    report['shopkeeper']=strip_meshes(ROOT/'assets/store/shopkeeper.glb')
    (REPORT/'report.json').write_text(json.dumps(report,indent=2))
    print('CREW_KIT',json.dumps({k:report[k] for k in ['objects','kit_bytes','shopkeeper']}))

main()
