"""Two dedicated expedition clips against the unchanged miner skeleton."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
from common import *
import build_miner_animation as animation
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'blender/build_miner.blend'))
rig=next(o for o in bpy.data.objects if o.type=='ARMATURE')
body=bpy.data.objects['Miner']
joints={b.name:(b.head_local.copy(),b.tail_local.copy()) for b in rig.data.bones}
rig.animation_data_clear()
for action in list(bpy.data.actions):bpy.data.actions.remove(action)
animation.CLIPS={'spear':1.4,'rifle':3.}
animation.animate(rig,body,joints,'expedition/miner_clips.glb','build_expedition_miner')
