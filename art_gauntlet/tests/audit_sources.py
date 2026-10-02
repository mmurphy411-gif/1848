"""Read-only integration check of the current authored manifests and scenes."""
import importlib
import json
from pathlib import Path
import sys
import bpy
ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from art_gauntlet.blender_worker import configure, audit
for folder in ("deer", "rainbow trout"):
    manifest = json.loads((ROOT / "characters" / folder / "gauntlet.json").read_text())
    bpy.ops.wm.open_mainfile(filepath=str(ROOT / manifest["source"]))
    configure(manifest)
    adapter = importlib.import_module("blender.gauntlet_adapters." + manifest["adapter"])
    result = audit(adapter.subject(manifest), manifest, adapter)
    assert not result["errors"], (folder, result["errors"])
    print("SOURCE AUDIT PASS", folder, result["triangles"], flush=True)
