# Milestone 3 — Light and Atmosphere

Read `ASTRA_BRIEF.md` first. This milestone is where the game starts to look like
a place. It must look good **with the grey boxes still in**. If the lighting only
works once real assets arrive, it is not done.

Do not touch: the water shader (milestone 4), assets (milestone 5), the miner
(milestone 6), or animating the time of day (milestone 7). Build the static
golden-hour look, but build it through a time-of-day function so milestone 7
only has to animate one number.

## Part 1 — Reshape the canyon first

The current canyon reads as a bathtub: walls climb at about 60 degrees to a flat
plateau at 24 m, and the far bank does the same. No golden-hour sun can reach
the bar through that, and a flat rim reads as a lid. Fix the shape before the
light, in `claim_layout.gd`, keeping every existing test passing.

Requirements for the new `height_at` beyond the bar (near wall) and beyond the
river (far wall):

- **A talus apron first.** For the first 6 to 10 m of rise above the bar edge, slope
  between 40 and 48 degrees (rise 0.85 to 1.1 per meter). It must stay above the
  walker's 35-degree floor limit so it remains unclimbable. Vary the apron width
  along X.
- **Then cliff bands.** Above the apron, alternate steeper bands (60 to 75 degrees)
  with narrow benches (10 to 20 degrees, 2 to 4 m wide). Two or three bands.
- **No flat top visible from the bar.** The rim must keep rising, gently, until it
  is beyond the camera's far plane or hidden by fog. Replace the 24 m plateau with a
  continuing rise of at least 0.3 per meter out to 80 m inland. The ridgeline must
  vary by at least 12 m along the length of the claim, with one clear notch or
  saddle on the far bank so low sun can pour through it.
- **Far bank taller than near bank.** The far wall should reach 60 to 90 m; the near
  wall 40 to 60 m. Both keep rising beyond that.
- **The canyon must be open along its axis.** Looking upstream (-X) and downstream
  (+X) from the bar, the walls should recede and open, not close into a bowl. The
  bar ends taper as they do now, but the canyon continues past them.

Do not change `shore_z`, `width_at`, `back_z`, or the bar's own height profile.
Tests for milestones 1 and 2 must pass unchanged.

## Part 2 — A time-of-day function, fixed at golden hour

Create `scripts/daylight.gd`, attached to a `Daylight` node that owns the
`DirectionalLight3D` and the `WorldEnvironment`. It exposes:

```
@export_range(0.0, 24.0) var hour := 19.25
func apply(hour: float) -> void
```

`apply` sets every light and sky value from the hour alone: sun azimuth and
elevation, sun color and energy, sky turbidity and tint, ambient, fog density and
color, and exposure. For this milestone `hour` stays at the golden-hour value and
`apply` is called once in `_ready` and whenever `hour` changes in the editor
(`@tool`). Milestone 7 will drive `hour` from a clock. Do not add a clock now.

**Sun path.** The canyon runs along X. The sun must set roughly **down-canyon**
so light rakes along the river rather than dropping behind a wall:

- At the golden-hour setting, sun azimuth within 25 degrees of the +X axis
  (downstream), elevation 7 to 11 degrees.
- The path across the day should be plausible for latitude 39.5 N in late June:
  rising around 4:45 in the northeast, peaking near 74 degrees a little after
  noon, setting around 20:30 in the northwest. It does not have to be
  astronomically exact, but it must be monotonic and continuous so milestone 7
  can animate it. Map "northwest" onto the +X (downstream) direction.

**Golden-hour values (starting points, tune by eye):**

- Sun color around 3000 K, energy 1.6 to 2.2, `light_angular_distance` 0.5 to 0.7 for a soft-edged sun, shadows on, 4 PSSM splits, `directional_shadow_max_distance` 180 to 220, blend splits on.
- Sky: `PhysicalSkyMaterial`, not `ProceduralSkyMaterial`. Rayleigh and Mie tuned so the horizon warms and the zenith stays blue. Sun disc visible.
- Ambient from the sky, energy 0.6 to 0.9.
- Tonemap **AgX** (fall back to ACES if unavailable in this build), white 1.0, exposure set so the lit gravel reads mid-tone and the sun-facing wall glows without clipping.

## Part 3 — Global illumination and occlusion

- **SDFGI on.** 4 cascades, cascade 0 distance around 20 m, use occlusion on, bounce feedback around 0.5. Read energy 1.0. Y scale 75 percent. The bar is small, so tune cascades so the whole claim sits in the first two.
- **SSAO on**, radius 1.5 to 2.5, intensity moderate. It is what makes grey boxes read as solid.
- **SSIL on** if the frame budget allows; off if it does not. Note the choice in the README.
- **SSR off** for now. It belongs with the water in milestone 4.
- **Glow on**, low: threshold high, strength 0.6 to 0.8, so only the sun disc and its reflection bloom.

## Part 4 — Volumetric fog

This is what turns a canyon into air you can see.

