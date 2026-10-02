"""Final source-art packaging, geometric checks and close-up evidence."""
import bpy,sys,json,math
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[1]
species=sys.argv[sys.argv.index('--')+1];out=ROOT/'artifacts'/f'{species}-convergence'
stage=int(sys.argv[sys.argv.index('--')+2]) if len(sys.argv)>sys.argv.index('--')+2 else 12
bpy.ops.wm.open_mainfile(filepath=str(out/f'pass_{stage:02}.blend'))
s=bpy.context.scene
# Consolidate the static ray geometry per fin for a practical editable source.
if species=='trout':
    for fin in ['Caudal fin','Dorsal fin','Adipose fin','Anal fin','Pectoral -1','Pectoral 1','Pelvic -1','Pelvic 1']:
        rays=[o for o in s.objects if o.name.startswith('Ray | '+fin+' ') and not o.hide_render]
        if not rays:continue
        bpy.ops.object.select_all(action='DESELECT')
        for o in rays:o.select_set(True)
        bpy.context.view_layer.objects.active=rays[0];bpy.ops.object.join();rays[0].name='Rays | '+fin
def components(o):
    parents=list(range(len(o.data.vertices)))
    def root(i):
        while i!=parents[i]:parents[i]=parents[parents[i]];i=parents[i]
        return i
    for e in o.data.edges:
        a,b=map(root,e.vertices)
        if a!=b:parents[b]=a
    counts={}
    for i in range(len(parents)):
        r=root(i);counts[r]=counts.get(r,0)+1
    return sorted(counts.values(),reverse=True)
visible=[o for o in s.objects if o.type=='MESH' and not o.hide_render]
report={'species':species,'checkpoint':stage,'finite_coordinates':True,'visible_meshes':len(visible),'base_triangles':0,'evaluated_triangles':0,'source_art_only':True,'animation_validated':False,'game_exported':False}
deps=bpy.context.evaluated_depsgraph_get()
for o in visible:
    assert all(math.isfinite(c) for v in o.data.vertices for c in v.co),o.name
    report['base_triangles']+=sum(len(p.vertices)-2 for p in o.data.polygons)
    ev=o.evaluated_get(deps);me=ev.to_mesh();report['evaluated_triangles']+=sum(len(p.vertices)-2 for p in me.polygons);ev.to_mesh_clear()
if species=='deer':
    report['continuous_skin_components']=components(bpy.data.objects['Deer continuous anatomy'])
    report['antler_components']={str(sign):components(bpy.data.objects['Buck antler '+str(sign)]) for sign in [-1,1]}
    print('ANTLER COMPONENTS',report['antler_components'],flush=True)
    report['hoof_ground_min_z']={o.name:min((o.matrix_world@v.co).z for v in o.data.vertices) for o in visible if o.name.startswith('Planted split hoof')}
    assert len(report['hoof_ground_min_z'])==8
    assert max(abs(v) for v in report['hoof_ground_min_z'].values())<.0001
    assert len(report['continuous_skin_components'])==1
    assert all(len(v)==1 for v in report['antler_components'].values())
else:
    report['body_components']=components(bpy.data.objects['Trout body'])
    report['fin_inventory']=[o.name for o in visible if 'fin_root' in o]
    assert len(report['fin_inventory'])==8
    assert len(report['body_components'])==1
    body=bpy.data.objects['Trout body'];uv=body.data.uv_layers[0];angles={l.vertex_index:uv.data[l.index].uv.y*math.tau for l in body.data.loops}
    errors=[]
    for v in body.data.vertices:
        if v.co.x>.13:
            t=max(0,min(1,(v.co.x-.13)/.023));a=angles[v.index]
            expected=Vector((v.co.x,math.cos(a)*(.009*(1-t)+.0008*t),math.sin(a)*(.017-.002*t)-.002*(1-t)))
            errors.append((v.co-expected).length)
    report['tail_ring_max_error_m']=max(errors);assert max(errors)<1e-6
# Organize the final editable scene. Source checkpoints retain every intermediate.
groups={}
for name in ['01 | Anatomy','02 | Coat and surface details','03 | Review cameras and lights','90 | Archived source pieces']:
    col=bpy.data.collections.get(name) or bpy.data.collections.new(name)
    if col.name not in s.collection.children:s.collection.children.link(col)
    groups[name]=col
for o in list(s.objects):
    if o.hide_render:key='90 | Archived source pieces'
    elif o.type in {'CAMERA','LIGHT'}:key='03 | Review cameras and lights'
    elif o.name.startswith(('Groom','Ray','Nostril','Seated lip','Iris','Pupil','Eye','Deer iris','Deer pupil')):key='02 | Coat and surface details'
    else:key='01 | Anatomy'
    for c in list(o.users_collection):c.objects.unlink(o)
    groups[key].objects.link(o)
groups['90 | Archived source pieces'].hide_render=True
s.camera=bpy.data.objects['Review three_quarter']
bpy.ops.object.select_all(action='DESELECT')
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.shading.type='MATERIAL';area.spaces.active.region_3d.view_distance=3 if species=='deer' else .65
            area.spaces.active.region_3d.view_location=Vector((0,.15,1.10)) if species=='deer' else Vector((.02,0,0))
bpy.ops.file.pack_all()
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'blender'/f'{species}_convergence_working.blend'))
(out/'final_verification.json').write_text(json.dumps(report,indent=2))
print('VERIFICATION',json.dumps(report))
# Close-ups are diagnostic supplements; four standard cameras remain unchanged.
s.cycles.samples=48;s.render.resolution_x=1200;s.render.resolution_y=1000
target=Vector((0,.70,1.68)) if species=='deer' else Vector((-.128,0,-.002))
loc=Vector((2,4,2.0)) if species=='deer' else Vector((-.4,-1,.15))
d=bpy.data.cameras.new('Detail evidence');d.type='ORTHO';d.ortho_scale=.68 if species=='deer' else .145
cam=bpy.data.objects.new('Detail evidence',d);s.collection.objects.link(cam);cam.location=loc;cam.rotation_euler=(target-loc).to_track_quat('-Z','Y').to_euler();s.camera=cam
s.render.filepath=str(out/f'pass_{stage:02}_head_detail.png');bpy.ops.render.render(write_still=True)
# Reopen the delivered scene and reproduce its side render to verify packaging.
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender'/f'{species}_convergence_working.blend'))
s=bpy.context.scene;s.camera=bpy.data.objects['Review side'];s.render.filepath=str(out/'packaging_side.png');bpy.ops.render.render(write_still=True)
