"""Blind evidence packets and discrepancy-first, fail-closed visual gates."""
import math
import random
import shutil
import uuid
from pathlib import Path
from PIL import Image, ImageDraw, ImageOps
from .storage import digest, fingerprint, read, write

DIMENSIONS = ("silhouette", "proportions", "identity", "materials", "detail_integration")
RUBRIC = {
    "version": "discrepancy-first-1",
    "instructions": "Judge each subject against the references independently. List discrepancies before scoring. A/B order is random. Do not infer which is newer. Request more evidence if needed. Do not force a passing score. acceptable_progress means the subject is worth retaining as a viable next working checkpoint relative to the other subject (or a coherent starting point when alone); it does not mean the 8/10 target has passed. Scores and discrepancies independently determine that gate. Explain relative strengths and regressions in the recommendation.",
    "anchors": {"4": "Large discrepancies dominate", "6": "Coherent, important mismatches", "8": "Strong agreement with only localized minor differences", "10": "No meaningful discrepancy at this scale"},
    "severity_caps": {"major": 6, "moderate": 7.5, "minor": 10},
    "dimensions": DIMENSIONS,
}


def board(rows, views, path):
    width = 1600
    cell = width // len(views)
    height = 32 + len(rows) * (cell + 32)
    canvas = Image.new("RGB", (width, height), "#e4e2dd")
    draw = ImageDraw.Draw(canvas)
    for i, view in enumerate(views):
        draw.text((i*cell+8, 8), view, fill="black")
    for row, (label, paths) in enumerate(rows):
        y = 32 + row*(cell+32)
        for i, view in enumerate(views):
            draw.text((i*cell+8, y+4), label, fill="black")
            im = Image.open(paths[view]).convert("RGBA")
            if im.getbbox():
                im = im.crop(im.getbbox())
            im = ImageOps.contain(im, (cell-16, cell-16))
            canvas.paste(im, (i*cell+(cell-im.width)//2, y+28+(cell-16-im.height)//2), im)
    canvas.save(path)


def make_packet(run, candidate, kind="source", second=False):
    run = Path(run)
    state = read(run / "run.json")
    manifest = read(run / "manifest.json")
    packet_id = uuid.uuid4().hex
    public = run / "packets" / packet_id
    public.mkdir(parents=True)
    cdir = run / "candidates" / candidate
    view_names = list(manifest["references"])
    subjects = [candidate]
    best = state.get("best_candidate")
    if best and best != candidate and kind == "source":
        subjects.append(best)
    random.SystemRandom().shuffle(subjects)
    mapping = dict(zip(("A", "B"), subjects))
    rows = [("REFERENCE", {v: run / "references" / f"{v}.png" for v in view_names})]
    for label, cid in mapping.items():
        folder = run / "candidates" / cid
        folder = folder / "export" / "renders" if kind == "export" else folder / "renders"
        rows.append((label, {v: folder / f"{v}.png" for v in view_names}))
    board(rows, view_names, public / "board.png")
    # Critical detail views are always included, not just those declared edited.
    evidence = ["board.png"]
    for label, cid in mapping.items():
        folder = run / "candidates" / cid
        folder = folder / "export" / "renders" if kind == "export" else folder / "renders"
        for v in manifest["protocol"].get("details", []):
            name = f"{label}_{v}.png"
            shutil.copy2(folder / f"{v}.png", public / name)
            evidence.append(name)
    if kind == "export":
        for v in ("close", "gameplay"):
            name = f"engine_{v}.png"
            shutil.copy2(cdir / "godot" / f"{v}.png", public / name)
            evidence.append(name)
    hashes = {name: digest(public / name) for name in evidence}
    packet = {"packet_id": packet_id, "rubric": RUBRIC,
              "target": manifest["target"], "views": view_names,
              "reference_notes": {v: manifest["references"][v].get("notes", "") for v in view_names},
              "subjects": list(mapping), "evidence": hashes,
              "review_schema": {"packet_id": packet_id, "evidence_hash": fingerprint(hashes),
                  "reviewer_id": "unique fresh reviewer/session identity", "inspected": evidence,
                  "subjects": {label: {"scores": {d: {v: 0 for v in view_names} for d in DIMENSIONS},
                        "discrepancies": [{"dimension": "proportions", "view": view_names[0], "region": "head", "severity": "major", "description": "specific visible mismatch", "critical": False}],
                        "confidence": "high", "acceptable_progress": False} for label in mapping},
                  "additional_evidence": [], "recommendation": "specific next repair"}}
    write(public / "packet.json", packet)
    # Private mapping is outside the reviewer folder. Reviewers receive only
    # packet.json and its listed images, never the candidate or run directory.
    write(run / "packet_maps" / f"{packet_id}.json", {"candidate": candidate, "mapping": mapping, "kind": kind, "second": second,
          "evidence_hash": fingerprint(hashes), "candidate_hash": digest(cdir / "candidate.blend"),
          "export_hash": digest(cdir / "export" / "asset.glb") if kind == "export" else None})
    pixels = sum(Image.open(public / name).width * Image.open(public / name).height for name in evidence)
    return public, len(evidence), pixels


def validate_review(review, packet):
    if review.get("packet_id") != packet["packet_id"] or review.get("evidence_hash") != fingerprint(packet["evidence"]):
        raise ValueError("Review does not match this evidence packet")
    if not isinstance(review.get("reviewer_id"), str) or not review["reviewer_id"].strip():
        raise ValueError("Reviewer identity is required")
    if set(review.get("inspected", [])) != set(packet["evidence"]):
        raise ValueError("All required evidence must be inspected")
    if set(review.get("subjects", {})) != set(packet["subjects"]):
        raise ValueError("Every anonymous subject needs its own assessment")
    if not isinstance(review.get("additional_evidence"), list):
        raise ValueError("additional_evidence must be a list")
    result = {}
    for label, subject in review["subjects"].items():
        if subject.get("confidence") not in {"high", "medium", "low"}:
            raise ValueError("Missing confidence")
        if type(subject.get("acceptable_progress")) is not bool:
            raise ValueError("acceptable_progress must be boolean")
        discrepancies = subject.get("discrepancies")
        if not isinstance(discrepancies, list):
            raise ValueError("Discrepancies must be recorded, including an explicit empty list")
        for issue in discrepancies:
            if issue.get("dimension") not in DIMENSIONS or issue.get("view") not in packet["views"] or issue.get("severity") not in RUBRIC["severity_caps"]:
                raise ValueError("Invalid discrepancy dimension, view or severity")
            if not issue.get("description") or not issue.get("region") or type(issue.get("critical")) is not bool:
                raise ValueError("Discrepancy lacks location, description or critical flag")
        scores = subject.get("scores", {})
        if set(scores) != set(DIMENSIONS):
            raise ValueError("Missing dimension scores")
        capped = {}
        for dimension in DIMENSIONS:
            if set(scores[dimension]) != set(packet["views"]):
                raise ValueError("Missing per-view scores")
            cap = min([10] + [RUBRIC["severity_caps"][i["severity"]] for i in discrepancies if i["dimension"] == dimension])
            capped[dimension] = {}
            for view, score in scores[dimension].items():
                if type(score) not in (int, float) or not math.isfinite(score) or not 0 <= score <= 10:
                    raise ValueError("Scores must be finite numbers from 0 to 10")
                capped[dimension][view] = min(score, cap)
        result[label] = {**subject, "scores": capped}
    return {**review, "subjects": result}


def visual_gate(subject, dimensions):
    return (subject["confidence"] != "low" and not any(i["critical"] for i in subject["discrepancies"])
            and all(min(subject["scores"][d].values()) >= 7 and sum(subject["scores"][d].values()) / len(subject["scores"][d]) >= 8 for d in dimensions))
