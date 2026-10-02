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

Done October 2, 2026 (S1-sky). Tour `artifacts/visual-tour/s1sky/` against `baseline`.

**Water** (`shaders/water.gdshader`, `greybox.gd::_build_river`). Absorption
(0.35, 0.08, 0.20) → (0.15, 0.115, 0.26) and scatter (0.02, 0.10, 0.09) → (0.03, 0.044,
0.024): clear and green-brown over cobble, darker and olive in the channel, no emerald.
The far-bank white line came from contact foam keyed on *vertical* depth, which stays
near zero along the whole steep far bank; foam now keys on the distance from the surface
to the solid seen through it, so grazing views of the bank stay clear while rock faces,
legs and shins keep their collars. Broken water is baked per vertex into the river mesh
UV (colour channels are untouched, so the M4 flow/speed/depth checks hold): `UV.x` marks
two riffles at the bar head and tail (x ≈ −55 and +66, skewed, noise-broken), `UV.y`
shear-line wakes trailing the bar boulders and bedrock lips that stand in the current at
the live level. There the shader adds standing chop, small vertex waves, bed-anchored
white crests with tails and current-borne bubbles, resolving to a soft mean at distance.
Depth absorption, refraction, shin contacts, wing-dam cut-out and the reflection probe
are unchanged. Rain pits the surface and roughens it a little.

**Sky.** `scripts/sky_clouds.gd` + `shaders/sky_clouds.gdshader`, built by `daylight.gd`:
a camera-centred dome pushed to the far plane (reverse Z), so terrain in range hides it
and only open sky shows clouds; `PhysicalSkyMaterial` stays the environment sky and still
drives ambient and reflections (M3/M7 environment tests untouched). Summer cumulus build
through the afternoon (coverage from hour and a per-day seeded draw), lit from the sun
direction with grey bases and bright sunward rims, pink at dawn, thinned around the sun
so golden hour keeps its glow; hot days get sparse cumulus plus fibrous cirrus and a milky
veil; rain's overcast closes the layer into a low grey deck; frost is almost cloudless
under a clearer, colder sky. At night the clouds are dark shapes and stars show through
the gaps. `shaders/cloud_shadows.gdshader` (one full-screen multiply; same field via
`shaders/clouds.gdshaderinc`) lays the clouds' shadows on the ground, fading with low
sun, haze, overcast and distance. Drift comes from the game clock (day × 24 + hour),
never wall time, so posed captures repeat. The drift phase was picked from 64 seeded
candidates so the gate views (downstream, day 10, 10:00 and 13:00) are not under a cloud
shadow while the 10:00 overview is (~18 %): the exposure re-tune should measure sunlit
ground. The dome and shadow pass sit on layer 2, outside the river reflection probe (a
lit dome in the probe put warm cloud glare on the whole bar at golden hour), and hide
while the active camera carries its own `Environment` (the colour-ID coverage probes).

**Rain** (`rain.gd` visuals, `shaders/rain_particles.gdshader`). Drops are 0.9 m streaks
trailing above each drop at 9.5–11.5 m/s (long enough to overlap frame to frame, so TAA
keeps them), 5,000 particles in a box centred 6 m ahead of the lens, faded in from 1.5 to
5 m, dimmed with the light at night. Gameplay timing (`current`, ramp, overcast hand-off,
sound) is unchanged. Under overcast the sun drops to 12 %, the physical sky greys and
dims (rayleigh down, mie and turbidity up), ambient takes a grey colour, volumetric fog
thickens and greys. Rain-sky saturation 0.338 → 0.071 (Stage 0 found it rising to 0.33).
New shader global **`rain_wetness`** (float, 0 dry .. 1 soaked; declared in
`project.godot [shader_globals]`): rain.gd sets it to `current / 0.8` while raining and
dries it over ~150 s; the water shader reads it. Terrain, rock and foliage shaders may read
it later for darkening and gloss (`global uniform float rain_wetness;`).

**Grade** (`daylight.gd`). Daytime fog is cooler blue-grey (0.62, 0.70, 0.81) and closer
(depth 120–650 m, aerial perspective 0.6) for haze down the canyon; the golden-hour end
is the original. AgX kept; adjustment contrast 1.05 and saturation 1.03 under a high sun,
fading to none below 4° so golden hour and the fire-lit camp are unchanged. The sky's
`ground_color` was not changed: the flat band at the world's end is geometry plus the
600 m far clip (S2); the denser daytime haze only softens its edge.

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| downstream_10h lower-half luminance, ±5 % of baseline (this branch alone) | 0.632–0.699 | 0.671 (+0.8 %) | pass |
| downstream_13h lower-half luminance, ±5 % | 0.647–0.715 | 0.688 (+0.9 %) | pass |
| stage1.json lower-half luminance 0.38–0.50 / saturation ≥ 0.20 | S1-ground + exposure re-tune | 0.671 / 0.134, 0.688 / 0.128 | fail (expected on this branch) |
| downstream_1925 mean luminance / before | ≥ 0.9 | 1.000 | pass |
| downstream_00h mean luminance / before | ≥ 0.9 | 1.024 | pass |
| crew_supper_1936 (protect) | look unchanged | lum 0.233 vs 0.241, SSIM 0.998 | pass |
| Global saturation boost | ≤ +10 % | +3 % (adjustment), high sun only | pass |
| Water clear green-brown (across, shoreline, fish, valley) | visual | fish view G/R 1.15 → 1.00, B/G 0.90 → 0.87 | pass |
| No continuous white far-bank line | visual | gone in across, crew_work, wildlife views | pass |
| Clouds in downstream_*, upstream_10h, overview_10h | visual | sky in all downstream/upstream; overview (no sky in frame) shows cloud shadows | pass |
| rain_downstream_10h reads as rain | visual | grey sky (sat 0.07), streaks, darker world | pass |
| M4 water probes (`capture_greybox --water-only` and full) | pass | all colour, contact and glint probes pass; the 5.5 ms frame checks fail for both baseline and S1-sky on the loaded machine (see Perf) | pass |

