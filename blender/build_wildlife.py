"""Five local wildlife species. Meter-scale, articulated parts, original geometry.
Blender +Y is the animal's forward direction (Godot -Z). No external textures.
Run: blender --background --python blender/build_wildlife.py
"""
import sys, math, random
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent))
import bpy
from mathutils import Vector
from common import reset, material, mesh_object, save, ASSETS

rng = random.Random(184812)
parts = []

def ell(name, p, scale, mat, tilt=0, detail=20):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=detail, ring_count=10 if detail>=20 else 6, location=p)
    o=bpy.context.object; o.name=name; o.scale=scale; o.rotation_euler.x=tilt
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    for f in o.data.polygons: f.use_smooth=True
    parts.append(o)
    return o

def segment(name, a, b, ra, rb, mat, sides=12):
    a,b=Vector(a),Vector(b); d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=sides, radius1=ra, radius2=rb, depth=d.length, location=(a+b)/2)
    o=bpy.context.object; o.name=name; o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
    o.data.materials.append(mat)
    for f in o.data.polygons: f.use_smooth=True
    parts.append(o); return o

def group(name, objects, pivot, organic=False, voxel=.025):
    bpy.ops.object.select_all(action='DESELECT')
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.object.join(); o=bpy.context.object; o.name=name
    if organic:
        m=o.modifiers.new('Continuous anatomy','REMESH'); m.mode='VOXEL';m.voxel_size=voxel
        bpy.ops.object.modifier_apply(modifier=m.name)
        m=o.modifiers.new('Relax skin','SMOOTH');m.factor=1.25;m.iterations=4
        bpy.ops.object.modifier_apply(modifier=m.name)
        m=o.modifiers.new('Game surface','DECIMATE');m.ratio=.42
        bpy.ops.object.modifier_apply(modifier=m.name)
    bpy.context.scene.cursor.location=pivot
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    for f in o.data.polygons: f.use_smooth=True
    return o

def parent(o, p):
    bpy.context.view_layer.update()
    matrix=o.matrix_world.copy();o.parent=p;o.matrix_world=matrix

def eyes(head, y, z, x, radius):
    for sign in [-1,1]:
        o=ell('Eye', (sign*x,y,z),(radius*.65,radius,radius), eye)
        parent(o,head)
        # Tiny wet tear duct, no cartoon whites or painted catchlights.
        o=ell('Tear', (sign*(x+.001),y+radius*.6,z-radius*.25),(radius*.42,radius*.48,radius*.42), nose)
        parent(o,head)

def ear(head, p, width, length, coat, inside, angle=0):
    start=len(parts)
    ell('Pinna',p,(width,.032,length),coat,angle)
    ell('Inner ear',(p[0],p[1]+.024,p[2]),(width*.70,.013,length*.75),inside,angle)
    o=group('Ear',parts[start:],(p[0],p[1],p[2]-length*.7))
    parent(o,head)

def fur(o, count, length, coat):
    """Sparse tapered guard hairs break the silhouette; the shader supplies underfur.
    Area-weighted deterministic sampling avoids rings of uniformly spaced spikes.
    """
    bpy.context.view_layer.update();o.data.calc_loop_triangles()
    tris=list(o.data.loop_triangles)
    weights=[t.area for t in tris]
    vertices=[];faces=[];colors=[];normals=[]
    for tri in rng.choices(tris,weights=weights,k=count):
        a,b,c=[o.matrix_world@o.data.vertices[i].co for i in tri.vertices]
        u,v=rng.random(),rng.random()
        if u+v>1: u=1-u;v=1-v
        p=a+(b-a)*u+(c-a)*v
        n=(b-a).cross(c-a).normalized()
        side=n.cross(Vector((0,0,1)))
        if side.length<.1: side=n.cross(Vector((1,0,0)))
        side.normalize()
        groom=Vector((0,-.55,-.45));groom-=n*groom.dot(n)
        tip=(n*.55+groom*.65).normalized()
        size=length*rng.uniform(.55,1.4)
        start=len(vertices)
        vertices += [p-side*size*.025,p+side*size*.025,p+tip*size]
        faces.append((start,start+1,start+2))
        tone=rng.uniform(.85,1.08)
        colors += [(tone,tone,tone,1)]*3
        normals += [n]*3
    hairs=mesh_object('Guard hairs',vertices,faces,colors=colors,materials=[coat])
    hairs.data.normals_split_custom_set_from_vertices(normals)
    parent(hairs,o)

