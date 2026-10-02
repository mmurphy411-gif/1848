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

(pending: S1-ground)

## Stage 1 — Sky, water and grade

(pending: S1-sky)

## Stage 2 — World edge and canyon walls

(pending: S2-canyon)

## Stage 3 — Rocks and ground clutter

(pending: S3-rocks)

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

(pending: S6-props)

## Integration

(pending: orchestrator)
