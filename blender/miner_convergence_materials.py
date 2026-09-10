"""Pass 15: differentiated cloth, leather/wood, and worked metal; structural wear masks."""
import bpy,sys,math
from pathlib import Path
from mathutils import Vector
from mathutils.kdtree import KDTree
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence_structural as s
b=s.b;c=s.c;OUT=s.OUT

PALETTE={
 'linen':((.48,.398,.276),.88,0,(.12,.085,.039),(.66,.565,.397),'cloth'),
 'trouser':((.096,.071,.043),.91,0,(.038,.028,.015),(.205,.153,.080),'cloth'),
 'vest':((.030,.027,.023),.84,0,(.042,.031,.015),(.125,.093,.049),'cloth'),
 'scarf':((.185,.026,.014),.85,0,(.065,.022,.012),(.30,.072,.039),'cloth'),
 'canvas':((.082,.069,.038),.94,0,(.035,.027,.013),(.21,.172,.092),'cloth'),
 'blanket':((.10,.087,.051),.96,0,(.035,.029,.017),(.235,.20,.117),'cloth'),
 'felt':((.061,.038,.019),.93,0,(.027,.018,.009),(.22,.155,.076),'cloth'),
 'leather':((.063,.027,.011),.68,0,(.028,.019,.010),(.225,.126,.050),'leather'),
 'boot':((.041,.023,.013),.71,0,(.063,.043,.021),(.175,.102,.046),'leather'),
 'satchel':((.087,.038,.014),.75,0,(.035,.022,.009),(.25,.144,.061),'leather'),
 'wood':((.145,.068,.025),.72,0,(.042,.023,.011),(.235,.133,.049),'wood'),
 'pan':((.17,.181,.175),.46,1,(.046,.033,.016),(.30,.31,.287),'metal'),
 'canteen':((.23,.245,.235),.40,1,(.042,.032,.021),(.34,.355,.326),'metal'),
 'iron':((.065,.069,.067),.56,.94,(.050,.025,.011),(.20,.21,.20),'metal'),
 'hardware':((.15,.105,.053),.52,.85,(.04,.022,.008),(.30,.224,.12),'metal'),
 'horn':((.082,.043,.018),.6,0,(.025,.018,.009),(.18,.12,.055),'leather')}

