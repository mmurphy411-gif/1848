"""Bounded mouth and dorsal projection repair, preserving the first candidate."""
import ast
import hashlib
import json
import math
from pathlib import Path
import bpy
import numpy as np

OUT=Path(__file__).resolve().parent
PREVIOUS=OUT.parent
ROOT=PREVIOUS.parents[1]
# Reuse earlier read-only inspection/render helpers without executing that run.
source=PREVIOUS/'run.py'
tree=ast.parse(source.read_text())
definitions=[n for n in tree.body if isinstance(n,(ast.Import,ast.ImportFrom,ast.FunctionDef))]
helpers={'__file__':str(source),'__name__':'surface_helpers'}
exec(compile(ast.Module(body=definitions,type_ignores=[]),str(source),'exec'),helpers)
helpers['OUT']=OUT

SOURCE=PREVIOUS/'trout_surface_candidate.blend'
HERO=next((ROOT/'characters/rainbow trout').glob('*(1).png'))
DORSAL=next((ROOT/'characters/rainbow trout').glob('*(2).png'))

def checksum(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def protected():
    snap=helpers['snapshot']()
    # All earlier UV layers, including the original projection, must survive.
    for o in bpy.context.scene.objects:
        if o.type=='MESH':
            snap[o.name]['existing_uvs']={u.name:helpers['digest']([list(v.uv) for v in u.data])
                for u in o.data.uv_layers if not u.name.startswith('Surface2 ')}
            snap[o.name]['old_colors']={a.name:helpers['digest']([list(v.color) for v in a.data])
                for a in o.data.color_attributes if not a.name.startswith('Surface2 ')}
    return snap

def smooth(a,b,x):
    t=max(0,min(1,(x-a)/(b-a)));return t*t*(3-2*t)
def interp(x,points):return float(np.interp(x,[p[0] for p in points],[p[1] for p in points]))

def uv_layer(o,name,coords,w,h):
    uv=o.data.uv_layers.new(name=name)
    for loop in o.data.loops:
        x,y=coords[loop.vertex_index];uv.data[loop.index].uv=(x/w,1-y/h)

def image_node(mat,image,uvname):
    n=mat.node_tree.nodes;l=mat.node_tree.links
    uv=n.new('ShaderNodeUVMap');uv.uv_map=uvname
    tex=n.new('ShaderNodeTexImage');tex.image=image;tex.extension='EXTEND'
    l.new(uv.outputs['UV'],tex.inputs['Vector']);return tex.outputs['Color']

def blend(mat,a,b,factor):
    node=mat.node_tree.nodes.new('ShaderNodeMixRGB');node.blend_type='MIX'
    links=mat.node_tree.links
    if isinstance(factor,(float,int)):node.inputs[0].default_value=factor
    else:links.new(factor,node.inputs[0])
    for i,value in enumerate([a,b],1):
        if isinstance(value,tuple):node.inputs[i].default_value=value
        else:links.new(value,node.inputs[i])
    return node.outputs['Color']

def repair():
    hero=bpy.data.images.load(str(HERO),check_existing=True);hero.pack()
    top=bpy.data.images.load(str(DORSAL),check_existing=True);top.pack()
    body=bpy.data.objects['Trout body'];groups={}
    for v in body.data.vertices:groups.setdefault(round(v.co.x,6),[]).append(v.co)
    rings=sorted((x,min(v.z for v in vs),max(v.z for v in vs),max(abs(v.y) for v in vs)) for x,vs in groups.items())
    targets=['Trout body','Seated opercular edge -1','Seated opercular edge 1']
    for name in targets:
        o=bpy.data.objects[name];coat_uv=[];clean_uv=[];masks=[]
        for v in o.data.vertices:
            x,y,z=o.matrix_world@v.co
            lo=interp(x,[(r[0],r[1]) for r in rings]);hi=interp(x,[(r[0],r[2]) for r in rings])
            half=interp(x,[(r[0],r[3]) for r in rings])
            q=max(0,min(1,(z-lo)/max(hi-lo,.001)));yn=max(-1,min(1,y/max(half,.001)))
            # The clean strip beside the illustrated median fins avoids reprojecting
            # them onto the body. It also avoids the source's contradictory tail.
            py=interp(x,[(-.18,321),(-.13,350),(-.10,369),(-.05,390),(0,413),(.05,441),(.10,466),(.153,488)])
            left=interp(py,[(321,965),(350,948),(370,943),(390,940),(413,944),(441,950),(466,959),(488,966)])
            right=interp(py,[(321,970),(350,967),(370,970),(390,970),(413,967),(441,967),(466,970),(488,973)])
            # The literal top-view strip was too low-resolution and included pale
            # flank color. Use the hero's sharp upper-flank spots with a planar
            # transverse mapping; the top view remains anatomy/palette evidence.
            px=interp(x,[(-.18,40),(-.148,112),(-.127,200),(-.108,269),
                        (-.05,455),(0,598),(.05,746),( .095,842),(.13,893),(.153,922)])
            upper=interp(px,[(40,681),(112,638),(200,601),(269,582),(350,566),
                            (455,560),(598,579),(746,609),(842,637),(893,643),(922,629)])
            lower=interp(px,[(40,727),(112,773),(200,787),(269,791),(350,815),
                            (455,821),(598,806),(746,776),(842,745),(893,742),(922,754)])
            py=upper+(lower-upper)*(.045+(.5+.5*yn)*.29)
            coat_uv.append((px,py))
            # Distinct sampled texture layers blend by color rather than moving UVs
            # through unrelated picture regions, which caused the first throat smear.
            clean_uv.append((420+max(0,min(1,(x+.18)/.13))*85,784+q*23+yn*3))
            top_mask=smooth(.66,.90,q)*smooth(-.155,-.125,x)
            mouth_mask=(1-smooth(-.149,-.130,x))*(1-smooth(.003,.012,z))
            throat_mask=(1-smooth(.14,.32,q))*(1-smooth(-.075,-.045,x))
            masks.append((top_mask,mouth_mask,throat_mask,1))
        uv_layer(o,'Surface2 dorsal',coat_uv,1086,1448)
        uv_layer(o,'Surface2 clean',clean_uv,1086,1448)
        attr=o.data.color_attributes.new(name='Surface2 masks',type='FLOAT_COLOR',domain='POINT')
        for i,color in enumerate(masks):attr.data[i].color=color
        mat=o.data.materials[0].copy();mat.name='Surface2 | '+name
        o.data.materials[0]=mat;n=mat.node_tree.nodes;l=mat.node_tree.links;p=n.get('Principled BSDF')
        original=p.inputs['Base Color'].links[0].from_socket
        attributes=n.new('ShaderNodeVertexColor');attributes.layer_name='Surface2 masks'
        channels=n.new('ShaderNodeSeparateColor');channels.mode='RGB';l.new(attributes.outputs['Color'],channels.inputs['Color'])
        # Two image projections failed on the curved crown. This bounded fallback
        # defines spot size in metres, independent of a drawing's perspective.
        position=n.new('ShaderNodeNewGeometry')
        spots=n.new('ShaderNodeTexVoronoi');spots.distance='EUCLIDEAN'
        spots.inputs['Scale'].default_value=310;spots.inputs['Randomness'].default_value=.94
        l.new(position.outputs['Position'],spots.inputs['Vector'])
        ramp=n.new('ShaderNodeValToRGB');ramp.color_ramp.interpolation='EASE'
        ramp.color_ramp.elements[0].position=.23;ramp.color_ramp.elements[0].color=(.007,.011,.006,1)
        ramp.color_ramp.elements[1].position=.36;ramp.color_ramp.elements[1].color=(.125,.145,.079,1)
        l.new(spots.outputs['Distance'],ramp.inputs['Fac'])
        dorsal_color=ramp.outputs['Color']
        belly=image_node(mat,hero,'Surface2 clean')
        clean_mouth=blend(mat,belly,(.48,.49,.39,1),.70)
        color=blend(mat,original,dorsal_color,channels.outputs['Red'])
        clean_throat=blend(mat,belly,(.52,.51,.43,1),.82)
        color=blend(mat,color,clean_throat,channels.outputs['Blue'])
        color=blend(mat,color,clean_mouth,channels.outputs['Green'])
        l.new(color,p.inputs['Base Color'])
    # Lip/jaw meshes already establish the mouth contour. Give them a coherent
    # tissue material instead of projecting a second illustrated mouth onto them.
    lip=bpy.data.materials.new('Surface2 | lip tissue');lip.use_nodes=True
    p=lip.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.48,.46,.36,1)
    p.inputs['Roughness'].default_value=.50;p.inputs['Coat Weight'].default_value=.10
    for name in ['Lower jaw','Upper lip -1','Upper lip 1','Lower lip -1','Lower lip 1']:
        o=bpy.data.objects[name];o.data.materials.clear();o.data.materials.append(lip)
    bpy.context.scene['surface_test']='Retained refinement: spatial crown spots blended with projected flanks; independent mouth/throat masks.'