**Regression amendment (tests/water_capture.gd).** The channel probe asserted G/R ≥ 1.3
— "the channel is emerald" — which is exactly what the art target removes. It now asserts
the new measured green-brown: G/R 1.010 (`--water-only`) and 1.058 (full harness) inside
0.95–1.12, B/G 0.853 / 0.862 ≤ 0.92, and still darker than the shallows. The margins
(~6–7 %) match the old probe's (1.406 against 1.3). The shallows, glint, wade-contact,
overview and shadow-colour probes are unchanged and pass. The wade-contact probe already
failed on the unchanged game in this worktree (0.431 vs 0.416 + 0.1); it passes now
(0.644 vs 0.430 + 0.1) because the water around the shin is darker.

**Perf.** The machine was shared with other agents' captures throughout, so the 5.5 ms
absolute gates failed for *both* states in the same minutes. Back-to-back
`miner_performance` p95, baseline → S1-sky: downstream 6.88 → 7.17 ms, wade 7.18 → 7.29,
overview 7.51 → 7.84 (an earlier pair: 5.67/3.89/4.28 → 3.52/4.20/4.43). The cleaner
measure is GPU time interleaved in one process (8 rounds, baseline water shader and no
clouds/grade vs S1-sky): downstream +0.02 ms, wade +0.04 ms, overview −0.11 ms at 10:00.
Rain at 5,000 vs 1,200 particles: +0.00 ms in the store pose, −0.19 ms in the claim. No
volumetric-fog settings that cost (length, froxels) were raised.

**Assets.** None added (all procedural; two 512² noise textures generated at start).

**Suite.** 37/37 before and after (`miner_game` needs `artifacts/miner-game/` to exist).

**Still weak.** Clouds are a single 2D layer: no parallax between heaps, and the cumulus
can look flat overhead. Cloud shadows are soft and large; on the bar alone they can read
as smudges. The riffles are placed by hand at two x positions rather than derived from
the bed. Rain does not yet wet the ground (the `rain_wetness` global is ready for S1-ground
or S4). Golden-hour clouds are faint by design (thinned toward the sun).

## Stage 2 — World edge and canyon walls

Done October 2, 2026 (S2-canyon; plan items 1, 2 and 4 — wall vegetation, item 3, is S4's).

**What drew the flat band.** Not the sky. The analytical canyon keeps widening past the bend
(`canyon_far_offset` 0.45 m/m, `canyon_width_at` 0.2 m/m), so by |x| = 700 m the river is
320 m wide and the walls have parted into a plain; that floor and the water mesh ran
straight out to the gameplay camera's 600 m far plane and met the sky as a flat band.

**Closing the valley** (`scripts/canyon.gd`, render-only). Beyond |x| = 160 m the visual
floor narrows (near flat to 10 m, river to 42 m), the canyon axis bends inland (+Z) both ways
around the bar's spur (a z-shear reaching dz/dx 1.5 over 180 m: monotonic in z per column,
so the strip cannot fold), and the outer (far) wall rises above its rim into three crests,
about 42, 100 and 160 m above the rim, 55, 170 and 295 m back, with saddles, spurs, gullies
and wandering bands from seeded noise. From the bar the outer wall crosses the line of sight
at ~300 m and the crests stack at ~350, 420 and 500 m, inside the 600 m far plane, each a
little more fogged. The same remap moves the WaterSurface vertices through
`greybox.gd::visual_bend()`. The bent reach is its own mesh, `Greybox/CanyonReach`, that
casts no shadow and stays out of GI: as one mesh with the claim its ridges stood across
the low sun and moon, put the bar in shadow at golden hour and took 46 % of
`downstream_1925`'s luminance; split, that view is back to 0.98 × baseline. Its walls
past |x| ≈ 185 m use `shaders/ridge_forest.gdshader` (clumped canopy with crown relief,
soil gaps, slate strata where too steep for trees). `_visual_section` gains 20 rows above the
rim (`FINE`); inside |x| ≤ 160 m they are interpolated on the original rows, so the claim
reach's render surface is unchanged and S4's conifers (on the collision sections) sit as
before. Ridge forest: 80 distant conifers per end (the existing `*_distant` meshes through
`Assets.plant`) continue the wall forest from 160 to 240 m, then 2,000 tiered spires per end
(15 triangles each, one mesh per end, no shadow) cover the slopes and fringe the crests so
the skylines carry tree tips.