def leg(name, hip, knee, ankle, foot_y, thickness, coat, hoof, foot_length):
    start=len(parts)
    segment('Upper',hip,knee,thickness,thickness*.60,coat)
    ell('Muscle',Vector(hip).lerp(Vector(knee),.35),(thickness,thickness*1.3,(Vector(hip)-Vector(knee)).length*.52),coat)
    upper=group(name,parts[start:],hip,True,max(.009,thickness*.20))
    start=len(parts)
    stocky=thickness>.12
    segment('Shin',knee,ankle,thickness*(.85 if stocky else .56),thickness*(.65 if stocky else .30),coat)
    ell('Joint',knee,(thickness*.60,thickness*.60,thickness*.60),coat)
    ell('Foot',(ankle[0],foot_y,ankle[2]*.5),(thickness*(.85 if stocky else .53),foot_length,ankle[2]*.65),coat if stocky else hoof)
    lower=group(name+'Lower',parts[start:],knee,stocky,.013)
    parent(lower,upper)
    return upper

def feather(name, a,b,width,mat):
    a,b=Vector(a),Vector(b)
    o=ell(name,(a+b)/2,(width,(b-a).length*.56,width*.21),mat,detail=12)
    o.rotation_euler=(b-a).to_track_quat('Y','Z').to_euler()
    return o

def mammal(species):
    global parts
    reset();parts=[]
    bear=species=='bear';deer=species=='deer'
    coat=material('Coat',(.052,.039,.029) if bear else (.28,.20,.125) if deer else (.27,.28,.265))
    light=material('Light fur',(.27,.175,.10) if bear else (.65,.60,.48))
    dark=material('Dark fur',(.023,.021,.018))
    inside=material('Ear velvet',(.18,.12,.105))
    hoof=material('Hoof' if deer else 'Paw',(.042,.035,.028))
    if bear:
        ell('Ribcage',(0,.1,.76),(.36,.65,.40),coat)
        ell('Rump',(0,-.49,.70),(.32,.39,.35),coat)
        ell('Shoulder',(0,.40,.80),(.32,.36,.33),coat)
        body=group('Body',parts[:],(0,0,.75),True,.032)
        start=len(parts)
        ell('Neck',(0,.68,.84),(.245,.34,.29),coat)
        ell('Skull',(0,.90,.88),(.215,.25,.205),coat)
        ell('Snout',(0,1.10,.81),(.14,.23,.12),coat)
        head=group('Head',parts[start:],(0,.56,.86),True,.018)
        parent(ell('Muzzle',(0,1.175,.798),(.130,.169,.095),light),head)
        parent(ell('Nose',(0,1.308,.823),(.076,.035,.043),nose),head)
        parent(ell('Mouth',(0,1.202,.757),(.101,.128,.009),dark),head)
        eyes(head,.985,.932,.189,.015)
        for s in [-1,1]: ear(head,(s*.168,.824,1.036),.071,.073,coat,inside,-.12)
        for s in [-1,1]:
            for front in [True,False]:
                y=.47 if front else -.50
                leg(('Front' if front else 'Hind')+('L' if s<0 else 'R'),(s*.235,y,.77),(s*.25,y-.055,.34),(s*.25,y+.045,.09),y+.10,.145 if front else .16,coat,hoof,.16)
        tail=ell('Tail',(0,-.825,.71),(.09,.105,.09),coat)
    elif deer:
        ell('Ribs',(0,.08,.965),(.205,.47,.28),coat)
        ell('Rump',(0,-.40,.965),(.215,.255,.265),coat)
        ell('Brisket',(0,.39,.94),(.17,.23,.29),coat)
        body=group('Body',parts[:],(0,0,.96),True,.018)
        start=len(parts)
        ell('Neck',(0,.51,1.235),(.122,.15,.37),coat,-.38)
        ell('Skull',(0,.70,1.535),(.104,.185,.145),coat)
        ell('Bridge',(0,.842,1.475),(.076,.168,.079),coat,.18)
        head=group('Head',parts[start:],(0,.39,1.02),True,.011)
        parent(ell('Jaw',(0,.831,1.43),(.062,.137,.044),light),head)
        parent(ell('Nose',(0,.978,1.467),(.060,.041,.044),nose),head)
        parent(ell('Throat',(0,.604,1.255),(.096,.055,.195),light,-.37),head)
        eyes(head,.776,1.558,.096,.016)
        for s in [-1,1]:
            ear(head,(s*.137,.627,1.699),.066,.140,coat,light,-.18)
            leg('Front'+('L' if s<0 else 'R'),(s*.13,.37,.98),(s*.142,.365,.48),(s*.145,.39,.075),.421,.061,coat,hoof,.065)
            leg('Hind'+('L' if s<0 else 'R'),(s*.145,-.41,1.0),(s*.165,-.57,.43),(s*.16,-.48,.075),-.45,.088,coat,hoof,.068)
        tail=segment('Tail',(0,-.63,1.035),(0,-.715,.805),.055,.016,dark)
        bpy.context.scene.cursor.location=(0,-.63,1.035)
        bpy.context.view_layer.objects.active=tail
        bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
        rump=material('Rump fur',(.46,.43,.36))
        parent(ell('Rump patch',(0,-.599,.97),(.128,.055,.16),rump),body)
    else:
        ell('Ribs',(0,.015,.16),(.070,.145,.088),coat)
        ell('Haunch',(0,-.092,.15),(.087,.086,.112),coat)
        body=group('Body',parts[:],(0,0,.15),True,.007)
        start=len(parts)
        ell('Skull',(0,.146,.217),(.059,.073,.062),coat)
        ell('Snout',(0,.201,.191),(.034,.059,.029),coat)
        head=group('Head',parts[start:],(0,.10,.19),True,.0045)
        parent(ell('Nose',(0,.246,.194),(.016,.012,.011),nose),head)
        eyes(head,.175,.235,.052,.009)
        for s in [-1,1]:
            ear(head,(s*.045,.118,.274),.026,.039,coat,inside)
            leg('Front'+('L' if s<0 else 'R'),(s*.045,.083,.15),(s*.044,.071,.065),(s*.04,.122,.022),.138,.021,coat,hoof,.033)
            leg('Hind'+('L' if s<0 else 'R'),(s*.059,-.088,.17),(s*.069,-.107,.055),(s*.061,-.046,.020),-.015,.035,coat,hoof,.043)
        start=len(parts)
        # Broad S-shaped bushy tail, not a thin rat tail or a single capsule.
        for i in range(13):
            t=i/12;y=-.14-.16*math.sin(t*2.4);z=.17+.30*t
            r=.025+.045*math.sin(math.pi*t)**.65
            ell('Tail fur',(0,y,z),(r,r*.80,.048),coat)
        tail=group('Tail',parts[start:],(0,-.135,.18),True,.007)
        parent(ell('Belly',(0,.025,.106),(.056,.11,.028),light),body)
    # Tint variation follows anatomy; no large blotches or spotted noise.
    for o in [body,head,tail]:
        attr=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
        for i,v in enumerate(o.data.vertices):
            p=o.matrix_world@v.co
            tone=1+rng.uniform(-.026,.026)+.05*math.sin(p.y*5)
            attr.data[i].color=(tone,tone,tone,1)
    fur(body,1400 if bear else 650,.017 if bear else .008,coat)
    fur(head,380,.010 if bear else .004,coat)
    if species=='squirrel': fur(tail,5200,.023,coat)
    export_species(species)

