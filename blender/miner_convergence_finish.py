"""Pass 16: garment construction, equipment construction, and localized final wear."""
import bpy,sys,math,random,json
from pathlib import Path
from mathutils import Vector
from mathutils.bvhtree import BVHTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence_structural as s
import miner_convergence_materials as m
b=s.b;c=s.c;OUT=s.OUT

def tree(o):return BVHTree.FromPolygons([v.co.copy() for v in o.data.vertices],[tuple(p.vertices) for p in o.data.polygons])

def stitches(name,paths,mat,group,bone,weight_fn=None,spacing=.006,radius=.00048):
    vs=[];fs=[]
    for path in paths:
        for a,bb in zip(path,path[1:]):
            a=Vector(a);bb=Vector(bb);delta=bb-a;length=delta.length
            if length<1e-5:continue
            axis=delta.normalized();cross=axis.cross(Vector((0,1,0)))
            if cross.length<.1:cross=axis.cross(Vector((1,0,0)))
            cross.normalize();other=axis.cross(cross).normalized();count=max(1,int(length/spacing))
            for i in range(count):
                p=a+delta*(i/count+.13/count);q=a+delta*(i/count+.64/count);off=len(vs)
                for center in [p,q]:
                    for k in range(4):vs.append(center+radius*(cross*math.cos(k*math.tau/4)+other*math.sin(k*math.tau/4)))
                fs.extend(tuple(off+j for j in f) for f in [(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7),(0,3,2,1),(4,5,6,7)])
    o=b.mesh(name,vs,fs,mat,group,bone)
    if weight_fn:b.replace_surface(o,vs,fs,mat,weight_fn)
    return o

def edge_path(o,front=True):
    edges={}
    for p in o.data.polygons:
        ids=list(p.vertices)
        for a,bb in zip(ids,ids[1:]+ids[:1]):key=tuple(sorted((a,bb)));edges[key]=edges.get(key,0)+1
    points=[o.data.vertices[i].co.copy() for e,n in edges.items() if n==1 for i in e]
    points=[p for p in points if p.y<-.045 and abs(p.x)<.155]
    if not points:return []
    result=[]
    for j in range(29):
        z=1.085+j/28*.34;p=min(points,key=lambda p:abs(p.z-z)*2+abs(p.x)*.03).copy();p.y-=.0025
        if not result or (p-result[-1]).length>.001:result.append(p)
    return result

