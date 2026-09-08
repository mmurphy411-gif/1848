# Milestone 4 — Water

Read `ASTRA_BRIEF.md` first. The river is the second thing the player looks at
after the light, and the panning loop happens at its edge. It must be clear,
green-tinted Sierra snowmelt with a visible bed, foam where it meets rock and
shore, and a sun glint that sparkles at golden hour.

Do not touch: assets (milestone 5), the miner and wading splashes (milestone 6),
the day-cycle clock (milestone 7), sound (milestone 8). No caustics, no
underwater camera, no water physics changes. `river.gd` and `depth_at` stay
analytical and unchanged.

## Part 0 — Three fixes carried from the milestone 3 review

Do these first. Two of them show through the water.

**1. Distance fog is too heavy.** `milestone-3-overview.png` is unreadable and the
downstream saddle is lost from the bar. Keep the volumetric haze in the channel,
but push the depth fog back: begin around 140 m, end around 900 m, curve near 1.0.
From the bar center at golden hour the far rim and the saddle must be legible.
Re-render the overview as `milestone-4-overview.png`; the bar, both walls, and the
river must be distinguishable.

**2. Shadows are brown.** Golden hour means warm light and cool shadows from the
blue sky. Right now the fog tint and ambient are both warm, so the downstream shot
is sepia. Cool the fog light color and volumetric albedo toward the sky, keep the
sun warm, and let sky ambient carry the shadows. Acceptance is measured, see the
shadow-color probe under **Renders**.

**3. The terrain is flat-shaded.** Every triangle has its own normal because the
ground mesh is unindexed and every triangle carries a slightly different vertex
color. Remove the per-triangle color variation (the color is constant per surface
kind now anyway), index the mesh so shared vertices merge, then generate smooth
normals. The facet grid on the walls and the checkerboard on the bar must go. The
riverbed is seen through the water, so this matters now.

## Part 1 — The water mesh

Rebuild the water surface in `greybox.gd`, keeping the collision volumes as they
are:

- Subdivide **across** the channel at about 1 m spacing (currently a single quad
  spans the whole width). Keep the 2 m spacing along X inside ±110 and the coarse
  spacing beyond.
- Bake per-vertex data into `COLOR`:
  - R, G: local flow direction in XZ, mapped from -1..1 to 0..1. Flow follows the
    bend: the direction is the tangent of the shoreline at that X, roughly
    `normalize(1, 0.015 x)`, the same everywhere across the channel.
  - B: flow speed factor, 0.2 at the shore rising to 1.0 mid-channel, back down at
    the far bank.
  - A: vertical water depth from `Layout`, normalized to 0..1 over 0..5 m.
- All vertices stay at Y = 0. Wave displacement happens in the shader, never in
  the mesh, so `depth_at` and the physics volumes remain true.

## Part 2 — The shader

`shaders/water.gdshader`, spatial, assigned to the water mesh through a
`ShaderMaterial` built by a new `scripts/water_surface.gd` on the mesh instance.
That script also builds the noise textures and sets uniforms; it owns nothing
else.

**Transparency and passes.** The water renders in the transparent pass with
`hint_screen_texture` and `hint_depth_texture` so it can see the bed behind it.
That has one consequence you must plan around: **Godot's screen-space reflections
do not apply to transparent surfaces.** The milestone 3 spec said SSR belonged with
the water. That was wrong. Leave SSR off (the milestone 3 assertion stays valid)
and get reflections from two sources instead:

- The sky and the sun disc through normal PBR specular with low roughness and
  Schlick Fresnel.
- The canyon walls through **one `ReflectionProbe`** boxed over the river corridor
  (at least 90 m along X, 12 m tall, 30 m across), update mode ONCE, interior off.
  Milestone 7 will re-capture it when the hour changes; not your problem now.

**Surface normals.** Two scrolling normal maps from `NoiseTexture2D` with
`as_normal_map` on (no external textures), world-scale about 6 m and 1.7 m, moving
along the baked flow direction at about 0.35 and 0.55 m/s, scaled by the baked
speed factor. Blend them, normal strength around 0.3 to 0.4. The result should be
gentle ripples that visibly move downstream, faster mid-channel, slower at the
shore.

**Waves.** A small vertex displacement, 2 to 4 cm amplitude, sum of three sines
along the flow direction, scaled by the speed factor so the shore is nearly still.
This is the only vertex work.

**Depth and color.** Reconstruct the scene depth from the depth texture, compute
the **view-ray distance through water** to the bed, and apply Beer-Lambert
absorption. Sierra water loses red first, then blue, and keeps green. Starting
absorption per meter: `vec3(0.35, 0.08, 0.20)`. Add a deep scatter color, dark
teal around `vec3(0.02, 0.10, 0.09)`, blended in with depth. At 20 cm the bed
should read almost untinted; at 4 m the channel should be dark green-teal.

**Refraction.** Offset the screen sample by the perturbed normal, scaled by water
depth and clamped small (about 0.02 in screen space). **Guard it:** if the
refracted sample's depth is above the water surface, fall back to the unrefracted
sample. Without this, the miner's legs and the boulders above the waterline smear
into the water, and it is the single most common tell of amateur water.

