# Visual upgrade plan

Written October 2, 2026, for execution by Opus 5.5, one stage per session. It follows
a visual audit of branch `2.0`. The audit captures are in `artifacts/visual-audit/`
(`sheet_a.jpg`, `sheet_b.jpg`, `sheet_c.jpg`, and `proof/proof_rocks.png`).

The owner's standing direction applies: output must be game-ready, the owner is
hands-off, and token cost matters. The owner approved two things for this plan:
CC0 asset libraries may be used, and the core tooling below is installed.

## 1. What is wrong today

Measured on the audit captures and the shipped textures:

| Finding | Evidence |
| --- | --- |
| The ground is far too bright | `gravel_albedo.png` averages 0.68 linear luminance and granite 0.42. Dry river gravel should be about 0.25–0.35. |
| The world is nearly monochrome | Lower-half frame saturation is 0.08–0.13 at 10:00 and 13:00. Gravel, sand, boulders and cliffs share one pale grey. |
| Canyon walls have no rock structure | Smooth noise-displaced slopes, no strata, nothing growing on them. |
| The world visibly ends | Up- and downstream the river meets a flat horizon band. |
| Boulders are one shape | 8 meshes, all domes, one material with the same crack pattern. |
| Trees lack variety and mass | 4 species, 1 mesh each. Oaks have black trunks, sparse leaves, and stand in a 5×2 grid. |
| The ground is bare | 240 grass cards and 60 flowers, all under oaks. No shrubs, driftwood, willows or litter. |
| Water is over-saturated | Emerald colour, a hard white line on the far bank, no riffles. |
| The sky is empty | A plain gradient at every hour. No clouds. |
| Wildlife is placeholder | Tube limbs and ball joints. The deer still costs 85,692 render vertices. |
| Crew are clones | 14 hands share the miner mesh with a tint. |
| Camp and store props are below the miner's standard | Box goods, flat brown store ground. |

What already works and must be protected: the miner, the fire-lit night camp,
golden-hour lighting, the water's depth absorption, and the deterministic build.

## 2. Art target

Grounded naturalism: the North Yuba canyon, late June to first snow, 1848.

- **Rock:** dark blue-grey slate and greenstone bedrock and cliffs; pale granite
  and white quartz as rounded river boulders; rust and ochre iron staining.
- **Ground:** mixed-colour river cobble (grey, tan, rust, dark), buff sand, a dark
  wet band at the waterline, red-brown Sierra soil above the flood line.
- **Plants:** black oak and canyon live oak on the bar; ponderosa, Douglas fir and
  incense cedar on the walls; manzanita, deerbrush and toyon on slopes; willow and
  alder at the water; grass that is green in June and gold by August.
- **Water:** clear, green-brown over cobble, white only where it breaks.
- **Light:** warm sun, cool shadow, summer cumulus, haze down the canyon.

## 3. Rules for every stage

1. **Gameplay maths is frozen.** Do not change `claim_layout.gd`, `gold_map.gd`,
   `river_model.gd`, collision shapes, boulder and bedrock footprints, oak trunk
   positions, or anything a rules test asserts. Visual meshes may change; the
   ground collision mesh is already separate from the render mesh.
2. **Tests.** Run the full suite before and after each stage. Rules assertions
   are never loosened. An art-budget assertion (for example the boulder triangle
   range in `tests/milestone_5.gd` line 39) may change only with a "Regression
   amendment" paragraph in the stage notes, as `MILESTONE_12.md` does.
3. **Frame budget.** 5.5 ms p95 at 1080p on the RTX 5080, measured with
   `tests/miner_performance.gd`. Headroom was 2–3 ms at the Milestone 6 notes
   round; re-measure it in Stage 0, since the crew and camp have been added since.
4. **Review by tour, not by gauntlet.** Each stage is judged on the standard tour
   (Stage 0) with before/after sheets and the numeric gates listed in the stage.
   Use at most one blind reviewer per stage, given only the before/after sheet
   and the stage's questions. Do not run per-asset model review loops.
5. **Intake over sculpting.** Prefer a normalised CC0 asset or a generator with
   parameters. Do not hand-place vertices in Python for organic forms.
6. **Provenance.** Every outside asset gets a row in `assets/CC0_MANIFEST.json`:
   source, id, URL, resolution, SHA-256, licence, date. Raw downloads live in the
   git-ignored `.tools/cc0_cache/`; only normalised game assets are committed.
7. **Determinism.** Seeds stay explicit. The same inputs must rebuild the same
   assets and placements.
8. **One commit per stage**, with notes appended to `VISUAL_UPGRADE_NOTES.md`:
   what changed, gate results, amendments, and what is still weak.

