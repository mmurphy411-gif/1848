"""Reference-driven deer/trout source-art checkpoints. No live game exports.

Blender --background --python blender/animal_convergence.py -- deer 0
Stages are cumulative, loading the preceding retained checkpoint.
"""
import bpy, sys, math, json, random
from pathlib import Path
from mathutils import Vector

ROOT = Path(__file__).resolve().parents[1]
SPECIES, STEP = sys.argv[sys.argv.index('--')+1:][:2]
STEP = int(STEP)
OUT = ROOT/'artifacts'/f'{SPECIES}-convergence'
OUT.mkdir(parents=True, exist_ok=True)

def mat(name, color, rough=.65, metallic=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes=True
    p=m.node_tree.nodes.get('Principled BSDF')
    p.inputs['Base Color'].default_value=(*color,1)
    p.inputs['Roughness'].default_value=rough
    p.inputs['Metallic'].default_value=metallic
    m.diffuse_color=(*color,1)
    return m

def mesh(name, vs, fs, material):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update()
    o=bpy.data.objects.new(name,d);bpy.context.scene.collection.objects.link(o)
    d.materials.append(material)
    for p in d.polygons:p.use_smooth=True
    return o

def ell(name, p, scale, material):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=32, ring_count=20, location=p)
    o=bpy.context.object;o.name=name;o.scale=scale
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(material)
    for f in o.data.polygons:f.use_smooth=True
    return o

def tube(name, pts, radii, material, sides=12):
    pts=[Vector(p) for p in pts];vs=[];fs=[]
    for j,p in enumerate(pts):
        tangent=(pts[min(j+1,len(pts)-1)]-pts[max(0,j-1)]).normalized()
        a=Vector((1,0,0)) if abs(tangent.x)<.9 else Vector((0,1,0))
        a=(a-tangent*a.dot(tangent)).normalized();b=tangent.cross(a)
        for k in range(sides):vs.append(p+radii[j]*(a*math.cos(k*math.tau/sides)+b*math.sin(k*math.tau/sides)))
    for j in range(len(pts)-1):
        for k in range(sides):
            a=j*sides+k;b=j*sides+(k+1)%sides;fs.append((a,b,b+sides,a+sides))
    fs.extend([tuple(reversed(range(sides))),tuple((len(pts)-1)*sides+k for k in range(sides))])
    return mesh(name,vs,fs,material)

def parent(o,p):
    bpy.context.view_layer.update();m=o.matrix_world.copy();o.parent=p;o.matrix_world=m

def assign(o,m):
    o.data.materials.clear();o.data.materials.append(m)
    for p in o.data.polygons:p.material_index=0

def active(o):
    bpy.ops.object.select_all(action='DESELECT');o.select_set(True);bpy.context.view_layer.objects.active=o

def world_edit(o, fn):
    bpy.context.view_layer.update();a=o.matrix_world.copy();inv=a.inverted()
    for v in o.data.vertices:v.co=inv@Vector(fn(a@v.co))
    o.data.update()

def setup():
    s=bpy.context.scene
    for o in list(s.objects):
        if o.type in {'CAMERA','LIGHT'}:bpy.data.objects.remove(o,do_unlink=True)
    s.render.engine='CYCLES';s.cycles.samples=20
    try:
        prefs=bpy.context.preferences.addons['cycles'].preferences;prefs.compute_device_type='OPTIX';prefs.get_devices()
        for d in prefs.devices:d.use=d.type!='CPU'
        s.cycles.device='GPU'
    except Exception:pass
    s.render.resolution_x=800;s.render.resolution_y=800;s.render.resolution_percentage=100
    s.render.image_settings.file_format='PNG';s.render.film_transparent=True
    s.view_settings.view_transform='AgX';s.view_settings.look='AgX - Medium High Contrast'
    w=bpy.data.worlds.new('Neutral review');w.use_nodes=True
    w.node_tree.nodes['Background'].inputs[0].default_value=(.55,.55,.55,1)
    w.node_tree.nodes['Background'].inputs[1].default_value=.6;s.world=w
    if SPECIES=='deer':
        target=Vector((0,.15,1.10));scale=2.5
        views={'front':(0,7,1.1),'side':(7,0,1.1),'back':(0,-7,1.1),'three_quarter':(4,7,1.4)}
    else:
        target=Vector((.02,0,0));scale=.46
        views={'front':(-3,0,.025),'side':(0,-3,0),'back':(3,0,.055),'three_quarter':(-1.5,-3,.4)}
    for name,loc in views.items():
        d=bpy.data.cameras.new(name);d.type='ORTHO';d.ortho_scale=scale
        o=bpy.data.objects.new('Review '+name,d);s.collection.objects.link(o);o.location=loc
        o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()
    mult=1 if SPECIES=='deer' else .16
    for name,loc,energy,size in [('Key',(3,4,5),500,4),('Fill',(-4,2,3),320,4),('Rim',(1,-4,4),400,3)]:
        d=bpy.data.lights.new(name,'AREA');d.energy=energy*mult*mult;d.shape='DISK';d.size=size*mult
        o=bpy.data.objects.new(name,d);s.collection.objects.link(o);o.location=Vector(loc)*mult
        o.rotation_euler=(target-o.location).to_track_quat('-Z','Y').to_euler()

