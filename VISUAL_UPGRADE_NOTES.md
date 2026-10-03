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

### Wave C — C-ground (terrain shader, scan rocks, cobbles, clutter)

Done October 2, 2026. Tour label `c_ground` (before/after sheets against `merge8` in
`artifacts/visual-tour/c_ground/`; census, probe logs and debug scripts in its
`cground_evidence/` folder).

#### What changed

**Boulder meshes (`tools/art/intake_rocks.py`, `blender/extract_piece.py`).** `extract_piece.py`
gains `--cast F`: before the water-wear smoothing, each piece is normalised to its bounding box,
pulled F of the way toward the box's ellipsoid (Blender Cast modifier) and scaled back. Smoothing
alone turned fractured blocks into pillows with sheer sides and a flat top (the "quarry block");
cast 0.4–0.5 gives the domed, egg-shaped section of a tumbled boulder and keeps the scan's lumps.
All eight bar/ring boulders now come from **different** scans: 01 `rock_moss_set_02` rock11 (2k,
8k source), 02 `stone_01` (quartz), 03 `namaqualand_boulders_01` rock a (2k, 4k source), 04/05/07
`rock_moss_set_01` rock04/rock01/rock05 (new source, 4k), 06 `namaqualand_boulder_04`, 08
`namaqualand_boulder_06`; margin rocks 09/10/12/13 re-cut (13 now `rock_moss_set_01` rock02), 11
unchanged. New `clutter/driftwood_snag.glb` (`dead_tree_trunk_02`, 4 m split snag, 1,500 tris).
Granite tint 0.62 → 0.575 grey (texture mean 0.27 linear before the shader's grain).

**Fitting (`scripts/scan_rocks.gd`).** Rounded scans keep near their own proportions: narrow-side
floor 0.78 → 0.62 of the radius, vertical stretch cap 1.35 → 1.12, visible height 1.35 → 1.1
vertical radii. Footprints stay exact (milestone_5 radius checks 3.400/2.700/… all exact). The
fitted mesh bakes the ground height under each vertex into UV2 (contact shading), and each
boulder's ground outline (radius vs angle, 2 Fourier orders) goes to the terrain as
`boulder_at[7]`/`boulder_shape[7]`. Yaw offsets for boulder_01 (3.2) and boulder_02 (0.3) were
chosen so milestone_3's golden-hour waterline rays stay 5/5 clear (the new shapes blocked 2 of 5 at
the old yaws). Far-bank margin rocks are placed along the reach the bar looks across
(`FAR_BANK_X`, one of each margin scan, 1.6–2.6 m) instead of anywhere in |x| < 75; margin
MultiMeshes carry a ground plane in custom data.

**`shaders/scan_rock.gdshader`.** Granite rocks (per-file `granite`/`veins` table in
`scan_rocks.gd`): baked moss/shadow blotches flattened toward the mean (they read as camouflage),
object-space crystal grain (two octaves, faded before it aliases), quartz veins (seeded planes, some
cells), rust spots in hollows and runs down steep faces, darker undersides/bleached tops, crustose
dots; soft ceiling at 0.36 so pale crystals never blow out. All rocks: lichen only above the spring
flood line, scoured/silt-filmed below it; wet band 0.32 m above the live river and soaked at the
line; contact darkening and splashed sand at the foot (UV2 ground for bar boulders, instance
ground plane for margin rocks); `rain_wetness` darkens (×0.5) and glosses (roughness 0.2).

**`shaders/terrain.gdshader`.** Bar: anti-tiling patches now also vary texture scale 0.65–1.55
(cobble-size zones); low swales tilt the shading normal and hold sand; sand ripples near the
camera (fields, not everywhere); gravel toning pulls bright white/cream pebbles toward grey-tan and
down 40 %, rust/ochre families browner; boulder contact shade, sand banked on the sides and a
tapered lee drift (upstream faces stay coarse cobble); no sand pockets below the late-summer low
water. Damp margin: soaked silt-skinned strip 0.3–0.6 m and a damp ragged band 1.2–2.6 m from the
live waterline (horizontal distance from the slope, capped 0.5 m above it), darker (×0.42), satin
rather than mirror (a glassy bank washed the darkening out); lighter hand under water. Oak duff:
warped, noise-broken litter islands fading over 2–8 m (no disc). Plain-ground path (store
clearing): redder/darker/trampled soil reaches, broken litter drifts, trodden stones. Walls: dry
cliff rock is matte (roughness ≥ 0.62–0.9 by steepness, SPECULAR 0.28) — the night streak in
`downstream_00h` was moonlight specular on a ledge (streak peak 196 → 93 on an 8-bit scale,
surrounding cliff 48). Rain (`rain_wetness`): ×0.5 and glossy, hollows first. River bed below
−0.3 m (greybox kind 4) now draws as river cobble, not wall talus (`greybox.gd` one line: it
clamped kind 4 to 3, which painted grey slate slabs on the deer/fish views).

**`shaders/rock.gdshader`.** `rain_wetness` darkens and glosses (bedrock slabs, wing dam, store ring).

**Cobbles (`scripts/cobbles.gd`).** Kinds retoned: fewer and greyer whites (14 → 7 %), browner tan
and rust, more slate (20 %) and greenstone (13 %). Placement draws unchanged.

**Clutter (`scripts/ground_clutter.gd`).** Own second generator (seed 184852, Stage 3 draws
unchanged): wrack logs 1.1–1.6× (3.4–5 m) lying along the flow, branches 1.2–1.9× on the wrack line
and boulder jams, 9 stranded snags (rolled so the trunk lies on the ground and the fork sticks up)
with logs jammed against them on the high-water line, and two snags against each boulder's inland
and lee faces; both ends of every long piece are checked against the panning strip, camp and
boulders. 99 pieces (was 81); snags cast shadows.

#### Findings → status

| # | Finding | Status | Evidence |
| --- | --- | --- | --- |
| 1 | ≥ 10 distinct silhouettes | fixed | Census (ID-coloured rocks over the tour cameras, ≥ 800 px): 13 meshes. 01 wildlife_bear, shoreline_close, valley_low, crew_work; 02 downstream_* (left), shoreline_close, wildlife_deer; 03 across_river, far_wall, quail, crew_work; 04 upstream (right), crew_work (centre), crew_lineup, quail; 05 camp_10h, camp_close, near_wall; 06 crew_supper, squirrel, near_wall, downstream_*; 07 valley_low, crew_work; 08 upstream_10h end; 09/10/12 far bank in across_river, far_wall, wildlife_deer/bear; 11 deer_close, jay; 13 downstream_* far end, deer, shoreline. No block shapes left (`boulder_meshes_new.jpg`). |
| 2 | Boulder surfaces | fixed | Grain, veins, rust, flood-line scouring, wet band, contact/drift; no rock pixel > 0.85 in any view; across_river_10h boulder no longer smeared. |
| 3 | River bar | fixed / partly | Damp margin visible in across_river, bear, deer views; pebbles toned; size zones, swales, lee drifts, ripples; much more driftwood (crew_work, downstream). Ripples read slightly regular close up. |
| 4 | Camp/store ground | partly | Oak duff now irregular. Store yard: natural no-vertex-colour path, no uniforms needed from C-props. **C-props:** `camp.gd` still adds its own 2.5 m `Assets.rock("duff",2)` disc under the fire (hard edge, visible in camp_close_10h) — remove or fade it. |
| 5 | Rain wetness | fixed | rain_downstream_10h lower-half 0.164 → 0.118; ground ≈ ×0.5 linear in rain (`cmp_rain.png`). |
| 6 | White square | not mine | A `SeasonEnd` snow flake (2.5 cm untextured GPUParticles3D quad): `tests/visual_tour.gd::fixed_particles()` calls `restart()` on every GPUParticles3D, which restarts the season-end snow although it is not emitting. Reproduced with `look.gd restart=1`; flakes also in merge8/c_ground `near_wall_10h`/`far_wall_10h`. **C-sky:** skip particles with `emitting == false`. |
| — | Night cliff streak (orchestrator) | fixed | `downstream_00h` (`night_a/b_crop.png`). |

