"""One reference-projected trout surface candidate; run with Blender --background --python.

Original image pixels are sampled by new UVs, never repainted or regenerated.
Geometry, transforms, existing UVs, visibility, lights and original cameras are protected.
"""
import bpy
import hashlib
import json
import math
import sys
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent
SOURCE = ROOT / 'blender/trout_convergence_working.blend'
REFERENCE = next((ROOT/'characters/rainbow trout').glob('*(1).png'))
MODE = sys.argv[sys.argv.index('--')+1] if '--' in sys.argv else 'all'

def file_hash(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def digest(values):
    return hashlib.sha256(json.dumps(values, sort_keys=True).encode()).hexdigest()

def snapshot():
    result = {}
    deps = bpy.context.evaluated_depsgraph_get()
    for o in bpy.context.scene.objects:
        entry = {'type':o.type, 'matrix':[list(r) for r in o.matrix_world],
                 'hide_render':o.hide_render, 'hide_viewport':o.hide_viewport,
                 'parent':o.parent.name if o.parent else None}
        if o.type == 'MESH':
            entry['geometry'] = digest(([list(v.co) for v in o.data.vertices],
                                        [list(p.vertices) for p in o.data.polygons]))
            entry['existing_uvs'] = {u.name:digest([list(v.uv) for v in u.data])
                                    for u in o.data.uv_layers if u.name != 'Reference projection'}
            ev = o.evaluated_get(deps); mesh = ev.to_mesh()
            entry['evaluated_geometry'] = digest(([list(v.co) for v in mesh.vertices],
                                                  [list(p.vertices) for p in mesh.polygons]))
            ev.to_mesh_clear()
        if o.type == 'CAMERA':
            entry['camera'] = [o.data.type,o.data.ortho_scale,o.data.lens,o.data.sensor_fit]
        if o.type == 'LIGHT':
            entry['light'] = [o.data.type,o.data.energy,list(o.data.color),o.data.size]
        result[o.name] = entry
    return result

def configure_render():
    s = bpy.context.scene
    s.render.engine = 'CYCLES'; s.cycles.samples = 32
    s.cycles.use_denoising = True; s.cycles.seed = 1848
    s.render.resolution_x = 1000; s.render.resolution_y = 1000
    s.render.resolution_percentage = 100
    s.render.film_transparent = True
    s.render.image_settings.file_format = 'PNG'
    try:
        prefs = bpy.context.preferences.addons['cycles'].preferences
        prefs.compute_device_type = 'OPTIX'; prefs.get_devices()
        for device in prefs.devices: device.use = device.type != 'CPU'
        s.cycles.device = 'GPU'
    except Exception:
        pass

def new_camera(name, location, target, scale):
    camera = bpy.data.cameras.new(name); camera.type='ORTHO'; camera.ortho_scale=scale
    o = bpy.data.objects.new(name,camera); bpy.context.scene.collection.objects.link(o)
    o.location=location; o.rotation_euler=(Vector(target)-o.location).to_track_quat('-Z','Y').to_euler()
    return o

def render_set(label):
    s=bpy.context.scene
    for view in ['side','three_quarter','dorsal','opposite','head']:
        s.camera=bpy.data.objects['Review '+view]
        s.render.filepath=str(OUT/f'{label}_{view}.png')
        bpy.ops.render.render(write_still=True)

def interp(x, table):
    return float(np.interp(x,[p[0] for p in table],[p[1] for p in table]))

# Inspected landmarks on the unmodified 1086 x 1448 hero reference.
XMAP=[(-.184,30),(-.18,40),(-.148,112),(-.127,200),(-.108,269),
      (-.05,455),(0,598),(.05,746),(.095,842),(.13,893),(.153,922)]
TOP=[(30,683),(70,663),(112,638),(200,601),(269,582),(350,566),
     (455,560),(598,579),(746,609),(842,637),(893,643),(922,629)]
BOTTOM=[(30,727),(70,753),(112,773),(200,787),(269,791),(350,815),
        (455,821),(598,806),(746,776),(842,745),(893,742),(922,754)]

def projection_material(image, name, roughness=.53, metallic=.06):
    mat=bpy.data.materials.new(name);mat.use_nodes=True
    n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
    uv=n.new('ShaderNodeUVMap');uv.uv_map='Reference projection'
    tex=n.new('ShaderNodeTexImage');tex.image=image;tex.extension='EXTEND';tex.interpolation='Linear'
    l.new(uv.outputs['UV'],tex.inputs['Vector'])
    l.new(tex.outputs['Color'],p.inputs['Base Color'])
    p.inputs['Roughness'].default_value=roughness;p.inputs['Metallic'].default_value=metallic
    p.inputs['Coat Weight'].default_value=.1;p.inputs['Coat Roughness'].default_value=.35
    return mat

def apply_uv(o, coords, material):
    layer=o.data.uv_layers.new(name='Reference projection')
    for loop in o.data.loops:
        px,py=coords[loop.vertex_index]
        layer.data[loop.index].uv=(px/1086,1-py/1448)
    o.data.materials.clear();o.data.materials.append(material)
    for p in o.data.polygons:p.material_index=0

def body_mapping(o, rings):
    result=[]
    for v in o.data.vertices:
        x,y,z=o.matrix_world@v.co
        lo=interp(x,[(a,b[0]) for a,b in rings]); hi=interp(x,[(a,b[1]) for a,b in rings])
        q=max(0,min(1,(z-lo)/max(.0001,hi-lo)))
        px=interp(x,XMAP);top=interp(px,TOP)+3;bottom=interp(px,BOTTOM)-4
        py=bottom+(top-bottom)*q
        # The reference's pectoral fin overlaps the belly: sample clean adjacent
        # belly scales instead of painting that fin a second time onto the body.
        if 230<px<365 and q<.22:
            weight=min(1,(.22-q)/.10)*min(1,(px-230)/22,(365-px)/22)
            px=px*(1-weight)+420*weight
            py=py*(1-weight)+(804-35*q)*weight
        result.append((px,py))
    return result

def fin_mapping(o, polygon):
    # Match each membrane's existing planar fan to an inset reference polygon.
    pts=np.array([[v.co.x,v.co.z] for v in o.data.vertices])
    center=pts[0]; boundary=pts[1:]
    p=np.array(polygon,dtype=float); pc=np.mean(p,axis=0)
    # Source and model have opposite vertical axes.
    angles=np.arctan2(boundary[:,1]-center[1],boundary[:,0]-center[0])
    refangles=np.arctan2(-(p[:,1]-pc[1]),p[:,0]-pc[0])
    def radius(angle, poly, c):
        direction=np.array([math.cos(angle),math.sin(angle)])
        hits=[]
        for a,b in zip(poly,np.roll(poly,-1,axis=0)):
            mat=np.column_stack((direction,-(b-a)))
            if abs(np.linalg.det(mat))<1e-10:continue
            t,u=np.linalg.solve(mat,a-c)
            if t>=0 and 0<=u<=1:hits.append(t)
        return min(hits) if hits else .001
    # Normalize each domain before radial transfer to preserve the ray fan.
    span=np.ptp(pts,axis=0); normalized=(pts-center)/np.maximum(span,1e-8)
    ref=p.copy();ref[:,1]*=-1;rc=ref.mean(axis=0);rs=np.ptp(ref,axis=0)
    refnorm=(ref-rc)/rs
    coords=[]
    for v in normalized:
        angle=math.atan2(v[1],v[0]);r=float(np.linalg.norm(v))
        rm=radius(angle,normalized[1:],np.zeros(2));rr=radius(angle,refnorm,np.zeros(2))
        t=min(1,r/max(rm,1e-8))*.93
        sample=rc+np.array([math.cos(angle),math.sin(angle)])*rr*t*rs
        coords.append((float(sample[0]),float(-sample[1])))
    return coords

def make_candidate():
    image=bpy.data.images.load(str(REFERENCE),check_existing=True);image.pack()
    bodymat=projection_material(image,'TEST | reference body')
    finmat=projection_material(image,'TEST | reference fins',.57,.02)
    body=bpy.data.objects['Trout body']; groups={}
    for v in body.data.vertices:groups.setdefault(round(v.co.x,6),[]).append(v.co.z)
    rings=sorted((x,(min(zs),max(zs))) for x,zs in groups.items())
    for name in ['Trout body','Lower jaw','Upper lip -1','Upper lip 1','Lower lip -1','Lower lip 1',
                 'Seated opercular edge -1','Seated opercular edge 1']:
        o=bpy.data.objects[name];apply_uv(o,body_mapping(o,rings),bodymat)
    polygons={
      'Caudal fin':[(897,648),(977,590),(1045,578),(1042,643),(1029,695),(1045,812),(1006,790),(929,745),(899,738)],
      'Dorsal fin':[(478,554),(524,517),(583,499),(610,536),(642,579),(562,573)],
      'Adipose fin':[(784,619),(811,603),(831,608),(834,624),(814,635)],
      'Anal fin':[(697,787),(745,766),(803,751),(824,793),(817,841),(768,823)],
      'Pectoral':[(246,763),(277,765),(320,780),(349,812),(358,834),(323,828),(283,802)],
      'Pelvic':[(543,807),(572,818),(614,843),(632,873),(609,877),(576,854)]}
    for name,poly in polygons.items():
        names=[name+' -1',name+' 1'] if name in ['Pectoral','Pelvic'] else [name]
        for objname in names:
            o=bpy.data.objects[objname];apply_uv(o,fin_mapping(o,poly),finmat)
    # Keep every ray mesh; reduce its contrast to sit with the reference-painted membrane.
    ray=bpy.data.materials['Trout fin rays'].copy();ray.name='TEST | quieter existing rays'
    p=ray.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.29,.24,.17,1)
    p.inputs['Roughness'].default_value=.6;p.inputs['Metallic'].default_value=0
    for o in bpy.context.scene.objects:
        if o.name.startswith('Rays |'):
            o.data.materials.clear();o.data.materials.append(ray)
    bpy.context.scene['surface_test']='One reference-projected candidate. Mirrored side art; original geometry retained.'

bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
source_hash=file_hash(SOURCE);reference_hash=file_hash(REFERENCE)
protected=snapshot()
configure_render()
new_camera('Review opposite',(-1.5,3,.4),(.02,0,0),.46)
new_camera('Review head',(-1.0,-3,.3),(-.125,0,0),.15)
baseline=snapshot()
if MODE in ['all','baseline']:render_set('baseline')
if MODE in ['all','candidate']:
    make_candidate()
    after=snapshot()
    assert baseline==after,'Protected scene data changed'
    s=bpy.context.scene;s.camera=bpy.data.objects['Review three_quarter']
    bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'trout_surface_candidate.blend'))
    render_set('candidate')
    bpy.ops.wm.open_mainfile(filepath=str(OUT/'trout_surface_candidate.blend'))
    assert snapshot()==baseline,'Saved scene changed protected data'
    assert file_hash(SOURCE)==source_hash and file_hash(REFERENCE)==reference_hash
    audit={'geometry_transforms_visibility_existing_uvs_cameras_lights_unchanged':True,
           'saved_scene_reopened_and_verified':True,'source_sha256':source_hash,
           'reference_sha256':reference_hash,'reference':str(REFERENCE),'original_scene':str(SOURCE),
           'protected_snapshot_sha256':digest(baseline),'candidate_count':1,
           'renderer':'Cycles, 32 samples, fixed seed 1848, original AgX view settings',
           'limitations':['Illustrated lighting remains in color image; no albedo reconstruction.',
                          'Reference side art mirrored onto opposite side.',
                          'Screen-size previews are Blender proxies, not Godot/water captures.',
                          'Material variant is not integrated into live game.']}
    (OUT/'audit.json').write_text(json.dumps(audit,indent=2))
    print('SURFACE TEST VERIFIED',flush=True)