## 4. Tooling (installed and verified October 2, 2026)

| Tool | Use | Verified command |
| --- | --- | --- |
| Godot 4.7.2 | Captures and tests | `./.tools/Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1600x900 --script <file>` |
| Blender 5.2 | Normalise, decimate, bake | `"/c/Program Files/Blender Foundation/Blender 5.2/blender.exe" --background --python <script> -- <args>` |
| gltf-transform 4.5.1 | GLB audit and optimisation | `npx --prefix tools/art gltf-transform inspect <file.glb>` |
| EZ-Tree 1.1.0 | Procedural trees and bushes | `node tools/art/make_tree.mjs "Oak Large" 1 out.glb` (`--list` shows 16 presets) |
| scikit-image, OpenCV | Image diffs and statistics | `python -c "import skimage, cv2"` |
| imageio-ffmpeg | Sequence and turntable video | bundled ffmpeg 7.1 |
| trimesh | Triangle and bounds audits | `python -c "import trimesh"` |

Node packages are pinned in `tools/art/package.json`; run `npm install` there on a
fresh clone. `tools/art/.gdignore` keeps Godot out of `node_modules`.

Seed scripts from the audit, working but unpolished, are in `tools/art/seed/`:

- `visual_tour.gd`: the 16-view tour used for the audit (promoted to
  `tests/visual_tour.gd` in Stage 0 and removed from the seed folder).
- `normalize_scan.py`: Poly Haven glTF → weld → decimate → GLB.
- `proof_in_scene.gd`: loads un-imported GLBs into the live claim for a quick look.

Things learned while proving the pipeline:

- Weld vertices before decimating an imported scan. Without it the decimate
  stalled at 26,611 triangles on a 3,000 target; with it, it reached 3,000.
- EZ-Tree needs a stub `document` in Node and exports geometry only. Its units
  are its own (a large oak is about 100 tall). Leaf cards carry 0–1 UVs and need
  an atlas and the foliage shader; untextured they render as flat quads.
- Poly Haven's API needs a `User-Agent` header. Endpoints used:
  `/assets?t=models|textures|hdris`, `/info/<id>`, `/files/<id>`. Check the API
  terms before any commercial release; the assets are CC0 either way. Fetch each
  asset once, cache it, and never call the API from the game.
- Poly Haven textures are JPG. Git LFS here tracks PNG, GLB, BLEND, EXR and WAV,
  so either convert to PNG or add `*.jpg` to `.gitattributes`.
- Scans are heavy: `boulder_01` is 124k polygons, `namaqualand_cliff_02` 364k,
  `grass_medium_01` 1.6M. Always normalise; never import the raw file.
- The orange `boulder_01` scan read far better than the current boulder at 3,000
  triangles and 1k textures, but it needs tinting toward the art target.

## 5. Budgets

| Asset | Triangles (LOD0) | Textures |
| --- | --- | --- |
| Bar boulder | ≤ 3,000 | 1k, 2k for the two largest |
| Cliff or outcrop kit piece | ≤ 6,000, at most 12 unique pieces | 2k |
| Near tree | ≤ 9,000 | shared 2k atlas per species |
| Distant tree | ≤ 500 | same atlas |
| Shrub / fern / grass clump | ≤ 800 / ≤ 300 / ≤ 60 | shared atlases |
| Driftwood, stump, log | ≤ 1,500 | 1k |
| Animal | ≤ 8,000 | 1k |
| Terrain texture set | n/a | 2k albedo, normal, packed ORM + height |

Committed `assets/` should stay under about 200 MB.

## Stage 0 — Infrastructure

Prerequisite for the owner: branch `2.0` has 142 uncommitted paths. Commit them
before Stage 0 so art changes are reviewable on their own.

1. **Standard tour.** Promote the seed to `tests/visual_tour.gd`. Fix the swapped
   view names (rig yaw 0 faces the river, π faces inland). Take `-- label=<name>`
   and write to `artifacts/visual-tour/<label>/`. Cover about 20 views: down- and
   upstream, across the river, both walls, camp, shoreline close-up, gravel
   close-up, under an oak, overview, low valley, each wildlife species, a fish
   underwater, the store, a crew work scene, and downstream at 06:00, 13:00,
   19:25 and midnight, plus one rain view and one day-100 low-water view. Find out
   why `weather=rain` produced a clear sky in the audit and fix the harness or
   report the bug.
2. **Sheets and statistics.** `tools/art/tour_sheet.py <before> <after>` builds
   contact sheets at 800×450 per tile and side-by-side before/after sheets, and
   writes `tour.json` with, per view: mean luminance, share of pixels above 0.85,
   mean saturation of the lower half, and SSIM against the baseline.
