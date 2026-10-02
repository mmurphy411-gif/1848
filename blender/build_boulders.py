"""Eight rounded jointed granite forms and three small river cobbles (legacy domes).

Superseded in visual-upgrade Stage 3: assets/boulders/ now holds normalised CC0 scans built by
tools/art/intake_rocks.py. This script would overwrite boulder_01..08 and cobble_01..03 with the
old domes, so it only runs with `-- --legacy` (build_boulders.blend keeps the old forms inspectable)."""
import sys, random, math, time
if '--legacy' not in sys.argv:
    print('build_boulders.py: superseded by tools/art/intake_rocks.py; pass -- --legacy to rebuild the old domes')
    sys.exit(0)
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
from mathutils import noise
start=time.perf_counter(); reset()
noise.seed_set(1848)
granite=material('Granite placeholder',(.5,.5,.48))
for i in range(11):
    rng=random.Random(1848+i)
    # Icosphere level 2 then two Catmull-Clark levels, decimated to the budget.
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2 if i<8 else 1,radius=1)
    obj=bpy.context.object; obj.name='boulder_%02d'%(i+1) if i<8 else 'cobble_%02d'%(i-7)
    sub=obj.modifiers.new('Two levels of water wear','SUBSURF'); sub.levels=2
    bpy.context.view_layer.objects.active=obj; bpy.ops.object.modifier_apply(modifier=sub.name)
    shift=Vector((rng.random()*20,rng.random()*20,rng.random()*20))
    for v in obj.data.vertices:
        p=v.co.copy(); n=noise.noise_vector(p*1.8+shift)
        v.co*=1+.13*n.x+.055*noise.noise(p*5+shift)
        v.co.x=min(v.co.x,.82+rng.random()*.005)
        v.co.y=max(v.co.y,-.83)
        v.co.z=max(v.co.z,-.66)
    dec=obj.modifiers.new('Export budget','DECIMATE'); dec.ratio=(2200 if i<8 else 160)/sum(len(p.vertices)-2 for p in obj.data.polygons)
    bpy.ops.object.modifier_apply(modifier=dec.name)
    # Unit horizontal radius and +/-1 vertical extent; placement scales to Layout.
    radius=max(math.hypot(v.co.x,v.co.y) for v in obj.data.vertices)
    lo=min(v.co.z for v in obj.data.vertices); hi=max(v.co.z for v in obj.data.vertices)
    for v in obj.data.vertices:
        v.co.x/=radius; v.co.y/=radius; v.co.z=(v.co.z-lo)/(hi-lo)*2-1
    color=obj.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
    for v in obj.data.vertices:
        polished=v.co.z<-.25
        lichen=v.co.z>.25 and noise.noise(v.co*3+shift)>.35
        color.data[v.index].color=(.63,.70,.70,1) if polished else ((.66,.72,.4,1) if lichen else (1,1,1,1))
    for p in obj.data.polygons: p.use_smooth=True
    obj.data.materials.append(granite)
    bpy.ops.object.shade_smooth()
    export(obj,'boulders/'+obj.name+'.glb')
    obj.location.x=i*3
save('build_boulders'); print('BOULDERS_SECONDS',time.perf_counter()-start)
