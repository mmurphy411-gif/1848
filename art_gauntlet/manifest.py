import math
import re
from pathlib import Path
from .storage import ROOT, contained, read


def validate(data, root=ROOT):
    if data.get("schema_version") != 1:
        raise ValueError("Unsupported manifest schema")
    if not re.fullmatch(r"[a-z][a-z0-9_]*", data.get("asset_id", "")):
        raise ValueError("asset_id must be a stable lowercase identifier")
    if data.get("adapter") not in {"deer", "trout", "generic"}:
        raise ValueError("Unknown adapter")
    source = contained(root, data["source"])
    if not source.is_file():
        raise ValueError(f"Missing source: {source}")
    protocol = data["protocol"]
    if not protocol.get("version") or not protocol.get("views"):
        raise ValueError("A versioned camera protocol is required")
    for view, settings in protocol["views"].items():
        if not re.fullmatch(r"[a-z_]+", view):
            raise ValueError("Invalid view identifier")
        for key in ("eye", "target"):
            if len(settings[key]) != 3 or not all(math.isfinite(x) for x in settings[key]):
                raise ValueError("Camera coordinates must be finite 3-vectors")
        if not math.isfinite(settings["scale"]) or settings["scale"] <= 0:
            raise ValueError("Camera scale must be positive")
    for name, ref in data["references"].items():
        if name not in protocol["views"]:
            raise ValueError(f"Reference has no camera: {name}")
        if not contained(root, ref["path"]).is_file():
            raise ValueError(f"Missing reference: {ref['path']}")
        box = ref["crop"]
        if len(box) != 4 or box[0] < 0 or box[1] < 0 or box[2] <= box[0] or box[3] <= box[1]:
            raise ValueError("Reference crops must have positive area")
    if not data["references"]:
        raise ValueError("At least one explicit reference is required")
    for key in ("max_candidates", "max_minutes", "max_model_calls", "max_review_images"):
        value = data["budget"][key]
        if not isinstance(value, (int, float)) or not math.isfinite(value) or value <= 0:
            raise ValueError(f"Invalid budget: {key}")
    for key in ("max_triangles", "max_materials", "max_objects", "atlas_size"):
        if not isinstance(data["game_budget"][key], int) or data["game_budget"][key] <= 0:
            raise ValueError(f"Invalid game budget: {key}")
    return data


def load(path):
    return validate(read(Path(path)))
