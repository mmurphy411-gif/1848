import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'miner_refined.blend'))
scene=bpy.context.scene;scene.camera=bpy.data.objects['Study torso'];scene.render.resolution_x=800;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
old=bpy.data.texts.get('MINER HEAD STUDY — READ ME')
if old:bpy.data.texts.remove(old)
note=bpy.data.texts.get('MINER REFINEMENT — READ ME') or bpy.data.texts.new('MINER REFINEMENT — READ ME');note.clear();note.write((OUT/'README.md').read_text())
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA';area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'miner_refined.blend'))
print('PACKAGED',sum(bool(im.packed_file) for im in bpy.data.images),'packed images')
