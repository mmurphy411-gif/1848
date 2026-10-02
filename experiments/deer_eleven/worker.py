"""Scoped edits of the retained static deer. No regeneration or source overwrite."""
import hashlib
import json
import math
import sys
from pathlib import Path
import bpy
from mathutils import Vector

job = json.loads(Path(sys.argv[sys.argv.index('--')+1]).read_text())
ROOT = Path(job['root']); sys.path.insert(0, str(ROOT))
from art_gauntlet.blender_worker import configure, audit, render
from blender.gauntlet_adapters import generic
from art_gauntlet.minimum_worker import rna

def write(p, value): Path(p).write_text(json.dumps(value, indent=2, sort_keys=True), encoding='utf-8')
def sha(p): return hashlib.sha256(Path(p).read_bytes()).hexdigest()
def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def bell(q, c, r): return math.exp(-sum(((q[i]-c[i])/r[i])**2 for i in range(3)))
def all_meshes(): return {o.name:o for o in bpy.context.scene.objects if o.type=='MESH'}
def snapshot():
    objects={}
    for name,o in all_meshes().items():
        m=o.data
        objects[name]={'vertices':[list(v.co) for v in m.vertices],
                       'edges':[list(e.vertices) for e in m.edges],
                       'faces':[[list(p.vertices),p.material_index,p.use_smooth] for p in m.polygons],
                       'world':[list(r) for r in o.matrix_world], 'parent':o.parent.name if o.parent else None,
                       'modifiers':[rna(x) for x in o.modifiers], 'constraints':[rna(x) for x in o.constraints],
                       'uv':{u.name:[list(d.uv) for d in u.data] for u in m.uv_layers},
                       'colors':{c.name:[list(d.color) for d in c.data] for c in m.color_attributes},
                       'groups':[g.name for g in o.vertex_groups],
                       'weights':[[(g.group,g.weight) for g in v.groups] for v in m.vertices],
                       'materials':[m.name for m in m.materials], 'shape_keys':str(m.shape_keys)}
    materials={m.name:{'surface':rna(m), 'nodes':[rna(n) for n in m.node_tree.nodes] if m.use_nodes else [],
                       'links':[[l.from_node.name,l.from_socket.identifier,l.to_node.name,l.to_socket.identifier] for l in m.node_tree.links] if m.use_nodes else []}
               for m in {m for o in all_meshes().values() for m in o.data.materials if m}}
    return {'objects':objects,'materials':materials,'armatures':[o.name for o in bpy.data.objects if o.type=='ARMATURE']}

def scope(plan):
    selected={}
    for name,o in all_meshes().items():
        if name not in plan.get('objects',[]): continue
        box=plan.get('body_box') if name=='Buck anatomy' else None
        selected[name]=[v.index for v in o.data.vertices if box is None or all(box[0][i] <= (o.matrix_world@v.co)[i] <= box[1][i] for i in range(3))]
    assert set(selected)==set(plan.get('objects',[])), 'Missing scope object'
    return selected

def set_color(obj, function):
    attr=obj.data.color_attributes['Coat']
    for loop in obj.data.loops:
        q=obj.matrix_world@obj.data.vertices[loop.vertex_index].co
        attr.data[loop.index].color=(*function(q,loop.vertex_index),1)