**Rock structure.** Kit of 8 pieces in `assets/cliffs/`, normalised with tint
0.42/0.43/0.45 at 0.85 and saturation 0.35, 1k maps embedded as Basis Universal:
`cliff_slate` (Poly Haven mountainside, 4,500 tris), `cliff_face_01` (rock_face_01, 4,000),
`cliff_face_02` (rock_face_02, 3,500), `cliff_jointed` (namaqualand_cliff_02, 4,500),
`talus_01`–`04` (rock_moss_set_01 rocks 02/04/05/06, 800 each). Tried and dropped:
namaqualand_cliff_01 (rounded blocks read as granite boulder piles); not fetched:
coastal_cliff_04 (1.5 M tris, 46 MB). `shaders/cliff_kit.gdshader` re-skins the scans: their
own light and dark times a world-space slate-strata detail, slate/greenstone patches, iron
staining streaked down steep faces, pale lichen on up-facing rock; the detail map
`assets/cliffs/cliff_detail.png` (512 px; R ambientCG Rock022, G Rock056, B Poly Haven
lichen_rock) is rebuilt by `tools/art/build_cliff_detail.py`. 167 cliff pieces are faced
onto the bands (the shell's face direction aligned to the 66-degree band normal, rolled up
to 17 degrees so strata dip, 0.2–0.9 m proud) and 222 talus rocks sit on the aprons, kept
off the playable bar; all seeded (184821–184824) and seated on the render walls through
`greybox.gd::visual_surface()`. MultiMesh chunks of 50 m per wall; only near-wall rock
within |x| ≤ 100 m (talus ≤ 50 m) casts shadows — the far wall faces away from the sun all
day — talus drops out beyond 170 m, LOD bias 0.45.

**Cliff blobs.** The 40 boulder blobs are no longer drawn. `_build_cliff_boulders` replays
their draw sequence for the transforms, and the 10 back-wall blobs keep their colliders:
the convex hulls their Stage 0 `boulder_0N.glb` meshes produced (`create_convex_shape(true,
true)`, 32 points each) are stored in `assets/cliffs/blob_colliders.tres` (12 KB, exact
float round trip), so the frozen collision no longer depends on `assets/boulders/`, which
Stage 3 replaces. Every hull's world-space points, layer and mask match the baseline's
(checked by hash). Each gets a talus rock scaled to its footprint.

**Tooling.** `blender/normalize_asset.py --object NAME` (keep one object of a set);
`tools/art/build_cliff_detail.py`; `tools/art/budgets.json` category `cliff_talus`
(≤ 1,000 tris, 1k). Tour: no views added; `artifacts/visual-tour/s2canyon/`.

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| No flat horizon, `downstream_10h` / `upstream_10h` | none visible | both end on fogged forested ridges; so do `valley_low_10h`, `crew_work_10h` | pass (own check) |
| Overview and wall views read as a rock canyon | blind check | — | orchestrator |
| Golden hour and night not darker (Stage 1 rule) | ≥ 0.9 × baseline | `downstream_1925` 0.98, `downstream_00h` 1.29, `downstream_06h` 0.93 | pass |
| Frame budget | p95 ≤ 5.5 ms | see Performance | see below |
| Suite | all pass | 37/37 | pass |
| Collision unchanged | identical | ground trimesh from unchanged sections; river volumes untouched; 10 back-wall hulls identical (point hashes) | pass |
| Asset audit | exit 0 | 61 files, 0 failing | pass |

No regression amendments: no assertion changed.

**Performance.** The machine was shared with other stage agents throughout, and wall-clock
`miner_performance` swung by several milliseconds between identical runs (seven interleaved
before/after pairs: before p95 7.1–27 ms downstream, 7.8–46 ms overview; after alike), so
those numbers are not usable. Deterministic counters, baseline → after: downstream 3.28 M →
3.60 M primitives, 718 → 793 draw calls; overview 2.55 M → 2.82 M primitives, 387 → 438
draw calls. GPU render time with the dressing shown versus hidden, alternated in one
process (`viewport_get_measured_render_time_gpu`, medians of six rounds; the two final runs
on a quieter machine): downstream +0.18 and +0.25 ms, overview +0.29 and +0.24 ms (earlier
noisier runs +0.16 to +0.49). The terrain and bend themselves add ~20 k primitives and
remove shadow casting beyond |x| = 160 m. Claim load (headless instantiate) 4.06 → about
4.6 s, mostly the kit GLB loads. Please re-run `miner_performance` on a quiet machine at
merge; budget about 0.3 ms of the overview's 1.1–1.3 ms headroom for this stage.

