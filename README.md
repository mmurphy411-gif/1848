# 1848

Milestone 4: a playable panning greybox with clear, flowing river water and golden-hour light.
Built with **Godot 4.7.2 standard**, GDScript, and the Forward+ renderer.

## Play

On this machine, double-click **Play.cmd**. It launches directly into the claim
using the local engine in `.tools/`. Alternatively, import `project.godot` into
Godot 4.7.2 and press **F5**. There are no plugins or third-party dependencies.

For a fresh clone, install the standard Godot build and open `project.godot`.
The Windows launcher also accepts a `GODOT_BIN` environment variable containing
the executable's full path, or `godot.exe` on PATH. The engine is not committed.

| Input | Action |
| --- | --- |
| WASD / arrow keys / left stick | Walk relative to the camera |
| Mouse / right stick | Slowly orbit the third-person camera |
| E / captured left click / gamepad A or cross | Pan at the water's edge or in the shallows |
| Escape during a result | Finish showing and collect the gold |
| Escape otherwise | Release the mouse; press again to quit |
| Uncaptured left click | Capture the mouse again (does not start a pan) |
| F3 (debug builds only) | Toggle the developer density overlay; off by default |

Walk into the shallows to wade. Near knee depth the current slows movement and
returns you toward the bar. The narrowing ends and rear slope redirect outward
movement smoothly. Rocks and canyon terrain have physical collision.

A pan takes six seconds, followed by a three-second close view of the pan. Walking
is held during the action; current still applies, and entering water deeper than
0.45 m during panning cancels the pan without a result. The five visual results are
no gold, a few specks, a thin line of color, a dense crescent, and a rare nugget.
The lower-right readout is the accumulated gold in ounces, awarded when the result
closes. There is no save system, and the total starts at zero on each launch.

The map is deterministic. Most gravel is lean; four rich areas follow the upstream
bar head and downstream boulder lees. Two dark bedrock slabs reinforce existing
lee deposits at their downstream edges. The head shares the upstream boulder's
lee, keeping the specification's three-to-five-pocket budget. Result rolls add
small variation; nuggets are restricted to rich deposits. F3 shows the underlying
field as a one-meter grid for development review, with slabs left visible.

## Blockout

- Approximately 84 by 38 meters of tapered gravel bar on the inside of a bend.
- Continuous canyon slopes on both banks, riverbed, and a curved water volume.
- Seven collidable boulder placeholders, including four near the water.
- Two low bedrock slab placeholders at the water's edge.
- A 1.8-meter capsule walking at 2.4 m/s; shallow-water speed drops toward 1.05 m/s.
- Smoothed shoulder camera with a collision-tested 4.6-meter spring arm.
- Static golden-hour light, physical sky, canyon haze, and calibrated plain materials.

`scenes/claim.tscn` is the main scene. The procedural greybox appears in the editor
when this scene opens; its generated meshes are not hand-authored scene children.
Edit `scripts/claim_layout.gd` for the bend, height profile, and bar proportions;
`scripts/greybox.gd` owns mesh construction; `BOULDERS` and `BEDROCK` both live in
the shared layout. River, boundary, and the pure `gold_map.gd` sample that layout.
`panner.gd` owns IDLE/PANNING/SHOWING; `pan_result.gd` owns yield rolls;
`pan_display.gd` owns replaceable pan visuals; `sack.gd` is the Sack autoload;
`hud.gd` owns the single label. Sack stages are exposed for the later belt model.
`orbit_camera.gd` focuses the existing camera and eases back without creating another.
Tests opt into spawn-seeded results with `Panner.reproducible`; normal play re-seeds
from time. `density_debug.gd` is a permanent debug-only tool.
Collision layers are terrain/rocks = 1, walker = 2, river = 3 (bit values 1, 2, 4).

Milestones 5 onward in `ASTRA_BRIEF.md` are untouched. Assets, the miner, and the
day-cycle clock belong to later milestones. Blender sources and glTF assets will go in `blender/`
and `assets/` when those milestones begin.

## Light and atmosphere