#### Gates

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| downstream_10h lower luminance / saturation | 0.38–0.50 / ≥ 0.20 | 0.421 / 0.262 | pass |
| downstream_13h lower luminance / saturation | 0.38–0.50 / ≥ 0.20 | 0.442 / 0.254 | pass |
| downstream_1925 mean / baseline | ≥ 0.90 | 0.890 (merge8 0.877) | fail (S-sky's; not worse) |
| downstream_00h mean / baseline | ≥ 0.90 | 1.344 | pass |
| Distinguishable boulder silhouettes | ≥ 10 | 13 | pass |
| milestone_5 footprint/placement/collision, milestone_1 feet | pass | pass | pass |
| milestone_3 golden-hour rays | ≥ 4/5 | 5/5 | pass |
| Asset audit | exit 0 | 135 files, 0 failing | pass |

#### GPU A/B (20th-pct GPU ms, 24 cycles, 1500-frame warm-up, quiet GPU)

| Toggle | downstream | wade | overview |
| --- | --- | --- | --- |
| terrain shader new vs merge8 | +0.008 | −0.046 | −0.020 |
| scan_rock shader new vs merge8 | +0.014 | +0.017 | +0.009 |
| rock shader new vs merge8 | +0.003 | +0.005 | −0.001 |
| new snags (added instances) | +0.016 | +0.008 | +0.017 |
| all of the above together | **+0.038** | **−0.019** | **−0.011** |
| all ground clutter (for scale) | +0.046 | +0.038 | +0.015 |

The new terrain features first cost +0.06 ms downstream; paid for by sharing noise (swale, 1 m
lumpiness, damp edge/reach, ripple fields, wander, soil, silt), gating the boulder loop to x −45..38
and the oak litter to inland > 7 m, and single-octave noise for wall strata, rind and moss. Probe:
`cground_evidence/probe_cg.gd --pass=cgfinal` (note: the attribution probe's `_terrain_swap` and
any repeated override swap find no terrain surfaces after the first swap; `_terrain_ab` caches them).

#### Shared files

`scripts/greybox.gd` (one line in `_visual_triangle`: river-bed kind 4 no longer clamped to wall),
`assets/CC0_MANIFEST.json` (rows for `rock_moss_set_01` 4k, `namaqualand_boulders_01` 4k,
`dead_tree_trunk_02` 1k; outputs appended).

#### Sizes

Boulder GLBs 14.4 → 13.3 MB; new snag 0.46 MB: about −0.6 MB net.

#### Regression amendments

None. milestone_5 ranges unchanged (all boulders 2,000–3,000 tris; snag is clutter, not asserted).

#### Still weak

Close-up sand ripples are a little regular; margin rocks are small in most views (1–5k px); boulder_02
(quartz) is the brightest object in the downstream series; the far bank's wet strip is narrow
because the bank is steep; scan_rock costs +0.01–0.02 ms more than merge8.

### Wave C — C-plants (vegetation)

October 2, 2026. Tour label `c_plants` (`artifacts/visual-tour/c_plants/`, before/after sheets
against `merge8`). Probe logs and the probe variant: `artifacts/perf_probe/c_plants/`.

#### What changed

**Performance (hard gate).**
- `shaders/foliage.gdshader`: alpha-to-coverage replaced by alpha scissor on every foliage
  material. A2C is not kept anywhere, not even on the bar oaks: with TAA the scissored
  edges looked the same in `under_oak_10h`, `camp_close_10h` and `wildlife_jay`.
- Understory shadows off (`UNDERSTORY` third field) for every plant except the new oak
  saplings near the bar. Willow and alder within about 90 m of the bar cast their shadows
  through opaque ellipsoids sized to the crown (`Understory/willow_shadow`, `alder_shadow`:
  shadow pass only, 64 triangles each).
- Conifers past 60 m (`*_distant`): `cast_shadow` off. Opaque 7-sided cones whose crown base
  and width come from the species' distant mesh cast their shadows (`<species>_shadow`,
  shadow pass only).
- Bar black oaks: `gi_mode` disabled (see the bark finding). They still receive GI and cast
  sun shadows.