def bird(species):
    global parts
    reset();parts=[];jay=species=='jay'
    coat=material('Blue feathers' if jay else 'Slate feathers',(.045,.155,.32) if jay else (.24,.265,.28))
    wingmat=material('Flight feathers',(.032,.115,.27) if jay else (.235,.188,.135))
    black=material('Black feathers',(.025,.031,.039));cream=material('Pale feathers',(.66,.61,.47))
    rust=material('Belly feathers',(.43,.285,.135));feet=material('Bird feet',(.18,.145,.115))
    h=.15 if jay else .15
    ell('Breast',(0,0,h),(.047 if jay else .075,.105 if jay else .093,.062 if jay else .095),coat,-.35)
    ell('Back',(0,-.053,h+.025),(.047 if jay else .07,.078,.055),coat)
    body=group('Body',parts[:],(0,0,h),True,.005)
    start=len(parts)
    ell('Head',(0,.072,h+.088),(.036,.048,.041) if jay else (.044,.051,.049),black)
    ell('Neck',(0,.04,h+.062),(.037,.044,.053),black if jay else coat)
    head=group('Head',parts[start:],(0,.032,h+.048),True,.003)
    parent(segment('Beak',(0,.102,h+.089),(0,.166 if jay else .132,h+.083),.012 if jay else .016,0,nose),head)
    eyes(head,.091,h+.103,.033 if jay else .039,.0045)
    start=len(parts)
    if jay:
        for i in range(6):
            x=(i-2.5)*.007
            feather('Crest',(x,.057,h+.118),(x*.45,.020,h+.194-abs(i-2.5)*.011),.010,black)
    else:
        for i in range(4):
            feather('Topknot',((i-1.5)*.005,.061,h+.138),((i-1.5)*.005,.09,h+.203),.008,black)
        ell('Topknot tip',(0,.105,h+.189),(.012,.018,.017),black)
        # White brow and throat border, shaped strips following the skull.
        for s in [-1,1]:
            feather('Brow',(s*.042,.052,h+.137),(s*.031,.095,h+.141),.005,cream)
            feather('Throat border',(s*.033,.091,h+.068),(s*.041,.057,h+.088),.007,cream)
        parent(ell('Belly',(0,.013,.111),(.065,.076,.061),rust),body)
        # Scalloped belly/flank coverts: rows vary in length and overlap.
        for s in [-1,1]:
            for row in range(4):
                for col in range(5):
                    y=-.05+col*.022;z=.093+row*.020
                    x=s*(.061+(.006 if row==2 else 0))
                    o=feather('Flank covert',(x,y,z+.01),(x+.002*s,y-.01,z-.008),.009,cream if (row+col)%3==0 else wingmat)
                    parent(o,body)
    # Only crest parts get the moving head parent (flanks were attached above).
    for o in parts[start:]:
        if o.name in bpy.data.objects and o.parent is None: parent(o,head)
    for s in [-1,1]:
        start=len(parts)
        ell('Wing cover',(s*.047,-.025,h+.030),(.014,.065,.036),wingmat)
        for i in range(7):
            feather('Primary',(s*(.047+i*.002),.001-i*.009,h+.032-i*.003),(s*.052,-.118-i*.008,h-.007-i*.002),.009,wingmat)
        wing=group('WingL' if s<0 else 'WingR',parts[start:],(s*.043,.018,h+.045))
        if jay:
            for i in range(5):
                parent(feather('Wing bar',(s*.063,-.027-i*.019,h+.008),(s*.065,-.022-i*.019,h+.039),.0025,black),wing)
            start=len(parts)
            ell('Flight cover',(s*.102,-.015,h+.032),(.068,.043,.009),wingmat)
            for i in range(9):
                feather('Spread primary',(s*.096,-.005-i*.007,h+.032),(s*(.235-i*.009),-.012-i*.016,h+.026),.010,wingmat)
            group('FlightL' if s<0 else 'FlightR',parts[start:],(s*.043,.018,h+.045))
        start=len(parts)
        segment('Shank',(s*.023,0,.105),(s*.025,.003,.025),.004,.003,feet,8)
        for t in [-1,0,1]: segment('Toe',(s*.025,.003,.018),(s*.025+t*.012,.037,.008),.0025,.0007,feet,6)
        segment('Hind toe',(s*.025,.003,.018),(s*.025,-.015,.009),.002,.0007,feet,6)
        group('FrontL' if s<0 else 'FrontR',parts[start:],(s*.023,0,.10))
    start=len(parts)
    for i in range(7):
        x=(i-3)*.007
        feather('Tail feather',(x,-.068,h+.01),(x*1.4,-.265+abs(i-3)*.009 if jay else -.147+abs(i-3)*.006,h-.025),.009,wingmat)
    group('Tail',parts[start:],(0,-.065,h+.01))
    export_species(species)

