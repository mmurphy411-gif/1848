# The Intrepid Miner — finished asset and playable integration

The game loads the completed miner through `scripts/miner_visual.gd`. Launch **Play.cmd**, or open `project.godot` in Godot and press **F5**. The editable master is [miner_finished.blend](blender/miner_finished.blend); the baked runtime derivative is [miner_game_export.blend](blender/miner_game_export.blend).

![Miner in the claim](artifacts/miner-game/expedition_front.png)

## Character and materials

- Connected anatomical head and neck, fitted eyes, blended front/profile reference textures, short beard growth, and layered hair cards with real strand transparency.
- Folded scarf, soft collar, fitted sleeve drape, worn felt hat, linen shirt, dark waistcoat, brown cotton trousers, leather boots, canvas pack, wool bedroll, and worn leather harness and hip equipment.
- Continuous anatomical hands and forearms fitted from the CC0 source through local bone frames. Established grip weights are transferred and smoothed over the topology, with an explicit forearm-to-hand transition. The wrist and palm have one connected surface.
- Corrected the seven panning clips. Wrists move up to 4 cm toward the pan so all five fingers can reach without separating their joints. Elbows approach from outside the torso and forearm roll follows the palm, removing the half-turn that collapsed wrist skin. A three-segment finger solver fits each attached chain around the outer lip. The pan keeps its original world motion throughout the sequence.
- Tall boot shafts and collars follow the calves. Carried tools use the existing grip corrections and clear the hands during activities.
- Eight independently skinned components and atlas surfaces: Body, Skin, Hair, Pack, Satchel, Canteen, Pickaxe, TravelPan. Source projection UVs survive until baking, then each component exports only its GameUV atlas.
- Body, skin and hair atlases are 2048 square; pack is 1024; other gear is 512. Color, tangent normals and roughness/metallic are baked. Hair opacity is baked into albedo alpha and clipped in the opaque depth pass. Wetting/drying remains active on the costume and fabric/leather gear.

The final asset has **116,477 triangles**, below the **120,000** limit, **eight surfaces**, **30 generated LOD levels**, and **30 runtime animations**: 21 embedded character clips plus nine store, mining and expedition clips. The GLB is approximately 34 MB with embedded textures and animations. The controller, collision capsule, inventory and activity sockets use their established contracts. These geometry counts exclude separate functional activity props, particles and the gold poke.

## Equipment

The pack appears above five pounds of inventory. Satchel and canteen are normally worn; the pickaxe appears when owned. The travel pan is carried during locomotion. Fishing and other activities clear the carried tools; panning uses the functional two-handed pan. Cooking, eating, tending the fire and sleeping stow the pack and hip equipment.

Call `set_equipment(item, enabled)` on `Walker/Visual` with `wear_pack`, `wear_satchel`, `wear_canteen`, `carry_pickaxe` or `carry_pan`. `clear_equipment_override(item)` restores inventory/activity behavior. All 32 combinations preserve the core clothed character.

## Verification

The final-run evidence lives under [artifacts/miner-finished](artifacts/miner-finished).

- [Runtime audit](artifacts/miner-game/runtime_audit.json): eight surfaces, triangle budget, valid atlas bindings, imported transparent/opaque hair coverage, normalized four-bone weights, live skeleton bindings, LODs, equipment transitions and all 30 clips.
- [Source verification](artifacts/miner-finished/source_verification.json): original rest matrices remain unchanged; curves outside the 37 corrected panning arm, hand, finger and pan-socket bones remain unchanged. The panning fit records pan-transform error below 0.00001 and wrist adjustment at or below 4 cm. Both reconstructed hands are single connected surfaces with normalized weights.
- Imported panning regression checks limit wrist bend and skin rotation to 130 degrees and finger-joint separation to 1 mm. The existing panning contact test requires every fingertip to stay within 3 cm of the rim through all three wash cycles. The actual pan-result close-up is also reviewed for surface folds and fingers intersecting the bowl.
- [Deformation audit](artifacts/miner-game/deformation_audit.json): actual exported mesh vertices evaluated at three times in every embedded clip, with finite coordinates and recorded bounds. Rest-matrix maximum difference is zero.
- [Mining contact checks](artifacts/miner-finished/miner_art.log): crevice fingertips within 0.0495 m of the shaft and rocker palms within 0.0290 m of the crossbar. These numerical checks are supplemented by the rendered live grip review.
- `miner_game`, `miner_art`, `milestone_6`, `milestone_6_notes`, `milestone_9`, `milestone_10`, and `milestone_11` all **PASS** against the final asset, covering locomotion, water effects, pan sequence/contact, fishing/camp, store and mining transitions.

