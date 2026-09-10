# The Intrepid Miner — playable integration

The game now loads **Pass 17** through `scripts/miner_visual.gd`. Launch **Play.cmd**, or open `project.godot` in Godot and press **F5**. The original character controller, collision capsule, interactions, inventory and camera behavior are retained.

![The current character in the claim](artifacts/miner-game/expedition_front.png)

## What was prepared

- Exported an independent game derivative from [the editable art scene](blender/miner_convergence_working.blend). The convergence source and its checkpoints remain intact.
- Consolidated the source objects into eight skinned components: body costume, skin, hair, pack/harness/bedroll, satchel, canteen, pickaxe and travel pan. All eight have independently baked material atlases. Fine hair curves were reduced and converted to mesh; dense cloth shells were reduced.
- Baked color, tangent-space normals and roughness/metallic maps. Body atlas: 2048 square; skin, hair and pack: 1024; the remaining gear: 512. Runtime materials retain wetting/drying behavior. Thin garment and beard surfaces render on both sides.
- Preserved the original bone names and rest transforms exactly. Retained the 21 character clips and the seven existing mining/store clips, for **28 runtime animations**. Locomotion arm tracks were adapted to the reviewed carrying pose; the activity sockets and contact animations were retained.
- Corrected tall boot weights so the shafts follow the calves through deep bends. Fitted the travel pan and pickaxe to the carry grips and moved the pickaxe head outside the boot silhouette. Runtime finger rotations correctly include the bone rest orientation.
- Enabled Godot's generated mesh LODs, reduced the former LOD bias from 8 to 1, and expanded animated culling margins to cover crouching/reaching poses.

The full highest-detail character is **109,425 triangles, eight mesh surfaces**. Import produced **30 additional LOD levels across the eight meshes**. These numbers exclude the separate functional activity props, gold poke and particles. The GLB is approximately 27.4 MB with embedded textures and animation data. This is a single-protagonist source LOD, not a crowd asset.

## Equipment behavior

The pack appears when inventory weight exceeds five pounds. The satchel and canteen are normally worn. The travel pickaxe appears only when owned. The travel pan is carried in the reference hand during locomotion. Carried props clear both hands during activities; panning uses the existing functional two-handed pan and result geometry. Cooking, eating, tending the fire and sleeping stow the travel pack and hip equipment.

For explicit wardrobe/loadout control, call `set_equipment(item, enabled)` on `Walker/Visual`, with one of `wear_pack`, `wear_satchel`, `wear_canteen`, `carry_pickaxe` or `carry_pan`. Call `clear_equipment_override(item)` to restore inventory/activity behavior. The character remains fully clothed with all five disabled. Activity tools still take precedence while an activity is running. The gold poke remains a separate gameplay object driven by gold inventory.

![No travel equipment](artifacts/miner-game/base_front.png)

## Validation

- `tests/miner_game.gd`: **PASS**. Eight atlas surfaces, valid texture bindings, four normalized weights per vertex, live skeleton bindings, LOD presence, all 32 equipment combinations, activity tool transitions, camp stowing and all 28 runtime clips.
- `blender/verify_miner_game.py`: **PASS**. Maximum original/current rest-matrix difference **0**. Actual mesh vertices were evaluated at three times in each of the 21 embedded clips and remained finite; bounds are recorded per component. Visual review caught and corrected the original rigid-boot problem rather than accepting finite coordinates alone.
- `tests/miner_art.gd`: **PASS**. Maximum tested crevice fingertip-to-shaft distance **0.0495 m**; rocker palm-to-crossbar distance **0.0290 m**.
- `tests/milestone_6.gd` and `tests/milestone_6_notes.gd`: **PASS**, including locomotion, water effects, pan sequence, planted feet and panning contacts. The legacy mesh-budget assertion in milestone 6 still concerns the legacy file; the new asset's complete budget is tested separately by `miner_game.gd`.
- `tests/milestone_9.gd`, `tests/milestone_10.gd`, `tests/milestone_11.gd`: **PASS**, covering fishing/camp, store transitions and mining/equipment behavior.

Actual claim captures include [front](artifacts/miner-game/live-front.png), [back](artifacts/miner-game/live-back.png), [profile](artifacts/miner-game/live-profile.png), [face](artifacts/miner-game/live-face.png), [crevicing](artifacts/miner-game/live-crevice.png), [grip](artifacts/miner-game/live-grip.png), [rocker loading](artifacts/miner-game/live-loading.png) and [rocking](artifacts/miner-game/live-rocking.png). Additional fixed-time deformation views include [walking](artifacts/miner-game/walk.png) and [lying down](artifacts/miner-game/lie_down.png); these fixed-time views are pose checks, not complete gameplay sequences.

Machine-readable checks: [runtime](artifacts/miner-game/runtime_audit.json), [mesh deformation](artifacts/miner-game/deformation_audit.json), [export preparation](artifacts/miner-game/prepare_audit.json), [travel grip fitting](artifacts/miner-game/travel_grip_fit.json).

`tests/miner_performance.gd` passed all three 1080p warmed runs on the local RTX 5080, VSync disabled, with 600 measured frames per view:

| View | Median | 95th percentile |
|---|---:|---:|
| Downstream | 3.05 ms | 3.41 ms |
| Moving through water with splashes | 3.29 ms | 3.79 ms |
| Overview | 3.78 ms | 4.18 ms |

All were below the existing **5.5 ms** budget. These are whole-scene measurements on this machine, not a guarantee for other hardware. [Performance log](artifacts/miner-game-performance.log).

## Rebuild

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python blender/export_intrepid_miner.py -- prepare
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python blender/export_intrepid_miner.py -- bake
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python blender/export_intrepid_miner.py -- export
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import --quit
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/miner_game.gd
```

The exporter saves [miner_game_export.blend](blender/miner_game_export.blend), the game [GLB](assets/miner/intrepid/miner.glb), baked PNGs and the generated `grips.gd` resource. It uses prepared/baked checkpoints under `artifacts/miner-game`; run all three stages when changing the art source. Do not edit the derivative as the master source. The GLB embeds its textures, and grip data is preloaded as a script resource so it is included in packaged builds without a special JSON-file export filter. Godot's extracted `miner_*.png` copies are generated files ignored by Git.

## Remaining limits

This completes integration into the existing playable project; it does not establish final reference likeness. Facial anatomy, hands and some cloth/garment intersections remain visibly stylized, especially at close range. Existing activity motion also remains stylized; it has not been replaced with a new animation set. Lower-end hardware and a distributable release build have not been validated by this integration.

The local engine logs retain the pre-existing Windows root-certificate warning, renderer shutdown texture-RID warning and store-test ObjectDB shutdown warnings. Functional checks pass; these logs are not warning-free.