def export_species(species):
    # glTF requires a white default when tinted surfaces are joined to details.
    for o in bpy.context.scene.objects:
        if o.type=='MESH' and not o.data.color_attributes:
            attr=o.data.color_attributes.new(name='Color',type='FLOAT_COLOR',domain='POINT')
            for value in attr.data: value.color=(1,1,1,1)
    # Consolidate static details into their articulated part, keeping draw calls low.
    for name in ['Body','Head','Tail','WingL','WingR']:
        o=bpy.data.objects.get(name)
        if o is None: continue
        children=[c for c in o.children_recursive if c.type=='MESH']
        bpy.ops.object.select_all(action='DESELECT')
        for child in children: child.select_set(True)
        o.select_set(True);bpy.context.view_layer.objects.active=o
        if children: bpy.ops.object.join()
    meshes=[o for o in bpy.context.scene.objects if o.type=='MESH']
    for o in meshes:
        # Explicit UVs for the microstructure shader and normal export.
        uv=o.data.uv_layers.new(name='UVMap')
        for poly in o.data.polygons:
            for li in poly.loop_indices:
                p=o.data.vertices[o.data.loops[li].vertex_index].co
                uv.data[li].uv=(p.y,p.z)
    dest=ASSETS/'wildlife';dest.mkdir(exist_ok=True)
    bpy.ops.object.select_all(action='SELECT')
    bpy.ops.export_scene.gltf(filepath=str(dest/(species+'.glb')),export_format='GLB',use_selection=True,
        export_yup=True,export_apply=True,export_animations=False,export_cameras=False,export_lights=False,
        export_vertex_color='ACTIVE',export_all_vertex_colors=True)
    print('WILDLIFE',species,'triangles',sum(sum(len(p.vertices)-2 for p in o.data.polygons) for o in meshes))
    save('build_'+species)

eye=material('Wet eye',(.007,.006,.005));eye.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.16
nose=material('Nose and beak',(.019,.017,.014));nose.node_tree.nodes.get('Principled BSDF').inputs['Roughness'].default_value=.45
for species in ['bear','deer','squirrel']: mammal(species)
for species in ['quail','jay']: bird(species)
