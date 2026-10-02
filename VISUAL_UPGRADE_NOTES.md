# Visual upgrade notes

Notes for `VISUAL_UPGRADE_PLAN.md`, one section per stage. Stages 1–6 were run in
parallel git worktrees by separate agents and merged by the orchestrator; each agent
replaces only its own placeholder below.

## Stage 0 — Infrastructure

Done October 2, 2026.

**Tour.** `tests/visual_tour.gd` replaces the seed (deleted). 28 views, about 46 s:
`downstream_10h`, `upstream_10h`, `across_river_10h`, `far_wall_10h`, `near_wall_10h`,
`camp_10h`, `shoreline_close_10h`, `gravel_close_10h`, `under_oak_10h`, `overview_10h`,
`valley_low_10h`, `fish_underwater_10h`, `downstream_06h`, `downstream_13h`,
`downstream_1925`, `downstream_00h`, `rain_downstream_10h`, `across_river_d100`,
`under_oak_d100`, `wildlife_deer`, `wildlife_deer_close`, `wildlife_bear`, `wildlife_jay`,
`wildlife_quail`, `wildlife_squirrel`, `crew_work_10h`, `crew_supper_1936`, `store`.
Arguments `label=`, `only=`, `settle=`; it writes `views.json` and hides the HUD. Rig yaw 0
faces the river; the audit's names (and its `e2_across_lowwater`) were swapped.
Noise floor: full run against full run differs by at most 0.011/255 mean per view; an
`only=` run against a full run by at most 0.063/255. Each view gets a fixed frame slot,
an SDFGI restart and a snapped camera rig.

**Rain finding (harness, not game).** `rain.gd` ramps rain in over ~24 s and the sky only
takes overcast when `daylight.gd` `apply()` runs, which the audit called before the ramp.
The harness now sets overcast 0.8 and then calls `apply()`. At full overcast the sky still
turns darker and bluer rather than grey, and the 8 mm, 30 %-alpha drops are nearly
invisible — Stage 1 work.

**Known tour quirk.** The store's lighting depends on which claim views ran earlier in the
same process (cleared only by disabling SDFGI; cause not found), so the store is captured
first. In play the store follows the claim, so the tour's store may differ from play.

**Tools.** `tools/art/tour_sheet.py` (contact and before/after sheets, `tour.json`, gates;
luminance is Rec.709 luma on sRGB values and saturation is HSV — these reproduce the audit's
0.660/0.126 and 0.672/0.127), `tools/art/fetch_cc0.py` (Poly Haven and ambientCG into the
shared git-ignored cache, manifest rows in `assets/CC0_MANIFEST.json`),
`tools/art/manifest.py` (union/3-way merge driver, opt-in via the `git config` line in its
docstring), `blender/normalize_asset.py` (weld, decimate, Cycles normal bake, ORM repack,
tint, `<name>_distant.glb` LOD), `tools/art/audit_assets.py` with `tools/art/budgets.json`
(53 files: 35 pass, 18 legacy allow-listed with reasons, 0 failing; characters provisionally
use the animal budget and props the driftwood/stump/log budget), `tools/run_suite.sh`
(moved from the ignored `artifacts/v2/`, location-independent, `LABEL=` logs to
`artifacts/suite/<label>/`), `tools/art/gates/stage1.json`. `blender/common.py` now shares
its export settings as `GLTF_EXPORT`; `tools/art/seed/proof_in_scene.gd` takes arguments.

**Pilot.** Poly Haven `boulder_01` 1k: 66,122 → 3,000 triangles (500 distant), 2.06 × 1.60 ×
2.94 m, three 1k JPEG maps, 1.4 MB; tint 0.62/0.61/0.58 at 0.85 took mean albedo from 0.126
to 0.300 linear; audit passes; rendered in the live claim
(`artifacts/visual-upgrade/proof/`). Not committed — Stage 3 does the real intake.

**Suite.** 37/37 pass in 144 s. Added `miner_art`, `fishing_assets`, `fishing_launch`, and
`phase2_launch` (salmon, raid, deer, bear, day 132). Excluded: helper classes
(`composition_guard`, `subject_coverage`), `simulate_season` (exits 2 on three pre-existing
design findings), renderer/real-time capture and performance scripts, and
`reflection_cleanup_probe` (reproduces an engine bug).

**Frame budget** (`miner_performance`, p95, 5.5 ms target): downstream 3.44/3.46 ms (~2.0 ms
headroom), wade 3.75/3.78 ms (~1.7 ms), overview 4.18/4.43 ms (1.1–1.3 ms).
`crew_performance` 4.09–4.33 ms. The overview is the tight view.

**Baseline gate values.** `downstream_10h` lower-half luminance 0.665, saturation 0.123;
`downstream_13h` 0.681 and 0.118; `downstream_1925` mean luminance 0.452;
`downstream_00h` 0.108.