`Daylight` in `scenes/claim.tscn` owns the Sun, WorldEnvironment, and two fog volumes.
Its `@tool` script, `scripts/daylight.gd`, exposes `hour`, fixed at **19.25**. Changing
it in the editor reapplies the look; `apply(hour)` deterministically sets the sun,
physical sky, ambient, fog, and shared camera exposure. There is no running clock.
The continuous sun path runs from 04:45 to 20:30, peaks at 74 degrees shortly after
noon, and sets along +X. At 19:15 its elevation is 10.15 degrees and azimuth is
-24.25 degrees from +X. Four of five tested waterline positions have an unobstructed
500-meter sun ray; one is shaded by a boulder.

The canyon now has a varying 6–10 m talus apron, two near-bank or three far-bank
cliff bands, and narrow benches. The rim continues rising beyond the claim, with
17 m of near-rim variation and a lower downstream saddle on the far bank. The
canyon and river geometry extend along the open valley beyond the tapered bar.
The playable shore, bar heights, and boundary behavior are unchanged.

Gravel, sand, wet gravel, granite, riverbed, and bedrock use the milestone's sRGB
albedos and individual roughness values. Terrain vertex colors are explicitly sRGB.
Milestone 4 removes per-triangle color variation, indexes the ground before generating
smooth normals, and aligns material boundaries with mesh strips to remove the facet
grid and alternating wedges along the shore. Wet gravel extends to 30 cm below water.
The lighting was tuned toward warm sunlight and cooler shadows, reducing the first
pass's orange cast. Physical-sky turbidity is 3 at golden hour, sun energy 1.9,
angular size 0.6 degrees, and four blended shadow splits reach 200 m. AgX and fixed
camera exposure (1.3 at golden hour, approximately 1.0 at noon) preserve mid-tones.
The camera keeps its 65-degree FOV, with a 600 m far plane, auto exposure and DOF off.

SDFGI uses four cascades, a 20 m first cascade, occlusion, 0.5 bounce feedback,
energy 1.0, and 75% Y scale. SSAO radius is 2 m; SSIL stays **on**. SSR stays off
for transparent water. Glow uses threshold 2.5 and strength 0.7. Volumetric
density is 0.004 with additional river mist and a subtractive volume above 10 m to
keep upper cliffs clearer. Godot 4.7 exposes volumetric sun scattering as
`volumetric_fog_anisotropy`, set to 0.4. Emission is off. Depth fog blends distant
walls into the sky between 140 and 900 m with a linear curve; its density of 1.0 means maximum opacity
in depth mode, independent of the much lower volumetric density.
These milestone 4 fog changes restore the overview's contrast and keep the saddle
legible. Fog albedo now follows the cooler sky while the sun remains warm. The
measured blue/red ratio in the boulder shadow is about twice that of sunlit gravel.

No performance reductions were needed. The RTX 5080 1080p lighting samples measured
approximately **2.4 ms p95** in both downstream and overview views with all these
effects enabled (600 warmed frames per view, VSync off), below the 5.5 ms proxy.
The five captures are ready for human visual acceptance and further art direction.

## Water

`scripts/water_surface.gd` owns the `ShaderMaterial` on `Greybox/River/WaterSurface`
and three seeded, seamless 256×256 `NoiseTexture2D` resources. Two are normal maps;
the third breaks up contact foam. `shaders/water.gdshader` uses two scales of ripples
(6 m and 1.7 m), moving downstream at 0.35 and 0.55 m/s times the baked current factor.
Three sine waves give 3 cm displacement, reduced near the banks. The source mesh
stays at Y=0, with approximately 1 m spacing across the river and 2 m along the claim.
Vertex color stores flow direction, current speed, and analytical depth as data.

The shader reconstructs view-ray thickness using the reverse-Z depth buffer and
absorbs red, blue, then green with Beer–Lambert transmission. Refraction rejects
samples above the surface or in front of the water, keeping emerged rocks and the
capsule crisp. Depth-driven foam fades from 15 to 60 cm, with a denser collar around
steep obstacles and sparse foam in shallow gravel. Foam receives ordinary lighting;
the shader's emission output transports the already-lit screen sample of the bed.
Fresnel, low-roughness PBR specular, and the ripples provide the sun glint. Alpha
fades across the final 5 cm at the bank.