def edit(plan, selected):
    op=plan['operation']; strength=plan.get('strength',1.0)
    if op=='eyes':
        body=bpy.data.objects['Buck anatomy']; graph=bpy.context.evaluated_depsgraph_get()
        for sign in (-1,1):
            o=bpy.data.objects[f'Eye {sign}']; old=[o.matrix_world@v.co for v in o.data.vertices]
            center=sum(old[:20],Vector())/20
            origin=Vector((sign*.6,center.y,center.z))
            hit,co,normal,face=body.ray_cast(body.matrix_world.inverted()@origin, Vector((-sign,0,0)))
            assert hit
            center=body.matrix_world@co
            n=Vector((sign*.94,.30,.10)).normalized()
            u=Vector((0,1,0));u=(u-n*u.dot(n)).normalized();v=n.cross(u)*sign
            for vert in o.data.vertices:
                ring,k=divmod(vert.index,20); radius=[0,.52,1,1.20][ring]; angle=k*math.tau/20
                q=center + u*(.025*radius*math.cos(angle)) + v*(.023*radius*math.sin(angle))
                if plan.get('conform'):
                    q=Vector((sign*.6,center.y+.025*radius*math.cos(angle),center.z+.025*radius*math.sin(angle)*(.70+.30*abs(math.sin(angle)))))
                    hit,site,surface_normal,_=body.ray_cast(q,Vector((-sign,0,0)))
                    assert hit, 'Conforming eye missed skull'
                    q=body.matrix_world@site+surface_normal*(.0015+.007*max(0,1-radius*radius))
                elif ring==3:
                    hit,rim,_,_=body.ray_cast(Vector((sign*.6,q.y,q.z)),Vector((-sign,0,0)))
                    if hit:q=body.matrix_world@rim+n*.002
                else:q+=n*(.005+.015*math.sqrt(max(0,1-radius*radius)))
                vert.co=o.matrix_world.inverted()@q
            set_color(o,lambda q,i: (.006,.003,.001) if i<20 else (.040,.019,.007) if i<40 else (.014,.007,.003) if i<60 else (.15,.08,.035))
            o.data.update()
        return
    if op=='coat':
        body=bpy.data.objects['Buck anatomy']
        def coat(q,index):
            x,y,z=q
            noise=(math.sin(x*71+y*53+z*37)+math.sin(x*143-y*79+z*111))*.025
            rgb=Vector((.205,.105,.043))*(1+noise)
            dorsal=smooth(1.04,1.32,z)*(1-smooth(.35,.60,y))
            rgb=rgb.lerp(Vector((.11,.061,.025)),dorsal*.35)
            front=.46+(z-1.18)*.66
            throat=(1-smooth(.045,.105,abs(x)))*smooth(1.13,1.28,z)*(1-smooth(1.52,1.58,z))*smooth(.01,.07,y-front)
            chin=smooth(.84,.98,y)*(1-smooth(1.77-.315*y,1.80-.315*y,z))*smooth(1.43,1.48,z)
            rump=(1-smooth(-.70,-.63,y))*(1-smooth(.08,.15,abs(x)))*smooth(.88,.97,z)*(1-smooth(1.17,1.24,z))
            rgb=rgb.lerp(Vector((.52,.45,.33)),max(throat,chin,rump)*.85)
            eye=math.sqrt(((y-.786)/.039)**2+((z-1.681)/.033)**2)
            eyering=math.exp(-((eye-1.1)/.25)**2)*smooth(.045,.08,abs(x))
            rgb=rgb.lerp(Vector((.38,.28,.15)),eyering*.7)
            return tuple(rgb)
        set_color(body,coat)
        for sign in (-1,1): set_color(bpy.data.objects[f'Ear inner {sign}'],lambda q,i:(.25,.19,.12))
        coatmat=body.data.materials[0]; nodes=coatmat.node_tree.nodes;links=coatmat.node_tree.links
        tex=nodes.new('ShaderNodeTexCoord');mapping=nodes.new('ShaderNodeVectorMath');mapping.operation='MULTIPLY';mapping.inputs[1].default_value=(3,3,.35)
        noise=nodes.new('ShaderNodeTexNoise');noise.inputs['Scale'].default_value=125;noise.inputs['Detail'].default_value=2
        bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.20;bump.inputs['Distance'].default_value=.0012
        links.new(tex.outputs['Object'],mapping.inputs[0]);links.new(mapping.outputs['Vector'],noise.inputs['Vector'])
        links.new(noise.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],nodes.get('Principled BSDF').inputs['Normal'])
        return
    for name,ids in selected.items():
        o=bpy.data.objects[name]; inv=o.matrix_world.inverted()
        for index in ids:
            vertex=o.data.vertices[index];q=o.matrix_world@vertex.co;x,y,z=q
            if op=='muzzle':
                w=smooth(.82,.98,y)*smooth(1.43,1.50,z)*(1-smooth(1.61,1.70,z))
                q.x*=1+.14*w*strength; q.z+=.008*w*strength
            elif op=='ears':
                t=max(0,min(1,(abs(x)-.085)/.245));w=math.sin(math.pi*t)
                q.y+=.022*w*strength; q.z+=(z-(1.775+.16*t))*.18*w*strength
            elif op=='neck':
                w=bell(q,(0,.49,1.32),(.32,.25,.22));q.x*=1+.10*w*strength;q.y-=.018*w*strength
            elif op=='chest':
                w=bell(q,(0,.02,.84),(.3,.36,.12));q.z+=.032*w*strength
                w=bell(q,(0,.34,.98),(.25,.20,.18));q.x*=1+.065*w*strength
            elif op=='croup':
                if name=='Black tail':
                    w=1-smooth(.88,1.20,z);q.y-=.017*w*strength;q.x*=1-.12*w*strength
                else:
                    w=bell(q,(0,-.43,1.23),(.3,.28,.16));q.z+=.018*w*strength;q.x*=1+.045*w*strength
            elif op=='forelegs':
                w=math.exp(-((z-.49)/.10)**2);q.x+=(-1 if x<0 else 1)*.006*w*strength
                w=math.exp(-((z-.28)/.12)**2); q.y+=(.43-y)*.065*w*strength
            elif op=='hindlegs':
                w=math.exp(-((z-.55)/.11)**2);q.y+=.016*w*strength
                w=math.exp(-((z-.29)/.13)**2);q.x*=1+.025*w*strength
            elif op=='hooves':
                if 'hoof' in name:q.y+=.015*smooth(0,.074,z)*strength
                else:q.y+=.015*(1-smooth(.075,.18,z))*strength
            elif op=='antlers':
                w=smooth(1.79,2.15,z);q.x*=1+.07*w*strength;q.y+=.018*w*strength
            vertex.co=inv@q
        o.data.update()
        if op=='antlers': set_color(o,lambda q,i:tuple(Vector((.11,.062,.025)).lerp(Vector((.42,.31,.17)),smooth(1.78,2.15,q.z))))

