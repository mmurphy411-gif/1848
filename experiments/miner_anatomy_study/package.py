import bpy
from pathlib import Path
OUT=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'miner_anatomy_candidate.blend'))
scene=bpy.context.scene;scene.camera=bpy.data.objects['Study face_quarter']
scene.render.resolution_x=900;scene.render.resolution_y=900;scene.render.resolution_percentage=100
note=bpy.data.texts.get('MINER HEAD STUDY — READ ME') or bpy.data.texts.new('MINER HEAD STUDY — READ ME')
note.clear();note.write((OUT/'README.md').read_text())
for screen in bpy.data.screens:
    for area in screen.areas:
        if area.type=='VIEW_3D':
            area.spaces.active.region_3d.view_perspective='CAMERA'
            area.spaces.active.shading.type='MATERIAL'
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'miner_anatomy_candidate.blend'))
print('PACKAGED',sum(bool(im.packed_file) for im in bpy.data.images),'packed images')
