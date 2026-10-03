# Wave C — C-plants (vegetation)

October 2, 2026. Tour label `c_plants` (`artifacts/visual-tour/c_plants/`, before/after sheets
against `merge8`). Probe logs and the probe variant: `artifacts/perf_probe/c_plants/`.

## What changed

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

## Gates

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| Vegetation GPU over pre-upgrade (downstream / wade / overview) | ≤ +0.35 / +0.45 / +0.35 ms | −0.05 / −0.07 / −0.53 (quiet pair, below) | pass |
| `under_oak_10h`, treeline views natural | blind check | grey-brown textured trunk; sapling, ferns and grass at the crown edge; no edge-on strips; clumped, three-depth riparian with distinct alders; denser rim | for review |
| Day 10 vs day 100 differ | visibly | foliage pixels moved > 10° toward yellow: `under_oak` 85 %, `across_river` 91 %. Day-100 hue spread (p20–p80): 8.5° / 11.3° in `merge8` (uniform), 43.8° / 56.5° now (uneven) | pass |
| Conifer count | 600 | 600 placed / 600 rendered (`milestone_6_notes`), plus 70 rim dressing trees outside `placements` | pass |
| Stage 1 colour gates | 10:00 / 13:00 unchanged | lower-half luminance 0.431 / 0.456, saturation 0.28 / 0.28 (pass); `downstream_1925` 0.877 (S-sky's, unchanged) | pass |
| Suite | all pass | 37 / 37 (`LABEL=c_plants`) | pass |
| `audit_assets.py` | exit 0 | 136 files, 0 failing (`oak_sapling` 648 / 800, `leaf_litter` 16 / 60) | pass |

## GPU-time A/B (in-process toggle, `artifacts/perf_probe/c_plants/probe_veg.gd`)

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

## Shared-file hunks

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

## Regression amendments

None. No test or threshold changed.

## Sizes

`oak_sapling.glb` 41 KB and `leaf_litter.glb` 2.4 KB. No new textures.

## Still weak

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