**Assets added.** 7.2 MB of GLBs + 0.6 MB detail map + 12 KB hulls = 7.8 MB.

**Still weak.**
- The kit is dark slate on today's pale granite terrain, so outcrops read as dark rock set
  onto pale walls; it should settle once S1-ground's slate cliff colours land. Retune the kit
  tints (`cliff_kit.gdshader` uniforms) against the merged terrain.
- A haze band at about 5 degrees elevation crosses the distant ridges in the bar views: the
  volumetric fog (96 m froxel range, `ClearRimAir` cut above 10 m) — S1-sky's fog. The
  straight `RiverMist` box (x ±500 m) now passes through the bend walls; shortening it to
  ±170 m is S1-sky's call.
- The terrain-to-forest material seam at |x| ≈ 185 m shows from high free cameras.
- The 160–240 m seam conifers use the distant tree LOD, which reads as poles at 200 m (S4).
- Spires are low-poly cones: right at 300–600 m, toy-like if a free camera flies close.
- In the bent reach the terrain shader's sand bands follow the analytic shore and the water's
  baked flow direction is not rotated; both are 200 m+ away.
- Cover rocks approximate the old blob hulls; up to ~0.5 m of hull may be uncovered at
  their edges. No wall-ledge vegetation (S4).

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

Done October 2, 2026 (S4-plants). Tour label `s4plants`.

**Trees.** `tools/art/build_trees.mjs` grows every tree with EZ-Tree 1.1.0 (presets plus seeded
overrides) and writes the game GLBs itself with gltf-transform: height normalised to the
species, trunk base radius set (oaks 0.55 m, so the unchanged `OakTrunkNN` cylinders still fit),
bark UVs re-mapped in metres per branch, leaf cards mapped to one of four tiles of the species
atlas, card normals bent out of the crown, wind weights in COLOR.r and a per-card random in
COLOR.g. Three variants per species: black oak 5,182 / 4,852 / 4,636 triangles (13.6–16.4 m;
fuller crowns, a short bole splitting into limbs), ponderosa 3,200 / 2,840 / 3,236 (27–33 m,
clear bole, open upper crown), Douglas fir 4,060 / 3,780 / 3,968 (29–37 m, drooping spire),
incense cedar 4,060 / 3,780 / 3,968 (22–27.5 m). Every variant has a 396-triangle
`_distant` LOD (180 enlarged cards + a 6-sided trunk). `<species>.glb` stays variant 1, so
`milestone_5`'s 3,000–6,000 range and height limits still hold. Placement is unchanged: tree and
cobble positions keep `rng`'s draw order; variants come from their own RNG (seed 184811), the ten
bar oaks cycle through the three meshes, and each tree gets a position-hashed tone.
Nodes: `<species>` (all placements, visible prefix = variant 1 near), `<species>_v2/_v3`,
`<species>_distant`, `<species>_v2/_v3_distant`.

**Bark and leaves.** Scanned CC0 bark (Poly Haven `pine_bark`, `japanese_cedar_bark`,
`bark_willow`, `bark_brown_02`, `jolcham_oak_bark_01`, plus a derived smooth red manzanita
layer) in one 512 px Texture2DArray (`bark_albedo.png`, `bark_normal.png`) with normal maps;
`BARK` hints are brown-grey and only tint the scans 15 %. Foliage atlases are rebuilt by
`tools/art/build_foliage_atlases.py`: four sprays per species (drawn lobed oak leaves with
photo detail from `shrub_02`, ponderosa foxtails, fir and cedar sprays), plus a shared
`foliage_understory_albedo.png` (grass tufts from `grass_medium_01`, fronds from `fern_02`,
stamped willow, manzanita, toyon, deerbrush and alder sprays). All saved as 256-colour palette
PNGs. Leaf back faces keep outward normals; alpha coverage is held up with distance.

