# Wave C — C-ground (terrain shader, scan rocks, cobbles, clutter)

Done October 2, 2026. Tour label `c_ground` (before/after sheets against `merge8` in
`artifacts/visual-tour/c_ground/`; census, probe logs and debug scripts in its
`cground_evidence/` folder).

## What changed

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

## Findings → status

| # | Finding | Status | Evidence |
| --- | --- | --- | --- |
| 1 | ≥ 10 distinct silhouettes | fixed | Census (ID-coloured rocks over the tour cameras, ≥ 800 px): 13 meshes. 01 wildlife_bear, shoreline_close, valley_low, crew_work; 02 downstream_* (left), shoreline_close, wildlife_deer; 03 across_river, far_wall, quail, crew_work; 04 upstream (right), crew_work (centre), crew_lineup, quail; 05 camp_10h, camp_close, near_wall; 06 crew_supper, squirrel, near_wall, downstream_*; 07 valley_low, crew_work; 08 upstream_10h end; 09/10/12 far bank in across_river, far_wall, wildlife_deer/bear; 11 deer_close, jay; 13 downstream_* far end, deer, shoreline. No block shapes left (`boulder_meshes_new.jpg`). |
| 2 | Boulder surfaces | fixed | Grain, veins, rust, flood-line scouring, wet band, contact/drift; no rock pixel > 0.85 in any view; across_river_10h boulder no longer smeared. |
| 3 | River bar | fixed / partly | Damp margin visible in across_river, bear, deer views; pebbles toned; size zones, swales, lee drifts, ripples; much more driftwood (crew_work, downstream). Ripples read slightly regular close up. |
| 4 | Camp/store ground | partly | Oak duff now irregular. Store yard: natural no-vertex-colour path, no uniforms needed from C-props. **C-props:** `camp.gd` still adds its own 2.5 m `Assets.rock("duff",2)` disc under the fire (hard edge, visible in camp_close_10h) — remove or fade it. |
| 5 | Rain wetness | fixed | rain_downstream_10h lower-half 0.164 → 0.118; ground ≈ ×0.5 linear in rain (`cmp_rain.png`). |
| 6 | White square | not mine | A `SeasonEnd` snow flake (2.5 cm untextured GPUParticles3D quad): `tests/visual_tour.gd::fixed_particles()` calls `restart()` on every GPUParticles3D, which restarts the season-end snow although it is not emitting. Reproduced with `look.gd restart=1`; flakes also in merge8/c_ground `near_wall_10h`/`far_wall_10h`. **C-sky:** skip particles with `emitting == false`. |
| — | Night cliff streak (orchestrator) | fixed | `downstream_00h` (`night_a/b_crop.png`). |

## Gates

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

## GPU A/B (20th-pct GPU ms, 24 cycles, 1500-frame warm-up, quiet GPU)

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

## Shared files

`scripts/greybox.gd` (one line in `_visual_triangle`: river-bed kind 4 no longer clamped to wall),
`assets/CC0_MANIFEST.json` (rows for `rock_moss_set_01` 4k, `namaqualand_boulders_01` 4k,
`dead_tree_trunk_02` 1k; outputs appended).

## Sizes

Boulder GLBs 14.4 → 13.3 MB; new snag 0.46 MB: about −0.6 MB net.

## Regression amendments

None. milestone_5 ranges unchanged (all boulders 2,000–3,000 tris; snag is clutter, not asserted).

## Still weak

Close-up sand ripples are a little regular; margin rocks are small in most views (1–5k px); boulder_02
(quartz) is the brightest object in the downstream series; the far bank's wet strip is narrow
because the bank is steep; scan_rock costs +0.01–0.02 ms more than merge8.
