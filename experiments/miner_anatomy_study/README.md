# Miner head study — 12 September 2026

The integrated result is now [miner_finished.blend](../../blender/miner_finished.blend), documented in [MINER_GAME_INTEGRATION.md](../../MINER_GAME_INTEGRATION.md). The [hair and costume refinement](refinement/README.md) and this page preserve the preceding studies; statements about pending integration below describe those historical checkpoints.

The original head-study result is **miner_anatomy_candidate.blend**. It is an editable Blender art study containing the full miner with a rebuilt head, packed front/profile projection images, review cameras, and the original rig and actions. The playable game still uses its existing exported asset.

![Before and after](comparison.png)

## What improved

- Replaced the separate head, eyelid, lip, nostril, ear and beard-shell construction with a connected anatomical head/neck surface derived from MakeHuman's core mesh. Adult shape targets provide the starting anatomy; the fit follows the existing miner's eye height, head size, hat and scarf opening.
- Added spherical eyes within the anatomical eyelids and weighted the neck transition to the existing Neck and Head bones.
- Used the built-in imagegen tool to derive front and side projection sources from the supplied fictional miner concept. Both images are packed in the Blender file. Vertex masks blend the projections across the cheeks and temples; the original anatomical UV layout remains available for baking.
- Replaced the broad hair strips with tapered wavy strand groups and added short beard growth following the facial surface.

This produces a substantial visible improvement in facial structure and surface detail. It does not establish final likeness or measured token/credit savings. The generated source portraits are intermediate texture inputs; all comparison and pose images are actual Blender renders.

## Review

- [Close comparison](comparison.png), [full character](full_comparison.png), [profile comparison](profile_comparison.png), [three views](turnaround.png).
- [Walking](pose_walk_full.png), [panning neck pose](pose_pan_swirl_face_quarter.png), [lying down head pose](pose_lie_down_face_quarter.png).
- [Verification](verification.json): all original rest matrices match exactly; all 21 source animation names/ranges are retained; 129 costume/gear/body meshes have unchanged vertex coordinates. All seven added meshes have valid bone groups and normalized weights. Their evaluated vertices remain finite at three points in each animation, totaling 63 pose samples.

The rendered samples also received visual inspection. These checks establish limited source-rig compatibility, not complete animation, collision, or game-runtime acceptance. The source art master's existing rigid-boot defect is visible in the walking sample; the production exporter has a separate boot correction described in the existing MINER_GAME_INTEGRATION.md.

## Remaining work

The hair remains too stringy and needs a denser groom and economical game representation. There is residual blending/feature mismatch near the temples and ears, and some light/shadow information remains in the generated images. The back of the head has simpler coverage. Eyelid/iris positioning and exact concept likeness can improve further. This study has no new facial animation controls.

The face now exposes how unfinished the shirt, scarf, hat and gear materials look beside it. Clothing construction is the next substantial art task. Before integration, bake the blended materials, reduce hair geometry, regenerate production LODs, and run the existing export/runtime checks. The new hair alone has 90,720 source vertices; this is not a game budget claim.

## Sources and reproduction

MakeHuman core assets are [CC0](https://static.makehumancommunity.org/about/license.html). The base mesh and used shape targets are from commit `a8bc2d54ff0ac92e78ff71431b1023eda42bf482` of [makehumancommunity/makehuman](https://github.com/makehumancommunity/makehuman/tree/a8bc2d54ff0ac92e78ff71431b1023eda42bf482). The downloaded license files, source data and hashes are in `source/` and [provenance.json](provenance.json). Only graphical data is incorporated into the mesh.

[Exact imagegen prompts and inputs](imagegen_prompts.json). Two built-in imagegen calls were used; no API/CLI fallback. Both final images are saved here as `face_projection_source.png` and `side_projection_source.png`.

From the repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/miner_anatomy_study/run.py -- --textured
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/miner_anatomy_study/run.py -- --baseline
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/miner_anatomy_study/verify.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/miner_anatomy_study/pose_preview.py
python experiments/miner_anatomy_study/compare.py
```

The first exploratory import of the legacy helper executed its stage-zero dispatcher, regenerating the legacy baseline inventory and four baseline renders. Its original baseline `.blend` was restored from its automatic backup. The study now explicitly disables that dispatcher during import. The retained art master and current game GLB were not edited.