def shader(role):
    base,rough,metal,dirtcol,wearcol,kind=PALETTE[role]
    mat=bpy.data.materials.get('FINISH | '+role) or bpy.data.materials.new('FINISH | '+role);mat.use_nodes=True;mat.diffuse_color=(*base,1)
    n=mat.node_tree.nodes;n.clear();l=mat.node_tree.links
    def node(kind,label,x,y):
        o=n.new(kind);o.label=label;o.location=(x,y);return o
    def mathnode(op,a,bb=None):
        o=node('ShaderNodeMath',op,0,-400);o.operation=op
        if isinstance(a,(int,float)):o.inputs[0].default_value=a
        else:l.new(a,o.inputs[0])
        if bb is not None:
            if isinstance(bb,(int,float)):o.inputs[1].default_value=bb
            else:l.new(bb,o.inputs[1])
        return o.outputs[0]
    out=node('ShaderNodeOutputMaterial','Surface',1050,80);p=node('ShaderNodeBsdfPrincipled','Physical material',780,80);l.new(p.outputs['BSDF'],out.inputs['Surface'])
    p.inputs['Roughness'].default_value=rough;p.inputs['Metallic'].default_value=metal;p.inputs['Specular IOR Level'].default_value=.3 if kind=='cloth' else .45
    if kind=='cloth':p.inputs['Sheen Weight'].default_value=.16;p.inputs['Sheen Roughness'].default_value=.8
    coord=node('ShaderNodeAttribute','Rest coordinates / stable under deformation',-1100,-80);coord.attribute_name='rest_position'
    attr=node('ShaderNodeAttribute','Structurally placed dirt and edge abrasion',-1100,350);attr.attribute_name='age_masks'
    split=node('ShaderNodeSeparateColor','R soil / G abrasion',-880,350);l.new(attr.outputs['Color'],split.inputs['Color'])
    macro=node('ShaderNodeTexNoise','Subtle broad fiber/finish variation',-820,80);macro.inputs['Scale'].default_value=20;macro.inputs['Detail'].default_value=3;l.new(coord.outputs['Vector'],macro.inputs['Vector'])
    ramp=node('ShaderNodeValToRGB','Restrained base palette',-550,80);ramp.color_ramp.elements[0].position=.15;ramp.color_ramp.elements[0].color=tuple(x*.70 for x in base)+(1,);ramp.color_ramp.elements[1].position=.85;ramp.color_ramp.elements[1].color=tuple(x*1.17 for x in base)+(1,);l.new(macro.outputs['Fac'],ramp.inputs[0])
    soil=mathnode('MULTIPLY',split.outputs['Red'],mathnode('MULTIPLY_ADD',macro.outputs['Fac'],.8))
    # Macro mask is deliberately limited to vertex-painted contact/wear regions.
    mix=node('ShaderNodeMixRGB','Dust and mud at contact zones',-190,140);mix.blend_type='MIX';l.new(soil,mix.inputs[0]);l.new(ramp.outputs['Color'],mix.inputs[1]);mix.inputs[2].default_value=(*dirtcol,1)
    abrasion=mathnode('MULTIPLY',split.outputs['Green'],mathnode('ADD',.25,mathnode('MULTIPLY',macro.outputs['Fac'],.60)))
    edge=node('ShaderNodeMixRGB','Exposed fiber / worn finish at edges',120,150);l.new(abrasion,edge.inputs[0]);l.new(mix.outputs[0],edge.inputs[1]);edge.inputs[2].default_value=(*wearcol,1);l.new(edge.outputs[0],p.inputs['Base Color'])
    fine=node('ShaderNodeTexNoise','Material-scale surface structure',-790,-230);fine.inputs['Scale'].default_value=650 if kind=='cloth' else 450 if kind=='leather' else 45;fine.inputs['Detail'].default_value=2.5
    vector=coord.outputs['Vector']
    if kind in ['wood','metal']:
        scale=node('ShaderNodeVectorMath','Directional grain / scratches',-1050,-250);scale.operation='MULTIPLY';l.new(vector,scale.inputs[0]);scale.inputs[1].default_value=(9,9,.25) if kind=='wood' else (22,22,.55);vector=scale.outputs['Vector']
    l.new(vector,fine.inputs['Vector'])
    height=fine.outputs['Fac']
    if kind=='cloth':
        w1=node('ShaderNodeTexWave','Warp',-790,-460);w2=node('ShaderNodeTexWave','Weft',-790,-670)
        for w,axis in [(w1,'X'),(w2,'Z')]:w.wave_type='BANDS';w.bands_direction=axis;w.inputs['Scale'].default_value=850;l.new(coord.outputs['Vector'],w.inputs['Vector'])
        height=mathnode('ADD',mathnode('MULTIPLY',fine.outputs['Fac'],.65),mathnode('MULTIPLY',mathnode('MULTIPLY',w1.outputs['Fac'],w2.outputs['Fac']),.35))
    bump=node('ShaderNodeBump','Shallow physical grain',380,-150);bump.inputs['Strength'].default_value=.24 if kind!='metal' else .17;bump.inputs['Distance'].default_value={'cloth':.00024,'leather':.00019,'wood':.00024,'metal':.000085}[kind];l.new(height,bump.inputs['Height']);l.new(bump.outputs['Normal'],p.inputs['Normal'])
    r=mathnode('ADD',rough-.09,mathnode('MULTIPLY',fine.outputs['Fac'],.18));r=mathnode('MAXIMUM',r,mathnode('MULTIPLY',soil,.96));l.new(r,p.inputs['Roughness'])
    if metal:l.new(mathnode('MULTIPLY',metal,mathnode('SUBTRACT',1,mathnode('MULTIPLY',soil,.85))),p.inputs['Metallic'])
    mat['material_intent']='Reference-driven '+kind+'; stable rest-coordinate grain and structurally placed dirt/abrasion masks. Bake for game export.'
    return mat