bpy.ops.wm.open_mainfile(filepath=str(SOURCE))
hashes={str(p):checksum(p) for p in [SOURCE,HERO,DORSAL,ROOT/'blender/trout_convergence_working.blend']}
before=protected()
repair()
assert before==protected(),'Protected scene data changed'
candidate=OUT/'trout_surface_refined.blend'
bpy.context.scene.camera=bpy.data.objects['Review three_quarter']
bpy.ops.wm.save_as_mainfile(filepath=str(candidate))
helpers['configure_render']()
helpers['render_set']('refined')
bpy.ops.wm.open_mainfile(filepath=str(candidate))
assert before==protected(),'Saved scene failed preservation check'
assert all(checksum(Path(p))==h for p,h in hashes.items())
(OUT/'audit.json').write_text(json.dumps({'protected_scene_unchanged':True,'saved_scene_reopened':True,
    'input_sha256':hashes,'new_candidate_count':3,'new_render_count':15,
    'scope':'Mouth/throat and dorsal projection only; no geometry edits; fins and eyes unchanged.',
    'limitations':['Two dorsal image projections rejected. Retained crown uses spatial procedural spots and selected olive colors.',
                   'Geometry and painted lighting remain imperfect; not a live game integration.']},indent=2))
print('REFINEMENT VERIFIED',flush=True)