def garment_details(lookup):
    thread=b.material('FINISH | dark linen thread',(.125,.092,.049),.94)
    button=bpy.data.materials['FINISH | hardware'];shadow=b.material('FINISH | buttonhole shadow',(.009,.007,.004),1)
    for o in list(s.active_meshes('COSTUME | vest and scarf')):
        if not o.name.startswith('Vest | continuous armhole'):continue
        path=edge_path(o)
        if path:stitches('Vest | sewn front edge '+o.name[-2:], [path],thread,'COSTUME | vest and scarf','Chest',c.garment_weight)
        side=1 if sum(v.co.x for v in o.data.vertices)>0 else -1;vt=tree(o)
        for j,z in enumerate([1.11,1.17,1.23,1.29,1.345]):
            if not path:continue
            p=min(path,key=lambda p:abs(p.z-z));x=p.x+side*.013
            hit,normal,idx,dist=vt.ray_cast(Vector((x,-.4,z)),Vector((0,1,0)),.5)
            if hit is None:continue
            center=Vector((x,hit.y-.002,z))
            if side<0:
                o2=b.tube('Vest | aged metal button '+str(j),[center+Vector((0,.001,0)),center-Vector((0,.0012,0)),center-Vector((0,.0016,0))],[.0048,.0049,.0038],button,'COSTUME | vest and scarf',12,'Chest')
                m.attributes(o2,'hardware')
            else:
                points=[center+Vector((-.003,0,0)),center+Vector((.003,0,0))]
                b.tube('Vest | bound buttonhole '+str(j),points,[.0007,.0007],shadow,'COSTUME | vest and scarf',4,'Chest')
    # Shoulder and sleeve seams follow the existing garment, not a straight floating line.
    for idx,side in [(36,'Left'),(37,'Right')]:
        o=lookup[idx];paths=[]
        for k in [3,15]:
            path=[]
            for j in range(1,15):
                p=o.data.vertices[j*24+k].co.copy();p.y+=math.copysign(.0015,p.y);path.append(p)
            paths.append(path)
        stitches('Shirt | sleeve seam '+side,paths,thread,'COSTUME | shirt',side+'UpperArm',lambda p,side=side:{side+'UpperArm':max(0,min(1,(p.z-1.045)/.13)),side+'LowerArm':1-max(0,min(1,(p.z-1.045)/.13))})
    # Visible warp threads and a few loose fibers at the intentional knee opening.
    pants=bpy.data.objects['Trousers | continuous work-cloth shell'];pt=tree(pants);paths=[];rng=random.Random(1848)
    for i in range(18):
        x=-.148+i*.0044;z=.626+(.018 if i%2 else -.016)
        hit,normal,idx,d=pt.find_nearest(Vector((x,-.10,z)))
        if hit is None:continue
        a=hit+Vector((0,-.0015,0));end=a+Vector((rng.uniform(-.003,.003),-.0004,-.005 if i%2 else .004))
        paths.append([a,end])
    for j in range(2):paths.append([(-.137,-.098,.625+j*.004),(-.11,-.096,.623+j*.004),(-.087,-.095,.625+j*.004)])
    stitches('Trousers | exposed knee warp and fray',paths,thread,'COSTUME | trousers','RightUpperLeg',spacing=.035,radius=.0004)
    # Boot toe-cap stitch line follows the longitudinal vamp.
    for idx,side in [(0,'Left'),(1,'Right')]:
        boot=lookup[idx];bt=tree(boot);cx=.11 if side=='Left' else -.11;path=[]
        for j in range(21):
            x=cx-.066+j/20*.132;y=-.133+.026*((x-cx)/.066)**2
            hit,normal,idx2,d=bt.ray_cast(Vector((x,y,.25)),Vector((0,0,-1)),.3)
            if hit is not None:path.append(hit+Vector((0,0,.001)))
        stitches('Boot | stitched toe cap '+side,[path],thread,'COSTUME | boots',side+'Foot',radius=.0005)

def equipment_details(lookup):
    thread=b.material('FINISH | waxed saddle thread',(.16,.096,.041),.9)
    for name,rows,cols,group,bone,front in [('Backpack | original constructed piece 1',5,25,'GEAR | backpack','Chest',False),('Satchel | overlapping flap',4,19,'GEAR | satchel','Hips',True)]:
        o=bpy.data.objects[name];ids=list(range(cols))+[j*cols+cols-1 for j in range(1,rows)]+list(range(rows*cols-2,(rows-1)*cols-1,-1))+[j*cols for j in range(rows-2,0,-1)]
        path=[]
        for i in ids:
            p=o.data.vertices[i].co.copy();p.y+=-.0015 if front else .0015;path.append(p)
        path.append(path[0]);stitches(name+' | bound flap seam',[path],thread,group,bone,spacing=.006,radius=.00048)
    # Hat edge has a bound seam with small irregular exposed felt fibers.
    hat=lookup[71];path=[hat.data.vertices[128+k].co.copy()+Vector((0,0,.0008)) for k in range(64)];path.append(path[0])
    stitches('Hat | battered bound brim',[path],thread,'COSTUME | hat','Head',spacing=.007,radius=.0004)
    for v in hat.data.vertices:
        p=v.co
        if p.z>1.69:
            p.y+=.003*math.exp(-((p.x+.04)/.035)**2)*max(0,-p.y/.10)
            p.z-=.002*math.exp(-((p.x-.024)/.026)**2)
    # A tongue and keeper make the substantial belt buckle mechanically legible.
    buckle=bpy.data.objects.get('Belt | rectangular forged buckle')
    if buckle:
        ps=[v.co for v in buckle.data.vertices];cx=(min(p.x for p in ps)+max(p.x for p in ps))/2;cy=min(p.y for p in ps)-.001;cz=(min(p.z for p in ps)+max(p.z for p in ps))/2
        o=b.tube('Belt | buckle tongue',[(cx+.025,cy,cz),(cx-.014,cy-.002,cz+.002)],[.0015,.001],bpy.data.materials['FINISH | hardware'],'COSTUME | belt',6,'Hips');m.attributes(o,'hardware')
    # Small fasteners on the leather harness remain part of detachable pack gear.
    for o in list(s.active_meshes('GEAR | backpack')):
        if not o.name.startswith('Pack | sewn continuous shoulder harness'):continue
        for row in [4,24]:
            p=o.data.vertices[row*3+1].co.copy();p.y-=.0015
            fastener=b.tube('Pack | harness rivet '+o.name[-2:]+' '+str(row),[p,p+Vector((0,-.0015,0))],[.0022,.0020],bpy.data.materials['FINISH | hardware'],'GEAR | backpack',10,'Chest');m.attributes(fastener,'hardware')

