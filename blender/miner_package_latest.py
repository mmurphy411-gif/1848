"""Package the reviewed Pass 17 asset and render larger neutral inspection views."""
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import bpy
import miner_convergence_continue as c

c.package_loadouts(stage=17,packaging_stage=170,quality_status='LARGE-FORM REVIEW GATE: silhouette 8/10 and proportions 8/10 (subjective). Polished source asset; facial likeness, animation deformation and game export are not final acceptance.')
scene=bpy.context.scene
scene.render.resolution_x=1300;scene.render.resolution_y=1800;scene.cycles.samples=64
for kit in ['base','expedition']:
    c.loadout(kit);scene.camera=bpy.data.objects['Review three_quarter']
    scene.render.filepath=str(c.OUT/f'pass_17_{kit}_three_quarter_large.png');bpy.ops.render.render(write_still=True)
c.loadout('base');scene.camera=bpy.data.objects['Review face']
scene.render.filepath=str(c.OUT/'pass_17_face_large.png');bpy.ops.render.render(write_still=True)
print('PASS_17_PACKAGED_AND_RENDERED')
