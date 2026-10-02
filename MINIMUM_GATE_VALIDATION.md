# Minimum preservation gate — implementation and validation

**Result: passed.** One rigged horse acquired; minimum gate implemented;
both validation directions passed; then exactly one narrow regional edit passed.
No new deer, model-generated candidate, reviewer call, art score, depth/position
pass, pose baseline, or contract extension was used.

## 1. Acquisition before editing

The fixture is the Horse from Quaternius's LowPoly Animated Farm Animal Pack.
The publisher's page and included License.txt declare CC0 1.0. CC0 permits
commercial use and modification. Exact source and license files were extracted
and hashed before any geometry edit. The source has 347 weighted vertices,
28 bones, an armature modifier and no shape keys. It is a coherent low-poly
equine fixture, not a photoreal sculpt or a newly approved game asset.

- [Publisher and license declaration](https://opengameart.org/content/lowpoly-animated-farm-animal-pack)
- [Official CC0 terms](https://creativecommons.org/publicdomain/zero/1.0/)
- [Local provenance and hashes](blender/reference_assets/quaternius_horse/provenance.json)
- [Original included license](blender/reference_assets/quaternius_horse/License.txt)
- [Unmodified acquired Blender scene](blender/reference_assets/quaternius_horse/Horse.blend)

## 2. Implemented scope

- Unlit isolated protected-region ID render: head and remainder, fixed head
  and side cameras. Editable-adjacent faces are excluded from this isolated pass.
- White silhouette matte from the same protected geometry and cameras.
- Exact canonical comparison of protected vertex positions, topology, material
  assignments and shader data, UV/color data, transforms, parents, modifiers,
  bone/rest and current pose data, weights, actions/constraints and shape-key
  inventory/data. This is validated against this horse's actual features;
  no deformation or arbitrary-rig compatibility claim is made.
- A persisted two-consecutive-failure counter checked before Blender dispatch.
  A successful attempt resets the streak; a worker failure counts as failure.

Only eight fixed vertex IDs at the right ear tip may move. All topology,
materials, weights and other vertex positions remain protected. Region lists
are fixed against the hashed source, not recomputed from each candidate.

## 3. Both validation directions

| Fixture | Observed evidence | Required/actual result |
| --- | --- | --- |
| Save/reopen repeat | All protected data equal; all four ID/matte images pixel-identical | PASS |
| Deliberate protected head vertex move | Geometry unequal; head ID changed 669 pixels; head matte changed 237 | REJECT |
| Permitted adjacent ear-tip edit | All protected data equal; all four ID/matte images pixel-identical | ACCEPT |
| Same permitted edit, shadow-only witness | 1,089 changed receiver pixels, max channel delta 209/255 | Does not reject preservation |
| Deliberate weight change | Rig data unequal | REJECT |
| Deliberate material change | Material data unequal | REJECT |
| Deliberate object transform change | Transform data unequal | REJECT |
| Two consecutive failed attempts | State persisted at 2; third attempt blocked before creating output or invoking Blender | STOP |

The permitted edit changed 3,921 pixels in the ordinary beauty render. The
shadow witness hides editable surfaces from the camera while retaining their
shadow casting onto protected surfaces. Its baseline repeat has zero changed
pixels, so the observed shadow change is not repeat-render noise. Beauty and
shadow witness images are validation evidence only, never preservation gates.

![Both validation directions](artifacts/gate_minimum/validation_02/validation_board.png)

![Shadow-only witness](artifacts/gate_minimum/validation_02/shadow_board.png)

Pixel tolerance was fixed at zero before the fixtures and verified by the
repeat capture on this renderer/device. The first validation stopped because
Blender's per-session material `session_uid` changed on reopening, although
images and actual material settings did not. Canonicalization now excludes
that runtime identifier. The initial failed evidence is preserved under
`artifacts/gate_minimum/validation_01`; no tolerance was enlarged.

## 4. Single proof edit, only after validation passed

Moved vertices 107, 108, 109, 110, 116, 117, 118 and 120 by +0.10 source units
on X. Reopened both saved scenes and verified those are the only changed
vertex positions, with that exact delta within floating-point precision.
All four protected ID/matte images are pixel-identical. Protected geometry,
materials, transforms and rig data remain equal. The beauty view changed
1,990 pixels, confirming the local edit is visible. This is a motion-of-scope
proof, not a claim that the ear looks better.

- [Proof-edit Blender scene](artifacts/gate_minimum/validation_02/single_edit/candidate.blend)
- [Actual vertex changes](artifacts/gate_minimum/validation_02/single_edit/actual_vertex_changes.json)
- [Proof result](artifacts/gate_minimum/validation_02/single_edit/result.json)
- [Full validation results](artifacts/gate_minimum/validation_02/validation.json)

## Reproduce

From the repository root, use a fresh output directory:

```powershell
python -m art_gauntlet.minimum_gate validate art_gauntlet/plans/minimum_horse_gate.json artifacts/gate_minimum/new_validation
python -m art_gauntlet.minimum_gate edit artifacts/gate_minimum/new_validation
python -m unittest discover -s art_gauntlet/tests -q
```

The `edit` command refuses failed validation or changed validated baseline/config,
and permits only one proof-edit dispatch. The deliberate failure fixture's stopped
state is retained separately from the fresh single-edit proof state. Existing
evidence directories are not overwritten. All 37 gauntlet tests passed, including
four new tests for persisted stopping, success reset, worker failures, and
step-3-before-edit ordering. Original acquired source hash verified at closeout.

Implementation: [minimum_gate.py](art_gauntlet/minimum_gate.py),
[minimum_worker.py](art_gauntlet/minimum_worker.py),
[fixture configuration](art_gauntlet/plans/minimum_horse_gate.json).

Deferred exactly as requested: depth/position passes, deformation pose baselines,
8/10 approval and dual-review scoring. No changes were made to the retention contract.