def verify(before,after,plan,allowed):
    assert before['armatures']==after['armatures']==[], 'Static study cannot edit rigged data'
    assert set(before['objects'])==set(after['objects']), 'Object set changed'
    changes={}; protected=0
    for name,a in before['objects'].items():
        b=after['objects'][name]
        assert len(a['vertices'])==len(b['vertices']), 'Topology changed'
        permitted=set(allowed.get(name,[])); changed=[]
        for i,(x,y) in enumerate(zip(a['vertices'],b['vertices'])):
            assert all(math.isfinite(v) for v in y), 'Nonfinite vertex'
            if x!=y:
                assert i in permitted, f'Protected vertex changed: {name}:{i}'
                changed.append({'id':i,'delta':[v-u for u,v in zip(x,y)]})
            if i not in permitted:protected+=1
        changes[name]=changed
        for field in a:
            if field=='vertices':continue
            if field=='colors' and name in plan.get('color_objects',[]):continue
            assert a[field]==b[field], f'Protected {field} changed: {name}'
    permitted_materials=set(plan.get('material_names',[]))
    assert set(before['materials'])==set(after['materials'])
    for name in before['materials']:
        if name not in permitted_materials:assert before['materials'][name]==after['materials'][name], f'Protected material changed: {name}'
    return {'passed':True,'protected_vertices_exact':protected,'changes':changes,'topology_unchanged':True,'rigs':0}

output=Path(job['output']);output.mkdir(parents=True,exist_ok=False)
source=Path(job['input']);source_hash=sha(source)
bpy.ops.wm.open_mainfile(filepath=str(source),load_ui=False,use_scripts=False)
device=configure(job['manifest']);bpy.context.view_layer.update()
before=snapshot();plan=job['plan'];allowed=scope(plan)
write(output/'before.json',before);write(output/'scope.json',allowed)
if plan['operation']!='baseline':edit(plan,allowed)
bpy.context.view_layer.update();after=snapshot()
preservation=verify(before,after,plan,allowed)
write(output/'after.json',after);write(output/'preservation.json',preservation)
structural=audit(generic.subject(job['manifest']),job['manifest'],generic)
write(output/'audit.json',structural)
assert not structural['errors'], structural['errors']
assert not structural['budget_violations'], structural['budget_violations']
bpy.context.scene.camera=bpy.data.objects['Gauntlet three_quarter']
bpy.ops.wm.save_as_mainfile(filepath=str(output/'candidate.blend'))
bpy.ops.wm.open_mainfile(filepath=str(output/'candidate.blend'),load_ui=False,use_scripts=False)
saved=snapshot();assert saved==after, 'Saved scene changed canonical evidence'
write(output/'saved_scene_check.json',{'passed':True,'sha256':sha(output/'candidate.blend')})
render(job['manifest'],output/'renders',sha(Path(sys.argv[sys.argv.index('--')+1])),device)
assert sha(source)==source_hash, 'Parent scene changed'
write(output/'complete.json',{'completed':True,'parent_sha256':source_hash,'candidate_sha256':sha(output/'candidate.blend'),
                             'device':device,'blender':bpy.app.version_string,'renders':9,'triangles':structural['triangles']})