**Sourcing research** (git-ignored, `artifacts/visual-upgrade/`): every Poly Haven rock
scan is tan, ochre or rust, so rock meshes need re-skinning toward slate and granite; Poly
Haven has no oak, willow, alder, manzanita, toyon or deerbrush models. Animals: deer is
covered (Quaternius deer and stag via Poly Pizza; Kelgar doe and buck on OpenGameArt);
black bear, jay and California quail have no acceptable CC0 base; the only squirrel base
is an "undead" model that needs a repaint.

## Stage 1 — Ground colour and terrain textures

Done October 2, 2026 (S1-ground; also plan Stage 3 item 3). Tour label `s1ground`.

**Scan sets.** `blender/build_textures.py` is now a plain-Python (numpy + Pillow) intake:
it fetches through `fetch_cc0.py`, grades albedo in linear light (periodic-blur flattening
of the scan's baked macro shading, saturation, tint, exact mean), writes RGTC-ready normals
(blue fixed, shaders rebuild Z) and packs ORM as AO, roughness, **height**, and records
outputs on the manifest rows. Rebuilds are byte-identical; all 21 maps wrap without seams.
Poly Haven `ganges_river_pebbles` (gravel, 2k), `dense_sand` (sand), `rock_boulder_dry`
(granite), `gray_rocks` (talus), `forest_leaves_04` (duff), `red_dirt_mud_01` (new `soil`
set), ambientCG `Rock022` (bedrock: slate strata). Mean linear albedo: gravel 0.250, sand
0.300, granite 0.335, cliff rock 0.26 texture / about 0.23 after strata and crevices,
talus 0.22, soil 0.13, duff 0.115. Imports switched from lossless to VRAM (BC7 albedo/ORM,
RGTC normals). Palette quantisation was tested and rejected for scans (a rust pebble
posterised to flat brown); `optimize_textures.py` now skips these sets. `build_gravel.py`
and `gravel_stones.png` are retired; the old procedural graphs stay in `build_textures.blend`.

**`terrain.gdshader`.** Layers are blended by masks sharpened with each layer's height
(`cover()`: sand fills between cobbles, soil and duff creep between stones), so no edge
follows a mesh strip. The sand rectangles were not strips: the old `fract(sin())` hash
rounded differently in neighbouring cells on the GPU, so value noise jumped at cell edges;
an exact integer hash fixes it. Anti-tiling: each planar layer uses a rotated, offset copy
per noise patch, joined in narrow height-blended seams (~1.2 samples per map). Bar: cobble
armour with low-frequency colour families (grey, rust, ochre, slate, dark) and a darkened
sandy matrix, sand in the swash band and lower-bar pockets, red-brown soil toward the wall
foot above the flood line, oak duff, and a wet band that soaks the bank to ~5 cm and dries
by ~35 cm above `water_level` (so it follows the falling river), plus a faint silt film on
newly exposed bank. Walls: tri-planar slate replaces the cliff multiplier with dipping
strata (slate, greenstone, weathered brown, dark), laminations, crevice and joint
darkening, vertical rust streaks, broad iron rind, moss on north-facing (+Z) rock above the
flood line, scoured paler rock below it, rare pale quartz-granite veins, slate talus
aprons, soil and duff on benches and the rim. `AO_LIGHT_AFFECT = 1` lets scan cavity AO
dim direct sun (contact shading normal maps cannot cast). Meshes without vertex colours get
a plain soil/gravel/duff ground with no river logic, so S6 can put `Assets.terrain()` on
the store yard (tested). `snow_amount`, `oak_canopies`, `review_mode` (sand weight and a
height-derived stone mask) and `water_level` still work.

**`rock.gdshader`** (modest): new ORM layout, Z rebuilt from RGTC, fixed side-projection Y
sign, crevice darkening from height, grey/warm/rust families, moss on north-facing tops,
wet line at the river for granite and bedrock materials (`Assets.set_water_level()`).

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| `downstream_10h` lower-half luminance | 0.38–0.50 | 0.451 | pass |
| `downstream_10h` lower-half saturation | ≥ 0.20 | 0.237 | pass |
| `downstream_13h` lower-half luminance | 0.38–0.50 | 0.468 | pass |
| `downstream_13h` lower-half saturation | ≥ 0.20 | 0.231 | pass |
| `downstream_1925` mean luminance / baseline | ≥ 0.90 | 0.825 | **fail** |
| `downstream_00h` mean luminance / baseline | ≥ 0.90 | 0.699 | **fail** |
| No visible repeat, `gravel_close_10h`, `overview_10h` | visual | none seen | pass |

The two failures cannot be fixed by material alone: ground albedo scales every hour alike
(lower half −32 % at 10:00, −29 % at 19:25, −40 % at 00:00, night being in the tone
curve's linear toe). Tested with this ground (then reverted; `daylight.gd` is S1-sky's):
`exposure_multiplier = lerpf(1.0, 1.6, warmth) * (1.0 + .4 * (1.0 - daylight))` gives
19:25 0.925 and 00:00 1.05 of baseline, with 10:00/13:00 unchanged (warmth is 0 above 40°);
`.3` instead of `.4` should land night near 0.97. It also lifts 06:00 to 0.88 and supper to
0.87 of baseline.

Regression amendment: `milestone_5.gd` expects the granite set at 1024 instead of 2048
(gravel stays 2048, the rest 1024). Granite now skins only cobbles, the fire ring, wing dam
stones, cliff blobs until Stage 2 and quartz veins; Stage 3 gives the bar boulders their
own material. Every set is still asserted at an exact size and referenced by the shader.

**Shared files.** `greybox.gd::_sync_river` calls `Assets.set_water_level(level)` (one
line); `asset_library.gd` adds the `soil` set, `water_level`, `set_water_level()` and drops
the stone mask; `tests/milestone_5.gd` amendment above.

**Perf.** Interleaved A/B in one process (old shader and lossless maps against the new,
alternating every 38 frames, viewport GPU time, two runs): median downstream 2.77→2.89 and
2.93→3.12 ms, overview 3.48→3.60 and 3.64→3.80 ms, so +0.12–0.19 ms GPU. Against a plain
material the Stage 0 terrain cost 0.17–0.23 ms and the new one 0.29–0.42 ms. The cheaper
integer hash saved 0.05–0.09 ms.
`miner_performance` p95 is dominated by machine load from other agents (best of five,
before/after: downstream 4.28/3.61, wade 4.87/4.04, overview 5.40/4.84 ms; single runs
reached 26 ms either way).

**Suite.** 37/37 before and after. `miner_game` writes `artifacts/miner-game/runtime_audit.json`
and hangs on a null file when that git-ignored folder is missing, as in a fresh worktree;
with the folder created it passes.

**Size.** Terrain sets 26.9 → 49.9 MB (+23.0 MB): gravel 19.2, soil 6.0, duff 6.0, talus
5.3, bedrock 5.0, sand 4.4, granite 4.1. AO and roughness are blurred 0.8 px and stored at
64 levels (−35 % ORM bytes, no visible steps); albedo and normals are full 8-bit RGB.

**Still weak.** North-facing walls read pale blue in shade under today's fog, so strata and
moss are subtle there; the slate talus apron is speckled at 20–40 m; mid-distance cobble
is busy with white quartz; the 13:00 gate margin depends partly on where sand pockets fall
(a pocket in the foreground adds ~0.03); quartz veins are rare enough to be missed; the
store's own `rock("duff"/"talus"/"sand")` materials changed look with the new sets.

## Stage 1 — Sky, water and grade

(pending: S1-sky)

## Stage 2 — World edge and canyon walls

(pending: S2-canyon)

## Stage 3 — Rocks and ground clutter

Done October 2, 2026 (S3-rocks; plan items 1, 2 and 4 — terrain textures are S1-ground's).

**Intake.** `tools/art/intake_rocks.py` rebuilds every file below from the CC0 cache: fetch
(`fetch_cc0.py`), `blender/extract_piece.py` (new: pulls one piece out of a scan set, crops
the shared atlas to that piece's UV square so its 1k maps are not 8/9 wasted, optional
`--round` water-wear smoothing before the bake, `--fit` to a unit footprint), then
`normalize_asset.py` (weld, decimate, bake, ORM, tint). Sources: `rock_moss_set_02`
(4k, and 8k for the two 2k crops), `stone_01`, `boulder_01`, `namaqualand_boulder_04/_05/_06`,
`namaqualand_boulders_01`, `rock_07`, `rock_09`, `dry_branches_medium_01`,
`dead_tree_trunk`, `tree_stump_01`, `bark_debris_01`. Rock scans are tinted toward pale granite
(albedo 0.30–0.32 linear, saturation 0.4); boulder_04/05/06 keep 20–40 % of their scan's
ochre as the iron-stain accent (0.22–0.25), boulder_02 is the white-quartz boulder,
boulder_11 dark slate. Rebuilds are byte-identical (checked on boulder_07 and cobble_10 with
`--out-dir`). `blender/build_boulders.py` now refuses to run without `-- --legacy`, so it
cannot overwrite the scans with the old domes.

**Boulders.** 13 scans replace the 8 domes (`assets/boulders/boulder_01..13.glb`, 2,999–3,000
tris for 01–08, 2,000 for the margin rocks 09–13; 2k maps on boulder_01 and boulder_03, the two
the camera meets closest in the tour, 1k on 02–08, 512 on 09–13). `scripts/scan_rocks.gd`
fits boulder_01..07 to `Layout.BOULDERS` in `greybox.gd::_build_boulders` with the old
approach (dimensions baked into the mesh, unit-scale convex collider): long axis along the
flow, footprint half-extent exactly the layout radius (narrow side stretched to at least
78 %), top 1.35 vertical radii above the centre ground as before (boulder_07 reaches 2.33 of
2.83 m: vertical stretch is capped at 1.35), base buried below the lowest ground under the
footprint and at least to the height where the rock reaches 92 % of its girth (capped at
30 %), so no boulder stands on an undercut foot. 25 margin rocks (seed 184830) sit outside the
playable bar: both bar ends (|x| 43–85), the far wall's foot at the waterline, and six on the
back edge (these get baked convex bodies). They draw as one MultiMesh per scan.
`shaders/scan_rock.gdshader`: baked maps, per-instance tint (instance uniform, or MultiMesh
colour with the lichen scale in alpha), a wet band 0.22 m above the river's live level
(`ScanRocks.set_water_level`, called beside the terrain's `water_level` in `_sync_river`),
lichen on up- and north-facing faces, optional rust under overhangs. The cliff boulders and
the store ring keep loading boulder_01..08 at unit scale; the scans have their natural height
(not a 2-unit dome), so those rocks now sit lower.

**Cobbles.** `scripts/cobbles.gd`, called from the cobble block of `vegetation.gd` (one
three-line hunk): 10 scan meshes (180 tris, 256 px, neutral grey) and 820 stones, 5–25 cm long,
coarser toward the channel and around the boulders, bedded 25–45 %, coloured per instance
(granite, tan, iron-stained, slate, greenstone, white quartz). It replays the legacy scatter's
exact draws on the shared `rng`, so the ground cover after it is unchanged (placement hashes of
grass, lupine, poppy, yarrow, oaks and conifers verified identical); new draws use its own
generator (seed 184841). Cobbles cast no shadows.

**Clutter.** `scripts/ground_clutter.gd` on a new `GroundClutter` node in `claim.tscn` (seed
184851): 81 pieces in 7 MultiMeshes, no collision. Silver driftwood branches and logs in clumps
along a wavering spring high-water contour 10–15 m inland, branches tucked against the boulders
on their inland and lee sides, bark and twigs under the oaks, two stumps just past the back of
the bar. Nothing within 4 m of the June shore (panning and cradle strip), and none in the camp,
its crew bunks and fire, the trail head, or the camp's path to the river.

Gates (tour `s3rocks` against `baseline`; copied to `artifacts/visual-tour/s3rocks/`):

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| Distinguishable boulder silhouettes | ≥ 10 | 13 scan shapes, plus the cliff boulders now built from them. boulder_01: wildlife_bear right, crew_work far left; 02 (quartz): downstream_10h left, shoreline_close left; 03: across_river right, crew_work centre, upstream right, under_oak, far_wall; 04: crew_work foreground; 05: camp_10h behind the camp; 06: downstream_10h behind the oaks; 07: upstream_10h left; margin scans at the far-bank waterline (across_river, wildlife_bear, wildlife_deer, far_wall), the bar ends (valley_low, crew_work, upstream) and the back edge (near_wall) | pass |
| Stage 1 colour gates not worse | ≤ / ≥ baseline | downstream_10h lower luminance 0.665 → 0.655, saturation 0.1226 → 0.1228; 13h 0.681 → 0.678, 0.1184 → 0.1187; 19:25 mean 0.987 × before; 00h 0.991 × before | pass (the absolute Stage 1 targets are S1's and fail on baseline too) |
| `milestone_5` footprint, placement, collision | pass | radius exact for all seven, sunk, convex only, camera boom retracts on boulder 1, 820 legal cobbles | pass |
| `milestone_1` boulder blocks walker and boom | pass | pass | pass |
| Asset audit | exit 0 | 30 new files ok; 72 files, 0 failing | pass |

Lower-half luminance rises only where a dome's shadow or face used to fill the frame:
`shoreline_close_10h` (0.602 → 0.657; that camera stands inside boulder_03's footprint and the
dome's shadow covered its foreground), `upstream_10h` (+0.009) and `wildlife_jay` (+0.024).

**Regression amendment.** `tests/milestone_5.gd` keeps both triangle ranges and extends their
coverage: boulders 1,500–3,000 now apply to boulder_01..13 (was 01..08), cobbles 1–199 to
cobble_01..10 (was 01..03). It adds one check: the clutter has no collision object, and every
piece except the stumps is at least 4 m inland of the June shore and clear of the camp. No
placement or rules assertion changed.

**Suite.** Before 36/37: `miner_game` failed only because a fresh worktree lacks the
git-ignored `artifacts/miner-game/` folder it writes to (then hung to the timeout). With the
folder created: 37/37 in 201 s.

**Frame budget.** The machine was shared with other stage agents throughout, and frame times
swung 3–35 ms between identical runs. Interleaved A/B (`miner_performance`, baseline files
swapped in and re-imported between runs): best p95 base downstream 3.47 / wade 3.82 /
overview 4.24 ms, this stage 3.59 / 4.25 / 4.38 ms (all under 5.5; the wade gap is inside the
run-to-run spread). GPU render time in the one quiet A/B round: downstream 2.79 → 2.82 ms,
wade 3.03 → 3.04, overview 3.44 → 3.43. Draw calls 718 → 784, 1,031 → 1,094 and 389 → 411;
primitives 3.28 M → 3.47 M downstream. The margin rocks are batched, and the cobbles and small
clutter cast no shadows, to hold the draw count.

**Size.** `assets/boulders/` 0.60 MB → 15.56 MB (boulders 14.7, cobbles 0.85) and a new
`assets/clutter/` of 2.04 MB: +17.0 MB. Godot extracts the embedded JPEGs on import; the copies
are git-ignored and import lossless (the project default for extracted GLB images): 276 MiB
of VRAM for all scan maps as RGBA8 with mipmaps. Block compression would cut that to about
70 MiB, but it needs a project-wide decision on extracted textures (committing the extracted
copies with VRAM-compressed `.import` files would duplicate the bytes in the repository).

**Still weak.** Scan albedo is soft on the 1k bar boulders within 3 m. boulder_01 keeps a
modest overhanging lobe (visible in `wildlife_bear`). The rocks read slightly warm in shade
next to the still-bright gravel; recheck the granite tint (`GRANITE` in `intake_rocks.py`)
against S1's ground. Cobbles are capped at 900 by `milestone_5`, so the bar reads sparse at a
distance and the gravel texture has to carry it. There is no leaf-litter asset (bark and twigs
under the oaks; the terrain's duff carries the rest). The cliff boulders now use the scan
meshes at unit scale with `Assets.rock()`, which S2 may want to revisit.

## Stage 4 — Vegetation

(pending: S4-plants)

## Stage 5 — Wildlife and fish

(pending: S5-wildlife)

## Stage 5 — Crew and Lambert

Done October 2, 2026 (S5-crew, worktree branch `worktree-agent-a2ea568f2c2aa27c7`).

**Crew kit.** `blender/build_crew_kit.py` re-cuts the hero's exported game meshes
(`blender/miner_game_export.blend`, with each face's source garment read from the
identical-topology `artifacts/miner-game/prepared.blend`) into `assets/crew/crew_kit.glb`:
Body (costume), Hat (split off the costume), Skin and Hair on MinerRig, 107,376 triangles.
Every face carries its garment id (UV2) and its rest position (CUSTOM0). The kit has no
textures, clips or gear: the miner's 2k atlases, its clip library and its pack, satchel and
canteen meshes are shared at runtime. Variants are procedural: 20 shape keys (hat
`crown_tall`, `crown_cone`, `crown_low`, `brim_wide`, `brim_narrow`, `brim_flat`,
`brim_droop`, `cap`, `tuque`; hair `hair_short`, `hair_long`, `hair_capped`; beard
`beard_long`, `beard_bushy`, `moustache_walrus`; `sleeves_rolled`, `sleeves_down`) and a
beard shell, the face's own lower-face triangles lifted 4.5 mm and split into moustache,
chin, jaw and cheek. The miner's 3,000 single-quad beard strands do not read beyond about
2 m; the shell gives beards mass at working distance and the shader frays its edge. A
quantisation pass (normalised-short weights and UVs, byte garment ids, no hair morph
normals) took the GLB from 10.0 to 7.7 MB. Lambert's `assets/store/shopkeeper.glb` is
stripped to his five clips (1.02 MB to 0.25 MB).

**Runtime.** `scripts/crew_look.gd` is a fixed casting per roster entry, drawn from each
man's origin; `scripts/crew_figure.gd` dresses the kit; `scripts/crew_build.gd` (a
SkeletonModifier3D) gives lean, average, stocky, heavy and broad builds and a head shape on
top of the clips' own bone scales; height is the figure scale. `shaders/crew.gdshader` is
one shared material per surface with the look in 13 instance uniforms: luminance-preserving
garment dyes, box-filtered checks, stripes and plaid, the harness straps worn as braces or
hidden, a plain faja or a ceinture flechee at the waist, the miner's torn knee left, patched
or whole, skin tone, shaving (lifts the painted stubble), a bald crown, hair and beard
colours, and which beard regions grow. Unworn garments collapse in the vertex shader.
`crew_hand.gd` uses the figure (same `skeleton`, `player`, `equipment` fields);
`crew.gd` reads the casting and gives waiting applicants their bedroll pack.

The fourteen: Pike (navy watch cap, striped frock, duck trousers, goatee), Boyle (grey
slouch, butternut shirt on braces, long chin-curtain), Soto (flat black vaquero hat,
crimson faja, moustache, tan), Kalama (low straw hat, long black hair, red check, brown,
clean-shaven, broad), Roux (blue wool cap, blue ceinture flechee, dark full beard, short and
stocky), Whitcomb (brown slouch, long grey beard, checked shirt), Doyle (charcoal slouch,
sky-blue army trousers, ginger mutton-chops), Brandt (heavy, bushy blond beard, blue
check), Ruiz (straw sombrero, white manta, faja, moustache), Freeman (black low hat, dark
skin, grey-flecked beard, red neckerchief), Lacy (straw farmer's hat, red flannel, braces,
lanky, clean-shaven), Ortuzar (flat-brimmed Chilean felt, plaid, full black beard), Fisk
(black plug hat, pale, clean-shaven, white shirt, black vest), Price (bare bald crown,
white chin-curtain). **Lambert** is built from the same kit: red toque, red ceinture
flechee, grey walrus moustache and side-whiskers, blue-checked shirt, blue neckerchief,
heavy build; `shopkeeper.gd` keeps `state`, `history`, `play`, `settle` and `busy`.

**Tour.** `crew_lineup` is appended (29 views): the fourteen in roster order on an arc 6 m
from the camera at 10:00, sun behind it. `store` and `crew_supper_1936` keep their cameras.
Evidence beyond the tour (plain-light lineup, head sheet, Lambert close-ups, kit report):
`artifacts/visual-tour/s5crew/extra/`.

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| Supper view, no two alike | distinct | 7 men; closest pair differs in 8 of 13 cast attributes (hat, colours, beard, skin, shirt, pattern, vest, trousers, scarf, braces, sash, build) | pass |
| Lineup, no two alike | distinct | 14 men; closest pair (Boyle, Price) differs in 7 of 13 | pass |
| Lambert at the miner's detail in `store` | same standard | the miner's own meshes and 2k atlases; red toque, moustache and check read at the counter | pass (for blind review) |
| Views without crew | unchanged | SSIM 0.994 to 1.000; `near_wall_10h`, `under_oak_10h` differ only where Pike and Boyle wait at the trail (new looks, packs) | pass |
| `store`, `crew_supper_1936` framing | unchanged | same cameras; SSIM 0.999 and 0.976 | pass |
| Suite | 37/37 | 37/37 in 172 s | pass |
| `audit_assets.py` | exit 0 | 54 files, 0 failing; kit allow-listed, shopkeeper now within budget (0 tris) | pass |
| `crew_performance` p95 (work, dam, supper) | baseline 4.1 to 4.3 ms | before 4.22, 4.11, 4.40 ms; after 4.30, 4.47, 4.76 ms (best of 6 rounds each); medians 3.49, 3.40, 3.67 vs 3.50, 3.43, 3.75 ms | +0.1 to +0.4 ms p95, within 5.5 ms |
| `miner_performance` p95 (downstream, wade, overview) | unchanged: no hands in these views, hero untouched | before 3.44, 3.90, 4.28 ms; after 4.20, 6.96, 4.31 ms (best of 8); medians 3.06, 3.29, 3.70 vs 3.35, 3.29, 3.74 ms | noise; overview (binding) +0.03 ms |

Frame times were taken in alternating before/after rounds in this worktree (before = the
Stage 0 `crew.gd`, `crew_hand.gd`, `shopkeeper.gd`) while other agents rendered on the same
GPU; single rounds swung by up to 10x, so the table gives the best round of each. Load-free
counts in the `crew_performance` views: ten hands at work 1,027 draw calls (1,007 before),
4.15 M primitives (4.22 M); supper 1,353 draws (1,345), 6.13 M primitives (6.15 M); mesh
buffers 147.8 MB (134.0 MB), the one shared kit.

**Regression amendments.** None; no assertion changed. `tests/visual_tour.gd` gains the
`crew_lineup` view (shared file, one hunk). Harness note: in a fresh worktree `miner_game`
hangs until the suite timeout because `artifacts/miner-game/` does not exist and its
runtime-audit write fails (`miner_game.gd` line 107); create the directory before running
the suite. Not a game fault; left for the orchestrator.

**Assets.** Added `assets/crew/crew_kit.glb` 7.7 MB; `assets/store/shopkeeper.glb` 1.02 to
0.25 MB. Net +7.0 MB.

**Still weak.** Every man has the miner's face: head proportions, skin, hair and beard
separate them at 6 m, but in close-up they are brothers. The beard shell is a painted
sheet, flat in profile close-ups, and long beards hang as a single blade. `sleeves_down`
still billows. The knit caps keep the felt texture (a crease highlight shows on the
toque's crown). Knee patches are flat squares. Lambert's sash is hidden by the counter in
the `store` view. Rebuilding the kit needs `prepared.blend` (regenerated by
`export_intrepid_miner.py prepare`) and must be redone whenever the miner is re-exported,
since the kit's faces follow the miner's atlases. The hero's own walk clip keys arm and hand
scale (hands about 15% wide while walking); the builds preserve it rather than fix it.

## Stage 6 — Camp, store and props

Done October 2, 2026 (agent S6-props, tour label `s6props`).

**Approach.** Collision and layout are untouched by construction. The camp's nine props
keep the original `camp.glb` meshes as their collision source (`camp.gd` builds shapes from
them as before; the file was re-exported without its 2k atlas, geometry and node transforms
verified identical) and draw new meshes instead. The store keeps the Milestone 10 log walls
and counter, rebuilt with the original code, as hidden `* proxy` meshes that alone get
collision. Built props share one set of tiling materials: they carry placeholder materials
named `kit_*`, and `scripts/prop_kit.gd` swaps in the textured ones from
`assets/props/kit_materials.glb` (2.9 MB, 21 materials: Poly Haven `bark_brown_02`,
`weathered_planks`, `cotton_jersey`, `hessian_230`, `poly_wool_herringbone`, plus small
procedural end grain, rope, iron, brass, slate, leather, paper, clay daub, beans, green
coffee, flour, salt, salt pork; glass). Dirt and contact shading are baked into vertex colour.

**Camp** (`blender/build_camp_kit.py`, `scripts/camp.gd`). Lean-to of forked bark poles with a
canvas that drapes over the ridge, sags between rafters and lifts between its four pegs,
lashings and two guy lines (kept behind the front line: the shelter test's 3 m bound still
holds); Poly Haven `stone_fire_pit` as the fire ring, with charred split wood (the crew's
supper fire copies it); bedroll of ground cloth, red wool blanket and tied coat roll; tripod
of bark sticks, chain and cast-iron kettle; cast-iron skillet (handle still on +X for the
cooking grip); smoking rack with forks, lashings and fish strips that show while smoking;
burlap cache sack on its rope; split firewood (still scaled by the firewood count); the
ledger on a Poly Haven chest. Dressing without collision, each beside a prop the walker and
crew already avoid: barrel and lantern, woodpile, chopping block with axe, stool, bucket,
pick and spade, gold pan, coffee pot and cups, three sacks (two under the lean-to, parented
to it so a bought tent hides them). Dressing fades out past 60 m; tools, cookware, embers
and ledger cast no shadow.

**Store** (`blender/build_store.py`, `scripts/store.gd`, `scripts/shelves.gd`). Bark log
walls with saddle-notch overhangs, end grain and clay chinking; posts, plates, rafters, a
rear ridge post; a two-sheet canvas roof sagging between rafters with guy lines; hewn plank
counter with a boarded front; deep plank shelves with aprons and a peg rail; a brass balance
(names and pivots as before); price board on legs and slate on an easel; ledger; Poly Haven
barrel under the fish plank; hitching rail. Goods (`goods.glb`, 34 meshes): sacks built from
a lathe profile then slumped, leaned and creased with seeded noise (cotton flour and salt tied
at the neck, open burlap beans and green coffee with rolled mouths), salt pork in brine in the
Poly Haven tub, all at four fill levels; hook papers in a tray, rope coils on the rail, willow
rod, boots, rocker kit, powder keg, tent roll, whiskey bottles, iron strongbox, dam timbers,
bunk rolls, paper parcels for the counter pile, price tags and pegs. Pick, shovel and crowbar
are Poly Haven tools; the tin pan is the miner's. Shelf stock not on the slate: blankets,
bolts of cloth, candle boxes, a soap crate. Yard: barrels, crates, lantern, tub, bucket,
bench, sacks. Display offsets in `shelves.gd` stand goods on the shelves; aim targets and
reach still use `store_layout.gd`. Ground: the claim's terrain shader through its own
material instance (no river wetness; duff textures in the gravel slot, sand patches as bare
earth, oak canopies over the clearing), the hill on the same material as wall, and a
ragged-edged trail in sand. Trees: 12 black oaks round the clearing, 32 young conifers
behind it, 70 distant conifers (shadowless) on the hill, all MultiMesh through
`Assets.plant()`, on their own seed (184813). The store canvas shader and 2k store atlas are
gone (unreferenced).

**Intake.** Fetched and normalised (rows in `assets/CC0_MANIFEST.json`): `stone_fire_pit`
(1,500 tris), `wine_barrel_01` (1,400), `wooden_crate_01` (1,200), `painted_wooden_bench`
(630; barn-red milk paint, period-plausible, saturation 0.8), `wooden_stool_02` (1,000,
desaturated), `wooden_lantern_01` (1,200), `wooden_axe_02` (700), `picke_dirty_01` (900),
`wooden_bucket_01` (1,000), `wooden_bucket_02` (1,099), `rusted_spade_01` (800),
`crowbar_01` (498); 1k maps for the large ones, 512 for the small. Gaps built
parametrically: sacks (modifier-style noise on lathes), rope (catenary and helix tubes),
jar/bottle (lathe), fence/rail, keg, strongbox. No anvil was needed.

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| Blind check, `store`, `camp_10h`, `crew_supper_1936` vs the miner's detail | pass | orchestrator | pending |
| Store suites: `milestone_10`; `store_capture` probes | pass | `milestone_10` PASS; probes: board contrast 8.68, slate glyph 29 px, weighing subject 0.126 (base 0.126) | pass; see note |
| Camp suites: `camp_layout`, `camp_movement`, `milestone_9`, `milestone_14`, `fishing_assets` | pass | all PASS; crossing distances identical to base | pass |
| Full suite | 37/37 | 37/37 (`miner_game` needs `artifacts/miner-game/` in a fresh worktree) | pass |
| `audit_assets.py` | exit 0 | 79 files: 63 ok, 16 allow-listed, 0 failing | pass |
| Supper fire look | protected | SSIM 0.983 vs baseline, mean L 0.239 | pass |

Note on store tests outside the suite: `store_capture` fails two probes on the unchanged base
too (Lambert portrait coverage 0.0597 vs 0.06 — measured on base and after; and the
spendthrift stock-thinning check, since 2.0 restocks outpace that history); both unchanged
by this stage. `store_sequences` stops at the trip hand-off on base as well: in a windowed
run the 2.0 pause book is open, so `Trip.eligible()` is false and no store loads.

**Regression amendments.** None. No assertion changed. `tests/visual_tour.gd` gains two
appended views in a new `props` section: `camp_close_10h` (camp props from 4 m) and
`store_shelves` (the shelves over the counter; captured after claim views, as in play).

**Frame budget.** The machine was shared and timings swung 3–20x between identical runs,
so the load-independent render counts are the comparison (1080p, same views as the
budget tests, base = unchanged checkout):

| View | Draw calls base → after | Primitives base → after |
| --- | --- | --- |
| downstream (miner_performance) | 646 → 761 | 3.11 M → 3.16 M |
| overview (binding view) | 380 → 394 | 2.53 M → 2.54 M |
| camp_10h | 897 → 1,081 | 3.56 M → 3.66 M |
| supper with camp fire lit | 714 → 812 | 3.61 M → 3.67 M |
| store_performance view | 707 → 698 | 1.08 M → 2.20 M |
| store arrival | 1,028 → 968 | 1.20 M → 2.32 M |

Timings (p95 ms, base and after run back to back, three rounds; seven agents shared the
GPU): base downstream 9.7–63.9, wade 9.2–37.3, overview 13.5–16.0, store 10.6–22.4, crew
supper 8.9–46.9; after downstream 3.6–38.5, wade 4.1–78.7, overview 7.4–31.7, store
4.5–17.3, crew supper 13.2–23.8. The quietest after-run (downstream 3.57, wade 4.06) is
within 0.3 ms of Stage 0's quiet figures (3.45/3.77). `store_performance` measured 4.505 ms
against its 4.5 ms gate in that run, before the store's near conifers were cut from 54 to 32
and the distant ring made shadowless. All three need a quiet re-measure at merge.

**Assets.** Added 11.1 MB (props 8.3 MB incl. the 2.9 MB kit, camp 1.5 MB, store and goods
1.3 MB); removed 25.0 MB (`store.glb` 6.5, `goods.glb` 6.5, `store_atlas.png` 6.3, the
atlas inside `camp.glb` 5.5). Net −13.9 MB. Budgets: new `kit_materials`, `building_kit`
(store stall, 8,844 tris) and `goods_kit` (16,132 tris over 34 goods, each ≤ 768)
categories; the store and goods allow-list entries are gone; `camp.glb` stays allow-listed
as never-drawn collision proxies.

**Still weak.** The store yard's sand patches and the trail read near-white until Stage 1's
darker ground sets land (they use the shared textures through the public uniforms). Sacks are
convincing at shelf distance but smooth up close (no true cloth folds). Tools on the top
shelf stand fanned; long tools and spears read as bundles of sticks. The bought tent and the
crew's bunk tents (`assets/expedition/tent.glb`, outside this stage's files; its collision
comes from its mesh) were not reworked. The lean-to canvas is a smooth sheet seen from behind.
Camp dressing adds about 115 draw calls in the downstream view.

## Integration

(pending: orchestrator)