**Foam.** Foam mask from vertical depth: full within about 15 cm of any
intersecting surface (shore, boulders, bedrock, and later the walker's legs, all
for free from the depth buffer), fading to zero by about 60 cm. Break it up with a
scrolled cellular or simplex `NoiseTexture2D` moving with the flow. Foam is
near-white, rough, and not emissive. A faint second foam band along wave crests
mid-channel is welcome if it stays subtle.

**Fresnel and specular.** Roughness about 0.05 to 0.1, metallic 0, specular high.
Fresnel drives how much you see into the water versus off it: looking down you see
the bed, looking across you see the sky and the walls. At golden hour looking
downstream the sun glint must sparkle across the ripples, which the perturbed
normals give you. Glow is already on for exactly this.

**Edge fade.** Alpha fades over the last 5 cm of depth so the waterline has no
hard edge against the gravel.

Expose these as shader uniforms with sensible defaults: absorption color, scatter
color, foam distance, foam texture scale, normal strength, wave amplitude, flow
speed multiplier, refraction strength. Milestone 7 will not need to touch them.

## Part 3 — What the bed needs

- The riverbed and shore materials from milestone 3 stay. With smooth normals and
  the wet band they are enough for now.
- Make sure the wet-gravel band (darker, roughness 0.5) extends 30 cm below the
  waterline as well as 1.5 m above it, so the shallows look wet rather than dusty.

## Performance

Same proxy as milestone 3: p95 under 5.5 ms at 1080p on the 5080 in the harness,
with the screen-texture copy, the depth texture, and the reflection probe all in.
If it does not fit, reduce in this order: noise texture size, wave sine count,
probe resolution. Record it.

## Tests — `tests/milestone_4.gd`

Headless cannot compile shaders, so these check structure; the renders check the
look.

- Milestone 1, 2, and 3 suites pass **unchanged**.
- `shaders/water.gdshader` loads as a `Shader`; its code contains
  `hint_depth_texture` and `hint_screen_texture`, and declares uniforms named for
  absorption, scatter, foam distance, normal strength, wave amplitude, and
  refraction strength.
- The water mesh instance has a `ShaderMaterial` using that shader.
- The water mesh has `ARRAY_COLOR`; every vertex Y is within 1 mm of 0; vertex
  count is above 2,000; the mesh spans at least X = -110 to 110.
- Baked flow: at a vertex near X = 30 mid-channel, the decoded flow direction has
  positive X and positive Z (the bend); at X = -30 positive X and negative Z.
  Speed factor at the shore is below 0.35 and mid-channel above 0.9.
- A `ReflectionProbe` exists whose box contains the world points (-40, 0, -10)
  and (40, 0, -10), with update mode ONCE.
- `ssr_enabled` is still false.
- The ground mesh is indexed: `ARRAY_INDEX` is non-empty and the vertex count is
  under half the index count on the largest surface.
- `fog_depth_begin` is at least 120.
- `river.depth_at` returns the same values as before at ten sample points
  (hard-code the current values into the test; this pins the analytical depth).
- Collision: the milestone 1 "cannot enter deep water" checks still hold, which
  the unchanged suite already proves.

## Renders and pixel probes

Extend the capture harness. All at 1080p, golden hour unless stated. For the
probes, project world points to screen with `Camera3D.unproject_position` and
average a 16 by 16 pixel patch; print the measured numbers next to each result.
Thresholds are sanity gates, not art; tune them once by eye and then leave them.

- `milestone-4-water-shore.png`: player camera crouched at the waterline near the
  boulder at X = -14, looking across it. Foam at the rock and shore, bed visible
  in the shallows, walls in the reflection at a grazing angle.
- `milestone-4-water-glint.png`: the milestone 3 boulders shot again (X = 6,
  low angle into the sun). The glint must now sparkle, not sit as one flat blob.
  **Probe:** in a 64 by 64 patch on the glint, luminance standard deviation
  above 0.06.
- `milestone-4-water-top.png`: 6 m above the shallows at X = 0, looking down at
  45 degrees. **Probe:** a patch 30 cm into the water shows bed color (green
  channel not more than 25 percent above the dry-gravel patch beside it); a patch
  4 m out is darker and greener (green above red by at least 30 percent).
- `milestone-4-water-wade.png`: walker placed knee-deep at X = 10; a foam ring
  where the capsule meets the water. **Probe:** a patch just outside the capsule
  at the waterline is brighter than a patch 1 m away by at least 0.1 luminance.
- `milestone-4-overview.png`: the milestone 3 overview camera after the fog fix.
  **Probe:** frame-wide luminance standard deviation above 0.08 (not milk).
- `milestone-4-shadow-color.png`: a camera 20 m above the boulder at X = 7,
  looking straight down. **Probe:** blue/red ratio of a patch in the boulder's
  shadow on the gravel is at least 12 percent higher than a patch of sunlit gravel
  beside it. Cool shadows, warm light.
- `milestone-4-noon-water.png`: `apply(12.0)`, the water-top shot again, then
  restore golden hour. For human comparison only.

Print the frame-time sample with everything on. Fail the harness if any probe or
the budget fails.

## Acceptance

- All four test suites pass; the harness passes its probes and budget.
- Human review of the shore and glint shots. The questions: does the water look
  cold and clear, does it look like it is moving, and would you kneel down and put
  a pan in it. Expect one round of notes on tint and foam amount.
- README updated: the water shader and its uniforms, why SSR stays off, the
  reflection probe, the Part 0 fixes.
- Commit as `Complete milestone 4 water`.