Rendered review: [face](artifacts/miner-game/face.png), [back](artifacts/miner-game/expedition_back.png), [walking](artifacts/miner-game/walk.png), [sleep pose](artifacts/miner-game/lie_down.png), [live crevice grip](artifacts/miner-game/live-grip.png), [rocking](artifacts/miner-game/live-rocking.png), [live panning](artifacts/milestone-6-pan-swirl.png), [pan result](artifacts/milestone-6-pan-lift.png). Fixed-time activity screenshots are deformation checks; the separate live captures exercise the gameplay state machines.

## Performance result

The current whole-scene 1080p **5.5 ms p95 gate has not passed consistently** on this RTX 5080. Two full-character runs and a control with miner visuals hidden produced:

| View | First run median / p95 | Repeat median / p95 | Miner hidden median / p95 |
|---|---:|---:|---:|
| Downstream | 3.33 / 4.79 ms | 3.28 / 4.60 ms | 3.27 / 5.83 ms |
| Moving wade | 3.51 / 5.08 ms | 4.92 / 6.84 ms | 4.73 / 6.44 ms |
| Overview | 4.04 / 5.73 ms | 4.05 / 5.38 ms | 4.05 / 5.46 ms |

Each cell measures 600 warmed frames, VSync off. [First log](artifacts/miner-finished/performance.log), [repeat](artifacts/miner-finished/performance-repeat.log), [hidden-miner control](artifacts/miner-finished/performance-control.log). The control shows the spikes are not confined to rendering this character; it does not establish their root cause. No passing result is claimed from median frame times alone.

The [last performance run](artifacts/miner-finished/performance-final.log), before the final panning-animation correction, measured median / p95 **3.24 / 5.99 ms** downstream, **3.44 / 6.11 ms** moving through water and **3.76 / 5.93 ms** in the overview. This run also fails the existing p95 gate. Functional integration and geometry checks pass; whole-scene frame-time acceptance remains open.

## Source and rebuild

The head and hands use MakeHuman graphical data under CC0, with source files, licenses, commit and hashes preserved in the [anatomy study provenance](experiments/miner_anatomy_study/provenance.json). The face/profile, hair and fabric images were generated using the built-in imagegen tool in the preceding studies. Exact prompts and source images are retained in the [head study](experiments/miner_anatomy_study/README.md) and [hair/costume study](experiments/miner_anatomy_study/refinement/README.md). This finishing pass reuses those images; all gameplay/review screenshots are rendered evidence.

`miner_finished.blend` preserves editable components, the original rig, corrected actions, hidden earlier surfaces, review cameras and packed images. Earlier checkpoints remain intact. `experiments/.gdignore` prevents study Blender files from interrupting runtime GLB import.

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python blender/finish_miner.py
foreach ($stage in @('prepare', 'bake', 'export')) {
    & 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python blender/export_intrepid_miner.py -- $stage
}
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import --quit
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/miner_game.gd
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python blender/verify_miner_game.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python-exit-code 1 --python blender/package_finished_miner.py
```

The finish builder starts from the retained `experiments/miner_anatomy_study/refinement/miner_refined.blend`. The exporter writes the game GLB, embedded textures, standalone baked PNGs and `grips.gd`, with inspectable prepared/baked intermediates. The final packaging script embeds this document and verifies source invariants.

The character retains stylized proportions and the existing animation set. This asset integration does not add facial animation, validate lower-end hardware, or produce a standalone release build of the entire game. Current engine logs also retain the root-certificate warning, texture-RID shutdown warning and some store/mining-test ObjectDB shutdown warnings.
