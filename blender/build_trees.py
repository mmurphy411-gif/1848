"""Species-specific branching and geometry-node foliage atlases, no external art.

Legacy (Milestone 5/6). Visual upgrade Stage 4 replaced its outputs: the foliage atlases come
from tools/art/build_foliage_atlases.py and the trees from tools/art/build_trees.mjs. Running
this script overwrites the Stage 4 trees and atlases with the old ones."""
import sys, random, math, time
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
start=time.perf_counter(); reset()
SPECIES=['ponderosa','incense_cedar','douglas_fir','black_oak']

def foliage_atlas(species,index):
    rng=random.Random(910+index)
    existing=set(bpy.context.scene.objects)
    verts=[]; faces=[]; points=[]; rotations=[]; scales=[]
    leaf_color=[(.09,.25,.045),(.045,.19,.065),(.055,.22,.095),(.16,.38,.055)][index]
    m=material('Living foliage',leaf_color)
    nodes=m.node_tree.nodes; links=m.node_tree.links
    emission=nodes.new('ShaderNodeEmission'); emission.inputs[0].default_value=(*leaf_color,1)
    links.new(emission.outputs[0],nodes.get('Material Output').inputs[0])
    # One leaf/needle is instanced by Geometry Nodes onto seeded botanical sprays.
    if index==3:
        outline=[(0,0),(-.22,.18),(-.13,.30),(-.35,.42),(-.21,.55),(-.36,.66),(-.19,.79),(0,1),(.19,.79),(.36,.66),(.21,.55),(.35,.42),(.13,.30),(.22,.18)]
        # Rounded lobes in the atlas source; this adds no runtime triangles.
        for refinement in range(2):
            outline=[((1-t)*a[0]+t*b[0],(1-t)*a[1]+t*b[1])
                     for a,b in zip(outline,outline[1:]+outline[:1]) for t in (.22,.78)]
    elif index==0: outline=[(-.008,0),(-.015,.4),(0,1),(.015,.4),(.008,0)]
    else: outline=[(-.025,0),(-.05,.28),(0,1),(.05,.28),(.025,0)]
    leaf=mesh_object('Leaf source',[(x,y,.02) for x,y in outline],[tuple(range(len(outline)))],materials=[m])
    leaf.hide_render=True
    # Several asymmetric side sprays leave holes between clusters in the card.
    for branch in range(1 if index==3 else (9 if index!=0 else 6)):
        angle=(branch%2*2-1)*(.45+.10*branch)
        root=Vector((0,-.70 if index==3 else -.88+branch*.18,0)); tip=root+Vector((math.sin(angle),math.cos(angle),0))*(1.35 if index==3 else .8)
        base=len(verts); direction=(tip-root).normalized(); side=Vector((-direction.y,direction.x,0))*.012
        verts.extend([root-side,root+side,tip+side*.2,tip-side*.2]); faces.append((base,base+1,base+2,base+3))
        for step in range(18 if index!=3 else 4):
            t=(step+.4)/(18 if index!=3 else 4)
            for sign in [-1,1]:
                p=root.lerp(tip,t)
                a=-angle+sign*(1.0 if index!=0 else .65)+rng.uniform(-.15,.15)
                length=(.20 if index!=3 else .65)*rng.uniform(.65,1.2)*(1-t*.45)
                if index==0: length*=1.65
                if index==1: length*=.65
                for needle in range(3 if index==0 else 1):
                    points.append(tuple(p)); rotations.append((0,0,a+(needle-1)*.13 if index==0 else a)); scales.append((length*(1.5 if index==1 else 1),length,1))
    source=mesh_object('Seeded spray points',points,[])
    for name,values in [('rotation',rotations),('scale',scales)]:
        attr=source.data.attributes.new(name,'FLOAT_VECTOR','POINT')
        for item,value in zip(attr.data,values): item.vector=value
    group=bpy.data.node_groups.new(species+' foliage scatter','GeometryNodeTree')
    group.interface.new_socket(name='Geometry',in_out='INPUT',socket_type='NodeSocketGeometry')
    group.interface.new_socket(name='Geometry',in_out='OUTPUT',socket_type='NodeSocketGeometry')
    n=group.nodes; l=group.links
    inp=n.new('NodeGroupInput'); out=n.new('NodeGroupOutput'); inst=n.new('GeometryNodeInstanceOnPoints'); real=n.new('GeometryNodeRealizeInstances')
    info=n.new('GeometryNodeObjectInfo'); info.inputs['Object'].default_value=leaf
    l.new(inp.outputs[0],inst.inputs['Points']); l.new(info.outputs['Geometry'],inst.inputs['Instance'])
    for name in ['rotation','scale']:
        attr=n.new('GeometryNodeInputNamedAttribute'); attr.data_type='FLOAT_VECTOR'; attr.inputs['Name'].default_value=name
        l.new(attr.outputs['Attribute'],inst.inputs[name.title()])
    l.new(inst.outputs[0],real.inputs[0]); l.new(real.outputs[0],out.inputs[0])
    mod=source.modifiers.new('Needles on seeded sprays','NODES'); mod.node_group=group
    mesh_object('Twigs',verts,faces,materials=[m])
    scene=bpy.context.scene; scene.render.engine='CYCLES'; scene.cycles.samples=1
    scene.render.film_transparent=True; scene.render.resolution_x=2048; scene.render.resolution_y=2048; scene.render.resolution_percentage=100
    scene.view_settings.view_transform='Standard'
    bpy.ops.object.camera_add(location=(0,0,5)); cam=bpy.context.object; cam.rotation_euler=(0,0,0); cam.data.type='ORTHO'; cam.data.ortho_scale=2.2; scene.camera=cam
    scene.render.image_settings.file_format='PNG'; scene.render.image_settings.color_mode='RGBA'
    path=ASSETS/'textures'/('foliage_'+species+'_albedo.png'); path.parent.mkdir(parents=True,exist_ok=True)
    scene.render.filepath=str(path); bpy.ops.render.render(write_still=True)
    # PNG render stamps contain wall-clock dates/timings. Remove only those
    # ancillary chunks, preserving the exact pixels and color profile.
    import struct
    data=path.read_bytes(); clean=data[:8]; offset=8
    while offset<len(data):
        size=struct.unpack_from('>I',data,offset)[0]
        chunk=data[offset:offset+size+12]
        if data[offset+4:offset+8] not in [b'tEXt',b'zTXt',b'iTXt',b'tIME']: clean+=chunk
        offset+=size+12
    path.write_bytes(clean)
    # Preserve the node setup in the source .blend as a separate collection.
    collection=bpy.data.collections.new('Atlas '+species); scene.collection.children.link(collection)
    for obj in list(bpy.context.scene.objects):
        if obj in existing: continue
        for c in list(obj.users_collection): c.objects.unlink(obj)
        collection.objects.link(obj)
    collection.hide_render=True; collection.hide_viewport=True
    return path