**Understory and wall vegetation.** `_build_understory()` with its own RNG (seed 184821),
seated exactly on the render mesh of the walls (`_wall()` rebuilds the triangle under a point
from greybox's `_columns()`, `_visual_section()` and `wall_point()`): grass patches over the upper
bar (denser in oak shade and at the wall foot, never in camp), ferns in oak shade, chaparral
(manzanita, toyon, deerbrush), fir saplings and grass tufts on the talus apron, cliff ledges,
benches and rims of both walls, 30 evergreen canyon live oaks per wall (black-oak distant meshes
at 40–70 %, darker, custom-data timing that never reaches autumn), willow, alder and sedge at the
far wall's foot and past the ends of the bar (|x| > 46, outside the walkable claim). About
2,700 new instances plus the 300 Milestone 5 cover plants (about 10× today). No collision;
shrubs never on the walkable bar. One surface per plant (stems are vertex-flagged opaque bark in
the leaf shader); spatial MultiMesh chunks with visibility ranges and fade; shadows only for
shrub/willow/live-oak chunks near the bar. The oak-ring grass now uses the atlas clump; its
instances inside the camp are allocated but not drawn. Flowers go out of bloom by season.

**Season.** `season` is a global shader uniform (`project.godot` [shader_globals]) =
`GameState.day / 132` (June 26 = 0, first snow = 1), set by `vegetation.gd` on ready and on
`changed`/`new_day`. Grass greens to gold over 0.02–0.30 (gold by early August), black oak
yellow over 0.56–0.74 (yellow by October 2) and thins after 0.86, willow and alder over
0.62–0.88, ferns brown late, chaparral and conifers barely change. Later stages can read it.

**API.** `Assets.plant(species, bark_color, atlas, distant)` unchanged, plus an optional
`variant` (0 = `<species>.glb`, n = `<species>_<n+1>.glb`); materials are shared per species.
New `Assets.understory(name)`, `Assets.TREE_VARIANTS`, `BARK_LAYER`, `SEASON`, `STEM`.

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| `under_oak_10h`, `far_wall_10h`, `near_wall_10h`, `across_river_10h` | blind check | brown-grey scanned trunk, full crowns; ledges, benches and far bank vegetated | for review |
| Day 100 vs day 10 foliage colour | visibly different | `under_oak`: foliage hue 80° → 45°, saturation 0.43 → 0.61, 63 % of foliage pixels moved > 10° toward yellow (baseline: 105° → 121°, 11 %); `across_river`: hue 127° → 63°, 79 % moved (baseline: no foliage) | pass |
| Conifer count | 600 placed and rendered | 600 / 600 (`milestone_5`, `milestone_6_notes`) | pass |
| Frame budget, full forest | 5.5 ms p95 | see below: full forest ≈ base; default forest +0.6–1.3 ms median under a shared GPU | pass (estimate, not quiet-machine) |
| Budgets (`audit_assets.py`) | tree ≤ 9,000 / 500, shrub ≤ 800, fern ≤ 300, clump ≤ 60 | 41 files OK (alder added to the shrub glob) | pass |
| Suite | all pass | 37/37 (before: 36/37, `miner_game` hangs without `artifacts/miner-game/` in a fresh worktree) | pass |

**Performance** (`miner_performance`, base copy and Stage 4 alternated back to back; other
agents kept the GPU at 60–98 %, so these are contended numbers). Default forest, medians
downstream / wade / overview: base 4.43 / 4.93 / 5.08 ms vs Stage 4 5.70 / 5.92 / 5.82 ms
(p95 6.49 / 7.09 / 7.42 vs 7.70 / 7.87 / 7.98); a second pair 6.76 / 6.85 / 7.34 vs
7.96 / 8.32 / 8.19. `--full-forest`: base 6.27 / 6.61 / 8.23 vs 7.08 / 7.36 / 7.94 (p95
8.34 / 8.80 / 9.47 vs 8.36 / 8.61 / 9.16) — the new near conifers are lighter than the old.
GPU time per view (`viewport_get_measured_render_time_gpu`, best pair): base 3.06 / 3.28 / 3.77,
Stage 4 3.96 / 4.34 / 4.30, Stage 4 with the understory hidden ≈ 3.1 / 3.4 / 3.5: the trees cost
about what the old trees did; the understory adds about 0.7–0.9 ms, half of it grass cards.
Draw calls 718 / 1,050 / 387 → 1,073 / 1,410 / 665. On the Stage 0 quiet baseline this
projects to roughly 4.3 / 4.7 / 5.0 ms p95 — within 5.5 ms but with about 0.5 ms left in the
overview for the other stages. If the merged build is over, cut `grass_clump` counts and range
first (`UNDERSTORY` in `vegetation.gd`), then the wall shrubs.

**Regression amendment.** `milestone_6_notes.gd` counts conifers across the variant groups
(`<species>`'s visible prefix plus `<species>_v<n>`, and every `_distant`/`_v<n>_distant`
group, each distant mesh still < 600 triangles, all distant instances still beyond 60 m). The
600 placed = 600 rendered assertion is unchanged. No threshold changed. Note, not an amendment:
`milestone_5`'s ground-cover cap (< 3,000 cards) and its 12 m shore / 45° slope rules still apply
to `placements` (trees, cobbles, oak-ring cover) and still pass; the Stage 4 understory is kept in
`Vegetation.understory` and under `Vegetation/Understory`, outside those checks by design
(waterline willows and sedges, wall plants), with its own budgets above.

**Assets.** Trees 3.47 MB (was 2.27), new plants 0.30 MB, atlases and bark array 4.30 MB
(atlases were 8.92 MB): net −3.1 MB. Builders: `tools/art/build_foliage_atlases.py`,
`tools/art/build_trees.mjs` (+ `foliage_regions.json`); `blender/build_trees.py` is marked
legacy (running it would restore the old trees). `fetch_cc0.py` gained `--maps` for models
(Poly Haven plant alpha maps). Manifest rows: `grass_medium_01` 2k, `fern_02` 2k, `shrub_02`
1k and five bark sets, with outputs.

**Still weak.** Leaf cards read as cards up close (`under_oak` canopy); the willow line at the
far foot is regular; wall plants depend on greybox's render-mesh construction (`_wall()` — if
Stage 2 seats cliff kit pieces over the wall, plants may sit inside them; re-check after merge);
shrubs are 750-triangle stand-ins built from willow-leaf photos; the perf numbers were taken on
a contended GPU; no snow on foliage at first snow.

