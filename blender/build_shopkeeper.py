"""Reuse the miner rig and body, with separate clothing and work clips.

Since visual upgrade Stage 5 only the five clips are used: Lambert is drawn from the crew
kit, and blender/build_crew_kit.py strips this mesh from assets/store/shopkeeper.glb."""
import sys,bmesh
from pathlib import Path
sys.path.insert(0,str(Path(__file__).parent))
from common import *
import build_miner_animation as animation
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/build_miner.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=bpy.data.objects['Miner']
joints={b.name:(b.head_local.copy(),b.tail_local.copy()) for b in rig.data.bones}
rig.animation_data_clear()
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
animation.CLIPS={'pour':3.,'take':1.5}
animation.animate(rig,body,joints,'store/miner_clips.glb','build_store_miner')
rig.animation_data_clear()
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
bm=bmesh.new();bm.from_mesh(body.data)
remove=[f for f in bm.faces if f.material_index in [4,5,6] or (f.material_index==2 and min(v.co.z for v in f.verts)>1.63)]
bmesh.ops.delete(bm,geom=remove,context='FACES');bm.to_mesh(body.data);bm.free()
colors=[(.45,.075,.04),(.075,.07,.057),(.12,.08,.04),(.55,.34,.19),(.2,.2,.18),(.2,.2,.18),(.15,.1,.07),(.4,.3,.1)]
indices=[p.material_index for p in body.data.polygons]
body.data.materials.clear()
for i,c in enumerate(colors):body.data.materials.append(material('Lambert '+str(i),c))
for p,index in zip(body.data.polygons,indices):p.material_index=index
def garment(name,p,size,color,bone):
    if name in ['Moustache','Grey side hair','Hair crown','Eye']:
        bpy.ops.mesh.primitive_uv_sphere_add(segments=16,ring_count=8,radius=.5,location=p)
    else:bpy.ops.mesh.primitive_cube_add(size=1,location=p)
    o=bpy.context.object;o.name=name;o.scale=size
    bpy.ops.object.transform_apply(location=True,rotation=False,scale=True)
    o.data.materials.append(material(name,color));group=o.vertex_groups.new(name=bone);group.add(list(range(len(o.data.vertices))),1,'REPLACE')
    mod=o.modifiers.new('Skin','ARMATURE');mod.object=rig;o.parent=rig
    bpy.ops.object.select_all(action='DESELECT');body.select_set(True);o.select_set(True);bpy.context.view_layer.objects.active=body;bpy.ops.object.join()
garment('Waistcoat',(0,-.105,1.21),(.33,.12,.38),(.09,.085,.067),'Chest')
garment('Apron',(0,-.148,.88),(.35,.035,.58),(.55,.46,.29),'Hips')
for i in range(9):garment('Woven sash',(0,-.168,.985+i*.008),(.37,.03,.006),(.50,.045,.035) if i%2 else (.04,.13,.26),'Hips')
garment('Moustache',(0,-.091,1.568),(.104,.036,.024),(.19,.17,.13),'Head')
for x in [-.076,.076]:garment('Grey side hair',(x,.0,1.627),(.027,.11,.09),(.31,.30,.27),'Head')
garment('Hair crown',(0,.005,1.671),(.15,.13,.04),(.19,.18,.16),'Head')
for x in [-.032,.032]:garment('Eye',(x,-.078,1.623),(.012,.010,.008),(.07,.05,.03),'Head')
animation.CLIPS={'keep_idle':4.,'weigh':3.,'write':1.5,'hand_over':1.5,'shelve':2.}
animation.animate(rig,body,joints,'store/shopkeeper.glb','build_shopkeeper')