3. **Baseline.** Capture label `baseline` before changing anything.
4. **CC0 intake.** `tools/art/fetch_cc0.py <source> <id> <resolution>` downloads to
   `.tools/cc0_cache/`, verifies size, and writes the manifest row.
5. **Normaliser.** Grow the seed into `blender/normalize_asset.py`: import, weld,
   decimate to a target, optional LOD1, scale to metres, origin at the base,
   repack AO/roughness/metallic as the game's ORM, optional tint, export GLB to
   `assets/<category>/`. Print triangles before and after.
6. **Audit.** `tools/art/audit_assets.py` runs gltf-transform over `assets/` and
   fails anything over the Section 5 budgets, with an allow-list for legacy files.
7. **Suite runner.** Move `artifacts/v2/run_suite.sh` to `tools/run_suite.sh`; it
   currently lives in a git-ignored folder.

Done when: baseline tour and `tour.json` exist, one asset has gone through
fetch → normalise → audit → in-scene render, and the suite passes unchanged.

## Stage 1 — Colour, light, sky and water

Shader and configuration work only. This is the largest gain for the least cost.

1. **Albedo.** Bring terrain albedo into range: gravel 0.25–0.35 linear, sand
   0.30–0.38, granite boulders 0.30–0.38, cliffs 0.15–0.28. Re-tune exposure in
   `daylight.gd` afterwards so mid-tones hold; do not fix brightness with
   exposure alone.
2. **Colour variety in `terrain.gdshader` and `rock.gdshader`.** Add low-frequency
   colour families (grey, rust, ochre, dark), a darker wet band above the
   waterline, moss on shaded north-facing rock, and red-brown soil above the
   flood line. Replace the cliff multiplier on line 85 with strata banding and
   crevice darkening.
3. **Material boundaries.** The sand and gravel edges follow mesh strips and show
   as straight lines and rectangles. Blend by noise and height instead.
4. **Water.** Pull `scatter` and `absorption` toward clear green-brown, remove the
   continuous white line on the far bank, and add broken water only at riffles
   and around obstacles.
5. **Sky.** Add a cloud layer that respects the existing day cycle and weather
   states (clear, hot, rain, frost). A scrolling, sun-tinted cloud dome keeps
   `PhysicalSkyMaterial` and the Milestone 3 and 7 environment tests intact.
6. **Grade.** Tune fog colour and aerial perspective, and add a restrained
   contrast and saturation adjustment. Keep AgX.

Gates: at 10:00 and 13:00 downstream, lower-half mean luminance 0.38–0.50
(baseline 0.66–0.67) and lower-half saturation ≥ 0.20 (baseline 0.13). Golden hour
and night must not get darker than baseline by more than 10 percent. Water
colour probes in `tests/capture_greybox.gd` will move; amend them with new
measured values, not looser thresholds.

## Stage 2 — World edge and canyon walls

1. **Close the valley.** Find what draws the flat horizon band beyond the bar and
   remove it. Bend the river out of sight both ways and terminate views on
   forested ridges: two or three fogged ridge layers beyond |x| = 150 m.
2. **Rock structure.** Normalise a kit of at most 12 scanned cliff and outcrop
   pieces and place them by seed along the cliff bands and talus aprons, sunk
   into the slope. Poly Haven candidates confirmed in the catalogue:
   `rock_face_01`, `rock_face_02`, `namaqualand_cliff_01`, `namaqualand_cliff_02`,
   `coastal_cliff_04`, `mountainside`, `rock_moss_set_01`, `rock_moss_set_02`.
   Tint them to the slate and greenstone target.
3. **Wall vegetation.** Shrubs, grass tufts and saplings on ledges and benches.
4. **Replace the 40 cliff blobs** from `_build_cliff_boulders` with talus built
   from the Stage 3 rock set.

Gates: no flat horizon visible in the down- and upstream tour views; the overview
and both wall views pass a blind check on "does this read as a rock canyon";
frame budget holds.

## Stage 3 — Rocks and ground

1. **Boulders.** Replace the 8 domes with 10–14 normalised scans. Catalogue
   candidates: `boulder_01`, `namaqualand_boulder_02` to `_06`, `rock_07`,
   `rock_09`, `stone_01`. Each bar boulder must still fit its `Layout.BOULDERS`
   footprint radius and height, with a regenerated convex collider, because gold
   lees and camera tests depend on those footprints.
2. **Cobbles.** Go from 3 meshes to at least 8, with per-instance colour and a
   real size range. Today's are 4–7.5 cm dots.
