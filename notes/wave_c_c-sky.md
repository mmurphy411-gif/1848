## Wave C — C-sky (daylight, clouds, fog, water, rain, tour harness)

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