def audit():
    bpy.context.view_layer.update();objects=[];coords=[]
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or o.hide_render:continue
        vs=[o.matrix_world@v.co for v in o.data.vertices];coords+=vs
        objects.append({'name':o.name,'vertices':len(vs),'triangles':sum(len(p.vertices)-2 for p in o.data.polygons),
          'bounds':[[round(min(v[k] for v in vs),5) for k in range(3)],[round(max(v[k] for v in vs),5) for k in range(3)]],
          'materials':[m.name if m else None for m in o.data.materials],'parent':o.parent.name if o.parent else None})
    assert all(math.isfinite(c) for p in coords for c in p)
    data={'species':SPECIES,'stage':STEP,'objects':objects,'triangles':sum(o['triangles'] for o in objects),'finite_coordinates':True,
      'bounds':[[min(p[k] for p in coords) for k in range(3)],[max(p[k] for p in coords) for k in range(3)]]}
    (OUT/f'pass_{STEP:02}_audit.json').write_text(json.dumps(data,indent=2))
    print('AUDIT',json.dumps(data))

def finish():
    s=bpy.context.scene;s.camera=bpy.data.objects['Review three_quarter']
    if SPECIES=='deer':
        side=bpy.data.objects['Review side'];side.location=(-7,0,1.1)
        side.rotation_euler=(Vector((0,.15,1.1))-side.location).to_track_quat('-Z','Y').to_euler()
    s['reference_directory']=str(ROOT/'characters'/('deer' if SPECIES=='deer' else 'rainbow trout'))
    s['source_art_checkpoint']=STEP;s['not_game_export']=True
    audit()
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/f'pass_{STEP:02}.blend'))
    bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender'/f'{SPECIES}_convergence_working.blend'))
    for view in ['front','side','back','three_quarter']:
        s.camera=bpy.data.objects['Review '+view];s.render.filepath=str(OUT/f'pass_{STEP:02}_{view}.png')
        bpy.ops.render.render(write_still=True)
    if 'Review dorsal' in bpy.data.objects:
        s.camera=bpy.data.objects['Review dorsal'];s.render.filepath=str(OUT/f'pass_{STEP:02}_dorsal.png');bpy.ops.render.render(write_still=True)
    black=mat('Review black',(0,0,0),1);black.node_tree.nodes.get('Principled BSDF').inputs['Specular IOR Level'].default_value=0
    bpy.context.view_layer.material_override=black
    s.cycles.samples=8
    for view in ['front','side','back','three_quarter']:
        s.camera=bpy.data.objects['Review '+view];s.render.filepath=str(OUT/f'pass_{STEP:02}_silhouette_{view}.png')
        bpy.ops.render.render(write_still=True)
    bpy.context.view_layer.material_override=None

if STEP==0:
    bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender'/('build_deer.blend' if SPECIES=='deer' else 'build_fish.blend')))
    if SPECIES=='trout':
        for o in list(bpy.context.scene.objects):
            if o.type=='MESH' and o.name!='trout':bpy.data.objects.remove(o,do_unlink=True)
    setup()
elif len(sys.argv)>sys.argv.index('--')+3 and sys.argv[sys.argv.index('--')+3]=='review':
    bpy.ops.wm.open_mainfile(filepath=str(OUT/f'pass_{STEP:02}.blend'))
else:
    bpy.ops.wm.open_mainfile(filepath=str(OUT/f'pass_{STEP-1:02}.blend'))
    sys.path.insert(0,str(ROOT/'blender'))
    mod=__import__(f'{SPECIES}_convergence_steps')
    mod.run(STEP,sys.modules[__name__])
finish()
