"""Isolated Godot inspection project; never installs a candidate into assets/."""
from pathlib import Path
import shutil
import subprocess
from PIL import Image, ImageStat
from .storage import ROOT, digest, event, lock, read, write
from .runner import run_path, executable, check_budget, verify_inputs


def capture(run, cid=None):
    run = run_path(run)
    with lock(run):
        state, manifest = read(run / "run.json"), read(run / "manifest.json")
        verify_inputs(run, state)
        check_budget(manifest, state)
        cid = cid or state["best_candidate"] or state["latest_attempt"]
        if cid not in state["candidates"]:
            raise ValueError("Unknown candidate")
        folder = run / "candidates" / cid
        output = folder / "godot"
        output.mkdir(exist_ok=True)
        shutil.copy2(folder / "export" / "asset.glb", output / "asset.glb")
        shutil.copy2(ROOT / "art_gauntlet" / "godot_capture.gd", output / "capture.gd")
        profile = manifest.get("engine_profile", "embedded")
        if profile == "fish_existing":
            shutil.copy2(ROOT / "shaders" / "fish.gdshader", output / "runtime.gdshader")
            shutil.copy2(ROOT / "assets" / "fish" / "fish_atlas.png", output / "runtime_atlas.png")
        elif profile == "wildlife_existing":
            shutil.copy2(ROOT / "shaders" / "wildlife.gdshader", output / "runtime.gdshader")
        elif profile != "embedded":
            raise ValueError("Unknown engine material profile")
        settings = {"profile": profile, "gameplay_distance": manifest.get("gameplay_distance", 2.5)}
        write(output / "settings.json", settings)
        (output / "project.godot").write_text('[application]\nconfig/name="Gauntlet isolated inspection"\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n', encoding="utf-8")
        binary = executable("godot")
        with (output / "godot.log").open("w", encoding="utf-8") as log:
            imported = subprocess.run([binary, "--headless", "--editor", "--path", str(output), "--import", "--quit"], stdout=log, stderr=subprocess.STDOUT, timeout=180)
            if imported.returncode:
                raise RuntimeError(f"Godot import failed: {output / 'godot.log'}")
            # A real rendering device is required. --headless uses a dummy display
            # on this environment; --disable-render-loop would produce no evidence.
            process = subprocess.run([binary, "--path", str(output), "--script", "capture.gd", "--rendering-method", "gl_compatibility", "--resolution", "1000x760", "--position", "-2000,-2000"],
                                     stdout=log, stderr=subprocess.STDOUT, timeout=120,
                                     creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
        if process.returncode or not (output / "engine_result.json").exists():
            raise RuntimeError(f"Godot capture failed: {output / 'godot.log'}")
        result = read(output / "engine_result.json")
        for view in ("close", "gameplay"):
            im = Image.open(output / f"{view}.png").convert("RGB")
            if max(ImageStat.Stat(im).stddev) < 1:
                raise ValueError("Engine produced a blank inspection frame")
        result.update({"passed": True, "profile": profile,
                       "runtime_materials_verified": profile in {"fish_existing", "wildlife_existing"},
                       "glb_hash": digest(output / "asset.glb"),
                       "runtime_shader_hash": digest(output / "runtime.gdshader") if (output / "runtime.gdshader").exists() else None,
                       "notes": "Static staging inspection, existing shader/material binding. Animation, underwater composition and live replacement are separate gates. A baked candidate may look wrong with the existing atlas or coat shader; visual review must assess this."})
        write(output / "audit.json", result)
        event(run, "engine_captured", candidate=cid, profile=profile)
        return result