3. **Terrain textures.** Replace the six generated sets with CC0 scans, adding a
   height channel for height-blended transitions and an anti-tiling method (two
   scales with rotation, or stochastic sampling). Catalogue candidates:
   `ganges_river_pebbles`, `dry_river_pebbles`, `river_small_rocks`,
   `gravelly_sand`, `damp_sand`, `forest_ground_04`, `forest_leaves_02`,
   `lichen_rock`, `mossy_rock`, `dark_rock`, `cliff_side`.
4. **Clutter.** Driftwood and flood debris along the high-water line and in
   boulder lees, leaf litter under oaks. Candidates: `dry_branches_medium_01`,
   `dead_tree_trunk`, `tree_stump_01`, `tree_stump_02`, `root_cluster_01`,
   `pine_roots`, `bark_debris_01`. Clutter must not block walking: no collision,
   or keep it out of the panning and camp lanes.

Gates: no visible texture repeat in the gravel close-up and overview views; at
least 10 distinguishable boulder silhouettes in the tour; Stage 1 colour gates
still hold; `milestone_5.gd` footprint and placement checks pass, with the
triangle-range amendment recorded.

## Stage 4 — Vegetation

1. **Tree variants.** Three or four meshes per species from `make_tree.mjs`
   (different seeds and overrides), normalised to species height, with leaf cards
   mapped to the species atlas and a distant LOD each. Keep the 10 oak trunk
   positions and colliders; vary mesh, scale and rotation per position.
2. **Bark and leaves.** Brown-grey bark, not black. Catalogue candidates:
   `pine_bark`, `jolcham_oak_bark_01`, `bark_brown_02`, `bark_willow`. Fuller oak
   crowns: the audit oaks are mostly bare limbs.
3. **Understory.** Shrubs, ferns, grass clumps and saplings at roughly ten to
   twenty times today's density, by seeded rules (shade, slope, distance from
   water), with per-instance colour and visibility ranges. Candidates: `shrub_01`
   to `shrub_04`, `fern_02`, `grass_medium_01`, `grass_medium_02`, `fir_sapling`,
   `pine_sapling_small`, and EZ-Tree `Bush 1–3` for willows at the waterline.
4. **Season.** Drive a `season` uniform from the calendar day: grass green to
   gold through July, oak leaves yellow by October, then the existing snow.

Gates: the oak-under and treeline views pass a blind check; day 10 and day 100
tour views differ visibly in foliage colour; conifer count stays 600; frame
budget holds with the full forest.

## Stage 5 — Wildlife and people

1. **Wildlife.** Replace the five primitive animals with rigged, animated models.
   First choice is the Quaternius CC0 animal packs; their exact contents were not
   verified in the audit, and they download as archives from quaternius.com, so
   the owner may need to fetch them. Check for deer, bear and small birds first,
   and report gaps before building anything.
   `wildlife_actor.gd` animates named part nodes procedurally. Move it to
   skeletal clips (idle, walk, run, graze) and keep the steering and state logic.
   Read `tests/wildlife.gd` first to see what it asserts about parts.
   If a species has no acceptable CC0 base, stop and report. Do not fall back to
   sculpting it from code.
2. **Fish.** Review the underwater tour view and bring the five species to the
   same standard if they fall short.
3. **Crew.** Build variety from the miner's eight modular meshes: three or four
   hats, hair and beard sets, shirt and vest options, and two or three builds,
   composed deterministically per roster entry so each of the 14 men is
   recognisable. Bring Lambert to the same standard.

Gates: each animal reads as its species in a blind check at 8–25 m; no two crew
members in the supper view look identical; animal budgets met.

## Stage 6 — Camp, store and props

1. **Camp.** Canvas with sag, ropes and stakes; a fire ring of real cobbles;
   bedrolls, crates, barrels and cook gear.
2. **Store.** Log walls with bark, detailed shelf goods in place of boxes, a
   ground material on the terrain shader, and full trees behind the stall.
3. Search the Poly Haven catalogue for period-appropriate props before building
   any; ids were not checked in the audit.

Gates: store and camp tour views pass a blind check against the miner's level of
detail; store suites pass.

## Deferred

A local image-to-3D trial (ComfyUI with TRELLIS, about 30–40 GB) was offered and
not installed. Revisit it only if Stage 5 cannot source acceptable animals.

## Order and expectations

Stages 0 and 1 come first and are low risk. Stages 2–4 can follow in any order,
though Stage 4 looks best after Stage 1's colour work. Stage 5 carries the most
integration risk. After each stage, show the owner the before/after sheet and
the gate table; nothing else needs owner time unless a gate fails twice.
