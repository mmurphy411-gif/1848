# Miner art pass — September 9, 2026

The miner now has a shaped jaw and nose bridge, inset eyes and eyelids, ears,
separate moustache and a beard surface following the jaw. Sleeves taper into
rounded shoulders, folds gather near the tuck and cuffs, and the shirt has a
collar, placket and buttons. Suspenders and shirt details share the torso's skin
weights. Boots have separate welt and sole layers. The body is **19,828
triangles**, within the existing 20,000-triangle limit.

The old rectangular pack is replaced by a **2,436-triangle canvas knapsack**:
filled gussets, overlapping flap, bound seams, leather shoulder and closure
straps, buckles and carry loop. Inventory still controls its visibility and
fullness. It follows the chest; there is no cloth simulation.

Mining fingers now curl from their knuckles. Crowbar, shovel and pick shafts
align with the two hand grips. Rocker wrists follow the moving crossbar's arc.
The existing skeleton rest joints, pan sockets and panning trajectories are
preserved. Skin uses a softer material response and no cloth normal map;
cloth and beard normal strength are reduced. Temporal antialiasing reduces the
shadow speckling visible on small curved surfaces.

## In-game review

These are real claim-scene captures from `tests/miner_art_capture.gd`:

| View | Findings |
| --- | --- |
| [Standing](artifacts/miner-art-front.png) | Narrower sleeves, shoulder transitions, shirt construction and distinct boot soles read at gameplay distance. |
| [Face](artifacts/miner-art-face.png) | Facial features are now present and the nose is part of the head surface. Eyelids, moustache and beard boundary still read as stylized geometry in this close-up. |
| [Back](artifacts/miner-art-back.png) | Rounded pack, flap, seams and buckles replace the box silhouette. Fabric and straps remain relatively stiff. |
| [Profile](artifacts/miner-art-profile.png) | Pack depth and attachment are visible. More irregular canvas wear and softer facial-hair edges remain useful future work. |
| [Crevice](artifacts/miner-art-crevice.png) | Both hands surround the shaft while the toe stays at the bedrock seam. |
| [Hands](artifacts/miner-art-grip.png) | Fingers curl around the iron instead of hanging open. Thumb anatomy and the palm-to-finger transition still need refinement. |
| [Loading](artifacts/miner-art-loading.png) | Hands share the tool shaft. A convincing digging and material-transfer motion is still a separate animation improvement. |
| [Rocking](artifacts/miner-art-rocking.png) | Hands follow the crossbar; the pack and tailored shirt remain readable while working. |
| [Pan lift](artifacts/milestone-6-pan-lift.png) | The original pan trajectory and rim contact survive the mesh update. The extreme close-up still exposes stretched palm/finger transitions in the existing pan grip. |

The pack and grip changes are the clearest improvements. The face remains the
largest gap to a realistic character; passing geometry/contact checks does not
constitute final art acceptance. Lambert and environment meshes retain their
previous art.

## Verification

- Milestones 6, 6 notes, 9, 10 and 11: pass.
- `tests/miner_art.gd`: pass. Maximum crevice fingertip distance from the shaft
  centerline is 4.95 cm; maximum palm-center distance from the rocker crossbar
  is 2.90 cm over a complete cycle. These are contact envelopes, not exact
  collision tests for every finger vertex.
- `tests/miner_performance.gd`, RTX 5080, 1920×1080, VSync off, 600 warmed
  frames per view, temporal antialiasing enabled: downstream p95 **3.69 ms**,
  moving wade **4.00 ms**, overview **4.47 ms**. Other GPUs were not measured.
- All eight final art views were opened and reviewed. The existing pan capture
  harness also checks the unchanged pan sequence in the updated character.
- Godot reports the existing root-certificate and shutdown resource warnings
  in this environment; the regression suites exit successfully.

## Rebuild and inspect

Run Blender in background mode with `blender/build_pack.py`, then
`blender/build_miner.py`, then `blender/build_mining_animation.py`. The main
miner builder imports `blender/miner_detail.py`; the `.blend` sources retain
the rig and inspectable geometry. Existing atlas packing instructions remain
in [blender/README.md](blender/README.md). This review reuses the accepted body
and beard atlases, pan and poke assets.

Import through Godot, then run:

```powershell
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import --quit
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/miner_art.gd
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/miner_art_capture.gd
```

The capture harness's optional `-- --diagnostics` isolates shadows and indirect
lighting in additional face captures. Those diagnostic lighting overrides do
not change gameplay settings. The final captures use the normal scene lighting.