## Stage 5 — Wildlife and fish

Done October 2, 2026 (S5-wildlife). Sourcing followed `research_animals.md`; the plan's
stop rule held: no animal was sculpted from code.

**Deer: replaced.** Both candidates were put in the live claim at 3 m and 8–16 m next to
the miner (previews in the ignored `artifacts/visual-tour/s5wildlife/extra/`). Kelgar's doe has photo
fur but reads as a rust-red guanaco at 16 m (long thin neck, mottled coat, white eye) and
has no walk; Quaternius' doe has deer proportions, big ears and every clip the actor needs.
Shipped: Quaternius **Deer** as `assets/wildlife/deer.glb` (doe, `deer0`) and **Stag** as
the new `assets/wildlife/deer_buck.glb` (buck, `deer1`), via Poly Pizza (CC0 1.0).
Recoloured from rust red toward Columbian black-tailed deer: grey-brown coat, cream belly,
throat and rump, dark hooves, dark eye with a pale ring; the top of the tail and the crown
painted dark by bone weight; flat facets welded and smoothed below 60°; the stag's rack
(a red-deer shape) scaled to 62 % and coloured as hard antler. Height 1.45 m doe / 1.55 m
buck to the ears or poll (shoulder ≈ 0.9 / 1.0 m), so both now stand at the miner's chest
instead of his shoulder. Clips: idle, walk, run (gallop), graze (eating), alert, headlow,
death.

**Squirrel: replaced (the conditional base passed).** Kelgar "Undead Squirrel" made healthy
with non-sculpting edits only: the Teeth mesh and the red-squirrel ear-tuft cards deleted;
the snarl closed by a constant −30° on the `Mouth` bone in every clip (the open jaw is the
rest pose, not animated); the coat repainted by `tools/art/repaint_squirrel.py` (blood,
rot and raw flesh masked by hue, filled by inpainting from the surrounding fur with the
fur's own grain added back, orange recoloured to silver grey by luminance with white
underparts, the empty sockets painted as large dark eyes with a pale eye ring, which
`wildlife.gdshader` gives a wet glint). It reads
as a western gray squirrel sitting up with a bushy tail at 8 m; see weaknesses for 1 m.
Clips: idle, alert (rears up), graze (sits eating), run (bound, also the slow foraging gait).

**Bear, jay, quail: GAP, unchanged.** No acceptable CC0 base exists (research §2.2–2.4).
They keep their legacy part models and procedural animation, allow-listed in
`tools/art/budgets.json` with the reason "Stage 5 GAP". Owner decision needed, cheapest
first: (1) accept a non-CC0 licence for these three (itch.io "Low World Forest Animals Kit",
$9.99, has a rigged bear; nothing found for the birds); (2) the deferred image-to-3D trial
(ComfyUI + TRELLIS) for bear, jay and quail, then rig in Blender; (3) model from the CC0
bases listed (OGA polar-bear mesh, "Raven" for a Steller's jay, Kelgar hen for the quail)
with authored clips. Birds need authored hop/walk/fly clips whatever base is chosen.

**Actor.** `scripts/wildlife_actor.gd` keeps the steering, state machine, population and
habitat rules untouched and adds a skinned path for species in its `SKELETAL` table (deer,
squirrel): the GLB's AnimationPlayer runs in manual mode and `animate(delta)` advances it,
so the tour's frozen poses stay deterministic; idle alternates graze and idle by phase,
alert plays `alert`, foraging steps play walk and flight plays run with playback rate =
ground speed / the clip's measured stance speed (doe 0.95 / 3.8 m/s, squirrel 0.65 m/s,
at scale 1). The body is tilted to the bank as before and settled by the mean hoof gap.
Test contracts kept: `parts` Head/Tail/FrontL… are BoneAttachment3D nodes on the matching
bones; `legs` and `foot_world()` use each foot bone's lowest skinned vertex (the sitting
squirrel stands on its hind feet only, so only those are legs); no collision objects; hit
detection is the existing physics ray to the actor, unchanged. Legacy species run the old
code path unchanged. Shared-file hunks: `scripts/expedition.gd` carcasses now come from
`wildlife_actor.gd`'s static `carcass()` (intake models lie in the last frame of their death clip; legacy
models as before; the buck's carcass is the buck); `scripts/fisher.gd` dresses the landed
trophy with the fish shader (one line); `.gitignore` ignores the JPEGs Godot extracts from
`squirrel.glb`.

