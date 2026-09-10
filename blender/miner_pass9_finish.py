"""Render the reviewed pass, validate all independent loadouts, and package snapshots."""
import sys,bpy
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parent))
import miner_convergence_pass9 as p
p.run()
p.c.finish(9)
p.c.package_loadouts(stage=9,packaging_stage=90)
