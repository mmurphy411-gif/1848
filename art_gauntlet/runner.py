"""File-driven orchestration. The assistant supplies plans and blind reviews."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import time
import uuid
from PIL import Image, ImageChops, ImageStat
from . import manifest as manifests, metric, review
from .storage import ROOT, contained, digest, event, fingerprint, lock, read, write


def executable(kind):
    env = os.environ.get("GAUNTLET_" + kind.upper())
    if env:
        path = Path(env)
        if not path.is_file():
            raise ValueError(f"Configured executable is missing: {path}")
        return str(path.resolve())
    found = shutil.which(kind)
    if found:
        return found
    choices = sorted(Path("C:/Program Files/Blender Foundation").glob("*/blender.exe")) if kind == "blender" else sorted((ROOT / ".tools").glob("Godot*console.exe"))
    if not choices:
        raise ValueError(f"Set GAUNTLET_{kind.upper()} to the executable path")
    return str(choices[-1])


def run_path(value):
    path = Path(value).resolve()
    if not path.is_relative_to(ROOT / "artifacts" / "gauntlet") or not (path / "run.json").is_file():
        raise ValueError("Expected an existing artifacts/gauntlet run directory")
    return path


def initialize(path):
    manifest = manifests.load(path)
    run = ROOT / "artifacts" / "gauntlet" / manifest["asset_id"] / (time.strftime("%Y%m%d-%H%M%S") + "-" + uuid.uuid4().hex[:6])
    run.mkdir(parents=True)
    (run / "references").mkdir()
    originals = {manifest["source"]: digest(ROOT / manifest["source"])}
    shutil.copy2(ROOT / manifest["source"], run / "baseline.blend")
    for name, ref in manifest["references"].items():
        original = contained(ROOT, ref["path"])
        originals[ref["path"]] = digest(original)
        image = Image.open(original)
        if ref["crop"][2] > image.width or ref["crop"][3] > image.height:
            raise ValueError(f"Reference crop outside image: {name}")
        crop = image.crop(ref["crop"])
        crop.save(run / "references" / f"{name}.png")
        if ref.get("mask"):
            mask_path = contained(ROOT, ref["mask"])
            originals[ref["mask"]] = digest(mask_path)
            mask = Image.open(mask_path).convert("L")
            if mask.size != crop.size:
                raise ValueError("Authored mask size must match reference crop")
        else:
            mask = metric.reference_mask(crop, ref.get("background_tolerance", 15))
        if not mask.getbbox():
            raise ValueError("Reference mask is empty")
        mask.save(run / "references" / f"{name}_mask.png")
    write(run / "manifest.json", manifest)
    state = {"schema_version": 1, "asset_id": manifest["asset_id"], "started": time.time(), "status": "awaiting_edit", "phase": "form",
             "best_candidate": None, "latest_attempt": None, "candidates": [], "originals": originals,
             "manifest_hash": digest(run / "manifest.json"),
             "reference_hashes": {p.name: digest(p) for p in (run / "references").glob("*.png")},
             "cost": {"planner_calls": 0, "reviewer_calls": 0, "review_images": 0, "review_pixels": 0}, "packet_ids": []}
    write(run / "run.json", state)
    event(run, "initialized")
    return run


def verify_inputs(run, state):
    if digest(run / "manifest.json") != state["manifest_hash"]:
        raise ValueError("Manifest changed: initialize a new protocol/run")
    for name, expected in state["originals"].items():
        if digest(contained(ROOT, name)) != expected:
            raise ValueError(f"Original input changed: {name}; initialize a new run")
    for name, expected in state["reference_hashes"].items():
        if digest(run / "references" / name) != expected:
            raise ValueError("Reference evidence changed: initialize a new protocol/run")


def check_budget(manifest, state, candidates=0, calls=0, images=0):
    budget = manifest["budget"]
    costs = state["cost"]
    tests = [(len(state["candidates"])+candidates <= budget["max_candidates"], "candidate"),
             ((time.time()-state["started"])/60 < budget["max_minutes"], "elapsed time"),
             (costs["planner_calls"]+costs["reviewer_calls"]+calls <= budget["max_model_calls"], "model call"),
             (costs["review_images"]+images <= budget["max_review_images"], "review image")]
    for okay, name in tests:
        if not okay:
            raise ValueError(f"Run incomplete: {name} budget exhausted")


def worker(run, input_path, output, action, plan=None):
    manifest = read(run / "manifest.json")
    state = read(run / "run.json")
    verify_inputs(run, state)
    check_budget(manifest, state)
    sources = list((ROOT / "art_gauntlet").glob("*.py")) + list((ROOT / "blender" / "gauntlet_adapters").glob("*.py")) + list((ROOT / "blender" / "gauntlet_recipes").glob("*.py"))
    binary = executable("blender")
    dependency_hashes = {p.relative_to(ROOT).as_posix(): digest(p) for p in sources}
    # Snapshot all authored image dependencies conservatively. Packed images are
    # covered by the scene hash; external inputs are also covered here.
    for folder in (ROOT / "textures", ROOT / "blender"):
        for p in folder.rglob("*"):
            if p.is_file() and p.suffix.lower() in {".png", ".jpg", ".jpeg", ".exr", ".hdr"}:
                dependency_hashes[p.relative_to(ROOT).as_posix()] = digest(p)
    signature = fingerprint({"input": digest(input_path), "manifest": manifest, "plan": plan, "action": action,
                             "code_and_images": dependency_hashes, "blender_binary": digest(binary)})
    dependencies = read(output / "dependencies.json") if (output / "dependencies.json").exists() else {}
    signature = fingerprint({"job": signature, "external": {p: digest(p) if Path(p).is_file() else None for p in dependencies}})
    marker = output / "complete.json"
    if marker.exists():
        old = read(marker)
        dependencies = read(output / "dependencies.json") if (output / "dependencies.json").exists() else {}
        dependencies_match = all(Path(p).is_file() and digest(p) == h for p,h in dependencies.items())
        if old["signature"] == signature and dependencies_match and all((output / p).is_file() and digest(output / p) == h for p,h in old["files"].items()):
            event(run, "cache_hit", action=action, candidate=output.name)
            return
    output.mkdir(parents=True, exist_ok=True)
    # Keep the implementation used by this attempt, not only its hash. Later
    # recipe changes must not erase how a historical candidate was constructed.
    for source in sources:
        destination = output / "code_snapshot" / source.relative_to(ROOT)
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, destination)
    job = {"action": action, "signature": signature, "input": str(input_path), "output": str(output), "manifest": manifest, "plan": plan or {}}
    write(output / "job.json", job)
    start = time.time()
    timeout = min(1800, max(1, int(manifest["budget"]["max_minutes"]*60-(start-state["started"]))))
    with (output / "blender.log").open("w", encoding="utf-8") as log:
        process = subprocess.run([binary, "--background", "--factory-startup", "--python-exit-code", "1", "--python", str(ROOT / "art_gauntlet" / "blender_worker.py"), "--", str(output / "job.json")],
                                 cwd=ROOT, stdout=log, stderr=subprocess.STDOUT, timeout=timeout)
    if process.returncode:
        raise RuntimeError(f"Blender failed ({process.returncode}); inspect {output / 'blender.log'}")
    required = [output / "audit.json", output / "worker.json", output / "dependencies.json", output / ("candidate.blend" if action == "build" else "asset.glb")]
    required += [output / "renders" / f"{v}.png" for v in manifest["protocol"]["views"]]
    required += [output / "renders" / f"{v}_mask.png" for v in manifest["references"]]
    if not all(p.is_file() for p in required):
        raise RuntimeError("Worker exited without all required evidence")
    write(marker, {"signature": signature, "seconds": time.time()-start,
                   "files": {p.relative_to(output).as_posix(): digest(p) for p in required}})
    event(run, "worker_completed", action=action, seconds=time.time()-start)


def finish_candidate(run, cid):
    state = read(run / "run.json")
    manifest = read(run / "manifest.json")
    folder = run / "candidates" / cid
    record = read(folder / "candidate.json")
    parent = run / "candidates" / record["parent"] / "candidate.blend" if record["parent"] else run / "baseline.blend"
    try:
        worker(run, parent, folder, "build", record["plan"])
        metrics = {}
        for view in manifest["references"]:
            mask = Image.open(folder / "renders" / f"{view}_mask.png").getchannel("A")
            metrics[view] = metric.compare(Image.open(run / "references" / f"{view}_mask.png"), mask)
        write(folder / "metric.json", metrics)
        previous = read(run / "candidates" / record["parent"] / "metric.json") if record["parent"] else None
        disposition = metric.disposition(metrics, previous, manifest["references"], blind_to_metric=record["plan"].get("metric_blind", False))
        record.update({"state": disposition if disposition in {"metric_rejected", "search_only"} else "awaiting_review", "metric_disposition": disposition,
                       "scene_hash": digest(folder / "candidate.blend"), "reviews": record.get("reviews", [])})
        state["status"] = record["state"]
        event(run, "candidate_ready", candidate=cid, disposition=disposition)
    except Exception as exc:
        record.update({"state": "failed", "error": str(exc)})
        state["status"] = "failed"
        event(run, "candidate_failed", candidate=cid, error=str(exc))
        raise
    finally:
        write(folder / "candidate.json", record)
        write(run / "run.json", state)
    return record


def iterate(run, plan):
    run = run_path(run)
    with lock(run):
        state, manifest = read(run / "run.json"), read(run / "manifest.json")
        verify_inputs(run, state)
        check_budget(manifest, state, candidates=1, calls=1)
        if not plan.get("hypothesis") or not isinstance(plan.get("operations"), list):
            raise ValueError("A hypothesis and explicit operations list are required")
        cid = uuid.uuid4().hex[:12]
        folder = run / "candidates" / cid
        folder.mkdir(parents=True)
        record = {"id": cid, "parent": state["best_candidate"], "plan": plan, "state": "building", "created": time.time(), "reviews": []}
        write(folder / "candidate.json", record)
        state["candidates"].append(cid)
        state["latest_attempt"] = cid
        state["cost"]["planner_calls"] += 1
        write(run / "run.json", state)
        event(run, "candidate_started", candidate=cid, parent=record["parent"])
        return finish_candidate(run, cid)


def resume(run):
    run = run_path(run)
    with lock(run):
        state = read(run / "run.json")
        cid = state["latest_attempt"]
        if not cid:
            return status(run)
        record = read(run / "candidates" / cid / "candidate.json")
        if record["state"] in {"failed", "building"}:
            return finish_candidate(run, cid)
        return status(run)


def packet(run, cid=None, kind="source"):
    run = run_path(run)
    with lock(run):
        state, manifest = read(run / "run.json"), read(run / "manifest.json")
        verify_inputs(run, state)
        cid = cid or state["latest_attempt"]
        if cid not in state["candidates"]:
            raise ValueError("Unknown candidate")
        folder = run / "candidates" / cid
        record = read(folder / "candidate.json")
        if record["state"] in {"failed", "building", "metric_rejected"}:
            raise ValueError("Candidate is not reviewable")
        if kind == "export" and not (folder / "godot" / "audit.json").exists():
            raise ValueError("Capture engine evidence before requesting export review")
        count = 1 + len(manifest["protocol"].get("details", [])) * (2 if state["best_candidate"] and state["best_candidate"] != cid and kind == "source" else 1) + (2 if kind == "export" else 0)
        check_budget(manifest, state, calls=1, images=count)
        path, images, pixels = review.make_packet(run, cid, kind, second=bool(record["reviews"]))
        state["cost"]["reviewer_calls"] += 1
        state["cost"]["review_images"] += images
        state["cost"]["review_pixels"] += pixels
        state["packet_ids"].append(path.name)
        write(run / "run.json", state)
        event(run, "review_call_reserved", packet=path.name, images=images, pixels=pixels)
        return {"packet": str(path / "packet.json"), "instructions": "Fresh reviewer sees ONLY this packet and listed images. Use fork_turns=none. Return review_schema as JSON. Calls are reserved when dispatched; abandoned packets still cost budget."}


def ingest(run, review_path):
    run = run_path(run)
    with lock(run):
        state, manifest = read(run / "run.json"), read(run / "manifest.json")
        verify_inputs(run, state)
        supplied = read(review_path)
        pid = supplied.get("packet_id")
        if pid not in state["packet_ids"]:
            raise ValueError("Unknown review packet")
        public = run / "packets" / pid
        packet_data = read(public / "packet.json")
        mapping = read(run / "packet_maps" / f"{pid}.json")
        for name, expected in packet_data["evidence"].items():
            if digest(public / name) != expected:
                raise ValueError("Review evidence changed")
        result = review.validate_review(supplied, packet_data)
        cid = mapping["candidate"]
        folder = run / "candidates" / cid
        record = read(folder / "candidate.json")
        if digest(folder / "candidate.blend") != mapping["candidate_hash"]:
            raise ValueError("Candidate changed after packet creation")
        if pid in record["reviews"]:
            raise ValueError("Review already ingested")
        for old in record["reviews"]:
            if read(run / "reviews" / f"{old}.json")["reviewer_id"] == result["reviewer_id"]:
                raise ValueError("A gate confirmation requires a fresh reviewer identity")
        if mapping["kind"] == "export":
            if digest(folder / "export" / "asset.glb") != mapping["export_hash"]:
                raise ValueError("Export changed after review request")
            if read(folder / "godot" / "audit.json")["glb_hash"] != mapping["export_hash"]:
                raise ValueError("Engine evidence is for a different export")
            if read(folder / "export" / "comparison.json")["glb_hash"] != mapping["export_hash"]:
                raise ValueError("Export comparison is stale")
        else:
            # A candidate may have been built before another review completed.
            # Freshness follows the checkpoint actually shown in its packet,
            # not the older scene from which the candidate was constructed.
            compared_best = next((v for v in mapping["mapping"].values() if v != cid), record["parent"])
            if state["best_candidate"] not in (compared_best, cid):
                raise ValueError("Best changed since comparison; request a fresh review")
        label = next(k for k,v in mapping["mapping"].items() if v == cid)
        subject = result["subjects"][label]
        write(run / "reviews" / f"{pid}.json", result)
        record["reviews"].append(pid)
        if result["additional_evidence"]:
            record["state"] = "awaiting_evidence"
            record["form_pass"] = False
            record["game_ready"] = False
            if state["best_candidate"] == cid:
                state["phase"] = "form"
        elif mapping["kind"] == "export":
            export_check = read(folder / "export" / "comparison.json")
            engine_check = read(folder / "godot" / "audit.json")
            passed = (state["best_candidate"] == cid and record.get("form_pass") and subject["acceptable_progress"] and review.visual_gate(subject, review.DIMENSIONS)
                      and export_check["passed"] and engine_check.get("passed") and engine_check.get("runtime_materials_verified"))
            record["export_reviews_passed"] = record.get("export_reviews_passed", []) + ([pid] if passed else [])
            if not passed and record["export_reviews_passed"]:
                record["export_disputed"] = True
            record["game_ready"] = bool(passed and len(record["export_reviews_passed"]) >= 2 and not record.get("export_disputed"))
            record["state"] = "game_ready" if record["game_ready"] else "export_reviewed_incomplete"
            if record["game_ready"]:
                state["phase"] = "game_ready"
            elif state["best_candidate"] == cid:
                state["phase"] = "polish" if record.get("form_pass") else "form"
        elif subject["acceptable_progress"] and not any(i["critical"] for i in subject["discrepancies"]):
            state["best_candidate"] = cid
            record["state"] = "retained"
            metrics = read(folder / "metric.json")
            calibrated = all(r.get("calibrated") and r.get("form_floor") is not None and metrics[v]["iou"] >= r["form_floor"] for v,r in manifest["references"].items())
            passed = review.visual_gate(subject, ("silhouette", "proportions")) and calibrated
            record["form_reviews_passed"] = record.get("form_reviews_passed", []) + ([pid] if passed else [])
            if not passed and record["form_reviews_passed"]:
                record["form_disputed"] = True
            record["form_pass"] = bool(passed and len(record["form_reviews_passed"]) >= 2 and not record.get("form_disputed"))
            state["phase"] = "polish" if record["form_pass"] else "form"
        else:
            record["state"] = "rejected"
            record["form_pass"] = False
            record["game_ready"] = False
            if state["best_candidate"] == cid:
                state["best_candidate"] = record["parent"]
                state["phase"] = "form"
        record["last_recommendation"] = result.get("recommendation", "")
        state["status"] = record["state"]
        write(folder / "candidate.json", record)
        write(run / "run.json", state)
        event(run, "review_ingested", packet=pid, decision=record["state"])
        return status(run)


def export_candidate(run, cid=None):
    run = run_path(run)
    with lock(run):
        state, manifest = read(run / "run.json"), read(run / "manifest.json")
        cid = cid or state["best_candidate"] or state["latest_attempt"]
        if cid not in state["candidates"]:
            raise ValueError("Unknown candidate")
        folder = run / "candidates" / cid
        worker(run, folder / "candidate.blend", folder / "export", "export")
        audit = read(folder / "export" / "audit.json")
        differences = {}
        for v in manifest["protocol"]["views"]:
            a = Image.open(folder / "renders" / f"{v}.png").convert("RGBA")
            b = Image.open(folder / "export" / "renders" / f"{v}.png").convert("RGBA")
            if a.size != b.size:
                raise ValueError("Export render dimensions differ")
            # Foreground union prevents empty backgrounds diluting errors.
            box = ImageChops.lighter(a.getchannel("A"), b.getchannel("A")).getbbox()
            differences[v] = sum(ImageStat.Stat(ImageChops.difference(a,b).crop(box)).mean) / (4*255) if box else 1
        errors = list(audit["errors"]) + list(audit["budget_violations"])
        if any(not o["uv"] for o in audit["objects"]):
            errors.append("Missing UV coordinates")
        if not audit["images"]:
            errors.append("Missing baked atlas")
        if any(max(i["size"]) > manifest["game_budget"]["atlas_size"] for i in audit["images"]):
            errors.append("Atlas exceeds budget")
        if any(x > manifest.get("export_tolerance", .02) for x in differences.values()):
            errors.append("Export render differs from source above tolerance")
        result = {"passed": not errors, "errors": errors, "foreground_rgba_mae": differences, "glb_hash": digest(folder / "export" / "asset.glb"),
                  "source_hash": digest(folder / "candidate.blend")}
        write(folder / "export" / "comparison.json", result)
        event(run, "export_checked", candidate=cid, passed=result["passed"])
        return result


def status(run):
    run = run_path(run)
    state = read(run / "run.json")
    latest = read(run / "candidates" / state["latest_attempt"] / "candidate.json") if state["latest_attempt"] else {}
    return {"run": str(run), "phase": state["phase"], "status": state["status"], "best_candidate": state["best_candidate"],
            "latest_attempt": state["latest_attempt"], "candidates": len(state["candidates"]), "cost": state["cost"],
            "next_repair": latest.get("last_recommendation"), "error": latest.get("error"),
            "next_action": "Request blind evidence packet, submit a plan, or inspect failed step; Python does not spawn assistant sessions."}


def report(run):
    run = run_path(run)
    state, manifest = read(run / "run.json"), read(run / "manifest.json")
    lines = [f"# Art Gauntlet: {state['asset_id']}", "", f"State: **{state['status']}**. Phase: **{state['phase']}**.", "",
             f"Best reviewed candidate: `{state['best_candidate']}`. Latest attempt: `{state['latest_attempt']}`.", "",
             "## Cost", "", "```json", json.dumps(state["cost"], indent=2), "```", "",
             "Calls are conservative dispatch reservations; pixels are a proxy, not a billing estimate.", "", "## Candidates", "",
             "| Candidate | Parent | State | Triangles |", "| --- | --- | --- | --- |"]
    for cid in state["candidates"]:
        folder = run / "candidates" / cid
        record = read(folder / "candidate.json")
        triangles = read(folder / "audit.json")["triangles"] if (folder / "audit.json").exists() else "—"
        lines.append(f"| {cid} | {record['parent']} | {record['state']} | {triangles} |")
    lines += ["", "## Gate limitations", "", "Uncalibrated masks block form readiness. Two fresh visual reviews are required at gates. Engine material compatibility must be verified. Budget compliance or successful export alone never implies accepted art.", "",
              "## Evidence", ""]
    for pid in state["packet_ids"]:
        lines.append(f"- [Review board {pid}](packets/{pid}/board.png)")
    (run / "report.md").write_text("\n".join(lines)+"\n", encoding="utf-8")
    return str(run / "report.md")


def package(run):
    import zipfile
    run = run_path(run)
    with lock(run):
        state = read(run / "run.json")
        verify_inputs(run, state)
        cid = state["best_candidate"]
        if not cid or not read(run / "candidates" / cid / "candidate.json").get("game_ready"):
            raise ValueError("Delivery requires a game-ready reviewed candidate")
        folder = run / "candidates" / cid
        record = read(folder / "candidate.json")
        current_source, current_glb = digest(folder / "candidate.blend"), digest(folder / "export" / "asset.glb")
        if current_source != record["scene_hash"]:
            raise ValueError("Reviewed source changed")
        comparison = read(folder / "export" / "comparison.json")
        if comparison.get("source_hash") != current_source or comparison["glb_hash"] != current_glb:
            raise ValueError("Export comparison no longer matches the delivery")
        for pid in record["export_reviews_passed"]:
            mapping = read(run / "packet_maps" / f"{pid}.json")
            if mapping["export_hash"] != current_glb or mapping["candidate_hash"] != current_source:
                raise ValueError("Delivery changed after visual review")
        report(run)
        bundle = run / "delivery.zip"
        temporary = run / "delivery.tmp"
        selected = [run / "run.json", run / "manifest.json", run / "report.md"]
        for path in (run / "references", run / "reviews", run / "packets", run / "packet_maps", run / "candidates" / cid):
            selected.extend(p for p in path.rglob("*") if p.is_file() and ".godot" not in p.parts)
        hashes = {p.relative_to(run).as_posix(): digest(p) for p in selected}
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED) as archive:
            for p in selected:
                archive.write(p, p.relative_to(run))
            archive.writestr("SHA256.json", json.dumps(hashes, indent=2))
        with zipfile.ZipFile(temporary) as archive:
            if archive.testzip():
                raise ValueError("Delivery archive verification failed")
        os.replace(temporary, bundle)
        return str(bundle)