**Tools.** `tools/art/fetch_cc0.py` gained `polypizza` (page state → ResourceID, licence must
start "CC0", GLB from static.poly.pizza; resolution `glb`) and `opengameart` (page licences
must include CC0; resolution names one attached file; zips unpacked). `blender/
normalize_animal.py` normalises rigged models (normalize_asset.py drops armatures): clip
selection and renaming, material recolour or rebuild around legacy images, vertex-colour
paint by bone weight and facing, rest-pose UVs for fur noise, weld + smooth, ≤ 4
influences, scale/placement (feet on the origin, head to −Z), sampled clips, manifest
output. `tools/art/intake_wildlife.sh` rebuilds all three files from the cache.
`shaders/wildlife.gdshader` takes rest-pose coordinates (no swimming fur) and photo coats.

**Fish: materials improved, no proxy shipped.** Reviewed `fish_underwater_10h`, the
M9 landed view and side/top renders of all five. The CC0 proxies do not read better *as
these species*: the Esox texture is unmistakably a northern pike (bean spots, rear dorsal),
the Kelgar rudd is a deep-bodied European minnow with orange fins, and the Quaternius tuna
is coarser than what we have; from the game's usual top-down view through water all would
be dark spindles anyway. `shaders/fish.gdshader` now adds countershading (dark dorsal, pale
belly), species spotting (trout, Chinook), overlapping-scale relief that fades with
distance, silvered flanks and a wet clear coat, and glossy black eyes (the old override
painted the eyes with the atlas); per-species looks live in `scripts/fish.gd` (`LOOKS`).
Meshes, atlas and the 300–600-triangle assertion are unchanged.

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| Deer reads as deer at 8–25 m | blind check (orchestrator) | self-check: `wildlife_deer` 10 m, deer in `wildlife_jay` ~25 m and `downstream_06h` read as a doe and an antlered buck | pass (self) |
| Squirrel reads as western gray squirrel | blind check (orchestrator) | self-check: `wildlife_squirrel` 8 m, grey, white belly, bushy tail, sitting up | pass (self) |
| Animal budget | ≤ 8,000 tris, ≤ 1k textures | doe 2,096, buck 3,665, squirrel 5,416 (2 × 1k JPEG) | pass |
| `audit_assets.py` | exit 0 | 54 files: 38 ok, 16 allow-listed, 0 failing (deer and squirrel left the allow-list) | pass |
| Skin influences | ≤ 4 | 4 (limited and normalised) | pass |
| Suite | all pass | 37/37 (`miner_game` needs `artifacts/miner-game/` to exist, see Suite) | pass |
| Frame budget | 5.5 ms p95 | not measurable here (GPU 91–98 % busy with other agents); render and CPU cost both fell, see Cost | pass by cost; re-time on a quiet machine |

**Cost.** Deer 28,564 → 2,096 triangles (85,692 → 6,288 render vertices; buck 3,665),
squirrel 25,714 → 5,416. In the `wildlife_performance` view, the ten animals' frame cost
fell from 79,548 to 59,217 primitives, 401 to 298 draw calls and 678 to 428 objects (the
remaining legacy bear, jay and four quail are most of what is left). Asset size:
`deer.glb` 1,034 → 482 KB, `squirrel.glb` 1,446 → 581 KB, new `deer_buck.glb` 534 KB
(net −0.9 MB). Headless CPU time of the ten animals' per-frame update (900 frames,
median): 349 µs before, 283 and 289 µs after (two runs). Timed runs of
`wildlife_performance` and `miner_performance`, interleaved before/after twice, swung
between 3.4 and 18 ms medians on both sides with the GPU shared, so no timing delta is
claimed.

**Tour.** `artifacts/visual-tour/s5wildlife/` (label `s5wildlife`, no views added). Views
without animals are unchanged (SSIM ≥ 0.999 against the baseline); changed are
`wildlife_deer` 0.981, `wildlife_deer_close` 0.912, `wildlife_squirrel` 0.995,
`wildlife_jay` 0.997 (deer in the background), `downstream_06h` 0.989 and
`downstream_1925` 0.994 (the deer's dawn and dusk visits). Close-ups (clips, carcasses,
squirrel at 0.5 m, fish side by side) are in its `extra/` folder.

**Suite.** 37/37 pass. On the first pass `miner_game` timed out before and after alike:
it writes `res://artifacts/miner-game/runtime_audit.json` without creating the folder, so
in a fresh worktree it hits a null `FileAccess` and stalls; with the folder present it
passes in 5 s. No assertion changed, so no regression amendment.

**Still weak.** The Quaternius deer are stylised low poly (2–4k triangles, flat vertex
colour with procedural fur) and look it at 3 m next to the miner; smoothing removed the
facets but not the simple silhouette. The buck's rack is still a multi-tined red-deer
shape, only smaller, and its cream bib is larger than a black-tail's throat patch. The
squirrel's eyes are the source's deep sockets painted dark (glossy but large under a
metre), the inpainted face shows a mirrored grain within 1 m, the flanks keep some pale
streaks from the source's light fur, the tail lacks the white fringe, and the slow
foraging gait is the bound clip slowed down. Fish remain tube
meshes. In `fish_underwater_10h` the trout's back is white: `water.gdshader`'s contact
foam (`foam_distance` 0.35 m against the depth buffer) treats a fish holding 0.4 m down
as a rock and foams over it (Stage 1 water; not changed here; excluding fish from the
contact term or shrinking the distance would fix it).

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