def build_tree(species,index,atlas):
    rng=random.Random(1848+index); verts=[]; faces=[]; uvs=[]; colors=[]; slots=[]
    height=[30,25,33,15][index]
    bark=material('Bark '+species,[(.37,.16,.055),(.22,.09,.035),(.15,.105,.075),(.12,.105,.08)][index])
    foliage=material('Foliage '+species,(.12,.3,.08)); p=foliage.node_tree.nodes.get('Principled BSDF')
    tex=foliage.node_tree.nodes.new('ShaderNodeTexImage'); tex.image=bpy.data.images.load(str(atlas)); foliage.node_tree.links.new(tex.outputs['Color'],p.inputs['Base Color']); foliage.node_tree.links.new(tex.outputs['Alpha'],p.inputs['Alpha'])
    foliage.surface_render_method='DITHERED'
    trunk=[Vector(((.4 if index==3 else .18)*math.sin(j*.8),.12*math.cos(j),(7 if index==3 else height)*j/14)) for j in range(15)]
    tube(verts,faces,uvs,colors,slots,trunk,[.55*(1-j/15)**1.1+.025 for j in range(15)],10,.15)
    def spray(center, direction, size, number):
        direction=Vector(direction).normalized()
        for k in range(number):
            jitter=Vector((rng.uniform(-1,1),rng.uniform(-1,1),rng.uniform(-.5,.5)))
            origin=Vector(center)+jitter*(1.5 if index==3 else size*.32)
            axis=(direction+jitter*(2.0 if index==3 else .65)).normalized()*size
            across=axis.cross(Vector((rng.uniform(-1,1),rng.uniform(-1,1),1))).normalized()*size
            card(verts,faces,uvs,colors,slots,origin,axis,across,min(1,origin.z/height+.2))
    if index<3:
        levels=8 if index==0 else 9
        for j in range(levels):
            h=(.38 if index==0 else .13)+(j/(levels-1))*(.59 if index==0 else .83)
            count=4 if index==0 else 5
            for k in range(count):
                angle=k*math.tau/count+j*2.39+rng.uniform(-.15,.15)
                radial=Vector((math.cos(angle),math.sin(angle),0))
                length=(5.5 if index!=2 else 6.4)*(1-h)**.65*rng.uniform(.8,1.15)
                root=Vector((0,0,height*h)); tip=root+radial*length+Vector((0,0,(.7 if index==0 else -.6)*length))
                pts=[root,root.lerp(tip,.45)+Vector((0,0,.4)),tip]
                tube(verts,faces,uvs,colors,slots,pts,[.14*(1-h)+.025,.055,.012],5,.7)
                for side in [-1,1]:
                    for s in [.5,.82]:
                        origin=root.lerp(tip,s); tangent=Vector((-radial.y,radial.x,0))*side
                        end=origin+(radial*.5+tangent*.65)*length*.42+Vector((0,0,-.3 if index==2 else .15))
                        tube(verts,faces,uvs,colors,slots,[origin,end],[.035,.004],4,.95)
                        spray(end,(end-origin),1.7 if index==0 else 2.0,7 if index==0 else 6)
                spray(tip,radial+Vector((0,0,.3)),1.8,10)
    else:
        def branch(root, direction, length, radius, depth):
            end=root+direction*length
            mid=root.lerp(end,.5)+Vector((rng.uniform(-.4,.4),rng.uniform(-.4,.4),.3))
            if depth:
                tube(verts,faces,uvs,colors,slots,[root,mid,end],[radius,radius*.7,radius*.35],12 if depth==2 else 9,.9)
            else:
                across=direction.cross(Vector((0,0,1))).normalized()*radius
                base=len(verts);verts.extend([root-across,root+across,end+across*.2,end-across*.2])
                faces.append(tuple(base+i for i in range(4)));slots.append(0)
                uvs.extend([(0,0),(1,0),(1,1),(0,1)]);colors.extend([(.5,0,0,1)]*4)
            if depth:
                for sign in [-1,1]:
                    d=(direction+Vector((rng.uniform(-.7,.7),rng.uniform(-.7,.7),.2))).normalized()
                    branch(end,d,length*.65,radius*.48,depth-1)
            else:
                for t in [.25,.6,1.0]: spray(mid.lerp(end,t),direction,rng.uniform(.4,.6),20)
        for k in range(9):
            a=k*2.399; root=Vector((0,0,4+k*.35)); direction=Vector((math.cos(a),math.sin(a),.6)).normalized()
            branch(root,direction,4.2,.25,2)
            # Interior sprays interrupt the empty bowl visible from underneath.
            spray(root+direction*2.8+Vector((0,0,1.4)),direction,.55,10)
    obj=mesh_object(species,verts,faces,uvs,colors,[bark,foliage],slots)
    # Cards use gently outward-biased normals, rather than flat billboard lighting.
    normals=[]
    for vertex,v,c in zip(obj.data.vertices,verts,colors):
        radial=Vector((v[0],v[1],max(.5,v[2]*.12))).normalized()
        normals.append(tuple(radial if c[1]>.5 else vertex.normal))
    obj.data.normals_split_custom_set_from_vertices(normals)
    export(obj,'trees/'+species+'.glb')
    obj.location.x=index*18