| Uniform | Default | Purpose |
| --- | --- | --- |
| `absorption` | (0.35, 0.08, 0.20) per m | Channel absorption |
| `scatter` | (0.02, 0.10, 0.09) | Deep teal scatter |
| `foam_distance` | 0.6 m | Contact foam fade distance |
| `foam_texture_scale` | 0.8 | Foam noise tiling |
| `normal_strength` | 0.35 | Ripple normal strength |
| `wave_amplitude` | 0.03 m | Maximum combined wave displacement |
| `flow_speed_multiplier` | 1.0 | Ripple, wave, and foam motion |
| `refraction_strength` | 0.015 | Screen offset, capped at 0.02 |

SSR stays off because Godot does not apply it to transparent surfaces. Sky and sun
specular are complemented by one boxed `RiverReflection` probe, 110×24×50 m, with
interior off and update mode ONCE. Its capture excludes the water's visual layer to
avoid reflecting the screen-reading surface into itself. The day-cycle milestone
will handle recapturing the probe when the hour changes. Water physics, collision
volumes, and `river.gd` are unchanged; ten pinned depth samples verify this.

All water features fit the 5.5 ms p95 proxy with no performance reductions. The
water-top view currently measures roughly 2.7 ms p95 on the RTX 5080 at 1080p.
The harness includes the screen copy, depth texture, reflection probe, GI and fog.
Godot 4.7.2 reports seven leaked texture RIDs at renderer shutdown when a reflection
probe has captured, including in an isolated scene that frees the probe before exit.
The warning disappears without the probe. The required probe remains enabled;
there are no shader compilation or gameplay errors associated with this warning.

## Verification

From the repository in PowerShell (substitute your Godot executable if needed):

```powershell
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import --quit
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/milestone_1.gd
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/milestone_2.gd
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/milestone_3.gd
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/milestone_4.gd
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1920x1080 --script tests/capture_greybox.gd
```

The unchanged milestone 1 integration test drives the actual scene through physical keyboard bindings,
camera input, dry walking, diagonal movement, wading, prolonged escape attempts,
idle current return, boulder collision, and camera obstruction. A failure exits
with code 1. Milestone 2 checks density/geology, accessible peaks, seeded rolls,
rare nuggets, eligibility, timing, movement lock, cancellation, camera focus,
Escape awards, sack totals/stages, HUD, fleck counts, and the F3 toggle.
The render harness also checks captured mouse input and saves `milestone-2-pan.png`
(tier 3 during SHOWING) and `milestone-2-density.png` (F3 from above), alongside the
player and overview PNGs in ignored `artifacts/`. Milestone 3 checks canyon profiles,
sunlight raycasts, environment settings, the sun path, fixed exposure, and spawning.
The milestone 1 and 2 test scripts remain unchanged.

The render harness also saves these 1920×1080 lighting captures:

- `milestone-3-bar-downstream.png`
- `milestone-3-bar-upstream.png`
- `milestone-3-boulders.png`
- `milestone-3-overview.png`
- `milestone-3-noon.png`

It restores golden hour after the noon comparison, prints warmed frame-time samples,
and fails if either lighting view exceeds the 5.5 ms p95 budget. Append
`-- --lighting-only` to run just the five lighting captures while tuning. No test
harness runs during normal play.

Milestone 4 adds structural checks for the shader, indexed ground, water vertex
data, reflection coverage, and pinned depth values. Milestone 1–3 suites are unchanged.
The render harness compiles the shader and saves seven more 1080p views:
`milestone-4-water-shore.png`, `milestone-4-water-glint.png`, `milestone-4-water-top.png`,
`milestone-4-water-wade.png`, `milestone-4-overview.png`, `milestone-4-shadow-color.png`,
and `milestone-4-noon-water.png`. It projects fixed world points to 16×16 pixel patches
(64×64 for the glint), prints measured colors and contrast, and fails any missing
color/foam/glint/overview gate or the frame budget. The shallow-water comparison
uses sunlit gravel in the same view, outside the boulder's shadow. Append
`-- --water-only` for the water views and probes during tuning. Human acceptance of
the shore and glint images remains the art-direction check.

The local render review uses an RTX 5080. This is a baseline check, not validation
of the final game's 60 FPS target on a mid-range GPU. A physical gamepad still needs
a human feel check; automated stick input verifies the bindings and orbit behavior.
