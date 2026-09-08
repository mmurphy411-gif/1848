"""Six seamless PBR sets, authored in shader nodes and baked in Cycles at 2048."""
import sys, math, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
start=time.perf_counter(); reset()
bpy.ops.mesh.primitive_plane_add(size=2)
plane=bpy.context.object
scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=1
scene.render.bake.margin=0
scene.view_settings.view_transform='Standard'
try:
    prefs=bpy.context.preferences.addons['cycles'].preferences
    prefs.compute_device_type='OPTIX'; prefs.get_devices()
    for device in prefs.devices: device.use=device.type!='CPU'
    scene.cycles.device='GPU'
except Exception: scene.cycles.device='CPU'
outdir=ASSETS/'textures'; outdir.mkdir(parents=True,exist_ok=True)

def graph(name):
    m=material(name,(.4,.4,.4)); n=m.node_tree.nodes; l=m.node_tree.links
    def node(kind, **kw):
        o=n.new(kind)
        for k,v in kw.items(): setattr(o,k,v)
        return o
    def mathop(op,a,b=None):
        o=node('ShaderNodeMath',operation=op)
        for index,value in enumerate([a,b]):
            if value is None: continue
            if isinstance(value,(int,float)): o.inputs[index].default_value=value
            else: l.new(value,o.inputs[index])
        return o.outputs[0]
    def ramp(value, entries):
        o=node('ShaderNodeValToRGB'); r=o.color_ramp
        while len(r.elements)>2: r.elements.remove(r.elements[-1])
        for i,(pos,color) in enumerate(entries):
            e=r.elements[i] if i<2 else r.elements.new(pos)
            e.position=pos; e.color=(*color,1)
        l.new(value,o.inputs[0]); return o.outputs[0]
    # Embed UV on a 4-D torus: both value and derivative wrap exactly.
    uv=node('ShaderNodeTexCoord'); sep=node('ShaderNodeSeparateXYZ'); l.new(uv.outputs['UV'],sep.inputs[0])
    u=mathop('MULTIPLY',sep.outputs['X'],math.tau); v=mathop('MULTIPLY',sep.outputs['Y'],math.tau)
    coords=node('ShaderNodeCombineXYZ')
    for axis,val in zip('XYZ',[mathop('SINE',u),mathop('COSINE',u),mathop('SINE',v)]): l.new(val,coords.inputs[axis])
    w=mathop('COSINE',v)
    def noise(scale, voronoi=False, feature='F1'):
        o=node('ShaderNodeTexVoronoi' if voronoi else 'ShaderNodeTexNoise')
        if voronoi: o.voronoi_dimensions='4D'; o.feature=feature
        else: o.noise_dimensions='4D'; o.inputs['Detail'].default_value=3
        o.inputs['Scale'].default_value=scale
        l.new(coords.outputs[0],o.inputs['Vector']); l.new(w,o.inputs['W'])
        return o
    fine=noise(90).outputs['Fac']; macro=noise(1.5).outputs['Fac']
    if name in ['gravel','talus']:
        cells=noise(4 if name=='gravel' else 8,True)
        distance=cells.outputs['Distance']; random=cells.outputs['Color']
        edge=noise(4 if name=='gravel' else 8,True,feature='DISTANCE_TO_EDGE').outputs['Distance']
        height=ramp(edge,[(.005,(.015,)*3),(.035,(.28,)*3),(.13,(.64,)*3),(.32,(.78,)*3)])
        coverage=ramp(edge,[(.006,(0,)*3),(.024,(1,)*3)])
        if name=='gravel':
            second=noise(4,True,feature='F2').outputs['Distance']
            roundness=mathop('DIVIDE',distance,second)
            dome=ramp(distance,[(.0,(1,)*3),(.35,(.86,)*3),(.7,(.3,)*3),(.92,(.02,)*3)])
            rim=ramp(roundness,[(.65,(1,)*3),(.88,(0,)*3)])
            height=mathop('MULTIPLY',dome,rim)
            coverage=ramp(roundness,[(.78,(1,)*3),(.88,(0,)*3)])
        stone=ramp(random,[(.08,(.10,.12,.12)),(.34,(.28,.25,.20)),(.52,(.46,.43,.37)),(.76,(.62,.60,.54)),(.95,(.24,.28,.28))])
        grain=node('ShaderNodeMixRGB',blend_type='MULTIPLY'); grain.inputs[0].default_value=.3; l.new(stone,grain.inputs[1]); l.new(fine,grain.inputs[2])
        mix=node('ShaderNodeMixRGB',blend_type='MIX'); l.new(coverage,mix.inputs[0]); mix.inputs[1].default_value=(.12,.10,.07,1); l.new(grain.outputs[0],mix.inputs[2]); albedo=mix.outputs[0]
        if name=='talus': height=mathop('MULTIPLY',height,mathop('ADD',.7,mathop('MULTIPLY',fine,.3)))
        rough=.92 if name=='gravel' else .94; strength=.09 if name=='gravel' else .12
    elif name=='granite':
        crystal=noise(55,True).outputs['Color']
        albedo=ramp(crystal,[(.15,(.12,.14,.14)),(.37,(.30,.31,.30)),(.52,(.56,.52,.48)),(.72,(.72,.72,.67)),(.90,(.35,.37,.37))])
        lichen=ramp(macro,[(.56,(0,0,0)),(.7,(1,1,1))])
        mix=node('ShaderNodeMixRGB'); l.new(lichen,mix.inputs[0]); l.new(albedo,mix.inputs[1]); mix.inputs[2].default_value=(.25,.27,.10,1); albedo=mix.outputs[0]
        cracks=noise(.5,True,feature='DISTANCE_TO_EDGE').outputs['Distance']
        fissure=ramp(cracks,[(0,(.55,)*3),(.015,(1,)*3)])
        mix=node('ShaderNodeMixRGB',blend_type='MULTIPLY'); mix.inputs[0].default_value=1; l.new(albedo,mix.inputs[1]); l.new(fissure,mix.inputs[2]); albedo=mix.outputs[0]
        height=mathop('MULTIPLY',fine,fissure); rough=.85; strength=.003
    elif name=='sand':
        warp=mathop('ADD',mathop('MULTIPLY',macro,18),mathop('MULTIPLY',noise(3).outputs['Fac'],6))
        ripple=mathop('SINE',mathop('ADD',mathop('MULTIPLY',v,18),warp))
        albedo=ramp(mathop('ADD',mathop('MULTIPLY',fine,.8),mathop('MULTIPLY',ripple,.12)),[(.1,(.22,.18,.12)),(.5,(.47,.40,.28)),(.9,(.62,.55,.4))])
        height=mathop('ADD',fine,mathop('MULTIPLY',ripple,.2)); rough=.9; strength=.0005
    elif name=='duff':
        streak=node('ShaderNodeTexWave'); streak.wave_type='BANDS'; streak.bands_direction='X'; streak.inputs['Scale'].default_value=45; streak.inputs['Distortion'].default_value=12; l.new(coords.outputs[0],streak.inputs['Vector'])
        height=mathop('MULTIPLY',streak.outputs['Fac'],noise(12).outputs['Fac'])
        albedo=ramp(height,[(.1,(.025,.018,.012)),(.3,(.1,.055,.025)),(.65,(.27,.15,.055)),(.9,(.4,.27,.1))]); rough=.98; strength=.025
    else:
        veins=noise(5,True,feature='DISTANCE_TO_EDGE').outputs['Distance']
        albedo=ramp(veins,[(0,(.62,.64,.58)),(.035,(.27,.32,.29)),(.07,(.11,.15,.14)),(.3,(.16,.20,.18))])
        height=mathop('MULTIPLY',fine,.3); rough=.6; strength=.016
    p=n.get('Principled BSDF'); l.new(albedo,p.inputs['Base Color']); p.inputs['Roughness'].default_value=rough
    bump=node('ShaderNodeBump'); bump.inputs['Distance'].default_value=strength; l.new(height,bump.inputs['Height']); l.new(bump.outputs[0],p.inputs['Normal'])
    emit=node('ShaderNodeEmission'); output=n.get('Material Output')
    orm=node('ShaderNodeCombineColor'); orm.inputs[0].default_value=.85; orm.inputs[1].default_value=rough; orm.inputs[2].default_value=0
    target=node('ShaderNodeTexImage'); n.active=target
    plane.data.materials.clear(); plane.data.materials.append(m)
    for suffix,source in [('albedo',albedo),('normal',None),('orm',orm.outputs[0])]:
        size=2048 if name in ['gravel','granite'] else 1024
        image=bpy.data.images.new(name+'_'+suffix,width=size,height=size,alpha=False)
        image.colorspace_settings.name='sRGB' if suffix=='albedo' else 'Non-Color'
        target.image=image; n.active=target
        if source:
            l.new(source,emit.inputs[0]); l.new(emit.outputs[0],output.inputs['Surface'])
        else: l.new(p.outputs[0],output.inputs['Surface'])
        bpy.ops.object.bake(type='EMIT' if source else 'NORMAL')
        image.filepath_raw=str(outdir/(name+'_'+suffix+'.png')); image.file_format='PNG'; image.save()
        if suffix=='orm':
            # All six dielectrics use constant roughness; grayscale R8 stores it.
            from png_helpers import png
            import numpy as np
            png(outdir/(name+'_'+suffix+'.png'),np.full((size,size),round(rough*255),dtype=np.uint8))
    l.new(p.outputs[0],output.inputs['Surface'])

for name in ['granite','talus','sand','duff','bedrock']:
    graph(name)
from build_gravel import build_gravel
build_gravel(outdir)
save('build_textures')
print('TEXTURES_SECONDS',round(time.perf_counter()-start,2))