**Under the oak.**
- *Near-black trunk.* Cause: SDFGI voxelises a crown's cards as a solid blob, so the trunk and
  the crown's underside got almost no indirect light. The trunk's shaded side measured luma
  4/255 in `merge8`. Bar oaks no longer occlude GI, which brings it to 31/255. The bark shader
  also grades each layer (`Assets.BARK_LOOK`: gain, saturation, normal depth, and a cavity AO
  taken from the scan's own furrows, so the plates read in shade). The oak layer is now
  grey-brown: gain 1.3, saturation 0.4, normal depth 1.7, cavity 0.85.
- *Stretched leaf strips.* These were cards seen nearly edge-on. The foliage shader now fades
  any card whose face (taken from screen derivatives) is within about 17° of the view ray.
  Leaf litter is exempt (`flat_cards`).
- *Bare sand.* `_oak_floor()` (own RNG, seed 184827) adds ground life inside each bar oak's
  4.6 m canopy circle, which keeps it inside C-ground's duff circle. Each oak gets about 12
  leaf-litter patches, grass tufts at the trunk foot and the drip line, ferns on the inland
  side, and 4 black-oak saplings (0.9–1.6 m). The river side of the crown edge carries the
  taller plants, because that is where the bar's views meet the oak. Nothing is placed within
  12 m of the water, in camp or on boulders, and nothing has collision. New assets, from
  `tools/art/build_trees.mjs`: `assets/plants/oak_sapling.glb` (EZ-Tree, 648 tris, oak atlas
  and oak season) and `leaf_litter.glb` (8 flat cards cut from the oak atlas, 16 tris, always
  dry).

**Treeline.** `_riparian()` (own RNG, seed 184831) replaces the single-row hedge:
- Clumps 5–19 m long separated by 2.5–11 m gaps.
- Three depths up the talus apron: sedge at the water; willow in front, a sixth of them young
  (0.3–0.5×); white alder behind, 8–12 m tall.
- Lone alders or young willows stand in some gaps, and plants lean out over the water.
- Per-plant looks (`Assets.PLANT_LOOK`): alder is darker and bluer (`leaf_tint`) with a pale
  stem; willow is lighter and grey-green.
- The near-bank strip past the ends of the bar uses the same rules.
- Instances: willow 286, alder 31, sedge 282 (before: about 187, 33, 310).

**Rim conifers.** `_rim_trees()` (own RNG, seed 184837) adds 70 ponderosa, Douglas fir and
incense cedar along the far rim and the first 22 m behind it. They are at least 4.5 m from
any tree and use the distant meshes, with shadows from proxy cones. They live under
`Understory/rim_*` as wall dressing, like the live oaks. The 600 Milestone 5 conifers in
`placements` are unchanged.

**Season.**
- `timing_spread` (foliage uniform, set from `SEASON`) spreads the turn three ways: per
  instance, per card, and toward the outer crown.
- Bar oaks get a 2.2× wider per-tree timing and a warm or lemon autumn hue per tree. The black
  oak window moves to 0.60–0.86 and leaf drop to 0.90.
- Cards go green → yellow-green → autumn colour, and the browner cards appear only late.
- A riparian clump shares part of its timing, so thickets turn one after another. Alder turns
  later (0.70–0.98) and only to a dull yellow-brown at 0.7 strength.
- Wall live oaks stay evergreen. None of the bar oaks is a live oak.

**Dusk glow.** The lime clump in `crew_supper_1936` is lit by the 6° sun (19:36), not by the
fires: the backlight-off and fire-light tests left it unchanged, while sun-off removed it. The
foliage now has a `light()` that matches Godot's Lambert plus transmission exactly in daylight
(`under_oak_10h` crown region is identical to the decimal). Below about 14° of sun it
desaturates the sun's colour on leaves, keeping luminance, and dims it slightly below about
11°. Effect on the clump: bright pixels down 29 %, saturation 0.72 → 0.62. `downstream_1925`
mean luminance is unchanged (0.8774 of baseline; it was 0.877).

**Floating grey square (not mine; root cause found).** It is a SeasonEnd snowflake: a
`QuadMesh` 0.025 m billboard, unshaded `Color(.84,.88,.9)`, 420 flakes in a 30 × 18 × 30 m box.
`tests/visual_tour.gd::fixed_particles()` calls `restart()` on every `GPUParticles3D`, and
`restart()` also sets `emitting = true`, so snow falls through every claim view of a full
tour. A flake that passes close to the lens reads as a big flat square. With `only=`, the
skipped slots render with 3D off, so the GPU particles don't advance and no flake is near the
lens. In `c_plants` the flakes land elsewhere (small squares on the boulder in `far_wall_10h`;
`merge8` also has one in `gravel_close_10h`). Fix for C-sky's harness: in
`fixed_particles()`, restart only particles whose `emitting` is already true. Not applied
here because the file is C-sky's.

#### Gates

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| Vegetation GPU over pre-upgrade (downstream / wade / overview) | ≤ +0.35 / +0.45 / +0.35 ms | −0.05 / −0.07 / −0.53 (quiet pair, below) | pass |
| `under_oak_10h`, treeline views natural | blind check | grey-brown textured trunk; sapling, ferns and grass at the crown edge; no edge-on strips; clumped, three-depth riparian with distinct alders; denser rim | for review |
| Day 10 vs day 100 differ | visibly | foliage pixels moved > 10° toward yellow: `under_oak` 85 %, `across_river` 91 %. Day-100 hue spread (p20–p80): 8.5° / 11.3° in `merge8` (uniform), 43.8° / 56.5° now (uneven) | pass |
| Conifer count | 600 | 600 placed / 600 rendered (`milestone_6_notes`), plus 70 rim dressing trees outside `placements` | pass |
| Stage 1 colour gates | 10:00 / 13:00 unchanged | lower-half luminance 0.431 / 0.456, saturation 0.28 / 0.28 (pass); `downstream_1925` 0.877 (S-sky's, unchanged) | pass |
| Suite | all pass | 37 / 37 (`LABEL=c_plants`) | pass |
| `audit_assets.py` | exit 0 | 136 files, 0 failing (`oak_sapling` 648 / 800, `leaf_litter` 16 / 60) | pass |

#### GPU-time A/B (in-process toggle, `artifacts/perf_probe/c_plants/probe_veg.gd`)

This is `probe.gd` plus `veg` and `vegparts` passes. The Vegetation node is hidden and shown
16 times per item. The figures are the 20th-percentile estimator, in ms. Runs alternated
between this worktree and `perf-baseline` (`310a9ae`). Other agents were rendering throughout;
noisy runs are left out.

| run | downstream | wade | overview |
| --- | --- | --- | --- |
| pre-upgrade (`base1`, `base4b`) | 0.64 / 0.64 | 0.57 / 0.57 | 1.31 / 1.29 |
| merged `88ac33d` (`merged1`) | 1.67 | 1.66 | 1.87–2.70 |
| this branch (`mine4b`) | 0.59 | 0.50 | 0.75 |
| **over pre-upgrade** | **−0.05** | **−0.07** | **−0.53** |
| saved vs merged | 1.08 | 1.16 | 1.1–1.9 |

Parts (`mine3`, noisy). Understory 0.26 / 0.26 / 0.41, of which willow and alder 0.22 / 0.23 /
0.12 and the oak floor about 0.02. Bar oaks 0.18 / 0.13 / 0.04. Distant trees 0.01 / 0.06 /
0.16. All vegetation shadows 0.25 / 0.28 / 0.29.

Supper: vegetation 0.47–0.49 vs pre-upgrade 0.68–0.84. Store: tree MultiMeshes 0.63–0.81,
0.54 of it their double-sided shadows (`store.gd`, C-props); the store frame is 2.9 ms against
4.5. The store trees could take the same cone shadow proxies if C-props wants 0.4–0.5 ms.

#### Shared-file hunks

`scripts/asset_library.gd` (all mine):
- `SEASON` gets timing spreads and the `litter` key.
- `UNDERSTORY` gets `oak_sapling` and `leaf_litter`.
- New `UNDERSTORY_ATLAS`, `PLANT_LOOK` and `BARK_LOOK`.
- `_bark_material` passes the bark grade.
- `_leaf_material` passes `timing_spread`.
- `understory()` applies `PLANT_LOOK`.
- `STEM` gets alder and `oak_sapling`.

`Assets.plant()` and `Assets.understory()` signatures are unchanged. No test, scene, project
or budget file was edited.

#### Regression amendments

None. No test or threshold changed.

#### Sizes

`oak_sapling.glb` 41 KB and `leaf_litter.glb` 2.4 KB. No new textures.

#### Still weak

- The supper clump still reads warm yellow-green. It really is sunlit at 6°, and cutting more
  would flatten golden hour.
- Willow and alder are still EZ-Tree stand-ins with stamped sprays; up close (`downstream_10h`
  far bank), alders read as small round trees, not true white alder.
- The understory's 12 m shore rule leaves the bar between the oaks and the water bare by
  design. In `under_oak_10h` the frame's foreground is that bar, so the oak floor shows only at
  the crown edge.
- Rim trees are seated on greybox's render mesh (`_wall`). Where C-canyon's cliff kit overhangs
  the rim, a trunk foot can sit inside a kit piece.
- The probe's A2C what-if rows in `artifacts/perf_probe/probe.gd` no longer find the
  `alpha_to_coverage` line, because it is gone. They will print "shader edit not found".

### Wave C — C-sky (daylight, clouds, fog, water, rain, tour harness)

Done October 2, 2026. Tour `artifacts/visual-tour/c_sky/` (sheets `tour_compare_*` against
`merge8`; gate run against `baseline`, kept as `tour_vs_baseline.json`).

**Clouds (finding 1).** `shaders/sky_clouds.gdshader` now marches ten steps through a slab of
heaped cumulus instead of shading one flat sheet: a heap stands tallest over the core of its
cluster (the coarse octave of the shared field) and the fine octaves break its outline, so
bases are flat and grey (darker under the thick cores) and tops rounded and sunlit. Near the
horizon the march is capped at about one cloud's depth, and the step offset is jittered per
pixel and per frame for TAA. A low sun lights the bases from below (`underlight`, warm cloud
undersides at golden hour). `sky_clouds.gd`: the first heaps stand by mid-morning (build
from 08:00 instead of 09:00, base cover 0.30 → 0.33). Daytime depth fog on the open sky
`fog_sky_affect` 0.15 → 0.05, and the volumetric fog is three times thinner (below), so
cumulus stand against blue. The drift phase was re-picked from 160 seeded candidates
(`artifacts/csky/phase_search.gd`): score = cloud cover in the visible sky of eight views
(downstream 06/10/13, upstream, far and near wall, under-oak 10/13), constraint = the
downstream bar in the 10:00 and 13:00 gate views stays out of cloud shadow (lower-half
luminance within 1 %). Cloud shadows now fade at 450–1000 m (was 180–650 m), so they also
cross the near ridges.

Root cause found while doing this: the downstream gate views contain almost no sky. C-canyon's
bend ridge rises to about 29° elevation, the top edge of the frame, leaving ~1.3 % of the
frame as sky (a sliver at top right). There the clouds now cover about half of that sliver;
upstream, under-oak, near/far wall and the valley view show readable heaps. A bigger cloud
presence downstream needs a lower ridge or a different camera, which are not mine.

**Golden hour (finding 2).** `daylight.gd` splits the low-sun range in two: *golden*
(sun above ~9.5°, e.g. 19:15 and 06:00) and *dusk* (below ~6.5°, e.g. the 19:36 supper).
Golden: sun (1.0, 0.76, 0.50) at 2.8 (was (1.0, 0.82, 0.62) at 1.9), warm Mie glow,
volumetric haze 0.004 → 0.0012 with near-neutral albedo (a blue veil lit amber was the milky
cream), tighter forward lobe (anisotropy 0.6) so the glow sits round the sun, RiverMist
0.006 → 0.0014. Dusk keeps the Stage 1 light and blue haze, so the fire-lit camp is
unchanged (crew_supper_1936 mean 0.189 vs 0.183, lower half 0.256 vs 0.248, SSIM 0.93).
The shade stays cool (shadow/sunlit B:R 1.88 in the water harness). downstream_1925 mean
luminance 0.877 → **0.924 × baseline**.

**Haze and aerial perspective (finding 3).** Volumetric fog 0.004 → 0.0012 by day (night
0.0045, dusk 0.004); ClearRimAir now removes 80 % of whatever the global density is (it was a
fixed −0.003). Depth fog begins at 120 m and ends at 1000 m (golden 1100), so with Godot's
smoothstep ramp it is ~10 % at 300 m, a third at 450 m and over half only at the 600 m far
clip: the bar, the walls and the 50–200 m middle distance keep contrast and colour, the far
ridges fade. RiverMist shortened from ±500 m to **±170 m** (`claim.tscn`, size 1000 → 340), so
it no longer runs through the bend walls; day density 0.003 → 0.0008.

**Night (finding 4).** The bright vertical streak on the left cliff in `downstream_00h` is the
canyon terrain wall itself (`Greybox/CanyonAndGravelBar`, terrain shader), exposed in a gap
between cliff-kit pieces on the far wall at about x 95–115, z −60…−70, y 20–35 (150 m from the
camera; picked with `artifacts/csky/pick.gd`), facing the low moon. Most of its brightness was
moon specular at a grazing angle: `moon.light_specular` 1 → 0.05 takes its peak from ~150 to
~90 against ~50 around it. The remaining diffuse contrast is the bare wall being lighter than
the kit: **for C-canyon** (fill that kit gap) or C-ground (rock-layer albedo there). Night
colour: moonlight (0.75, 0.83, 1.0), fog light and fog albedo blue-grey instead of saturated
blue, and the moonlit haze now veils the night sky as it veils the ridges
(`volumetric_fog_sky_affect` 0.04 → 1.0; it was why ridge-top trees hung as dark shapes
against a brighter sky). Lower-half saturation 0.453 → 0.321.

**Rain (finding 5).** New `shaders/rain_streak.gdshader` (spatial, per drop): a 0.55 m trail
slanted along the drops' wind-blown fall (1.6, −10.5, 0.5 m/s), turned to face the lens about
that axis, never narrower than 1.5 px (narrower streaks fade instead: soft depth falloff
rather than shimmer), faded in from 3–7 m and out at 16–30 m. 20,000 drops in a 28 m box
(was 5,000 in 20 m: twice the density). The particle shader's `sin()` hash lost precision at
large drop numbers, so many drops fell on the same lines (the full-height "film scratches");
it is now an integer hash of `RANDOM_SEED` and `NUMBER`. `rain_wetness` is driven during rain
(1.0 in the tour's rain view; `current / 0.8` in play) as before.

**Water (finding 6).** `shaders/water.gdshader`: (a) the absorption path is capped at twice
the bed depth, so views steeper than 30° are unchanged while grazing views (where the straight
ray ran six times the depth) see their shallows; (b) within ~25 m of a low viewer, over water
shallower than ~2 m, reflection eases off (the bed shows through, as the eye adapts to it);
(c) the bed sample uses an explicit mip level from depth (automatic selection blurred the bed
into murk at grazing angles). Long reaches: beyond the reflection probe's box the engine could
only reflect open sky, hence the flat milky pond; there the water now reflects an approximate
canyon (walls below a rim, hazy sky above, lit for the hour by `daylight.gd`), and beyond
~25 m current lines (long streaks of brighter, aerated water carried with the flow) replace the
averaged-out ripples. `greybox.gd::_build_river` bakes the world flow direction into UV2, which
turns with C-canyon's bend beyond |x| = 160 (COLOR keeps the analytical flow, so the M4 vertex
checks hold); the shader scrolls normals and lines along it.

**Floating grey square and tour timing (finding 7).** The square was a SeasonEnd snowflake:
`fixed_particles()` called `restart()` on every GPUParticles3D, which also switches emission
on, starting the first-snow emitter (found independently; C-plants reported the same). Fixed:
only emitting systems restart. Slot overruns: `merge8` was captured without `--fixed-fps 60`;
then physics ticks follow the wall clock, so `place()`'s 90 physics frames span hundreds of
render frames and views overrun. The tour now re-runs itself in a child process with
`--fixed-fps 60` when started without it (exit code and output passed through). Full runs:
31 views, no overruns, no grey square.

**Perf (finding 8).** `directional_shadow_blend_splits` off (no visible seam; A/B images
identical to the eye, differences only in leaf-level shadow texels). GI at half resolution
(`project.godot`): image differences mean ≤ 0.3/255, p99 ≤ 4.3/255 in downstream, under-oak,
camp and the night camp — taken.

GPU A/B in one process (`artifacts/csky/probe.gd`, pass `csky`: each feature toggled between
this branch and its `merge8` state, 16–20 cycles; 20th-percentile estimator, ms; two runs):

| | downstream | wade | overview |
| --- | --- | --- | --- |
| clouds + shadows + water + fog, wave C vs merge8 | +0.007 / −0.002 | −0.001 / −0.021 | +0.012 / +0.014 |
| of which water shader | +0.001 / +0.000 | −0.006 / +0.082* | −0.003 / +0.003 |
| sun blend_splits off (saving) | 0.28 (run 1) | 0.21 / 0.29 | 0.12 / 0.13 |
| GI half resolution (saving, run 1; now baked in) | noisy | noisy | 0.12 |

*noisy run (IQR 0.26). The first run predates the last water edits. Target ≤ +0.05 in every
view: met. Rain in the store pose (full rain,
20,000 drops): +0.009 ms. Rain is inactive in the miner_performance views.

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| downstream_10h lower-half luminance / saturation | 0.38–0.50 / ≥ 0.20 | 0.428 / 0.297 | pass |
| downstream_13h lower-half luminance / saturation | 0.38–0.50 / ≥ 0.20 | 0.450 / 0.293 | pass |
| downstream_1925 mean luminance / baseline | ≥ 0.90 | 0.924 (merge8 0.877) | pass |
| downstream_00h mean luminance / baseline | ≥ 0.90 | 1.026 | pass |
| crew_supper_1936 (protect) | unchanged | mean 0.189 vs 0.183, SSIM 0.93 | pass |
| Tour determinism | no slot overrun | 31/31, none | pass |
| Water probes `capture_greybox --water-only` | pass | all colour/glint/contact probes pass (see amendment); the wall-clock 1080p check passed at 3.92 ms p95 in one run and failed at 7.58 in another on the loaded machine | pass |

`merge8` itself fails the `--water-only` "Shallows green" probe (0.310 > 0.289); this branch
passes it (0.312 ≤ 0.323). In the full `capture_greybox` harness the water probes pass too
(channel G/R 0.894 against a floor of 0.853). Its asset probes at 19:15 (gravel and granite
luminance deviation, conifer canopy G/R ≥ 1.2) already fail on `merge8` lighting (0.017, 0.030,
1.155 — measured with this branch and `merge8`'s `daylight.gd`); with the amber golden hour
the canopy reads 1.010. They belong to the ground and plant probes and are left as they are.

`miner_performance` wall clock at the end of the work (machine still shared): p95 downstream
4.65, wade 5.31, overview 4.95 ms — all under 5.5.

**Regression amendment (tests/water_capture.gd).** The channel probe's G/R floor of 0.95 was
an absolute value measured under the Stage 1 golden-hour light (S1's own amendment). Finding 2
asks for a deeper amber sun in clearer air at that same 19:25 pose, which warms everything the
probe sees: the sunlit dry gravel now measures G/R 0.735 and the channel 0.834–0.843 (with
`merge8`'s water shader and this light it is 0.851, so the water is not the cause). The floor
is now relative to the sunlit dry gravel in the same frame: the channel must be at least 5 %
greener than it (measured 14 % greener). The emerald ceiling (1.12), the blue limit
(B/G ≤ 0.92) and "darker than the shallows" are unchanged and pass.

**Shared files.** `scenes/claim.tscn` (RiverMist size), `project.godot` (one line:
`global_illumination/gi/use_half_resolution=true`), `tests/water_capture.gd` (amendment
above), `tests/visual_tour.gd` (harness: particle restart, fixed-fps relaunch).

**Suite.** 37/37 (`LABEL=c_sky`). **Assets.** None added (one new shader file).

**Still weak.** Downstream skies are a 1 % sliver (geometry). The night streak keeps a diffuse
residue until the kit gap is filled. The reach reflection is an approximation (a lit band,
not the real walls). Clouds are one heaped layer: no parallax between heaps, and seen from
right under them they still read as a sheet. Rain has no splashes or ripples on the bar.

### Wave C — C-canyon (canyon reach, ridge forest, cliff kit, talus)

Second attempt on the Stage 2 gates. Tour `c_canyon` (`artifacts/visual-tour/c_canyon/`,
before/after sheets against `merge8`). Render-only throughout: collision, river volumes,
the 10 back-wall hulls, the claim reach's render surface and S4's wall-plant seating are
unchanged.

#### What changed

**Ridge relief** (`scripts/canyon.gd`). The slopes above both rims of the bent reach now
carry structure instead of a smooth sweep: cliff bands (7 m risers of 8-19 m on the far
wall at about 74/128/196/262/335 m above the rim, 4 on the near wall, each wandering
±18 m and dying out along the valley), draws (gullies 7-16 m deep that meander down the
slope) and tors (low rock knobs seeded per 70 × 56 m cell, most on the crests). The crests
are wider and less varied (half-widths 85/150/190 m, ±30 % height) so their faces lie at
35-50 degrees and can hold timber between the bands. On stretches of the bent reach the
three claim-style cliff bands below the rim merge into one face, and their faces stand
out or fall back by up to 5 m (`rib()`), so the walls round the bend are not the claim's
terraces repeated. The same functions return a ground cover per point (forest density,
draw, rock, scree): timber is thick in the draws, open on spurs and crests, absent on
rock and the scree fans below each band. Stage 2's three-octave noise on the bent reach
was replaced by two longer octaves (its finest octave stood up as 60-degree spikes on
the finer grid).

**Render grid** (`greybox.gd::_visual_section/_visual_column/_visual_triangle`). The bent
reach samples the far slopes every 5 m (near slopes 10 m) up to 300 m above the rim and
splits the 20 m columns into 5 m (10 m beyond |x| 330, unchanged beyond 450). Claim-reach
columns repeat their FINE rows to the same count, so their surface is identical (the
repeats are skipped as zero-area). `wall_point()` gained an `eased` flag: more than 15 m
into the bend its ledges and most of its noise fade out above the rim, leaving the forms
to the relief. The vertex colour carries the ground cover and UV.x the height above the
rim to the ridge shader. The ridge material now starts where the slopes do (8 m above
the rim, meandering between |x| 175 and 205 m) and takes the cliff bands too beyond
|x| 205-245 m. CanyonReach: 14.7 k → 48.6 k triangles (no shadow, no GI).

**Ridge shader** (`shaders/ridge_forest.gdshader`, rewritten). Dry Sierra slope in late
summer instead of pale soil: needle duff and red-brown soil under timber, olive chaparral
and cured tan grass on sun-facing (-Z) slopes, pale scree fans, and slate/greenstone rock
in dipping strata broken into jointed blocks that are lit block by block. Steep ground is
rock whatever the cover says; the first 8-22 m above the rim are broken cliff top. Within
~100 m of the bend start the rock continues the terrain shader's strata exactly (same
integer hash and fbm), blocks fade and grass/chaparral give way to duff, so the material
change at |x| ≈ 185 m no longer shows as a line from the high cameras. Canopy texture is
clumped by the cover, with oak-coloured crowns in the lower sunny stands.

**Treeline** (`canyon_dressing.gd::_treeline`). 2,600 trees per end (was 2,000) placed by
the ground cover, not uniformly: spires 9-33 m tall (most young, a few big; draws grow
them 30 % taller; below the rim only small ones on benches) and, on lower south faces,
low six-sided oak domes (24 triangles). The seam trees at |x| 160-240 m are fir and cedar
only: the distant ponderosa LOD is a long bare trunk under a small crown and read as a
pole at 150-250 m.

**Far wall** (`canyon_dressing.gd::_tall_cliffs/_toe`). Every 40-80 m along the claim
reach a slate scan spans two cliff bands and the bench between (stretched up the face,
out of GI), replacing the band pieces it covers, so the wall reads as one high broken face
rather than a quarry ledge. At the waterline, rock fallen from the wall in runs with gaps:
talus 0.9-3.6× scale, some standing in the shallows, and low bedrock bluffs (cliff_face
scans) facing the river — the foot of the wall is no longer one straight line along the
water. Seed 184828/184829; all MultiMesh, no shadow, no collision.

**Kit colour** (`shaders/cliff_kit.gdshader`). `scan_mean` was the scans' sRGB mean (0.40)
applied to linear texels (0.15), which left the kit at about two thirds of the albedo the
shader intended; in merge8 the pieces' mean luma matched the wall's (0.27 vs 0.27 on the
far wall) only because the scans' crevices ran near black, and they read as flat grey
lumps without the wall's banding. Now 0.147, with the scan's light/dark eased (pow 0.75),
slate/greenstone tints set against the terrain's bedrock set, the walls' strata (same
hash) multiplied in so a piece's bands line up with the wall's, and pieces in the bend
lifted to meet the paler ridge rock. Kit vs wall luma with the dressing shown/hidden:
far wall 0.30 vs 0.28, bend at 300 m 0.22 vs 0.20, high camera 0.34 vs 0.30 — a touch
proud, as sunlit outcrops are. SPECULAR 0.3 (rock is a poor mirror). LOD bias 0.45 → 0.25 for all kit groups.

#### Findings

| # | Finding | Result | Evidence |
|---|---|---|---|
| 1 | Distant slopes smooth, rockless, even same-size trees | fixed (own check) | `downstream_10h`, `upstream_10h`, `valley_low_10h` end on banded rock and timber in clumps with open ground; `look_k/high_dn` shows bands, tors, draws, scree |
| 2 | Snowfield in `downstream_06h` | fixed | top centre is now duff/olive/tan with rock bands; no pale ground left |
| 3 | Far wall base straight, wall low | partly | `far_wall_10h`: rocks and bluffs break the toe, tall faces span two bands; the water strip itself (C-sky) is unchanged and short stretches of plain toe remain |
| 4 | Seating; seam at |x| ≈ 185; seam poles | fixed / fixed / fixed | talus sunk 20-40 % of height; seam strata continuous (`look_l/seam_hi_dn`); seam trees fir/cedar |
| 5 | Night streak `downstream_00h` | not mine | it is the terrain material's specular on the far wall (gone with the terrain swapped to a SPECULAR 0 flat material; unchanged with the dressing hidden) — `terrain.gdshader` (C-ground) |
| 6 | Kit vs terrain colour | fixed | see Kit colour |

#### Performance

GPU ms of my nodes (CanyonDressing + CanyonReach) shown vs hidden, same probe and
protocol as `perf_probe/attribution.md` (20th-percentile of 12-frame windows, 16 cycles),
before (HEAD files) and after alternated in the same session:

| view | HEAD (merge8 files) | Wave C | Δ | rounds (quiet windows) |
|---|---:|---:|---:|---|
| downstream | 0.20 | 0.18 | −0.02 (rounds: +0.00, −0.02, +0.01, −0.02) | 4 rounds, 2-3 launches each |
| wade | 0.27 | 0.28 | +0.01 (rounds: −0.00, −0.01, +0.03, +0.02) | 4 rounds |
| overview | 0.23 | 0.16 | −0.08 (rounds: −0.06, −0.11, −0.07, −0.08) | 4 rounds |

Logs: `artifacts/c_canyon/ab_r1..r4.log` in the worktree (r1 was taken while the hung
processes were still loading the GPU; r2-r4 after they were stopped). Inside the total:
the kit LOD bias 0.45 → 0.25 saves 0.03 (bar) / 0.07 (overview); the new ridge shader
costs ~0.03 more than Stage 2's at the bar, less in the overview; toe rock and tall faces
0.01-0.02 together. All three views stay at or under +0.3 ms; the wade view is flat
within the noise floor (null-toggle IQR ±0.01-0.02).

Claim build (headless instantiate + ready, alternated): 2.9-3.0 → 3.7-4.0 s (+0.8 s: the
finer bent-reach grid and its ground cover ~0.6 s, the cover-driven treeline ~0.3 s; first
cut from +2.6 s by caching per-column relief and coarser near-slope rows). Not a gate.

#### Gates and checks

| Gate | Target | Measured | Result |
|---|---|---|---|
| Stage 1 colour gates (10:00/13:00) | lower-half luma 0.38-0.50, sat ≥ 0.20 | downstream_10h 0.430 / 0.281, downstream_13h 0.456 / 0.276 | pass |
| Golden hour | ≥ 0.90 × baseline | 0.877 (merge8 0.877) — S-sky's | unchanged |
| My GPU cost | ≤ +0.3 ms any view, not risen | see table | pass |
| Collision | unchanged | ground trimesh from unchanged sections; hulls untouched; river volumes untouched | pass |
| Suite | all pass | 37/37 (`LABEL=c_canyon`) | pass |
| Asset audit | exit 0 | 134 files, 0 failing (no assets added) | pass |

No regression amendments. No assets added or changed (0 MB).

#### Still weak

- The ridge rock is procedural blocks on a 5 m mesh: right at 200-600 m, flat if a free
  camera flies close. No kit pieces stand on the ridge tors.
- Spires and domes stay low-poly cones and domes; fine at 300 m+, toy-like up close.
- The far waterline is still a clean edge where there is no toe rock; the near-black
  water strip under the far wall is C-sky's.
- The night streak is in `terrain.gdshader` (C-ground): its specular on the moonlit far
  wall.

### Wave C — characters (crew, wildlife, fish)

Done October 2, 2026 (C-characters). Tour `c_characters` (31 views, before/after against
`merge8`) in `artifacts/visual-tour/c_characters/`, with close evidence in its `extra/`
(plain-light lineup, deer sheet, sleeves and hands, supper crop, fish crop, perf logs and
the probe scripts). No views added; `wildlife_jay` and `wildlife_squirrel` re-framed as asked.

**1. Crew period dress.** Doyle's sky-blue army trousers (the "stonewash jeans") are now
dark blue kersey with a forage cap, and no hired hand wears the miner's open knee tear any
more (four patched in paler cloth, the rest mended: the knee skin under the tear is drawn
as cloth). The crossed fold ridges on every pair of trousers ("cross-gartering") are
modelled and painted into the miner's atlas: `blender/build_crew_kit.py::flatten_trousers`
relaxes the kit's own shin and boot-top geometry (radius about each leg's axis, 20
umbrella passes on the welded surface, open edges and garment seams held; 3,372 vertices,
mean 3.2 mm; the hero is untouched), and `crew.gdshader` flattens the painted fold lines on
the legs and on pale cloth. Sleeves: the miner's sleeve puffs to 7.4 cm round the upper arm,
and `sleeves_down` billowed it further ("leg-of-mutton"). The key is replaced by
`sleeves_slim`, a plain shirt-sleeve profile (5.0–5.3 cm, never inside the forearm skin + 7
mm), used by every man not in rolled sleeves (`sleeves_rolled` slimmed the same way); sleeves
to the wrist (Soto, Ruiz, Fisk) are a 9 mm cloth layer drawn on the forearm skin in the vertex
shader in the shirt's own weave, with a darker cuff. New instance uniforms `boots` and `belt`
(belt.a carries the wrist sleeves).

**2. Near-duplicates.** Re-cast in `crew_look.gd`: Soto indigo shirt under his black vest;
Freeman brown felt hat, hickory-striped shirt on braces, navy trousers, no vest; Fisk
pinstriped shirt; Price buff shirt on black braces, black trousers, no vest; Roux madder-red
toque, green-grey shirt, grey trousers, no canteen (Pike keeps the navy cap and canteen);
Lacy butternut, Brandt grey-drill trousers; boot and belt leather varied on nine men. A
pairwise check of all 91 pairs against the rule (hat or headwear AND shirt colour or pattern
AND one of vest, trousers, beard; colours apart by > 0.12 sRGB) passes with 0 failures;
the closest pair (Boyle, Price) differs in 8 of 18 cast attributes.

**3. Supper posing.** New `scripts/crew_pose.gd`, a SkeletonModifier3D on each figure
(before the build modifier), computed from the rig's bone rests: standing men's arms hang
close with palms in and fingers loosely curled (the clip's A-pose and splayed claw go);
seated men have the hips at the seat (two-bone IK for legs and arms), forearms on the knees
or hands clasped, a tin cup in hand, per-man lean and head turn from a seeded RNG. `crew.gd`
gives the ring a `SUPPER` table; `crew_hand.gd` brings a seat (chopping round, crate or
stool, existing props) and tinware (cup, plate). Work clips are untouched. Supper now shows
a harmonica player and a man eating on the ground, two seated with a cup or forearms on
knees on a round and a crate, one leaning forward on a stool, one standing with a cup, one
stretched out. No sit clip exists; the eat and lie_down clips are the miner's.

**4. Wildlife framing.** In `tests/visual_tour.gd::wildlife()` the jay and squirrel are moved
to the nearest open ground in direct sun (sun ray clear of tree crowns and of the physics
world) and seen at 9 m with an 18° lens on a crown-free sightline (`sunlit_spot`,
`open_eye`). Deer, bear and quail views keep their framing. Bear, jay, quail unchanged.

**5. Deer.** `wildlife.gdshader` lays out a black-tailed coat from rest-pose landmarks
(per model in `wildlife_actor.gd::DEER`): grey-brown saddle over a paler flank, cream belly
and inner legs, dark lower legs, white rump patch, tail black on top, grey face with a pale
muzzle band, white chin and throat, darker crown; the doe's dark eye-patch surface is now
coat (eyes small and dark, no ring); the body normal is bent toward an elliptical cross-
section (85 %), which removes the flank blotches. Buck: back grey-brown, rack at 82 % with
dark beams and paler tips. A `HeadShape` modifier lifts the doe's ears 0.42 rad about their
root bones and narrows both skulls (Head bone width 0.90 / 0.84). No sculpting.

**6. Fish.** Darker backs (`fish.gd::LOOKS`), a pale lateral line with a soft flank sheen,
and a matte back (specular and clear coat drop on the dorsal: the sky sheen hid the fish),
no emission. Each school fish casts a soft decal shadow on the bed along the sun (radial
fall-off, occlusion 0 / roughness 1 so the wet stones' glints go too; none at night).

| Gate / finding | Target | Measured | Result |
| --- | --- | --- | --- |
| Crew period dress | no denim, plain sleeves, no garters | Doyle navy kersey; slim sleeves; legs flattened (`crew_lineup`, `extra/lineup_plain_light.png`) | fixed (for blind review) |
| Near-duplicates | rule above, every pair | 91/91 pairs pass | fixed |
| Supper posing | varied, seated, holding things | 7 men: 4 seated (3 on props), 2 with cups, 1 eating, 1 lying (`crew_supper_1936`) | fixed |
| Squirrel / jay readable | in light, 8–12 m, in frame | both sunlit at 9 m, centred | fixed |
| Deer | coat, eye, antlers, ears | as above; buck ears unchanged (rig has no ear bones) | partly |
| Fish readability | visible, no glow | dark spindle with lateral line and bed shadow (`fish_underwater_10h`, `extra/fish_before_after_crop.png`) | fixed (modest) |
| Stage 1 colour gates | 10:00/13:00 pass | pass (golden hour 0.877, S-sky's, unchanged) | pass |
| Suite | 37/37 | 37/37 (161 s); crew_models, v2_flow, wildlife, milestone_9 re-run on the final cast | pass |
| `audit_assets.py` | exit 0 | 134 files, 0 failing | pass |

**GPU-time A/B** (in-process toggles, 16 cycles, 1080p, after the hung processes were
stopped; median Δ, [IQR]): supper (`crew_performance` view) whole crew 0.30 ms [0.19..0.35]
(attribution on `merge8`: 0.44); seats + tinware +0.04 [−0.04..+0.11] (low quantile +0.003);
pose modifiers +0.006 GPU, +0.016 CPU; crew `lod_bias` 0.25 (hands only, Lambert keeps 1.0)
−0.18 [−0.38..+0.09], primitives 4.84 M → 3.33 M, no visible change at 2.5 m. Wildlife view:
deer coat branch +0.006, antler +0.000, head modifiers +0.015 (deer at 3 m: 0.000 / +0.009 /
0.000). Fish: shadows (13 decals) +0.001 low-quantile at the fish view, −0.01 across the river.
Net for my features: about −0.14 ms at supper, ±0.02 ms elsewhere.

**Back-to-back p95/median** (HEAD files vs mine swapped in this worktree, two rounds,
GPU shared with other agents): `crew_performance` supper median 5.14/4.91 → 4.88/4.79 ms,
p95 6.35/5.61 → 5.94/5.64; work 5.60/5.54 → 5.59/5.17; dam 5.78/5.54 → 5.72/5.45.
`wildlife_performance` p95 6.96/6.48 → 6.88/6.49 (median 5.82/5.52 → 6.02/5.56, noise).
`miner_performance` p95 downstream 5.59/5.42 → 5.43/5.50, wade 6.31/6.10 → 6.07/5.89,
overview 5.85/5.47 → 5.70/5.22.

**Shared files.** `tests/visual_tour.gd`: one hunk in `wildlife()` (two views re-framed) and
four helper functions after it (`crowns`, `clear_of_crowns`, `sunlit_spot`, `open_eye`). No
other shared file. **Regression amendments:** none; no assertion changed.

**Assets.** `assets/crew/crew_kit.glb` 7.74 → 7.91 MB (`sleeves_slim` replaces
`sleeves_down`; flattened legs). Nothing else added.

**Still weak.** The buck's ears still jut sideways (no ear bones on the Stag rig; a fix
needs a vertex deformation or new bones) and its head stays blocky; both deer remain low-poly
Quaternius bodies, smooth but simple, and the coat is uniform at close range. The hands at
the sides read as loose fists rather than open relaxed hands in close-ups; seated men are
posed by IK, so knees and hips are plausible but not cloth-accurate, and the seat props
cast shadow. Fish are still tube meshes; from 3 m above the water the trout reads as a dark
spindle with a pale line, not as a trout. Every man still has the miner's face.

### Wave C — C-props (camp, store and props)

Done October 2, 2026 (agent C-props, tour label `c_props`, compared against `merge8`).
Final tour: `artifacts/visual-tour/c_props/` (before/after sheets against merge8);
close-ups, A/B probes and logs: `artifacts/visual-upgrade/c_props_closeups/`.

#### What changed, by reviewer finding

1. **Detail parity (store goods).** Sacks are rebuilt as sewn sacks rather than lathes: two
   panels with proud side seams (a pillow section), bottom ears, slight belly, slump and
   seeded creases; flour and salt in coarse osnaburg (new `kit_osnaburg`, from the hessian
   scan, so the weave reads), beans and coffee in burlap with rolled mouths; tied necks with
   a cord end and a flared tuft. Every sack carries a painted shipping mark (SUPERFINE
   FLOUR, SALT, RIO COFFEE, BEANS) as a decal patch on its own surface (`shaders/stencil.gdshader`,
   `assets/props/stencil_mask.png`). New salt-glazed stoneware (`kit_crock`: buff orange-peel
   body, Albany-slip shoulder with drips) jugs and crocks; nailed crates with corner battens
   and a stencilled "J. L. FRENCH CAMP" mark; a nail keg; paper-labelled boxes and tins
   (`kit_labels`: 16 printed 1840s labels, serif type, foxed paper). Stall at distance:
   lighter split-board counter front, canvas backlight raised so the roof underside glows.
2. **Period.** Price board: six butted planks in worn oxblood paint (`kit_paint`) on two
   peeled poles with rope lashings and a two-board roof; the lettering is ochre-cream
   PatrickHand (gameplay text unchanged). The "LAMBERT / FRENCH CAMP" Label3D is gone: the
   name is brush-painted in serif capitals into the canvas sign (`kit_sign`, with rules and
   lozenges). The church-pew bench is replaced by a puncheon bench (split half-log on four
   splayed pegs, `assets/props/bench.glb`, parametric). Counter slate carries wiped chalk ghosts.
3. **Shelves.** Middle shelf: soap and candle boxes, tea canisters, pepper and mustard
   tins, five bolts of cloth, stacked sardine tins and oyster cans, candle and match and
   saleratus boxes, pickle jars, three hanging candle bundles, folded striped trade blankets
   (`kit_blanket`), a lard crock and a jug. Bottom-shelf ends: nail keg, two jugs and a
   crock. Top-shelf ends: tin plates and cups, tin coffee pot, flints and percussion caps.
   Outside the east wall (facing the trail): rope coil, frying pan, tin kettle on pegs.
   All stock items, names, positions and shelves.gd mappings are untouched.
4. **Camp.** Lean-to canvas re-modelled as cloth: catenary sag down the slope, troughs
   between the four hem stakes, tension wrinkles from each stake to the forks, scalloped
   hem, a folded front flap, side wings brought down to staked feet, a bowed ridge pole;
   stakes are pale whittled wood and ropes 7-8 mm so they read. The bought tent and the
   crew bunk tents are a new canvas A-tent (`assets/camp/tent.glb`: sagging slopes, rolled
   door flaps, hem ties, stakes, guy lines) over the expedition tent kept as hidden
   collision (`camp.gd tent_instance()`). Bedroll: red wool roll with striped inner layers
   and leather straps at the shelter mouth, coat pillow, ground cloth. New cook gear
   (tin coffee pot, Dutch oven with flanged lid, legs and bail, tin plates, cups); woodpile
   doubled with stakes, rounds and kindling. Layout and collision frozen (camp tests pass;
   shelter front bound still 3.29 m).
5. **Fire.** Ring of ten separate river cobbles (Poly Haven `stone_01`, normalised to 240
   tris, packed end to end, sunk a third, soot and per-stone tone in vertex colour) round a
   sooty ash bed. When lit: nine crossed flame ribbons (`fire.gdshader` mode 1: noise-torn
   tongues, yellow root, red tips), coals glowing in cracks (mode 2), a thin smoke column;
   the old flame particles re-shaded into stretched, soft licks (mode 0). Intensities are
   kept low so night exposure and AgX keep them orange. The crew's supper light and its
   omni (crew.gd) are untouched, so the fire-lit crew and ground look is preserved.
6. **Ground.** Store clearing: the bar's gravel now in the gravel slot (was duff), litter
   patches kept; the trail's gravel slot no longer takes sand (the near-white strip) and
   its litter slot takes soil. 70 pieces of litter (cobbles, bark) scattered over the yard
   off the trail, apron and props (own seed 184821).
7. **Notice.** The board right of the crew fire is the claim notice (crew.gd text
   "NOTICE / <bar> claimed and worked by the undersigned & Co."). It is now a torn,
   nailed paper on a weathered board under two shakes on a peeled post (`notice.glb`).

#### Gates

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| Blind check (store, store_shelves, camp_10h, camp_close_10h, crew_supper_1936) | pass | orchestrator | pending |
| GPU A/B vs merge8 meshes, camp_10h framing | ≤ +0.1 ms | +0.015 median / −0.001 low-quantile | pass |
| GPU A/B, camp_close framing | ≤ +0.1 ms | +0.018 / −0.002 | pass |
| GPU A/B, supper framing, all camp+crew changes | ≤ +0.1 ms | −0.009 / +0.008 (null ±0.01) | pass |
| GPU A/B, store_performance framing (stall, goods, bench, freight, litter) | inside 4.5 ms | +0.027 / +0.024; store total 3.33 ms GPU | pass |
| Full suite | 37/37 | 37/37 (re-run of camp/store suites after last tweak 8/8) | pass |
| `store_capture` probes | board ≥22 px, contrast ≥4; slate ≥20 | board 34 px, 8.55; slate 29 px; Lambert 0.0665 (now passes) | pass (stock-thinning probe fails as on base) |
| `audit_assets.py` | exit 0 | 137 files, 0 failing | pass |
| Stage 1 colour gates | 10:00/13:00 unchanged | pass; golden hour 0.877 (S-sky's, as merge8) | unchanged |

A/B method: `artifacts/visual-upgrade/c_props_closeups/ab.gd` and `ab_store.gd` swap the
merge8 GLBs (extracted from HEAD) for the new ones in place, 30 (camp) / 24 (store) cycles
alternating order, GPU time per half from `viewport_get_measured_render_time_gpu`; "low" is
the per-half 20th percentile, robust to the other agents' load. Draws: camp +5 (+11
shadow), supper +2, store +37 (more materials on the shelf stock). Wall-clock
`store_performance` p95 was 7.1-13.4 ms on the contended machine (not a valid absolute).

#### Regression amendments

Art budgets only (`tools/art/budgets.json`); no rules assertion changed. New `camp_kit`
category (2,600 tris) for `lean_to.glb` (2,312: a 24 x 18 cloth grid plus wings) and
`fire_ring.glb` (2,540: ten scanned stones plus the ash bed) — each one draw, measured
above. `building_kit` 12,000 → 17,000 (store.glb 16,786: shelf stock and wall goods) and
`goods_kit` 18,000 → 20,000 (18,996: seamed sacks with marks, freight). The store has
1.2 ms of GPU headroom under its 4.5 ms budget and the A/B cost is +0.02 ms.

#### Shared files touched (small hunks)

- `scripts/crew.gd` (C-characters): `_build_notice` uses `notice.glb` (same node chain:
  stake → paper → Label3D, same text); bunk-tent creation calls `camp.tent_instance()`
  instead of loading `tent.glb` and building trimesh collision itself (same collision).
- `tools/art/budgets.json`, `assets/CC0_MANIFEST.json` (fire_ring.glb now an output of
  `stone_01`; removed from `stone_fire_pit` and `painted_wooden_bench`, no longer used).

#### Assets

Added/changed: kit 3.01 → 4.36 MB (osnaburg, blanket, paint, sign, tin, crock, ash, labels),
camp −0.22 MB (lean-to, bedroll, coffee, woodpile up 0.22 MB; fire ring 1.04 → 0.46 MB;
new flames, tent, notice 0.15 MB), store/goods +0.88 MB, bench 0.74 → 0.02 MB, stencil
mask 0.13 MB. Net about +1.4 MB. Lettered sources come from `tools/art/build_prop_labels.py` (system Python
+ Pillow; written to the cache, not committed; uses a local KaTeX_Main serif, SIL OFL,
falling back to PatrickHand). Rebuild: `python tools/art/build_prop_labels.py`, then
`blender/prop_kit.py`, `blender/build_store.py`, `blender/build_camp_kit.py` (fire_ring
needs the normalised stone first; command in its docstring).

#### Still weak

- The fire is modest at supper distance: the tongues are small next to the omni light's
  pool, and their cores still go pale yellow under AgX; ash bed looks a little glossy.
- The lean-to reads as cloth close up; from camp_10h it is still a cream flap over a
  shaded underside. Tents sag only gently. No cloth simulation was used.
- The store clearing's large tan soil areas depend on C-ground's plain-ground path; my
  part is the texture slots and the scattered litter.
- Ring stones are one scan copied ten times; up close a few show sharp scan edges.
- The outfitting sign is still a paper on a box post.

### Final verification (after Wave C)

Head of `2.0` after all merges; tour `final` (31 views, deterministic again: the tour now
relaunches itself with `--fixed-fps 60`, no slot overruns, and the stray first-snow
particle is no longer restarted by the harness).

**Numeric gates.**

| Gate | Target | Final | Result |
| --- | --- | --- | --- |
| `downstream_10h` lower-half luminance / saturation | 0.38–0.50 / ≥ 0.20 | 0.420 / 0.280 | pass |
| `downstream_13h` lower-half luminance / saturation | 0.38–0.50 / ≥ 0.20 | 0.437 / 0.274 | pass |
| Golden hour (`downstream_1925`) vs baseline | ≥ 0.90× | 0.941× | pass |
| Night (`downstream_00h`) vs baseline | ≥ 0.90× | 0.997× | pass |
| Distinct boulder silhouettes | ≥ 10 | 13 by ID census; 11 by blind count | pass |
| Conifer count | 600 | 600 placed and rendered (+70 rim dressing outside `placements`) | pass |
| Suite | all pass | 37/37 | pass |
| Asset audit | 0 failing | 140 files: 126 ok, 14 allow-listed | pass |
| Committed `assets/` | ~200 MB | 199.7 MB | pass |

**Frame budget, quiet machine** (hung processes stopped; same-session A/B against the
pre-upgrade commit, 3 alternating rounds, `miner_performance` p95 at 1080p):

| View | Pre-upgrade | Final | Budget |
| --- | --- | --- | --- |
| Downstream | 3.45–3.68 ms | 3.66–3.98 ms | 5.5 |
| Wade | 3.83–4.14 ms | 4.05–4.35 ms | 5.5 |
| Overview | 4.51–4.56 ms | 3.82–4.05 ms | 5.5 |
| Store (`store_performance`) | 2.57 ms | 2.96 ms | 4.5 |
| Crew supper (`crew_performance`) | 4.57 ms | 4.48 ms | — |
| Wildlife (`wildlife_performance`) | 4.86 ms | 4.16 ms | — |

**Blind reviews, round 2** (fresh reviewers, same questions, final frames):

| Stage | Round 1 | Round 2 | Still failing |
| --- | --- | --- | --- |
| 1 light | 3/5 | 2/5 (golden hour and rain now pass) | midday reads cool/flat to the reviewer; clouds mostly hidden by the bend ridge (downstream views are ~1.3 % sky); water still reads opaque from the gameplay camera |
| 2 canyon | 2/4 | 2/4 (rock canyon, no flat horizon) | far bend wall's horizontal terraces read as tiled/quarry; skyline conifers an even comb; boulders not bedded |
| 3 rocks | 2/5 | 3/5 (≥ 10 silhouettes, no tiling, river-rounded) | sand reads pinkish and blotchy; damp margin not read as a wet band; contact sand not read |
| 4 plants | 1/4 | 1/4 (season) | crown reads as cards from directly below; bark now reads too red; understory not visible in the under-oak camera; riparian clumps still read as a row |
| 5 animals / crew | deer pass; crew identical pass | deer, squirrel, crew distinct pass | bear, jay, quail are primitives (no CC0 base); puffed shoulder caps from the shared miner body |
| 6 props | 0/5 | 2/5 (period fit, stocked shelves) | camp below character detail from the review camera; canvas sag/ropes not read; fire ring reads square; hard-edged path to the store; pale ground behind the store |

The reviewers are not always consistent with each other (round 1 called the oak bark black,
round 2 too red; round 1 passed midday colour, round 2 failed it), but every remaining item
above is visible in the frames. Per the plan, gates that failed twice go to the owner rather
than to a third automatic round.

**For the owner.**

1. Bear, Steller's jay and California quail: no rigged CC0 base exists, so they remain the
   legacy primitives. Options: fetch a model manually, try the deferred image-to-3D route
   (ComfyUI + TRELLIS, ~30–40 GB), or accept them.
2. Whether to run a third round on the twice-failed blind checks above (plants, props and
   rocks have the most concrete, fixable findings), or accept the current state.
3. The 70 rim conifers added as wall dressing sit outside the 600 counted placements.
4. `tools/art/build_prop_labels.py` renders sign lettering from a KaTeX serif font (SIL OFL)
   found in the local Python site-packages; only the rendered pixels ship. Vendoring the font
   under `tools/art/` would make the rebuild self-contained.
5. Non-suite capture probes in `tests/water_capture.gd` / `capture_greybox.gd` that check
   gravel, granite and canopy colours against the old art fail under the new art and light;
   they need re-baselining (they are not in `tools/run_suite.sh`).