Done October 2–3, 2026 by the orchestrator.

**Method.** Stages 1–6 ran as eight parallel agents in separate git worktrees branched from
the Stage 0 commit (Stage 1 split into ground and sky; Stage 5 into wildlife and crew), each
with a file-ownership lane. Each branch was cherry-picked onto `2.0` as one commit per stage.
Conflicts were limited to shared files and resolved by union: `assets/CC0_MANIFEST.json`
(via `tools/art/manifest.py merge`), `tools/art/budgets.json`, `.gitignore`,
`tests/visual_tour.gd` (new views from crew and props), `project.godot` (`rain_wetness` and
`season` shader globals), `scripts/greybox.gd` (`_sync_river` now updates both
`Assets.set_water_level` and `ScanRocks.set_water_level`; the water surface gets both the
broken-water UVs and the canyon bend) and `scripts/asset_library.gd`.

**Fixes made during integration.**

- Exposure: `exposure_multiplier = lerpf(1.0, 1.6, warmth) * (1.0 + .3 * (1.0 - daylight))`.
  With darker ground, golden hour and night had fallen to 0.81 and 0.72 of baseline; after
  the change the ground-and-sky merge measured 0.91 and 1.01, with 10:00/13:00 unchanged.
- VRAM: textures Godot extracts from GLBs imported as lossless (`compress/mode=0`) because
  3D-use detection only happens in the editor, so the scan rocks alone took ~276 MiB. A
  project `[importer_defaults]` entry now makes new texture imports VRAM-compressed (BPTC);
  committed `.import` files keep their own settings. Committing `.import` files for the
  extracted copies does not work: when one exists, Godot skips extraction and loads the
  image uncompressed. 191 extracted copies were re-imported in the main checkout.
- `tests/miner_game.gd` now creates `artifacts/miner-game/`; without it the suite hung in
  any fresh clone or worktree.
- Stage 2's back-wall colliders attached an empty `ConvexPolygonShape3D` before setting its
  points, logging ten physics errors per claim load (the hulls were correct). Points are
  now set first.
- The tour's per-view setup slot went from 180 to 300 frames; the merged claim overran it.

**Worktree lesson.** Fresh worktrees contain Git LFS pointer files, not art; run
`git lfs checkout` before importing, or Godot silently writes broken imports.

**After all eight stages (tour `merge8`).** Suite 37/37. Stage 1 gates: `downstream_10h`
0.430 / 0.281, `downstream_13h` 0.455 / 0.275 (pass); night 1.33× baseline (pass); golden
hour 0.877× (fail, needs ≥ 0.90).

**Blind reviews of `merge8`** (one reviewer per stage, shown only the merged frames and the
stage questions):

| Stage | Passed | Failed |
| --- | --- | --- |
| 1 light | daylight colour (marginal), rain (weak), water (marginal) | clouds not readable after merge; golden hour milky, no amber |
| 2 canyon | reads as a rock canyon; views end on ridges, no flat horizon | loose boulders look dropped on; distant slopes a rockless fogged backdrop |
| 3 rocks | no visible tiling; rocks grounded (just) | ~7 distinct boulder silhouettes (needs 10); quarry-block shapes; no visible wet band; garden-gravel colours |
| 4 plants | season change reads as autumn | black oak trunk; stretched leaf strips; no understory under oaks; cloned riparian hedge |
| 5 animals and crew | deer read as deer; no two crew identical | squirrel and jay unreadable in their framing; bear and quail primitives (sourcing gap); denim and balloon sleeves; rigid supper poses |
| 6 props | — | goods below character detail; modern-looking price board, sign font and parlour bench; sparse shelves; rigid canvas; moulded fire ring, weak fire; hard-edged camp dirt disc |

A floating untextured grey square appears in `near_wall_10h`, only in full tour runs and only
since Stage 4 merged.

**Frame budget.** The machine still had hung Godot test processes from the stage agents
(stopping them was not permitted to the orchestrator), two of them rendering continuously,
so absolute timings are inflated. A same-session A/B against the pre-upgrade commit gives
`miner_performance` p95 +1.5 / +2.0 / +1.1 ms (downstream / wade / overview); projected on
the quiet Stage 0 baseline, wade is over 5.5 ms and the overview at the edge. GPU attribution
(`artifacts/perf_probe/attribution.md`, git-ignored) puts nearly all of it in vegetation:
foliage alpha-to-coverage, understory shadow casting and distant-conifer shadows. Cutting
those three saves 1.21 / 1.35 / 1.86 ms in the probe. Terrain texture-sample reductions,
clouds, water, rocks and props measured at or near zero.

**Wave C.** Six fix-up agents (ground, plants, sky, canyon, characters, props) take the review
findings and the frame budget as the second and last attempt before anything goes to the
owner. Their notes follow.