def role_for(o):
    name=o.name;groups=[g.name for g in o.users_collection];idx=o.get('source_component',-1)
    if idx==71:return 'felt'
    if idx==72:return 'leather'
    if name.startswith(('Gold pan |',)):return 'pan'
    if name.startswith('Canteen |'):return 'leather' if 'hanger' in name else 'canteen'
    if name.startswith('Pickaxe |'):return 'wood' if 'shaft' in name else 'iron'
    if any(word in name.lower() for word in ['buckle','closure frame','adjuster','adjustment']) and any('GEAR' in g or 'boots' in g or 'belt' in g for g in groups):return 'hardware'
    if 'GEAR | satchel' in groups:return 'satchel'
    if 'GEAR | backpack' in groups:return 'leather' if any(t in name for t in ['harness','closure']) else 'canvas'
    if 'GEAR | bedroll' in groups:return 'leather' if 'binding' in name else 'blanket'
    if 'COSTUME | boots' in groups:return 'boot'
    if 'COSTUME | trousers' in groups:return 'trouser'
    if name.startswith('Neckerchief |'):return 'scarf'
    if name.startswith('Vest |'):return 'vest'
    if idx in range(44,48):return 'horn'
    if 'COSTUME | shirt' in groups:return 'linen'
    if any('COSTUME | belt' in g for g in groups):return 'leather'
    return None

def attributes(o,role):
    coords=o.data.attributes.get('rest_position') or o.data.attributes.new(name='rest_position',type='FLOAT_VECTOR',domain='POINT')
    masks=o.data.color_attributes.get('age_masks') or o.data.color_attributes.new(name='age_masks',type='FLOAT_COLOR',domain='POINT')
    counts={}
    for p in o.data.polygons:
        ids=list(p.vertices)
        for a,bb in zip(ids,ids[1:]+ids[:1]):key=tuple(sorted((a,bb)));counts[key]=counts.get(key,0)+1
    boundary={i for e,n in counts.items() if n==1 for i in e};kd=None
    if boundary:
        kd=KDTree(len(boundary))
        for i in boundary:kd.insert(o.data.vertices[i].co,i)
        kd.balance()
    zs=[v.co.z for v in o.data.vertices];lo=min(zs);hi=max(zs);height=max(.001,hi-lo)
    def g(z,center,w):return math.exp(-((z-center)/w)**2)
    for v in o.data.vertices:
        p=v.co;x,y,z=p;coords.data[v.index].vector=p
        edge=math.exp(-kd.find(p)[2]/.004) if kd else 0
        dirt=.07;wear=.12+edge*.40
        if role=='linen':dirt=.07+.35*g(z,1.115,.042)+.24*g(z,1.05,.036)+.12*g(z,1.44,.03);wear=.10+edge*.35
        elif role=='trouser':dirt=.12+.55*g(z,.40,.08)+.28*g(z,.625,.07)*max(0,-y/.10);wear=.10+.22*g(z,.63,.10)+.17*g(z,.40,.06)+edge*.45
        elif role=='vest':dirt=.10+.30*g(z,1.09,.05)+.16*g(z,1.43,.04);wear=.10+edge*.65
        elif role=='scarf':dirt=.10+.20*max(0,(1.45-z)/.16);wear=.08+edge*.35
        elif role=='boot':dirt=.10+.72*math.exp(-max(0,z-.035)/.075);wear=.12+.28*max(0,min(1,(-y-.08)/.13))+edge*.42
        elif role=='canvas':dirt=.13+.44*math.exp(-max(0,z-1.0)/.10);wear=.14+edge*.60
        elif role=='blanket':dirt=.12+.16*max(0,(.22-y)/.09);wear=.16+edge*.48
        elif role=='felt':
            radius=math.sqrt((x/.204)**2+(y/.192)**2);dirt=.12+.30*g(z,1.675,.018);wear=.12+.50*max(0,min(1,(radius-.77)/.23))
        elif role in ['satchel','leather']:
            dirt=.12+(.35*math.exp(-max(0,z-lo)/(height*.22)) if role=='satchel' else .05);wear=.14+edge*.66
        elif role=='wood':dirt=.10+.50*math.exp(-max(0,z-lo)/(height*.12));wear=.18+.15*g(z,hi-.065,.06)
        elif role in ['pan','canteen','iron','hardware']:dirt=.14+.20*math.exp(-max(0,z-lo)/(height*.15));wear=.22+edge*.4
        masks.data[v.index].color=(min(.95,dirt),min(.85,wear),.5,1)

def run():
    s.load_previous(15);materials={role:shader(role) for role in PALETTE}
    for o in bpy.context.scene.objects:
        if o.type!='MESH' or o.hide_render or any(g.hide_render for g in o.users_collection):continue
        role=role_for(o)
        if not role:continue
        attributes(o,role);b.assign(o,materials[role]);o['surface_role']=role
    s.finish(15)

if __name__=='__main__':run()