def localized_wear():
    # Increase material variation selectively; preserve the clear hierarchy of clean and worn areas.
    for role in ['trouser','canvas','felt','boot','satchel','leather']:
        mat=bpy.data.materials['FINISH | '+role];base=m.PALETTE[role][0];n=mat.node_tree.nodes;l=mat.node_tree.links
        ramp=next(o for o in n if o.label=='Restrained base palette')
        ramp.color_ramp.elements[0].color=tuple(x*.43 for x in base)+(1,);ramp.color_ramp.elements[0].position=.24
        ramp.color_ramp.elements[1].color=tuple(x*1.38 for x in base)+(1,);ramp.color_ramp.elements[1].position=.78
        attr=next(o for o in n if o.bl_idname=='ShaderNodeAttribute' and o.attribute_name=='age_masks')
        coord=next(o for o in n if o.bl_idname=='ShaderNodeAttribute' and o.attribute_name=='rest_position')
        split=n.new('ShaderNodeSeparateColor');l.new(attr.outputs['Color'],split.inputs[0])
        noise=n.new('ShaderNodeTexNoise');noise.label='Dried dirt breakup only in contact mask';noise.inputs['Scale'].default_value=80;noise.inputs['Detail'].default_value=2;l.new(coord.outputs['Vector'],noise.inputs['Vector'])
        threshold=n.new('ShaderNodeValToRGB');threshold.color_ramp.elements[0].position=.55;threshold.color_ramp.elements[1].position=.70;l.new(noise.outputs['Fac'],threshold.inputs[0])
        mult=n.new('ShaderNodeMath');mult.operation='MULTIPLY';l.new(split.outputs['Red'],mult.inputs[0]);l.new(threshold.outputs[0],mult.inputs[1])
        mix=n.new('ShaderNodeMixRGB');mix.label='Localized dry dust fragments';mix.inputs[2].default_value=(.14,.091,.039,1);l.new(mult.outputs[0],mix.inputs[0])
        p=next(o for o in n if o.bl_idname=='ShaderNodeBsdfPrincipled');previous=p.inputs['Base Color'].links[0].from_socket;l.new(previous,mix.inputs[1]);l.new(mix.outputs[0],p.inputs['Base Color'])

def optimize():
    audit=[]
    for o in list(bpy.context.scene.objects):
        if o.hide_render or o.type!='MESH':continue
        target=18000 if o.name=='Trousers | continuous work-cloth shell' else 1800 if o.name.startswith('Vest | continuous armhole') else None
        if not target:continue
        before=sum(len(p.vertices)-2 for p in o.data.polygons)
        if before<=target:continue
        old=o.data.copy();old.use_fake_user=True;old.name=o.name+' | before final reduction'
        bpy.context.view_layer.objects.active=o;mod=o.modifiers.new('Measured source reduction','DECIMATE');mod.ratio=target/before;mod.use_collapse_triangulate=True
        bpy.ops.object.modifier_move_to_index(modifier=mod.name,index=0);bpy.ops.object.modifier_apply(modifier=mod.name)
        audit.append({'object':o.name,'before_base_triangles':before,'after_base_triangles':sum(len(p.vertices)-2 for p in o.data.polygons)})
    (OUT/'pass_16_reduction_audit.json').write_text(json.dumps(audit,indent=2))

def run():
    lookup=s.load_previous(16);garment_details(lookup);equipment_details(lookup);localized_wear();optimize()
    for prop,groups in c.GEAR.items():
        for group in groups:
            for o in s.active_meshes(group):c.driver(o,'hide_render',prop,'not enabled');c.driver(o,'hide_viewport',prop,'not enabled')
    s.finish(16)

if __name__=='__main__':run()
