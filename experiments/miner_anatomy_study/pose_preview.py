import bpy,sys
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).resolve().parent
sys.path.insert(0,str(OUT));import run as study
bpy.ops.wm.open_mainfile(filepath=str(OUT/'miner_anatomy_candidate.blend'))
rig=bpy.data.objects['MinerRig'];scene=bpy.context.scene
for track in rig.animation_data.nla_tracks:track.mute=True
for name in ['pan_swirl','lie_down']:
    act=bpy.data.actions[name];rig.animation_data.action=act
    if act.slots:rig.animation_data.action_slot=act.slots[0]
    scene.frame_set(round(sum(act.frame_range)/2));bpy.context.view_layer.update()
    center=rig.matrix_world@rig.pose.bones['Head'].head+Vector((0,0,.08))
    cam=bpy.data.objects['Study face_quarter'];cam.location=center+Vector((2.5,-4,.12));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler();cam.data.ortho_scale=.55
    study.render('pose_'+name,['face_quarter'])
