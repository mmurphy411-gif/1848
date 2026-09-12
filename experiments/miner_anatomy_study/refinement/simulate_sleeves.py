"""Drape tailored sleeve tubes over static arm forms, then save rest-space surfaces."""
import bpy,math,json,random
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
bpy.ops.wm.read_factory_settings(use_empty=True)
scene=bpy.context.scene;scene.gravity=(0,0,-9.81);scene.render.fps=24
rows=43;n=56;objects=[];rng=random.Random(1848)
def rings(nrows,n):return [(j*n+k,j*n+(k+1)%n,(j+1)*n+(k+1)%n,(j+1)*n+k) for j in range(nrows-1) for k in range(n)]
def mesh(name,vs,fs):
    d=bpy.data.meshes.new(name);d.from_pydata(vs,[],fs);d.update();o=bpy.data.objects.new(name,d);scene.collection.objects.link(o);return o
for side in [-1,1]:
    start=Vector((side*.205,0,1.419));end=Vector((side*.347,0,1.099));axis=(end-start).normalized();across=Vector((side,0,0));across=(across-axis*across.dot(axis)).normalized();depth=Vector((0,1,0))
    vs=[];cv=[]
    for j in range(rows):
        t=j/(rows-1);center=start.lerp(end,t)
        radius=.065+.018*math.sin(t*math.pi)-.007*t
        arm=.052-.005*t
        for k in range(n):
            a=k*math.tau/n;d=across*math.cos(a)+depth*math.sin(a)
            radial=radius+.0013*math.sin(a*7+t*9+side)*math.sin(t*math.pi)
            vs.append(center+d*radial)
            cv.append(center+d*arm)
    col=mesh('arm_form_'+str(side),cv,rings(rows,n)+[tuple(range(n-1,-1,-1)),tuple((rows-1)*n+k for k in range(n))]);col.modifiers.new('Arm collision','COLLISION');col.collision.thickness_outer=.0015;col.collision.cloth_friction=8
    o=mesh('sleeve_'+str(side),vs,rings(rows,n));pin=o.vertex_groups.new(name='sewn_ends')
    for j in range(rows):
        t=j/(rows-1);w=1 if j in [0,1,rows-1,rows-2] else .6 if j in [2,rows-3] else 0
        if w:pin.add(list(range(j*n,(j+1)*n)),w,'REPLACE')
    cloth=o.modifiers.new('Gravity drape','CLOTH');s=cloth.settings;s.quality=9;s.mass=.12;s.air_damping=2;s.tension_stiffness=18;s.compression_stiffness=12;s.shear_stiffness=8;s.bending_stiffness=.13;s.vertex_group_mass='sewn_ends';s.pin_stiffness=1
    cloth.collision_settings.use_collision=True;cloth.collision_settings.distance_min=.0015;cloth.collision_settings.collision_quality=4;cloth.collision_settings.use_self_collision=True;cloth.collision_settings.self_distance_min=.0015
    cloth.point_cache.frame_start=1;cloth.point_cache.frame_end=64;objects.append((side,o))
for frame in range(1,65):
    scene.frame_set(frame);bpy.context.view_layer.update()
    for side,o in objects:
        ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());temp=ev.to_mesh();ev.to_mesh_clear()
    if frame%16==0:print('DRAPE_FRAME',frame,flush=True)
result={'frames':64,'rows':rows,'sides':n,'method':'Pinned shoulder and rolled-cuff boundaries; gravity drape with arm-form and self collision. Frozen as rest geometry, not runtime simulation.','sleeves':{}}
for side,o in objects:
    ev=o.evaluated_get(bpy.context.evaluated_depsgraph_get());d=ev.to_mesh();coords=[list(v.co) for v in d.vertices];ev.to_mesh_clear()
    assert all(math.isfinite(x) for p in coords for x in p)
    result['sleeves'][str(side)]={'vertices':coords,'faces':rings(rows,n)}
(OUT/'sleeve_drape.json').write_text(json.dumps(result))
print('DRAPE_SAVED',flush=True)
