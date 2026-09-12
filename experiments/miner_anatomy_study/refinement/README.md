# Miner refinement — hair and costume

This checkpoint has been superseded by the [finished editable miner](../../../blender/miner_finished.blend) and its [playable integration](../../../MINER_GAME_INTEGRATION.md). The remaining-work notes below record the state of this earlier study.

The retained scene is **miner_refined.blend**. It continues the previous anatomical head study and contains the full editable miner, the original rig/actions, packed texture images, and review cameras. It is a Blender art checkpoint; the playable game still uses its existing export.

![Previous study and current refinement](comparison.png)

## Changes

- Replaced the thick strand geometry with layered transparent hair cards and a textured undercoat. Visible source hair vertices fall from **90,720 to 10,780** (88.1% fewer). The result has denser coverage and softer strand edges. This count excludes the retained beard and hidden previous groom. Alpha overdraw and runtime performance have not been measured.
- Increased use of the side projection around the temples to reduce the front texture's stray hair/shadow artifacts. The retained anatomical head geometry and eyes are unchanged.
- Rebuilt the neckerchief with several gathered folds, unequal tails and a cloth knot; replaced the stiff shirt collar pieces with curved surfaces. The wrap blends between Chest and Neck. The knot and tails follow the chest, and the lower tails fit the shirt surface.
- Simulated two loose sleeve tubes over arm collision forms for 64 frames. Direct use of those tubes was rejected because the shoulders/cuffs did not fit the existing costume. The final sleeves transfer the simulated fold displacement onto copies of the original fitted sleeves, retaining their original shoulder/cuff joins and skin weights. Broad test-tube shrinkage is removed so the existing garment keeps its volume. The result is frozen rest geometry, not a runtime cloth simulation.
- Added generated woven linen, faded red scarf, dark waistcoat fabric and cracked leather detail. These materials use stable rest-space UV coordinates and local dirt masks. Added a warmer, matte brown felt treatment to the hat.

## Review and verification

[Torso comparison](comparison.png) · [Hair comparison](hair_comparison.png) · [Full character](full_comparison.png) · [Back](back_comparison.png).

[verification.json](verification.json) records:

- Original bone rest matrices match exactly, and all **21 animation clips** retain their curves, keyframes and handles.
- All **292 original mesh geometry records** remain intact inside the derivative; superseded surfaces are hidden. New fitted sleeves are separate copies.
- All ten new visible meshes have valid bone groups and normalized weights.
- Evaluated vertices remain finite at three times in each animation: **63 samples**.

Rendered [walking](pose_walk_full.png), [panning](pose_pan_swirl_torso.png), and [lying down](pose_lie_down_torso.png) samples received visual review. Those images exposed the scarf fitting issue addressed during this refinement. Finite-vertex checks are limited compatibility checks; they do not establish full deformation, collision, or game-runtime acceptance.

## Remaining limits

Hair tips still have a somewhat regular outline; finer flyaways, additional curl variation and proper export alpha settings need attention. Cloth construction remains stylized, especially the knot, collar, shoulder masses and shirt front. The scarf has static skinning, so it does not settle under gravity in every pose. Some projection mismatch remains near the ears/temples.

The hands, forearm transitions, trousers, boot construction and pack still lag behind the head and upper-body materials. The existing source art master's wrist/boot issues are visible in some pose previews. Full production integration requires baking the material graphs, configuring hair transparency, regenerating LODs, and running the game's existing integration/performance checks. No runtime or credit-saving claim is made here.

## Assets and reproduction

Two new images were produced with the **built-in imagegen tool**, without an API/CLI fallback: [hair_atlas.png](hair_atlas.png), with genuine alpha, and [fabric_atlas.png](fabric_atlas.png). [Exact prompts](imagegen_prompts.json). The earlier MakeHuman anatomy provenance and face projection sources remain documented in the [parent study](../README.md).

From the repository root:

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/miner_anatomy_study/refinement/simulate_sleeves.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/miner_anatomy_study/refinement/run_refine.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/miner_anatomy_study/refinement/run_refine.py -- --baseline
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/miner_anatomy_study/refinement/verify.py
python experiments/miner_anatomy_study/refinement/compare.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python experiments/miner_anatomy_study/refinement/package.py
```

The supplied `sleeve_drape.json` can be reused to skip simulation. All comparisons use matching cameras/lighting and unretouched Blender renders. The previous study, original art master and game GLB remain separate.