- `volumetric_fog_enabled` on. Density low (0.01 to 0.03). Albedo slightly warm. Emission off.
- Sun scattering (`volumetric_fog_sun_scatter`) 0.3 to 0.5 so the sun's side of the canyon has visible beams where boulders and the far rim break the light.
- Fog should be thicker in the canyon bottom and thinner above. Use `fog_height` and `fog_height_density` (or a `FogVolume` covering the river corridor) so the river channel holds a faint haze and the rim above is clear.
- Distance fog on as well, light, so the canyon walls at 200 m fade into the sky color rather than stopping at the far plane.
- Fog color follows the sun: at golden hour it is warm, tinted from the sky.

## Part 5 — Fix the greybox materials so light has something to land on

The current terrain vertex colors are written as linear values and render near
white. Fix this, and give each surface an honest albedo so the lighting can be
judged:

| Surface | Albedo (sRGB) | Roughness |
|---|---|---|
| Gravel bar | warm grey, about 0.40 0.37 0.32 | 0.95 |
| Sand strip at water | slightly lighter, 0.48 0.44 0.37 | 0.9 |
| Wet gravel (within 1.5 m of water) | darker, 0.28 0.26 0.23 | 0.5 |
| Granite walls and boulders | 0.50 0.50 0.48 | 0.85 |
| Bedrock slabs | 0.16 0.18 0.18 | 0.6 |
| Riverbed | 0.30 0.32 0.28 | 0.7 |

Set `vertex_color_is_srgb` correctly or convert the colors. The wall and boulder
grey should read clearly darker than the sky. Nothing on screen should clip to white
except the sun disc.

Leave the water material alone. Milestone 4 replaces it.

## Part 6 — Camera

- `CameraAttributesPractical`: auto exposure **off** (deterministic renders), fixed exposure set through `daylight.gd`. DOF off.
- Far plane to 600 m so the canyon can recede into fog rather than clip.
- Keep the field of view.

## Performance

Everything must hold 60 fps at 1080p on a mid-range GPU. You cannot measure that
directly on the RTX 5080. Use this proxy: the render harness frame-time sample must
show **p95 under 5.5 ms** on the 5080 with everything in this milestone enabled.
If it does not, back off in this order: SSIL off, SDFGI cascades to 3, fog
resolution down, SSAO quality down. Record what you turned off and why in the README.

## Tests — `tests/milestone_3.gd`

- Milestone 1 and 2 suites still pass unchanged.
- `Daylight.hour` is between 18.5 and 20.0 and `apply` has been called (sun rotation is not the milestone 1 default).
- Sun elevation between 7 and 11 degrees; azimuth within 25 degrees of +X.
- **The bar is sunlit.** From five points along the waterline (X = -30, -15, 0, 15, 30, at `shore_z + 1.0`, 1.2 m up), a raycast toward the sun direction travels 500 m without hitting terrain, for at least four of the five.
- **Light enters through the saddle.** From the bar center, at least one raycast in a 20-degree cone around the sun direction is clear.
- Canyon shape: for X in -40, 0, 40, the height at 12 m beyond `back_z` is at least 8 m above the bar edge; the height at 80 m beyond is at least 40 m; there is no run of 10 m anywhere from 0 to 80 m inland where total rise is under 2 m (no plateau).
- Far bank at 60 m beyond the far shore is at least 60 m high for at least one X in -40..40.
- Environment: `sdfgi_enabled`, `ssao_enabled`, `volumetric_fog_enabled`, `glow_enabled` all true; `ssr_enabled` false; sky material is `PhysicalSkyMaterial`; tonemap is AgX or ACES.
- `apply(6.0)` and `apply(12.0)` and `apply(19.25)` produce three different sun rotations with monotonically changing azimuth and elevation that rises then falls. Then restore 19.25. This proves milestone 7 can animate it.
- Walker still spawns on the floor and the milestone 1 boundary suite passes after the terrain reshape.

## Renders

Extend the capture harness to save, at 1080p, at the golden-hour setting:

- `milestone-3-bar-downstream.png`: player camera at X = -20 on the bar, looking downstream into the sun.
- `milestone-3-bar-upstream.png`: player camera at X = 20, looking upstream, sun behind the camera, far wall lit.
- `milestone-3-boulders.png`: player camera near the boulder at X = 7, low angle, fog beams if present.
- `milestone-3-overview.png`: high oblique from the downstream end showing the whole canyon receding.
- `milestone-3-noon.png`: `apply(12.0)`, then the downstream shot again, then restore golden hour. A flat-noon comparison so a human can see the difference the hour makes.

Print the frame-time sample with all milestone 3 features on.

## Acceptance

- All four test suites pass.
- p95 frame time under 5.5 ms on the 5080, or documented reductions.
- The five renders exist. **A human will look at them and decide whether the
  downstream shot makes them want to stand there.** That judgment is the real
  acceptance test for this milestone, and it may send you back to tune. Expect
  at least one round of "warmer", "more haze", "wall too bright". That is normal.
- README updated: the Daylight node, the hour parameter, what was tuned, what was
  turned off for performance.
- Commit as `Complete milestone 3 light and atmosphere`.
