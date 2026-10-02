from .generic import subject, audit
from .generic import apply as apply_common


def apply(manifest, plan):
    for operation in plan.get("operations", []):
        if operation["recipe"] == "build_deer":
            from blender.gauntlet_recipes.deer import build
            build(operation.get("parameters", {}))
        else:
            apply_common(manifest, {"operations": [operation]})