def build_distant(species,index,atlas):
    # One crown cluster, sharing the full tree's atlas. Root coordinates and
    # species crown envelope match the full model; only geometry is reduced.
    rng=random.Random(1848+index);v=[];f=[];uv=[];c=[];slots=[]
    height=[30,25,33][index]
    bark=bpy.data.materials['Bark '+species];foliage=bpy.data.materials['Foliage '+species]
    tube(v,f,uv,c,slots,[Vector((0,0,height*j/8)) for j in range(9)],
         [.55*(1-j/9)**1.1+.025 for j in range(9)],6,.15)
    source=bpy.data.objects[species].data
    leaves=[p for p in source.polygons if p.material_index==1]
    for j in range(160):
        poly=leaves[int((j+.5)*len(leaves)/160)]
        points=[source.vertices[i].co.copy() for i in poly.vertices]
        center=sum(points,Vector())/4
        # Retain the parent tree's branch-fan directions and canopy envelope.
        points=[center+(point-center)*1.55 for point in points]
        base=len(v);v.extend(points);f.append(tuple(base+k for k in range(4)))
        uv.extend([(0,0),(1,0),(1,1),(0,1)]);slots.append(1)
        c.extend([(min(.95,center.z/height+.2),1,0,1)]*4)
    obj=mesh_object(species+'_distant',v,f,uv,c,[bark,foliage],slots)
    normals=[tuple(Vector((p[0],p[1],max(.5,p[2]*.12))).normalized()) if color[1]>.5 else tuple(vertex.normal)
             for p,color,vertex in zip(v,c,obj.data.vertices)]
    obj.data.normals_split_custom_set_from_vertices(normals)
    export(obj,'trees/'+species+'_distant.glb');obj.location.x=index*18;obj.location.y=20

atlases=[]
for i,species in enumerate(SPECIES):
    # Do not delete previous atlas collections: keep inspectable node sources.
    atlases.append(foliage_atlas(species,i))
for i,species in enumerate(SPECIES): build_tree(species,i,atlases[i])
for i,species in enumerate(SPECIES[:3]):build_distant(species,i,atlases[i])
save('build_trees'); print('TREES_SECONDS',time.perf_counter()-start)
