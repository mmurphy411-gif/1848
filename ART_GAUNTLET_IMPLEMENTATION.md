# Art Gauntlet — implementation and trial results

September 10, 2026. **The runner is usable; neither animal is certified game-ready.**

Start with [`art_gauntlet/README.md`](art_gauntlet/README.md). The module uses the
deer and rainbow trout manifests and shared Blender recipes. No original art
scene or live game asset was replaced.

## Implemented

- Manifest-driven capture, exact reference crops, configurable cameras,
  silhouettes, critical close-ups and geometric audits.
- Isolated candidates, immutable originals, atomic records, OS-owned locks,
  explicit best/parent pointers and resumable failures.
- Hash-verified whole-job reuse and per-view capture checkpoints.
- Inspectable paper-background masks, IoU, outline distance and geometric bands.
- Blind review packets, evidence validation, discrepancy caps, fresh gate
  confirmations, rejection and rollback.
- World-space deformation, reduction and shared base-color atlas baking.
- glTF export/reimport, budget/UV/texture checks and image comparison.
- Isolated Godot capture with existing fish or wildlife material bindings.
- Reports, dispatch/image budgets and delivery ZIPs guarded by completed gates.

The assistant drives artistic exchanges through files. `run` initializes the
workflow and returns its next request; Python does not independently invoke model
sessions. This boundary is explicit in the CLI and README.

## Real trout trial

| Check | Existing source | Reduced and baked experiment |
| --- | ---: | ---: |
| Evaluated triangles | 36,686 | 10,425 |
| Materials | 12 | 1 |
| Visible mesh objects | 32 | 32 |
| Export/reimport technical checks | Failed | Passed |
| Visual acceptance | Rejected | Incomplete; rejected engine appearance |

The experiment reduced triangles by approximately **71.6%** and fit the
provisional 12,000-triangle, two-material, 40-object and 2048-pixel atlas ceilings.
The object ceiling is an inspection default, not an established shipping target.

The reduced export's foreground RGBA mean absolute difference, normalized to
0–1, ranged from **0.00205 to 0.00569** across five views, below the 0.02 tolerance.
This measures export fidelity to the reduced source, not reference likeness or
preservation of every original shader effect.

The original source failed on triangles, materials, UVs and export appearance.
A fresh blind reviewer also found major mouth and feature-integration defects,
so the runner did not retain it as an accepted candidate.

The reduced candidate imported and rendered in Godot 4.7.2. The existing fish
shader bound the shared fish atlas to its newly packed UVs, creating stretched
dark marks and a broad transverse pink band. A second fresh reviewer rejected
that appearance and flagged remaining anatomy problems. The run is explicitly
**`export_reviewed_incomplete`**. No derivative was installed into the game.

Local evidence under the existing ignored `artifacts/` convention:

- [Original trout run](artifacts/gauntlet/rainbow_trout/20260910-172853-3effcf/report.md)
- [Reduced trout run](artifacts/gauntlet/rainbow_trout/20260910-173331-51bcf2/report.md)
- [Export comparison](artifacts/gauntlet/rainbow_trout/20260910-173331-51bcf2/candidates/c96648e0ee18/export/comparison.json)
- [Godot close-up](artifacts/gauntlet/rainbow_trout/20260910-173331-51bcf2/candidates/c96648e0ee18/godot/close.png)
- [Blind export review](artifacts/gauntlet/rainbow_trout/20260910-173331-51bcf2/reviews/16c2f5d01ea94fe8898d905d6ecb3ae2.json)

These artifacts are local, not portable through Git alone. Successful delivery
bundles include evidence; an incomplete experiment has no shipping bundle.

## Deer and calibration

The same runner captured the deer at **852,016 evaluated triangles** without
species branches in the workflow or render worker. It remains awaiting visual
review; this was a reuse/capture test, not a claimed art gate.

[Deer capture report](artifacts/gauntlet/deer/20260910-173854-f12d53/report.md).

Review exposed a reversed trout dorsal camera and unsuitable white-background
masking for beige paper. Cameras now support explicit roll; segmentation estimates
paper color from the crop boundary. Parameter trials showed that tolerance 15
preserved pale fins better than 45. Older runs retain their original evidence;
current manifests use the corrected setting.

The manifests remain **uncalibrated**. Form readiness stays blocked until masks,
projection conflicts and per-view floors are checked against concrete anchors.
The trout's illustrated top view shows a broad tail inconsistent with a natural
vertical tail; blindly maximizing overlap would damage anatomy.

## Verification

- **31 Python tests passed:** metrics, stale/missing evidence, severity caps,
  budgets, failures, best-parent selection, cache reuse/corruption recovery,
  confirmation disputes, engine vetoes, a complete synthetic review chain,
  ZIP integrity and rejection of an export changed after review.
- **Four real Blender fixture checks passed:** buried eye rejected, exposed eye
  accepted, detached component rejected, rigged geometry refused by static reduction.
- **Both current manifest/source audits passed**, including configured connectivity
  and visibility checks.
- Real captures completed for both species; real trout export/reimport and Godot
  inspection completed. The runs verify original scene/reference hashes.

```powershell
python -m unittest discover -s art_gauntlet/tests -v
& "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python art_gauntlet/tests/blender_checks.py
& "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --factory-startup --python-exit-code 1 --python art_gauntlet/tests/audit_sources.py
```

Observed Blender worker times were about 13.5 seconds for initial trout capture,
50.9 seconds for reduction/baking/capture, and 17.5 seconds for deer capture.
These exclude review and orchestration and are not comparative speedup claims.
Restricted cache-directory warnings did not prevent completion on the recorded GPU.

## Remaining scope

Next resolve the candidate atlas binding to the game fish material, then repair
the trout mouth, cheeks and fin insertions. The module detects the integration
failure but does not change gameplay bindings.

Concept-only block-outs and a bear trial, automatic parameter search, high-to-low
normal/fur transfer, richer landmarks and rig/loadout support remain unimplemented.
The current base-color bake intentionally does not preserve procedural roughness,
translucency or normal detail. Visual review remains essential.
