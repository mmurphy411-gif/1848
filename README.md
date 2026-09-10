# 1848

Phase 2, milestone 11 playable build: the falling river, exposed bedrock,
crevicing, boots, pick and shovel, and a buildable rocker join Lambert's store,
fishing and camp. See [MINING_GUIDE.md](MINING_GUIDE.md) for quick work scenarios
and [STORE_GUIDE.md](STORE_GUIDE.md) for the two-visit store test. Earlier balance
findings remain documented below.
Built with **Godot 4.7.2 standard**, GDScript, and the Forward+ renderer.

The playable miner now uses the baked Pass 17 character, with removable travel
equipment and the existing gameplay animations. See
[MINER_GAME_INTEGRATION.md](MINER_GAME_INTEGRATION.md) for captures, verification,
equipment behavior and the export workflow. The earlier asset review remains in
[MINER_ART_REVIEW.md](MINER_ART_REVIEW.md).

## Play

On this machine, double-click **Play.cmd**. It launches directly into the claim
using the local engine in `.tools/`. Alternatively, import `project.godot` into
Godot 4.7.2 and press **F5**. There are no plugins or third-party dependencies.

For a fresh clone, install Git LFS, run `git lfs install` before cloning (or
`git lfs pull` in an existing clone), install the standard Godot build and open
`project.godot`.
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

A pan takes eleven seconds, followed by a three-second close view of the pan. Walking
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

The sections below retain the development record for each milestone. Current
Blender sources live in `blender/`, exported assets in `assets/`, and authored
procedural audio sources in `audio/`.

## Light and atmosphere

`Daylight` in `scenes/claim.tscn` owns the Sun, WorldEnvironment, and two fog volumes.
Its `@tool` script, `scripts/daylight.gd`, exposes an editor pose at **19.25**. Changing
it in the editor reapplies the look; `apply(hour)` deterministically sets the sun,
physical sky, ambient, fog, and shared camera exposure. Explicit `apply(hour)` calls
pause the clock for deterministic review; normal play starts the clock at dawn.
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
capsule crisp. Depth-driven foam fades from 8 to 35 cm, with a denser collar around
steep obstacles and sparse foam in shallow gravel. Foam receives ordinary lighting;
the shader's emission output transports the already-lit screen sample of the bed.
Fresnel, low-roughness PBR specular, and the ripples provide the sun glint. Alpha
fades across the final 5 cm at the bank.

| Uniform | Default | Purpose |
| --- | --- | --- |
| `absorption` | (0.35, 0.08, 0.20) per m | Channel absorption |
| `scatter` | (0.02, 0.10, 0.09) | Deep teal scatter |
| `foam_distance` | 0.35 m | Contact foam fade distance |
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
& .\.tools\Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/milestone_5.gd
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

## Milestone 5 — Procedural assets

All assets are generated by the headless Blender 5.2 scripts documented in
[blender/README.md](blender/README.md). Their inspectable `.blend` files and exported
GLBs/PNGs are committed. The six 2048 PBR sets use periodic shader-node coordinates;
`blender/review_textures.py` checks edge continuity and writes 3×3 review sheets.
Godot imports enable mesh LOD and texture mipmaps explicitly.

The ground uses one world-space terrain shader. Vertex color stores geology rather
than albedo; the existing indexed terrain and collision triangles are unchanged.
Granite and talus use triplanar projection (seven texture samples); gravel, wet
gravel, sand and duff use planar projection (three, or six at a sand transition).
The narrow cliff/apron transition samples both triplanar sets for a continuous
blend; most cliff pixels sample only one. Forest duff fades onto shallow benches.
Slope chooses cliff versus apron, world noise breaks material boundaries, and
normal strength fades between 40 and 70 m. Tile scales are 4/3/1.5/2/2/2 meters
for granite/talus/gravel/sand/duff/bedrock. Macro variation shifts brightness by
about five percent. Duff surrounds oak canopies and occupies forest benches.

Eight 1,920-triangle boulder variants replace the seven placeholders deterministically,
at the original layout positions. Baked dimensions preserve footprint radii and
unit-scale convex colliders; bases are sunk into the gravel. Lower vertex colors
add a polished tint, upper colors add lichen. Two jointed schist ledges retain the
original slab footprints and their downstream crevices.

`Vegetation` scatters 600 conifers on both walls, sampling the analytical terrain
and rejecting steep rendered triangles too. Roots are seated on the actual
triangulated surface so they cannot float over an interpolated bench. Cedar and
fir favor lower bands; ponderosa favors higher ground and the far bank. Ten black
oaks occupy the inland bar, at least 6 m apart, each with a trunk collision cylinder.
All plants stay at least 12 m inland and off slopes above 45 degrees. The 600
cobbles stay at least 1.5 m from the shore and outside boulder footprints.

Tree budgets, including cards: ponderosa 4,376; incense cedar 5,680; Douglas fir
5,680; black oak 3,052 triangles. Heights are 31.7, 26.9, 34.1 and 14.6 m. Geometry
Nodes bake distinct needle/spray/lobed-leaf atlases. A common foliage shader uses
alpha scissor, outward card normals and two wind frequencies with world phase;
tip displacement stays below 15 cm. Grass and three June flower variants grow on
duff near oaks: 240 grass instances and 20 each of lupine, poppy and yarrow, totaling
2,940 cards. Grass visibility ends at 40 m; cobbles at 60 m.

No performance reduction was needed to fit the 5.5 ms proxy: downstream measures
about 4.1 ms p95 and overview about 4.7 ms at 1080p on the RTX 5080, with water,
GI, fog and all vegetation enabled. Flowers were reduced to meet the separate
3,000-card limit. Geometry was redistributed from small woody branches into
foliage to improve conifer silhouettes within the per-tree triangle budgets.

The carried-forward foam fix narrows the band to 8–35 cm, stretches breakup 3.5×
along flow, and replaces bed derivatives with analytical-minus-buffer depth to
detect obstacles without triangle seams. Every harness camera now receives a
2 m forward-ray composition check; obstruction reports the offending object and
fails the run. The shore view has been re-shot. The water transmission probe moved
from 5 cm (now deliberately full foam) to 38 cm depth, just beyond the new foam
band; color thresholds and all four existing integration suites are unchanged.
The top-down water view is widened to include dry gravel outside the replacement
boulder's shadow; its comparison patch averages multiple cobbles.

`tests/milestone_5.gd` checks files, budgets, export attributes, atlas sizes and
alpha, tree heights, LOD, boulder footprints/convex collision, material assignment,
placement rules, card count, oak collision and camera retraction. The render
harness saves eight `milestone-5-*.png` views and the corrected M4 shore view in
`artifacts/`, with contrast, canopy-color, foam-coverage and frame-time gates.
Append `-- --assets-only` for these views, or additionally `--priority-only` for
the gravel close-up and treeline. Review those two first. Automated gates do not
replace the milestone's human art review; foliage and cobble appearance remain
the first subjects for review notes.


## Milestone 6 — miner and carried review fixes

The original walker capsule and boundary controller remain unchanged. `Visual`
now loads an 8,980-triangle, 1.780 m skinned miner, with separate 1,280-triangle
steel pan and 276-triangle tied poke. The rig has Godot humanoid bone names,
independent fingers, and at most two nonzero skin weights per vertex. Closed
shirt/seat surfaces and overlapping cuffs keep the silhouette continuous.

`blender/build_miner.py` builds the body, props, procedural cloth materials and
high-resolution displaced swatches. Cycles bakes their folds onto the low mesh's
normal atlas. `build_miner_animation.py` solves two-bone IK for hands and feet and
bakes eight NLA clips. The BLM Alaska demonstration was watched before keyframing:
[How to pan for gold](https://www.youtube.com/watch?v=AeaHDcDZylE), especially the
shake, drain and final wash. The reference informed the low hands, short shakes,
planted heels and restrained torso motion. No footage or downloaded artwork is
included in the project.

| Clip | Seconds | Playback |
| --- | ---: | --- |
| idle | 4 | loop, breath and weight shift |
| walk | 1 | loop, rate follows horizontal speed / 2.4 |
| wade | 1.2 | loop, higher recovery arc, rate follows speed / 1.05 |
| pan_enter | 2 | crouch, transfer from left carry to two hands |
| pan_swirl | 2 | three loops, 6 cm circular radius plus short shakes |
| pan_wash | 1.5 | gradual 42-degree drain tilt |
| pan_lift | 1.5 | raise and inspect |
| pan_exit | 1 | stand and return to left carry |

`miner_visual.gd` owns a manual-clock AnimationTree state machine with idle,
walk and wade transitions and a nested pan machine. `panner.gd` still owns the
unchanged density/yield calls, award timing and public IDLE/PANNING/SHOWING states.
The clip table totals **11 seconds**, as the M6 amendment confirms. Only M2's
358-frame wait changed, to `PAN_DURATION * 60 - 2`; the remaining M2 assertions
are unchanged. SHOWING holds the lift pose for three seconds before the exit.
The turn toward water takes 0.3 seconds.

The physical pan always stays on a `BoneAttachment3D` using `pan_socket`, which
is parented to RightHand and keyed across to the left hand for carrying. The
existing `Visual/Pan` is now just the result layer: its transform follows the
same socket, its flecks lie in the modeled crease, and its idle visibility still
means that there is no displayed result. The placeholder cylinder is gone. The
camera views the raised pan from beside the shoulder to clear the unchanged
collision capsule. The poke observes `Sack.changed` and has five increasing
volume keys; its hanging orientation follows gravity during the crouch.

The wet-line material darkens and glosses wool and leather with a 20 cm transition,
then dries over 60 seconds. Foot emitters run only above 5 cm depth and 0.3 m/s;
their droplets launch in world-up and disappear at the water surface. Shadow bias
was adjusted for the miner; the daylight clock and sound remain untouched.

Part 0 replaces tiled Voronoi grout with independently placed 8–15 cm stones
(20% coverage), 3–8 cm stones (40%), and pea gravel/sand. Tile edges wrap, rims
are partly buried, and the terrain blends into sand over 3–8 m patches. Cobble
instances now use the same 8–15 cm diameter class. Sand ripples have two-scale
domain warping and half their former normal strength. Each of the seven grass
cards carries six thinner olive blades, and oak duff fades at its edges.

The cliff render mesh samples actual bench edges, with layered normal displacement
rising from 0.5 to 2.5 m and projecting ledge lips. The original ground collision
mesh is retained. Forty large boulders use the existing meshes at 2–5× scale on
both cliff feet; nearby examples have convex collision. No bar boulder, boundary,
layout constant or analytical height changed. Granite has stronger macro variation.
Oak cards are 40–60 cm sprays of eight leaves, with 5,716 total tree triangles;
all four foliage atlases are 2048. Foliage retains multisample alpha coverage.

Terrain albedo/normal/ORM dimensions are 2048 for gravel and granite and 1024 for
talus, sand, duff and bedrock. ORM is grayscale R8 roughness; shaders supply the
constant dielectric metallic/AO values. `blender/optimize_textures.py` packs bakes
as palette PNGs without changing dimensions. Tree/miner GLBs retain surface slots
and share external textures instead of embedding duplicate copies. M5's texture
size assertions changed under the explicit amendment; all other M5 checks remain.
The performance fallback order reduced cliff rocks from 60 to 40, droplets from
16 to eight per foot, and the body atlases from 2048 to 1024. The remaining
forest cost required the permitted minimum of 300 conifers: retain the nearest
stands and a distributed sample of the distant forest, while consuming the full
original RNG stream to preserve oak and ground-cover positions. Foliage uses
2x MSAA with alpha-to-coverage, matte Lambert shading, bilinear mip filtering,
one extra mip at distance, and an orthogonal-basis wind transform. The coverage
edge is below the alpha-scissor cutoff. A check with all 600 trees restored still
missed the overview budget (5.64 ms p95).

Git LFS now tracks PNG, GLB, BLEND and EXR, including the existing assets. A fresh
local clone hydrates its files and passes `git lfs fsck`. Migration is forward-only:
the automatic approval review rejected rewriting all historical commits and refs,
so historical blobs remain in old commits. Current and future binary revisions
are LFS objects. There is no configured remote in this repository.

Two old render probes became geometrically invalid under M6. The rebuilt ledge
covers the former treeline canopy rectangle `(1010,240,64,64)` with granite;
restoring all 600 original trees confirmed the same occlusion. Its replacement
`(710,200,64,64)` samples a visible conifer crown in the unchanged camera, with
the same G/R >= 1.2 threshold and unchanged adjacent-rock control. The old water
probe sampled the 64 cm capsule edge, now open water. It follows the right shin's
bone axis at the surface, using matching 8-pixel patches for the narrower leg and
its water control; the +0.1 luminance threshold remains. The depth intersection
alone lost the thin shin collar, so two small surface rings now follow the actual
legs. Foam is nearer white, still rough and diffuse with no emission. No earlier
integration-test assertion was loosened.

Cliff-block review exposed suspended silhouettes: blocks now sit partly buried
in the lower apron, using vertical seating rather than an outward normal offset
from the steep face. The oak atlas uses rounded source lobes; its eight leaves
and runtime triangle count are unchanged.

`assets/` decreased from **98,374,291 bytes (98.37 MB)** to **23,589,243 bytes
(23.59 MB)**, including local import metadata and Godot's extracted pan map.
All authored PNG, GLB and BLEND revisions use LFS. The source `.blend` files
remain outside `assets/` and are also in LFS.

Final checks on the RTX 5080 at a forced 1920x1080 viewport:

| Check | Result |
| --- | --- |
| Milestone 1–6 headless suites | All six PASS |
| Complete M1–5 capture harness | PASS: composition, water, material and frame-budget gates |
| M6 stills and 144-frame capture | PASS: all 1080p guards, submerged pan, gravel and torso-shadow probes |
| M6 real-time downstream, 600 warmed frames | median 3.07 ms; p95 3.30 ms |
| M6 real-time moving wade with particles | median 3.19 ms; p95 3.47 ms |
| M6 real-time overview | median 4.62 ms; p95 4.97 ms |
| Idle foot placement | 0.0096 m maximum error |
| Three swirl loops | each dips to -0.100 m; X/Z standard deviation 0.043/0.037 m |
| Torso cast-shadow continuity | all five ray-projected samples darken against the no-shadow control |

Run each `tests/milestone_N.gd` with Godot `--headless --path . --fixed-fps 60
--script tests/milestone_N.gd`. Run `tests/capture_greybox.gd` and
`tests/miner_performance.gd` with the graphical renderer and no fixed-FPS flag.
Run `tests/miner_capture.gd` with `--fixed-fps 60` to record exactly five physics
ticks per image at 12 fps. All captures use `--resolution 1920x1080` and force a
1920x1080 content viewport, so Windows window sizing cannot shrink the output.
Logs and review media live in ignored `artifacts/`. These checks do not replace
the human art review requested by the milestone.

### Milestone 6 visual review

The entire 144-frame pan sequence was opened in six ordered contact sheets, with
full-size checks of the crouch and lift. The twelve-second recording is under
`artifacts/pan-sequence/`; it is intentionally ignored by Git. Review the sequence
first, then upstream, gravel-close and oak-under. These are review notes, not a
claim that an automated probe substitutes for the user's art review.
`artifacts/milestone-6-pan-preview.webp` plays the same frames as a 12-second
preview; the original PNGs remain available for full-resolution frame inspection.

| Render | Demanding art-director note |
| --- | --- |
| pan sequence, frames 000–023 | The entry is deliberate and the heels stay planted, but the crouch is still quite deep. |
| pan sequence, frames 024–047 | The first swirl travels in a restrained circle, though the upper arms could look less stiff. |
| pan sequence, frames 048–071 | The second swirl holds its grip, but its repeated rhythm is easy to recognize. |
| pan sequence, frames 072–095 | The last swirl remains economical, though a little more hand asymmetry would improve it. |
| pan sequence, frames 096–113 | The drain tilt reads, but the scuff pattern needs more varied wear to imply a long day's work. |
| pan sequence, frames 114–143 | The lift makes the gold readable, while the near forearm remains prominent in the focus frame. |
| miner-standing | The hat and suspenders carry the rear silhouette, but the shoulder transitions remain simple. |
| standing-shadow-baseline | The comparison exposes the torso's cast shadow, though the gravel's own contrast makes visual comparison less immediate. |
| miner-walk | The feet separate at mid-stride, but the upper body's posture is still rather upright. |
| miner-wade | Wet boots and contact foam read, but the smallest droplets are easy to miss at player distance. |
| pan-swirl | The low pan and planted boots establish water contact, though the crouch could use more asymmetry. |
| pan-lift | Flecks collect in the real crease, but the close view exposes simple hand anatomy. |
| sack-stage-3 | The poke's volume increases, but it needs more fabric character to sell its weight. |
| downstream | The miner gives the valley scale, though the far channel still feels sparse. |
| upstream | The ledges now break the cliff into rock bands, but some upper planes remain broad and regular. |
| oak-under | Small leaf clusters replace giant cutouts, though the crown still reveals repeated spray shapes. |
| gravel-close | The three stone sizes break the mosaic pattern, but the largest stones still have conspicuously smooth faces. |

Early M5 regression renders were also opened: gravel-close needed more mineral
contrast; treeline showed overdraw and sparse crown holes; downstream/upstream
exposed the reversed imported facing and rounded wall bands; boulder-close still
has overly even mineral speckle; oak showed repeated sprays; overview exaggerated
the regular cliff slopes; noon exposed angular shoulders; the M4 shore view still
shows a fairly regular ripple direction. Those observations drove the facing,
cliff, material and contrast corrections rather than moving existing probes.

### Regression render review after the miner replacement

All earlier-milestone views were opened in labeled contact sheets, with the
water-wade and treeline also opened full size. M1's old diagnostic overview is
not a hero view.

| Render | Demanding art-director note |
| --- | --- |
| milestone-1-player | The hat and pan establish the character, but the river exit is still an abrupt horizon. |
| milestone-1-overview | Foreground foliage crowds this old diagnostic angle and makes the claim difficult to read. |
| milestone-2-pan | The result reads, but enlarged hands and the sleeve seam need refinement. |
| milestone-2-density | The density pattern remains legible, though trees obscure some diagnostic cells. |
| milestone-3-bar-downstream | The silhouette sits well against the bar, but distant atmosphere flattens the far end. |
| milestone-3-bar-upstream | Cliff ledges improve the canyon, though their long parallel bands remain conspicuous. |
| milestone-3-boulders | Boulder and miner establish scale, but the near rock dominates their relationship. |
| milestone-3-overview | The bend reads, while repeated bench widths still advertise the terrain formula. |
| milestone-3-noon | Noon exposes the rock forms, but the miner's shoulder joins become more obvious. |
| milestone-4-water-shore | The shore stays open to view, but the ripple direction needs more local variation. |
| milestone-4-water-glint | The reflection reads, but its narrow corridor and empty horizon feel staged. |
| milestone-4-water-top | Bed transmission is clear, though the sand and gravel bands need less parallelism. |
| milestone-4-water-wade | The shin collar reads, but the adjacent boulder overwhelms this test composition. |
| milestone-4-overview | The green channel separates from its banks, but the outer river strips remain too straight. |
| milestone-4-shadow-color | Cool shadows survive the bias change, though boulder speckle lacks mineral hierarchy. |
| milestone-4-noon-water | The depth gradient is clear, but bright foam and gravel compete for attention. |
| milestone-5-gravel-close | Three stone scales replace the grout mosaic, though dark stones still read flat in shadow. |
| milestone-5-treeline | Conifer silhouettes differ, but sparse branch fans show their repeated cards. |
| milestone-5-downstream | The pan gives the miner a purpose, while the far channel needs more natural closure. |
| milestone-5-upstream | Talus blocks now sit in the slope, though rounded forms contrast strongly with the ledges. |
| milestone-5-boulder-close | The rock silhouette works, but mineral speckle is too evenly distributed. |
| milestone-5-oak | Leaf sprays are smaller and rounder, but repetition remains visible against the sky. |
| milestone-5-overview | Canyon shape is clearer than the old smooth slopes, but strata need more interruption. |
| milestone-5-noon | Materials separate under neutral light, though sand still has a broad uniform rhythm. |
| foliage atlas review | Rounded oak lobes improve the spray, but conifer needle spacing still feels combed. |
| body atlas review | Wool and linen folds bake cleanly, but repeated swatches limit garment-specific wear. |
| pan scuff atlas review | Scratches interrupt the steel, but their similar width needs more age variation. |

## Milestone 6 notes round

Implementation is checkpointed in `e03b4e7`; review evidence remains in `artifacts/`.
This round is **not
accepted as complete**: the specified nearest-boulder oak-shadow gate still
fails, the engine reports a reflection-atlas texture leak at shutdown, and human
review is outstanding. The completion commit is withheld until those acceptance
items are resolved. This notes checkpoint changed no day clock, sound,
claim-layout values, gold map, pan-result rules, boundary physics or walker capsule.
The subsequently requested Milestones 7 and 8 are recorded below.

### Repository rewrite

Before the rewrite, a full non-hardlinked backup was made at
`C:\Users\mmurp\1848-m6-backup`, including the notes file. The prescribed
`git lfs migrate import --everything --include="*.png,*.glb,*.blend,*.exr"`
rewrote all 14 commits. `Complete milestone 6 miner` is now
`cee03a0e8ff020750d434b2529e41c8cb2f84725` (formerly
`d6ae1c1b07ceefbd4b3014023ff4c0c591278583`).

All 88 reachable historical binary blobs were checked for LFS pointer contents,
and `git lfs fsck` passed. A fresh clone at `C:\Users\mmurp\1848-m6-verify`
imported successfully and passed all six original milestone suites. Only after
that verification were the local reflogs expired and unreachable old blobs
pruned. `.git` fell from **220,001,489 to 124,481,127 bytes**, including the
local LFS object store; the ordinary Git pack is approximately 179 KB. Those are
the immediate migration measurements, before this round's newly built assets.
Evidence is in `artifacts/notes-6-lfs-history.json` and the
`notes-6-clone-suite-*` logs. There is no remote to force-push.

### Miner, motion and camera

The procedural fallback is documented in `blender/README.md`; no external art
was introduced. The miner is **13,812 triangles**, below the new 20,000 ceiling.
Skin has smooth normals and reduced normal-map strength, the shirt has fuller
sleeves and modeled gathers, the brim is wider, and the beard has shaped volume
and separate strand maps. Each hand has five separated three-segment fingers,
a palm aligned to the finger row and a thumb web. The poke has a neck tie and
folds. Body textures remain 1024 pixels.

| Rig measure | Before notes | After notes |
| --- | --- | --- |
| Swirl hip height above soles | 0.40 m | 0.52 m |
| Torso pitch from vertical | 72 degrees | 43 degrees |
| Head pitch from vertical | Followed torso | 63 degrees |
| Knee separation | 0.31 m | 0.601 m |
| Swirl circle radii | 0.06 m | 0.102 / 0.110 / 0.118 m |
| Lowest rim over the swirl cycles | Insufficient controlled dip | -0.044 to -0.029 m |
| Minimum highest rim point | Not recorded | +0.054 m |
| Shoulder travel per cycle | Not recorded | 0.073–0.074 m |
| Cycle 2 versus cycle 1 path RMS | Identical loops | 0.0244 m |
| Maximum fingertip distance from rim | Not recorded | 0.0196 m |

The three cycles have separate phase offsets and radii, with three brief shake
impulses per cycle. The gameplay camera blends over 0.6 seconds to 2.2 m left
of the hips and 0.4 m above them, aiming at the pan. A sphere sweep includes
terrain and boulders and mirrors the shot when the other side is clearer.
Mouse and stick orbit are held until the return blend finishes. SHOWING uses
the ruled 0.55 m forward / 0.35 m above the pan opening and a 38-degree vertical
field of view. The walker is excluded from the sweep, as in the original boom.
PANNING retains the ordinary 65-degree field of view so the head and working
pose fit above the low pan aim; the earlier 45-degree trial cropped the head.

The fixed side review camera is 2 m left at crouched hip height, and the front
three-quarter camera is 1.5 m away at 30 degrees above the pan. The side camera
uses a 36 mm gate with a 50 mm focal length (39.6-degree vertical field of view)
to keep the working crouch in frame in Godot's vertical-FOV convention. This
is a review framing convention, not a standard 24 mm-high full-frame gate.

The original 2 m composition ray conflicts with the newly required cameras
only 0.65–1.5 m from their subject: it hits the invisible walker or ground behind
the pan. Following the brief's contradiction rule, close views exclude the
walker's capsule and test the ray up to the intended subject; ordinary views
retain the original 2 m test. The physical camera sphere sweep still checks
obstructions throughout gameplay transitions. Review cameras exist only in the
capture harness.

### Forest, materials and validation

All **600 conifers** are restored at the original placements. Instances beyond
60 m use species-specific **416-triangle** crown clusters with the same atlas.
The full models and their original placement arrays remain available for the
unchanged earlier tests. `--full-forest` selects full models for the benchmark
control. The initial 600-tree overview measured 5.76 ms p95; the first distant
variant pass measured 3.53 ms p95. Final measurements follow below.

| Final 1080p RTX 5080 run, 600 warmed frames | Full models median / p95 | Distant variants median / p95 |
| --- | --- | --- |
| Downstream | 3.56 / 3.84 ms | 2.53 / 2.79 ms |
| Moving wade with splashes | 3.79 / 4.08 ms | 2.74 / 3.06 ms |
| Overview | 4.94 / 5.28 ms | 3.02 / 3.39 ms |

Both final configurations fit 5.5 ms, and distant models provide additional
headroom. The 6.0 ms overview exception is not used. The final comparison uses
the same final geometry and materials in both runs; the older 5.76/3.53 ms
numbers above describe the initial budget investigation. Logs are
`notes-6-perf-{full,distant}-final.log` in `artifacts/`.

Oak trunk and first-order/second-order limbs are tapered tubes. An opaque bark
shader fixes the blue transparent limb artifacts; leaf surfaces alone use the
cutout shader. Tree MultiMeshes explicitly cast double-sided shadows. Interior
leaf coverage is 45.9% in the under-canopy view. Gravel uses warm, low-saturation
stones, and all sand transitions span at least 1.7 m with coarse and fine edge
noise. The bake emits an exact stone mask for the screenshot probe.

The first full graphical regression exposed two material interactions: the
lighter stone palette flattened the old gravel-detail sample, and the brighter
riverbed reduced the contrast of the shin foam. The fine gravel matrix was
darkened while retaining pale stone faces, and submerged gravel now retains
wet reflectance instead of reverting to dry reflectance below 40 cm. The
water shader and probe thresholds are unchanged.

The foliage antialiasing edge is 0.25, below the 0.38 scissor threshold as
required by [Godot's spatial shader reference](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html).

The still-image material-ID probes measure SHOWING pan interior and contents at
23.5%, skin at 12.1%, and the largest material (terrain) at 39.7%. Gravel has
95.2% of identified stone pixels in the required luminance interval, and the
longest near-0.5 sand-transition run is 169 pixels. All subject-minimum gates
and still-image composition guards pass. These measurements do not constitute
human approval of the model or pose.

The oak-shadow gate remains failed: the geometrically nearest visible boulder
is `Boulder02`, and the leaf-shadow control changes only 47 pixels there, with
0.7% footprint density. The prominent oak silhouette in this standing view
falls on the canyon wall; the nearest world-space boulder is outside the frame.
The probe was not moved to the wall to manufacture a pass. A user ruling on
the intended receiver is pending. The fixed camera and scene placements remain
unchanged.

`tests/reflection_cleanup_probe.gd` isolates the shutdown warning to one
ReflectionProbe: the minimal scene leaks seven texture RIDs with the probe and
none without it, even after freeing the scene and processing extra frames.
This matches [Godot issue 122498](https://github.com/godotengine/godot/issues/122498),
which identifies unfreed reflection-atlas color views and their parent texture.
The application cleanup is explicit, but that does **not** fix the engine leak.
The reflection feature and warning have not been disabled to hide it.

### Notes render review

The final stills were opened together and the SHOWING shot was also inspected
full size. The side animation must be reviewed first, followed by SHOWING,
standing/side, gravel and oak-under. Captures, frame manifests, contact sheets,
animated previews, masks and logs remain in ignored `artifacts/`.

| Render | Demanding art-director note |
| --- | --- |
| pan-side-swirl | The crouch and low pan are readable, but the sleeves still have a broad angular shoulder silhouette. |
| pan-front-swirl | The larger circular sweep is measurable, but the two hands retain a rigidly matched pose. |
| pan-front-wash | The tilt exposes the crease clearly, though the arm lines are still stiff and symmetrical. |
| pan-showing | The gold and bowl are now the subject, but the near wrists remain bulky and the beard is only a narrow strip under the hat. |
| hands | Separate curled fingers read at the rim, but the finger-to-palm transitions and thumb anatomy need human scrutiny. |
| miner-standing | The wider hat helps the silhouette, while the requested boulder canopy shadow is still absent from this fixed view. |
| standing-no-leaf-shadows | The control preserves the branches, but its tiny change on the target boulder cannot support a canopy-shadow acceptance claim. |
| miner-side | The beard breaks the jaw and the pan hangs vertically, but the torso remains rather straight-sided. |
| sack-stage-3 | The tie and gathered neck are visible from the left rear, though the bag's large folds remain simple. |
| gravel-close | The colors read as warmer river stones and the sand edge wanders, but the repeated rounded stone faces remain conspicuous. |
| oak-under | Solid brown limbs replace the ribbons and foliage fills the crown, but the limb forks still look angular. |
| overview | The restored forest fills both slopes, while repeated vertical trunks and canyon benches still reveal the procedural construction. |
| material-ID and gravel-mix controls | Subject masks align with the beauty views, but opaque water is used only for diagnostics and must not be mistaken for final shading. |

Reproduce with Godot `--headless --path . --fixed-fps 60 --script
tests/milestone_6_notes.gd`; run the same suite graphically to check actual
MultiMesh transform readback. The dummy headless renderer returns identity
transforms, so headless mode checks distant allocation against canonical
placements instead. Run `tests/miner_notes_capture.gd` graphically at 1920x1080
with `--fixed-fps 60`, then `python tests/probe_miner_notes.py` and
`python tests/build_pan_review.py`. Run `tests/miner_performance.gd` without a
fixed FPS for real-time performance. The original M2 labels alone are corrected;
M5's count is exactly 600 and M6's ceiling is 20,000, as explicitly permitted.

The complete M1–5 graphical regression passes after the submerged-gravel fix
(`artifacts/notes-6-regression-final.log`): contact foam 0.621 versus nearby
0.456, gravel sample deviation 0.054, all water/material/guard/frame gates pass.
All seven final headless suites pass, and the graphical notes rig suite also
passes. The 24 regression renders were reopened in four contact sheets:

| Regression render | Current art-director note |
| --- | --- |
| M1 player | The hanging pan reads, but the distant river exit remains abrupt. |
| M1 overview | The restored trees fill the old diagnostic view so densely that the claim itself is hard to read. |
| M2 pan | The bowl is prominent, but the hands still look too mechanical. |
| M2 density | The grid is legible, though its lowest rows are obscured by oak crowns. |
| M3 downstream | The sunlight gives the miner scale, but the empty channel exit remains conspicuous. |
| M3 upstream | The oak trunks frame the path, while long canyon bands remain repetitive. |
| M3 boulders | The boulders have scale, but the nearest rock competes with the miner. |
| M3 noon | The materials separate clearly, but noon exposes the blocky shoulder joins. |
| M3 overview | The tree count is restored, though the canyon benches remain overly regular. |
| M4 shore | The material transition is softer, but the left foreground boulder still dominates. |
| M4 glint | The bright glint reads, while the surrounding horizon remains empty. |
| M4 top | The wet bed is clearer and darker, but the broad channel bands remain regular. |
| M4 wade | Contact foam separates from the wet bed, though the huge neighboring boulder overwhelms the test view. |
| M4 overview | The channel is clear, but the opposite shore still looks unnaturally straight. |
| M4 shadow-color | Cool shadows remain readable, while the rock speckle is too uniformly distributed. |
| M4 noon-water | Water depth reads, but the bright dry bar still competes with the foam. |
| M5 gravel-close | Warm stone faces keep their local contrast, but their rounded relief remains repetitive. |
| M5 treeline | Bark is solid and the canopy casts detail, though the conifer cards still reveal repeated fans. |
| M5 downstream | The rear miner silhouette is clearer, but the shirt remains straight-sided. |
| M5 upstream | The oak branches have volume, though the visible wall shadow is still mostly branches. |
| M5 boulder-close | The boulder's outline works, but its mineral noise needs a stronger hierarchy. |
| M5 oak | The old angle looks past the crown, so it remains a poor view for judging canopy density. |
| M5 overview | The full forest fills the slopes, but trunk spacing still reads as a generated distribution. |
| M5 noon | The bar palette is coherent, while the broad sand ripples still repeat too evenly. |

The final gravel calibration passes both the notes brightness gate (95.2%) and
the original M6 local-detail gate (0.057 deviation). The final water-only run
and original M6 still harness pass; the latter also checks the submerged pan
and all five torso-shadow samples. Its legacy sack filename now uses the same
left-rear framing as the notes harness. Logs are `notes-6-water-last.log` and
`notes-6-original-capture.log`. The old M6 views were reopened as well:

| Original M6 render | Current art-director note |
| --- | --- |
| downstream | The fuller sleeves improve the rear outline, but the distant river exit is still abrupt. |
| upstream | The sack is readable at the belt, while the broad canyon bands remain repetitive. |
| miner-standing | The carried pan hangs convincingly, but the shoulders remain angular. |
| standing-shadow-baseline | Torso-shadow removal is measurable, though the gravel texture distracts from the comparison. |
| miner-walk | The stride separates the feet, but the torso still looks rigid. |
| miner-wade | Wet boots and foam read, while the small splash details are hard to judge at this distance. |
| pan-swirl | The pan reaches the water, though this old opposite-side angle is weaker than the new side review. |
| pan-lift | The bowl dominates appropriately, but wrist bulk and thumb anatomy still need work. |
| sack-stage-3 | The left-rear close view exposes the tie, but the poke's folds are still broad and simple. |
| gravel-close | The brightness and relief gates both pass, but smooth pebble domes remain too repetitive. |
| oak-under | The old view looks past the crown, so use the new notes oak-under shot for canopy review. |

### Ordered animation review

The player and fixed-side recordings each contain **144 1080p frames at 12 fps**;
the front review contains **108 frames** covering swirl, wash and lift. Frame
manifests validate timestamps and dimensions. All 17 contact sheets were
opened in order, with full-size checks of the working pose and lift. Animated
previews are `artifacts/notes-6-{player,side,front}-preview.webp`; original PNGs
are in `pan-sequence/`, `pan-sequence-side/`, and `pan-sequence-front/`.
The final player recording includes the last gravel calibration; side/front
recordings precede that small stone-face brightness adjustment but use the
same final character, animation and review cameras. The stills use final
materials throughout.

| Review sheet | Demanding art-director note |
| --- | --- |
| side 01, entry | The pan rotates from carry to working grip, but the fixed low framing crops the head during early entry. |
| side 02, first swirl | The circle is now visible against the planted boots, but shoulder movement could feel less mechanically coupled. |
| side 03, second swirl | The radius and phase change are apparent, though the central torso remains stiff. |
| side 04, third swirl | The larger sweep breaks the repeated path, but the grip is still too symmetrical. |
| side 05, wash | The drain angle reads clearly, while the elbows feel locked into a repeated stance. |
| side 06, lift and hold | The pan rises to the face without moving the feet, but the hands become visibly mechanical as they rise. |
| player 01, entry | The side dolly reveals the action, but the hat grazes the top edge during the descent. |
| player 02, first swirl | The whole working pose is visible, though the water glint competes with the pan. |
| player 03, second swirl | The sweep stays readable, but the broad sleeve shape hides some elbow articulation. |
| player 04, third swirl | The larger final cycle is visible, though the dark pan still competes with the boot beside it. |
| player 05, wash | The pan tilt is readable, but this angle gives less crease detail than the front review. |
| player 06, lift and SHOWING | The close-up transition ends on the gold, while the near wrists remain too prominent. |
| front 01, first swirl | Water crosses only the low rim and the bowl stays legible, though the hands are posed too evenly. |
| front 02, second swirl | The different path is visible against the gravel, but the shoulders are outside this pan-focused frame. |
| front 03, third swirl | The pan's wider circle reads, though the repeated finger curl remains conspicuous. |
| front 04, wash | The crease is exposed as the pan drains, but the matched arm lines look stiff. |
| front 05, lift | The rising pan and wide brim are clear, while the hands still look like separate mechanical pieces. |

The hand/forearm anatomy and early-entry framing remain explicit visual review
concerns, even with all geometric grip and camera tests passing. This is the
human review required by the notes, not a claim of final visual acceptance.

## Milestone 7 — day cycle

The main scene now starts at 04:45. Dawn to 20:30 lasts 1,200 real seconds;
night lasts 180 seconds before dawn returns. The clock handles midnight, long
frames and multiple complete wraps, and never feeds the density or yield RNG.
Scene instances created by tests remain at the established 19:15 pose. Launching
that scene as `current_scene` starts the clock and audio, so F5 and Play.cmd both
enter the same playable state. The editor pose remains separately adjustable.

The existing PhysicalSkyMaterial, fog volumes, SDFGI and reflection probe remain.
Moonlight is a second shadowed directional light, excluded from the physical sky's
single-sun calculation ([PhysicalSkyMaterial documentation](https://docs.godotengine.org/en/4.3/classes/class_physicalskymaterial.html)).
River mist thickens at night. A seeded 4,096 × 2,048
half-float panorama supplies fine stars, fading in between -3 and -10 degrees of
sun elevation. Its black background preserves the daytime calibration. Brightness
uploads occur only when the rounded twilight fade changes, not continuously.
The existing reflection capture is invalidated every eight real seconds during
play and immediately for explicit light poses; it is not rendered every frame.

`audio/build_audio.py` authors 24 kHz mono WAVs from seeded noise and oscillators.
River and rapids have separate spatial sources; pine wind comes from the banks.
Birds fade out at dusk, crickets fade in, and sparse owl calls replace birds.
Playback offsets, call spacing, pitch and positions vary using a separate cosmetic
RNG. Eleven bounded spatial voices serve ambience; no music or wildlife AI is
introduced. Waveforms have headroom and continuous periodic ambient seams. WAVs
use LFS; Godot imports them with its default QOA compression. Action samples are
included for the final polish pass. This is authored synthesis, not field recording;
human listening review is still useful for the bird and owl timbres.

Validation: `tests/milestone_7.gd` checks 20/3-minute timing, wraps, frame-rate
independence, frozen poses, noon/golden/night lighting, star fade, bounded audio
sources and day/night crossfades. `tests/day_cycle_capture.gd` renders six fixed
hours at 1080p through the unchanged composition guard and measures both night
and the running clock. Logs and renders are in `artifacts/`.

Art-director review of the six final player views (each opened at full size):

| Render | Send-back note |
| --- | --- |
| milestone-7-dawn.png | The rock shadow silhouettes remain too smooth for this sharply lit canyon. |
| milestone-7-noon.png | The pale bar and flat upper wall planes still make noon feel bleached. |
| milestone-7-golden.png | The warm opening reads, but the foreground sand ripples remain too repetitive. |
| milestone-7-dusk.png | The right bank loses more bark detail than the near gravel as dusk deepens. |
| milestone-7-night.png | The moon reveals the bar and stars, but the water highlight is too restrained in this downstream composition. |
| milestone-7-next-dawn.png | The first warm light arrives on boulders before the broad bar, leaving the miner nearly silhouetted. |

All development iterations were also opened: the initial six had an overbright
additive star field that washed out daylight and made stars into square lights;
the second six removed that wash but made night stars too faint and moonlight too
blue. The final set uses a black panorama background, smaller star texels and a
less blue, lower moon. The original Milestone 6 oak-shadow probe, human animation
review and Godot reflection-atlas shutdown warning remain open; this milestone
is not a claim that those older acceptance gates have passed. The cleanup is
saved as `e03b4e7` with an explicit checkpoint message, not a completion message.

Final Milestone 7 verification: Milestones 1–7 plus `milestone_6_notes` all pass
unchanged, editor import has no script errors, and all six capture guards pass.
On the local RTX 5080, 600 warmed 1080p frames measured night median/p95
2.63/2.87 ms and the live day cycle 2.87/3.14 ms. This is local hardware evidence,
not a measurement on the brief's unspecified mid-range GPU. The known seven
reflection texture RID shutdown warnings remain visible and documented.

## Milestone 8 — polish

The pan now shows dark, wet concentrate even on a zero-gold result. Gold flakes
have varied flattened shapes, orientations and tones, with a few thicker grains
in the crescent and a deformed pea-sized nugget in tier 4. A modest emissive floor
keeps the result readable at night without the former bright orange glow. Counts,
yield probabilities, the hidden map, award timing and eleven-second action remain
unchanged; every visual variation uses its own seeded cosmetic generator.

The five existing sack thresholds remain 0, 0.25, 1, 3 and 8 ounces. Its gathered
neck and tie now retain their initial size while the bag body grows. Fine canvas
weave and a small movement-driven swing give it weight. The capture's material-ID
pass includes the same neck deformation so it measures the real silhouette.
Camera FOV now shares the dolly's exact 0.6-second easing rather than finishing on
a different exponential curve. The right stick gives finer control near centre,
and a small clearance advantage is required before switching panning sides, to
avoid oscillating between two almost equally blocked camera positions.

Bark and leaves now share one wind function, with a slow, nonuniform gust envelope
inside the existing 14 cm amplitude ceiling. Pine wind audio uses that envelope's
rhythm. Dry footsteps follow each 1.2 m traveled; wading steps follow 0.63 m,
matching the existing animation strides. Gravel, scoop, swirl and wash sounds
follow the panning timeline. Swirl fades and stops on cancellation; idle feet are
silent. Ambience and Foley have separate buses and a master limiter. Normal Escape
and window-close exits stop sound and let the audio thread drain before quitting;
this removes the nine loop/playback pairs found by the shutdown check.

`tests/milestone_8.gd` exercises actual dry walking, wading, panning, cancellation,
contents reset, stage uniforms, camera completion and bus configuration.
`tests/polish_capture.gd` captures all five pan tiers, a night pan, all five sack
stages, and two underneath-oak wind views. Every shot uses the composition guard;
`tests/probe_polish.py` checks subject coverage, monotonic sack silhouette growth
and recorded audio levels. The SHOWING gates remain 15% minimum pan interior and
contents, 20% maximum skin and 40% maximum single material. Sack coverage minima
increase from 0.8% to 1.8% across stages, preserving the old stage-3 minimum of 1.5%;
no other material may cover more than half the frame. These checks verify framing,
not the artistic quality of the miner's hands.

`tests/audio_capture.gd` records the actual mixed game output: 19 seconds of day,
walking, wading and a complete pan, then eight seconds of night ambience and an owl.
Day peak/RMS were 0.331/0.0449; night 0.228/0.0383, with negligible DC offset and no
clipping. Files are `artifacts/milestone-8-day-audio.wav` and
`artifacts/milestone-8-night-audio.wav`. This is output-level and playback validation,
not a claim that a person has approved the synthesized wildlife timbres.

Final performance, local RTX 5080, 1080p, VSync off, 600 warmed frames per view,
with day clock and all spatial ambience active:

| View | Median | p95 |
| --- | --- | --- |
| Downstream | 2.88 ms | 3.13 ms |
| Moving wade with splashes and footsteps | 3.12 ms | 3.52 ms |
| Overview, all 600 conifers | 3.37 ms | 3.62 ms |

Art-director review (all saved beauty views opened):

| Render | Send-back note |
| --- | --- |
| milestone-8-pan-tier-0.png | The dark concentrate reads, but the coarse cuff silhouettes still intrude into the bowl. |
| milestone-8-pan-tier-1.png | Two flecks are clear against the sand, though their isolated placement feels deliberately staged. |
| milestone-8-pan-tier-2.png | The thinner flakes form a legible arc, but their spacing remains too orderly. |
| milestone-8-pan-tier-3.png | The crescent is distinguishable at a glance, but the larger grains could have less uniform highlights. |
| milestone-8-pan-tier-4.png | The nugget is unmistakable, though its angular edge still reads somewhat sculpted. |
| milestone-8-pan-night.png | The gold stays readable, but the concentrate loses its fine texture in the deep shadow. |
| milestone-8-sack-stage-0.png | The empty poke is visibly flat, but its long side planes need softer folds. |
| milestone-8-sack-stage-1.png | The first increase reads beside the forearm, though the canvas still looks too clean. |
| milestone-8-sack-stage-2.png | The neck stays anchored, but the lower bag still has a straight polygonal edge. |
| milestone-8-sack-stage-3.png | The larger belly is clear, but the tie could cast a stronger little contact shadow. |
| milestone-8-sack-stage-4.png | The largest bag feels full, though its lateral silhouette is still too symmetrical. |

The first polish result set was also opened: flakes looked like orange beads, so
the final pass made them thinner, longer, tangent to the crease and more yellow.
All five sack shots were opened in both sets; their criticisms above remain.
Diagnostic ID images are coverage evidence, not beauty renders.

Scope and remaining acceptance: Milestones 7 and 8 implement the two remaining
brief sections; there are no separate MILESTONE_7.md or MILESTONE_8.md specifications
in this repository. The user's request to finish them authorizes the day clock
and sound that were outside the earlier notes round. Milestone 6's human review,
nearest-boulder oak-shadow gate and upstream reflection-atlas texture warning
are still explicitly unresolved. No probe was moved and no old performance floor
or forest reduction was used to make these new milestones pass. The known engine
warning remains visible; the project is not represented as having passed all
Milestone 6 notes acceptance criteria.

Additional final wind review:

| Render | Send-back note |
| --- | --- |
| milestone-8-oak-wind-0.png | The leaf motion is restrained, but the angular limb junctions and large central stub still look constructed. |
| milestone-8-oak-wind-4.png | The gust changes the crown, but separated-looking twig junctions remain conspicuous from directly underneath. |

The initial two wind shots accidentally reused the old cross-canyon aim and only
put 11.7% foliage in frame; both were opened and rejected for missing their subject.
The harness now uses the already established notes-round underneath-crown camera
and its original oak instance, reaching 45.9% foliage. The boulder-shadow receiver
and its probe were not changed. Both final wind views and all eleven final pan/sack
views were rechecked together in the two `milestone-8-review-*.jpg` contact sheets;
the first sheet makes the orderly tier-2 spacing conspicuous, and the second makes
the sack's broad flat side planes and the oak junctions conspicuous.

Final Milestone 8 verification: all nine headless suites (1–8 plus 6 notes) pass;
all thirteen final capture guards and subject probes pass; editor import and the
main-scene launch/quit smoke test have no script errors. Pan subject coverage is
23.7%, skin 12.1%, and the largest background material 39.7%. Actual sack silhouette
coverage grows monotonically from 0.98% to 2.20%, including the neck correction.
Recorded day/night audio passes the level probes, and the new audio ObjectDB
shutdown leaks are eliminated. Only the previously isolated seven reflection
texture RID warnings remain in graphical shutdown logs. Validation files are
`artifacts/m8-milestone_*.log`, `milestone-8-probes.json`,
`milestone-8-capture-final.log`, `milestone-8-performance.log` and
`milestone-8-launch.log`. No earlier milestone assertion was weakened in this pass.

## Phase 2 — Milestone 9 review build

Phase 1 is the completed prototype baseline. The current scope is defined by
`PHASE2_BRIEF.md` and `MILESTONE_9.md`: a day now includes gathering, hand-line
fishing, cooking, eating, and sleeping. This implementation is a **review candidate**;
the memo's ordered human review and live playtest have not happened. The historical
Phase 1 review notes above are retained as development records.

### Play the new loop

For a step-by-step dusk catch and camp playtest, see [How to fish](FISHING_GUIDE.md).

- **F / gamepad Y:** enter a fishing stance at the water's edge, then cast. During
  drift it brings the line back for a recast. Strike after the line jerks, then hold
  to pull and release when the fish surges. Escape leaves the stance or ends a reveal.
- **G / gamepad X:** gather on eligible ground; interact with camp props. In a fishing
  stance it cycles available bait. Mouse wheel also cycles bait.
- **At camp:** the ring takes three driftwood to light, then one per extension. G at
  the skillet offers frying; F confirms. G at the rack hangs a fish. G at the cache
  stores carried fish or retrieves them. The bedroll ends the day; the crate opens
  the ledger. G also eats a carried cooked portion or smoked fish when away from a
  more specific interaction. Escape or G closes the ledger.
- **F4, debug builds:** open the season sandbox. Apply seed, date, hour, condition,
  dollars, gold, gear, bait, and fish counts; override weather or fire. Dawn, Dusk,
  Next day, Sleep and Refresh fish exercise the real scene. Movement is held while
  a panel is open. Idle away from an interaction, only the gold readout remains.

Examples (the launcher forwards arguments; the optional extra `--` is harmless):

```bat
Play.cmd -- day=20 hour=18.5 hooks=20 bait.grasshopper=6 firewood=10
Play.cmd -- day=95 hour=6
Play.cmd -- hooks=0
Play.cmd -- day=120 weather=frost hour=7
```

The first example supplies a dusk test kit. Walk toward the downstream side of the
boulder at X = -14; aim into its pool. The camp is under the central oak, inland of
the spawn. A September/October dawn scenario starts beside the head riffle so the
salmon are immediately reachable. Hooks cannot be bought yet: the store is milestone
10. There is no save system. Sandbox counts are test fixtures, not earned supplies.

### Models and ownership

`GameState` owns seed, day, dollars, condition and inventory. Gold remains exclusively
in the unchanged `Sack` autoload. Journal entries, catch totals, cached fish, meals
and daily-check flags live inside the inventory. Start hour and weather override
are scenario configuration. Applying an hour is an exact snapshot, not a simulation
of skipped meals; it marks the midday checkpoint according to the selected hour.
Changing counts preserves existing fish records and only adds/removes the difference.

`Calendar` starts June 26, 1848 at day 0; day 132 is November 5. The clock keeps its
1,200-second day and 180-second night. Every wrap emits one day-end signal, including
multiple wraps in a large advance; posing the hour emits none. Sleep fades out,
ends the day, then returns the miner to the bedroll at dawn.

Pure static models cover calendar, weather, condition, cooking, fishery and fight.
Actions own their seeded random generators; the fish map has no mutable RNG.
Weather is mixed from integer seed/day inputs and does not depend on call order.

| Period | Clear | Hot | Rain | Frost |
| --- | ---: | ---: | ---: | ---: |
| June / July | 65% | 33% | 2% | 0% |
| August | 60% | 35% | 5% | 0% |
| September | 80% | 8% | 12% | 0% |
| October 1–15 | 72% | 0% | 28% | 0% |
| October 16–31 | 60% | 0% | 25% | 15% |
| November | 45% | 0% | 15% | 40% |

Rain increases bite rates, removes grasshoppers, drives camera-following particles
that expire at the ground/water, and blends overcast over 30 seconds. Frost triples
morning river mist before 09:00 and fades it by 10:00. The water shader and water level
are unchanged. Hot weather applies haze and reduces midday trout presence.

### The fish map

Four boulder pools use the same obstacles as the gold map: their downstream wakes
slow the current and shelter trout. Two slab seams represent insect-rich edges;
the head riffle holds the seasonal salmon run; the deep runs suit larger resident
fish, and the tail-out suits bottom-feeding suckers. No gold-map, pan-result, layout
or boundary values were changed.

| Species | Weight | Habitat / bait |
| --- | --- | --- |
| Rainbow trout | 0.3–1.8 lb; 3% up to 3 lb | Pools, seams, riffle; grasshopper, hellgrammite, worm |
| Sacramento sucker | 1–3 lb | Run, flat, pool bottom; worm, pork |
| Sacramento pikeminnow | 1–4 lb | Runs at midday; pork, hellgrammite |
| Hardhead | 1–3 lb | Runs at midday; hellgrammite, worm |
| Fall-run Chinook | 10–20 lb | Riffle, days 81–127; visible, not line-catchable |

Trout peak at dawn and dusk; salmon intensity peaks on day 99, October 3. Population
rounding reserves capacity for salmon before filling resident habitats and caps the
stable population at 24. Ordinary fish meshes hold upstream, dart, flee and return;
populations crossfade over two seconds. Body sway runs in a vertex shader. An opaque
dither fade is essential: alpha-blended fish were incorrectly drawn over the water
instead of appearing in its refraction/depth snapshot.

The hand-line state machine is IDLE → STANCE → CAST → DRIFT → BITE → FIGHT → LAND →
SHOWING → STANCE, with a SNAGGED branch. One bait is reserved on casting. Recasting,
early strikes and cancellation retain it; a stolen bait or landed fish consumes it.
The strike window is 0.15–0.75 seconds. Fish approach for two seconds before a bite.
Drift reads the existing water mesh's flow colors once per second. A 12-segment ribbon
joins the winder and bait. Runs have a 0.4-second warning on a line tension meter,
followed by an explicit release prompt. Ordinary pulling settles at 35%; pulling
during a run adds 110 percentage points per second, releasing removes 160 per
second, and the line breaks at 100%. This replaces the immediate run break after
playtest feedback that the fish's movement was too subtle. From working tension,
there is about 0.59 seconds to release after the run starts. Snags near boulders/slabs have a 25% chance, with a 50% failed
freeing attempt. Each lost hook also costs two metres of line. Fishing and panning
are mutually exclusive, and camp actions require both idle.

### Camp, food and condition

Camp uses the existing black oak nearest X = 0 at least ten metres inland. Its center
is three metres riverward of that trunk. The lean-to, bedroll, ring, skillet, pot,
rack, crate, cache and driftwood are imported props with terrain-layer collision.
After camp playtest feedback, the shelter faces riverward from 3.4 m inland of the
ring, offset to one side of the oak; its bedroll is underneath and the ledger crate
stands beside it. The rack, pot and wood stack are spaced around the clearing.
The shelter uses a triangle collision shape so its doorway remains open.
The bedroll can be reached from the doorway; waking places the miner outside the
low roof so the standing collision capsule stays clear.
A duff patch follows the existing ground. Driftwood has three visible stock sizes.
The fire burns two game hours, then one hour of embers; added wood extends burning
up to four hours. Firelight is warm, shadowed and spatially audible.

Gathering takes two seconds. Bait has a 70% success chance, driftwood always succeeds.
Daily attempt budgets are six grasshoppers, four hellgrammites, four worms and ten
wood. Grasshoppers follow actual grass placements, worms follow oak duff, and wet
rock bait follows the shared boulders/slabs. Budgets reset on the day tick.

A fried fish takes twenty game minutes and gives +20 condition, capped at 100. A fish
is visibly held over the coals in a dedicated three-second `cook` animation loop.
Confirming a fry positions and turns the miner at the fire; the skillet follows the
right-hand grip, with movement held until the cooking action ends. The resting
skillet is hidden during the subsequent carried meal and restored afterward. A fish
of at least two pounds leaves a cooked second portion, usable that day. Smoking needs
four hours of burning fire and pauses without fire; unfinished rack fish spoil at
day end. Smoked fish keeps and gives +15 without a fire. Fresh fish survives the next
morning and spoils the following one. The cache follows the same spoilage rules.
Missing the midday or evening meal costs 15; the floor is 5. At 70+ condition, pan
and wade speeds are unchanged; at 40 they reach 0.77 playback and 0.8 m/s. Below 40,
25% of pans lose one tier and bank the reduced yield, never the original yield.

The ledger has two scrolling written pages: today's state/events and season totals.
Its script face is Cedarville Cursive, distributed under the SIL Open Font License;
the license is in `assets/fonts/OFL.txt`, with the font from
[Google Fonts](https://github.com/google/fonts/tree/main/ofl/cedarvillecursive).
Paper/canvas and all fish/camp assets are authored in the Blender builders. Audio is
original deterministic synthesis in `audio/build_phase2_audio.py`.

### Explicit interpretations and tuning

- The slab-relative seam coordinates in the memo fall shallower than its required
  depth. Only fish positions are projected onto the 0.7 m contour; slab positions,
  terrain and water remain untouched.
- The exact original fight rates conflict with the 3–8 second trout target: seven
  stamina plus mandatory releases produced a 10.38-second 1 lb fight. Pull fatigue
  is tuned to 1.4 units/second, recovery stays 0.4, and runs stay 0.8 seconds. The
  tested 1 lb fight is now 7.07 seconds. This is a disclosed balance change.
- Overcast sun attenuation uses a smooth nonlinear curve with the specified end
  points, so 0.8 rain also satisfies the memo's at-most-55% sun gate. The 17:00 rain
  beauty view is separate from the unchanged transmission probe's 19:15 pose.
  Moving that probe to 17:00 had put its dry reference in a boulder shadow.
- The simulation supplies diagnostic hook/line stock, as F4 does. Four starting hooks
  cannot exercise a required 8–20 seasonal losses without the unbuilt store. Its
  careful policy places 16% of casts in the snag-risk band, then uses the live 25%
  snag / 50% failed-free rules. That exposure is a policy assumption, not a hidden
  global snag probability in the game.

### Automated evidence

`tests/milestone_9_models.gd` checks the pure models before scene integration.
`tests/milestone_9.gd` exercises the real season state, clock, action exclusions,
strike branches, line break, successful landing, exactly-once award, fire, frying,
smoking, spoilage, ledger and sandbox rebuild. Existing suites 1–8 and 6 notes pass
unchanged at default condition. Use `--headless --fixed-fps 60 --script tests/...`
with the local Godot executable for fast regression runs.

`tests/simulate_season.gd` writes `artifacts/season-careful.csv` and
`artifacts/season-careless.csv`. For seed 1848, the careful policy takes 573 trout,
loses 14 hooks, has 189 smoked fish on November 1, and stays at 60+ condition on all
130 days. It respects gathering success, daily bait attempts, the single rack and
nine fire-hours available from ten wood. It discards unsmoked excess. The careless
policy reaches 5 within seven days. Two identical seeds produce identical ledgers;
seed + 1 differs. August rain across 50 seeds is 4.32%. Mean seeded dusk trout wait
is 16.18 seconds; rain has 1.5 times the rate. Salmon sightings span days 81–127.

The warmed 1080p heavy-scene measurement was 3.08 ms median / 3.30 ms p95 on the local
RTX 5080, with fire shadows, rain and the fish population active. This is local GPU
evidence, not a claim about unspecified mid-range hardware. Final numerical render
results are in `artifacts/milestone-9-capture.json`; logs are `artifacts/m9-*.log`.
The world anchors for the old water transmission probe remain unchanged.
`tests/fishing_launch.gd` also passes a main-scene launch and graceful quit. The
previously isolated seven reflection-atlas texture RID warnings remain at renderer
shutdown; no new application object or audio-playback leaks appeared in the final
integration run.

### Visual review — send-back notes

Every saved beauty view was opened; masks are diagnostic coverage evidence.

| Render | Art-director note |
| --- | --- |
| milestone-9-trout-holding.png | The two trout are readable through the river, but the telephoto framing compresses the bank and their flanks still look too broad. |
| milestone-9-cast.png | The underhand cast reads, but the thin line can disappear against bright reflections. |
| milestone-9-wait.png | The approach is present, but a moving player may miss it behind the shoulder. |
| milestone-9-fight.png | The line and fish movement communicate the pull, but the run cue needs the live timing review. |
| milestone-9-landed.png | The fish occupies the close view properly, but the miner's grip is stiff and the head silhouette needs softer shaping. |
| milestone-9-salmon-riffle.png | Individual salmon bodies are visible, though several overlap into a crowded group. |
| milestone-9-camp-dusk.png | The seated pose and warm clearing read as camp; the lean-to's cloth and the duff patch edge could be less regular. |
| milestone-9-camp-night.png | The fire is the warm point across the bar, but the distant shelter silhouette could read more clearly. |
| milestone-9-rain-pool.png | The river remains legible under lower light; the small streaks still need a live rain review. |
| milestone-9-rain-transmission.png | The submerged gravel retains contrast, but the overhead diagnostic angle is not a player-facing beauty shot. |
| milestone-9-ledger.png | The writing is readable, but the paper needs more convincing page edges and a stronger center fold. |
| milestone-9-sandbox.png | Every field is accessible, but the long plain developer panel requires scrolling on smaller windows. |

The catch sequence is 120 frames and the camp sequence 144 frames at 12 fps, stored
in `artifacts/catch-sequence/` and `artifacts/camp-sequence/`. The catch is an
instrumented successful playthrough using the real state machine and release logic;
the camp sequence lights the fire and eats a stored fish. The longer fry is tested
separately at its full game-time duration. These are not human playtest approval.
The sequence harness checks a fishable starting position and requires `SHOWING`;
it records at a matching 12 Hz physics tick so scripted releases cannot miss a run
between captured frames. Terrain-height placement keeps the camp actor grounded.
The catch's approach and thin line remain subtle from the player camera; the lift
and close-up read clearly, with a stiff hand grip still visible. The camp's fire
transition and seated meal read, but the eating gesture is repetitive. Contact
sheets and animated previews are in `artifacts/review/` and remain uncommitted.

**Acceptance remains open for the memo's human review:** bank trout, catch flip
sequence, camp at dusk, ledger, then a live dusk catch → fry → sleep → morning ledger.
The code is checkpointed as a review candidate. The final completion message
`Complete milestone 9 fishing and camp` is reserved for acceptance after that review.

### Fishing playtest follow-up — tension feedback

The fight now displays actual tension, a numeric percentage, and text prompts to
pull or release. Green/yellow/red provide a second cue. The meter hides outside
the fight and while the ledger or sandbox is open. A break explains that tension
reached 100%, while the existing hook and line loss rules remain in effect.

`tests/fishing_tension.gd` verifies reaction time at 30, 60 and 144 Hz, recovery from
80% tension, a catch controlled by the meter, state visibility, and release prompts.
Milestone 9 integration and model checks pass. The 1280×720 captures
`artifacts/tension-{pull,warning,run,slack}.png` were opened: the meter reads clearly
above the bait count, though the underwater fish movement remains subtle.
These captures use posed fight values to inspect each HUD state; the model and
integration tests exercise the actual tension changes.

### Camp playtest follow-up — clearance and cooking

`tests/camp_layout.gd` exercises the fire and skillet interactions, cooking through
a whole animation loop, the meal award, single-skillet visibility and movement
release. The skillet's center stays within 4.3 cm of the fire center, at least
42.8 cm above the ring origin. The shelter is entirely more than three metres
inland of the fire. Milestone 6, its panning notes suite, and milestone 9 pass after
the miner rebuild. The prior panning clips and geometry remain unchanged.

Final 1080p renders were opened and all pass the composition guard:

| Render | Art-director note |
| --- | --- |
| camp-rework-layout.png | The clearing now has distinct sleeping and cooking areas, though the oak hides part of the shelter from this side. |
| camp-rework-frying.png | The hand, handle and skillet line up over the coals; the flame shapes still look chunky at this distance. |
| camp-rework-meal.png | The miner eats beside the ring with one skillet visible, but the seated hand gesture still needs softer finger poses. |
| camp-rework-dusk.png | The fire has space around it and lights a separate shelter; the distant roof cloth could show more wear. |

## Milestone 9 notes — time economy

One game hour is 76.2 real seconds during daylight. A 20-minute real day spans
04:45–20:30. A pan takes 11 real seconds, about 8.7 game minutes: at most about
100 pans fit if he never walks. The mean dusk trout bite is 16 real seconds,
about 12.6 game minutes, or three to four bites per real minute at the best pool.
Frying takes 20 game minutes, about 25 real seconds. Smoking needs four game hours,
about five real minutes of fire.

The scarce resource in this game is the player's real minutes, not the fish.

## Milestone 9 notes — partial model work and design stop

This is an **uncommitted, incomplete notes round**, not milestone 9 acceptance.
Part 1's pure fishery model now has stable spot indices, the prescribed six-day
catch pressure (0.30 per catch, floor 0.15), autumn decline, and boulder-sized
pools sampled in the specified depth band. Fight intervals vary deterministically
between two and four seconds. `tests/fishery_pressure.gd` checks these models.
The new snag rule is factored into `fishing_rules.gd` for the simulation, but is
not yet wired into the live Fisher. Catch pressure is also not wired to live
catches yet; GameState's catch-log migration is pending. No new visual assets
or render acceptance are claimed for this partial round.

The original trout-focused careful policy now rotates to the highest eligible
pressure-adjusted rate and moves away below 0.5. Casts scatter by a seeded 1.5 m
and use the geometry-based snag rule. The old policy snag-exposure constant is
gone. The daily maximum is observed, not forced by a catch-count cap. Rotation
accounts for bank walking at the existing 2.4 m/s, and landing/reveal costs 4.5 s.
The simulation no longer catches a species if its rounded visible population is
zero. It retains the original two one-game-hour fishing sessions, daily bait
attempts, one rack slot per session, and diagnostic hook/line supply.

At the default 6% sunk-bait snag rate, seed 1848 produces 322 trout, 56 smoked
fish on November 1, seven hook losses, and 130 healthy days. Increasing that
action-rule rate to 8% (inside the explicitly allowed 4–10% interval) yields:

| Measure | Result | Required band |
| --- | --- | --- |
| Trout taken | 310 | 150–280 — fails |
| Smoked stock on November 1 | 48 | 5–40 — fails |
| Hooks lost | 11 | 8–20 — passes |
| Days at condition 60+ | 130 / 130 | At least 85% — passes |
| October days with two fresh river meals | 19 / 31 (61.3%) | Below 70% — passes |
| Maximum take from one spot in a day | 2 | At most 3 — passes |

The prescribed pressure constants remain unchanged. The season script exits with
a design-stop failure and writes its CSV evidence, rather than weakening its
assertions. These are the revised policy's results; the old 573-trout result above
is historical. The notes' standing rule requires stopping when the named model
tuning cannot meet a band; no stock cap, artificial catch limit, or extra policy
knob has been introduced to force the remaining targets. The remaining balance
decision must be resolved before this can be called a completed notes round.

### Test omissions, explicitly recorded

The original milestone 9 round omitted the shore-approach flee/return timing,
real grass-band interaction by hour/weather, daily bait/wood limits and reset,
seed variation over half the spots, rain transition and frost-mist timing, complete
HUD eligibility, sandbox WASD isolation, camp/boulder overlap, and the stance-turn
duration band. They were not covered by the smaller integration suite; the README
should have disclosed that. Those tests are still pending in this notes round.

Parts 2–7 also remain pending: in-world run line/arm/spray/audio cues and diagnostic
meter toggle; rebuilt fish heads/fins and tail grip with hull checks; bank fish
depth/shadow treatment and framing; cloth/duff/fire revisions; GameState journal
and catch-log migration; camp-only eating and updated fishing guide; the full
`milestone_9_notes.gd` suite, re-shot probes and both catch-camera sequences.
The current fishing guide still describes the live build. No milestone 10 work
has started. Nothing in this notes round has been committed.

### User ruling — September 8, 2026

The user accepted plentiful fish: time spent fishing is time forgone panning
for gold. The 310-trout season and 48 smoked fish on November 1 are accepted.
The simulation therefore retains the minimum food checks but removes the trout
and smoked-stock upper limits; no model or policy constant changes to force a
scarcity target. The remaining checks still apply.

The user authorized committing this partial milestone 9 work and beginning
milestone 10. This supersedes the notes' prerequisite to finish the entire notes
round before starting the store. The pending live wiring, visual revisions and
omitted tests listed above remain deferred, not passed or completed. The prior
design-stop status above describes the review before this ruling.

## Milestone 10 — accepted checkpoint

On September 9 the user authorized committing this build and proceeding to
milestone 11. The balance findings and visual review notes below are retained
as follow-up work, not claimed resolved. M10 model and integration suites pass
on this checkpoint. Camp movement now steps over low clutter with headroom and
landing checks; `tests/camp_movement.gd`, camp interactions, and M1 movement pass.
The review-build status below records the state before this acceptance.

The user's **go ahead and implement** approves the revised storyboard gate.
Milestone 9's accepted checkpoint remains `ba8fab8`; the previously deferred
M9 notes are not being claimed complete. Milestone 10 is implemented and
uncommitted. The season's three design findings below prevent calling the
whole milestone accepted. Start testing with [STORE_GUIDE.md](STORE_GUIDE.md).

Jean-Baptiste Lambert is a fictional French-Canadian former trapping-brigade
trader, now selling provisions under canvas. This follows the memo's French
Camp background, rather than adding an explanatory speech to the game. His
red shirt, grey hair, moustache, apron and red-and-blue sash distinguish him
from the miner. The name comes from `Store.KEEPER`; the board, prompt and
ledger use it. The reused miner rig carries idle, weigh, write, hand-over and
shelve clips. Only pour and take clips were added to the miner's library.

### Travel, counter and kit

The trail starts six meters inland of camp. G while facing it begins a trip
only by 09:00, with no active fishing, panning or camp task. One second fades
frame the four-second rim view. Departure at H arrives at H+6; shopping is a
paused-clock clearing; return is H+12. A carried smoked fish or cooked portion
is eaten before the midday check. The claim remains off-tree during shopping,
preserving its actual nodes, inventory, fish, camp and gold. Twelve hours burn
down the unattended fire without advancing smoking. The return resumes the
same claim and clock at the trail. The clearing guides outward walking back
inward instead of putting up a hard wall.

Lambert stands across the counter and moves between marks beside the scale
and slate. The board, slate and pour have dedicated focus cameras. Esc releases
a reading view. Pouring moves 0.25 oz/s, removes actual dust continuously,
and credits 92% of it on release. The stream, weights and beam move during the
pour. Shelf selection reserves one unit, slides its prop into the pile, and
updates the slate. Returning the last item releases the reservation.

Settlement is atomic: fish credit and coin first, then the exact dust shortfall
at the thumbed rate. Automatic dust settlement visibly pours before Lambert
writes and hands over. Insufficient funds return the last item and leave
`SHORT`. Smoked fish offered at the barrel remain owned until settlement.
Unsettled items and fish offers are returned on departure. Only completed
transactions enter dated purchases and the visit record.

`Pack.weight` includes food, fish, rod and line, with a 40 lb limit. Hooks and
gold add no pack weight. The back pack appears above 5 lb and grows at 15 and
30 lb. The willow rod extends the cast to 12 m and slows tension growth during
a run to 80%; hand-line behavior remains unchanged. Its tip supplies the
line's origin. The reused cast has the allowed 40-degree forearm adjustment;
no additional fishing clips were authored. The low-held reused motion still
deserves a live art review as an overhead cast.

### Prices and finite stock

`prices.gd` blends seeded noise in five-day buckets around the $16-to-$14 gold
trend. Wander amplitude is $1.50 and daily noise $0.06, keeping the theoretical
daily step under $0.75. Fifty seeds give early/late means $15.792/$14.221 and
a maximum observed step of $0.694, inside the memo's bands. Goods use day
0/36/67/97/128 inflation checkpoints 1/1.5/2.5/4/6 with item-specific ±8%
wobble, rounded to cents. Smoked fish pay $0.12 times the index per pound.

Stock is opening plus seven-day shipments beginning day 3, minus dated
purchases. The listed last day is a cutoff, not an extra delivery. For
example, hooks last ship on day 108 before their day-112 cutoff. The rod has
exactly one extra delivery on day 36. There are no invented off-screen buyers.

| Item | Unit | June base | lb/unit | Opening | Shipment | Last day | Sale |
| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |
| Hook | each | $0.25 | 0 | 24 | 24 | 112 | yes |
| Line | 20 m coil | $1.00 | 0.2 | 6 | 4 | 112 | yes |
| Rod | each | $3.00 | 1.5 | 1 | 1 | 36 | yes |
| Flour | lb | $0.10 | 1 | 200 | 150 | 119 | yes |
| Beans | lb | $0.08 | 1 | 120 | 80 | 119 | yes |
| Pork | lb | $0.20 | 1 | 80 | 60 | 119 | yes |
| Coffee | lb | $0.25 | 1 | 20 | 15 | 105 | yes |
| Salt | lb | $0.10 | 1 | 40 | 30 | 119 | yes |
| Crowbar | each | $6 | 5 | 2 | 1 | 98 | display |
| Pick | each | $8 | 7 | 2 | 1 | 98 | display |
| Shovel | each | $8 | 5 | 2 | 1 | 98 | display |
| Boots | pair | $12 | 3 | 2 | 1 | 84 | display |
| Rocker | lumber and iron | $25 | 40 | 1 | 1 | 84 | display |
| Spear | each | $6 | 2 | 1 | 1 | 91 | display |
| Rifle | each | $60 | 9 | 1 | 0 | — | display |
| Powder | 20 shots | $4 | 1 | 3 | 2 | 112 | display |
| Tent | each | $20 | 18 | 1 | 1 | 84 | display |

### Food, ledger and sandbox

The skillet now offers fish, biscuits and pork; the pot offers beans and
coffee. G cycles a utensil's recipes and F starts one. Biscuits consume 0.5 lb
flour and 0.02 lb salt over 15 game minutes; another batch before leaving camp
becomes a carried portion. Beans consume 1 lb and 0.05 lb salt over two hours
of fire, with one portion eaten and two carried. Pork consumes 0.5 lb over ten
minutes. Those meals give +20 condition. Coffee consumes 0.1 lb over ten
minutes, gives +5 once before 10:00, and is not a meal. Carried recipe portions
keep two days. The tripod pot moves over the fire during pot recipes and
returns afterward. Smoking costs 0.1 lb salt; the default 2 lb covers twenty
fish. At the crate, 0.25 lb pork and the knife produce four pork baits.

The ledger's left page records the latest completed store visit, actual and
weighed ounces, purchase quantities and prices, and coin. The right page
compares the latest prices to the preceding visit in smaller margin figures,
then lists season totals and the pack. The store HUD has one ounces-and-coin
readout; camp returns to the original sack readout.

F4 adds fractional food quantities, rod ownership, a current gold/flour price
line, Go to store and Home. The shortcuts bypass travel eligibility for tests.
Scenario keys include `goods.flour`, `goods.beans`, `goods.pork`, `goods.coffee`,
`goods.salt`, `rod=1` and `scene=store`. Store scenario entry starts at the
counter. Gold is set through the sandbox. Session state is not a disk save.

### Season results and outstanding balance findings

`tests/simulate_season.gd` runs 132 days with a 1,200-second daylight budget.
Walking, bait gathering, waiting, fighting, landing, wood gathering, tending,
recipes, panning and travel spend time. It calls the actual gold, pan, fish,
fight, condition, recipe, price and counter models, including pan-tier decline,
local fishing pressure, finite goods, pack capacity and the 92% sale rate.
The careful policy supplies food, tends a smoking fire and pans rich ground;
careless spends daylight panning without meals; spendthrift shops weekly for
pork and coffee and pans middling ground. These authored policies are test
strategies, not predictions of human behavior. No gold subsidy or price tuning
was introduced to obtain these results.

| Policy | End value | Condition | Trips | Hook purchases | Trail meals | October two-meal days |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Careful | $19,325.34 | 100 | 8 | 4 | 4 | 31/31 |
| Careless | $15,121.48 | 5 | 0 | 0 | 0 | 0/31 |
| Spendthrift | $173.32 | 100 | 19 | 0 | 1 | 31/31 |

Both hard stop conditions pass: careful ends ahead and can purchase hooks by
the second visit. Deterministic replay and a different seed are checked.
Three acceptance assertions fail, so the simulation deliberately exits 2:

- Starting with no food and no coin produces trips on days 0, 1, 2, 3 and 5,
  followed by days 39, 69 and 105. The first two are not thirty days apart.
- Salt is replenished before it is exhausted, rather than forcing the first
  store visit after twenty smoked fish.
- The specified shipments outpace spendthrift purchases, so it never sees
  sold-out stock. The real policy also fails the six-fewer-objects October
  shelf probe: the display grows from 68 to 640 objects, including pegs.

The four required outputs are `artifacts/season-careful.csv`,
`season-careless.csv`, `season-spendthrift.csv` and `season-summary.md`.
The October capture uses that CSV purchase history, not a fabricated sellout.
These findings are preserved for the user's balance decision.

### Verification and visual review

Regression suites 1–9, milestone 6 notes, milestone 9 models, fishing tension,
camp layout and fishery pressure passed. No milestone 9 notes suite exists at
this checkpoint. M10 model and integration suites pass, including actual G
input, 8/12 m aim, pack refusal, SHORT, offer undo, exact automatic settlement,
travel state, two-visit ledger, recipes and sandbox. The final changes were
rechecked with M10, M9, tension and camp-layout suites. The protected gold map,
pan result, claim-layout values, boundary and water shader are unchanged.

At 1920×1080 on the RTX 5080, 600 uncapped store frames after 240 warm-up
frames give median **2.223 ms**, p95 **2.339 ms**, below 4.5 ms. Lambert animates,
October stock is present and all rain particles are enabled. A separate GPU
mask sample finds zero rain pixels below the canvas in twelve samples, with
3,882 outside rain pixels as the positive control.
The unchanged claim night/fire/rain/24-fish benchmark also passes: median
3.09 ms and p95 3.32 ms over 600 warmed frames.

Measured board glyph lines are at least **32 px**, with **9.3:1** contrast.
The pile/slate capture's minimum is **28 px**. Visible subject masks give the
pour **12.83%** coverage and **13.47%** counter; Lambert's face/hand regions
give **6.03%**. Those masks use bone-centered anatomical regions, not a
claim that every pixel is exposed skin. The composition guard passes the
delivered store frames and sequence frames. Numerical probes do not replace
the art review below. The final rim uses (12, 28, 40), looking at (0, 2, 0),
44-degree FOV, with **34.45%** visible bar/river coverage. Its probe preserves
foliage alpha cutouts. The season and stock-depletion assertions remain red.

The kit has 2,676 triangles, all goods/fill states 2,864, Lambert 13,492, the
two miner clips' mesh 13,812, and the rod 24. Blender sources are retained.
Store and goods share one 2048 atlas. Imported atlas duplicates are ignored;
the authored source is retained. New large binaries follow existing Git LFS
rules. Godot logs include this environment's certificate-store and shader-cache
write diagnostics, plus some engine shutdown resource diagnostics; no gameplay
script errors remain in the passing suites.

![Store review contact sheet](artifacts/milestone-10-contact.png)

| Render | Art-director review / remaining work |
| --- | --- |
| Rim dawn | The live fire and smoke replace the storyboard fixture; the higher oblique view passes landscape coverage, though foliage still competes with camp for attention. |
| Arrival | The curved approach reveals the board and counter at a three-quarter angle; terrain and trail edges remain visibly procedural and deserve a softer art pass. |
| Board | The dated price list fills its own reading camera and clears the supporting post; retain this measured legibility during further texture work. |
| Weighing | Sack, stream, pans, hands and beam share the view inside the real tent; the thumb contact and weight placement need the human motion review. |
| Lambert | Hair, moustache, apron and sash distinguish him; the face remains stylized and the lower hand needs more breathing room despite passing the region-coverage check. |
| Shelves June | Three tiers and distinct item silhouettes are visible; the food sacks still look too regular. |
| Shelves October | This is the actual spendthrift history and visibly fuller stock; sparse shelves require a balance decision, not an art fixture. |
| Counter | Flour, hook paper and coil are separate on the wood, with every slate line inside its face; more convincing scoop and paper details would strengthen the sale. |
| Rain store | The canopy shelters the counter and the GPU cutoff passes; canvas sag and its worn texture remain visually coarse. |
| Rim dusk | The same camera has evening light and an extinguished fire; it retains the dawn view's foliage limitation. |
| Ledger prices | Actual visits on days 30 and 65 show differing goods prices in the margin; the scrollable pack section continues below the initial page. |
| Rod cast | The corrected socket keeps the rod out of the ground and the tip feeds the line; the reused low-held cast needs human approval before any further animation work. |
| SHORT | A real unaffordable settlement produces the large shortfall text; review its persistence while choosing a cheaper pile. |
| Empty peg | A real exhausted line-stock fixture leaves the peg bare; the surrounding loose merchandise could use clearer spacing. |

![Weigh and settle sequence](artifacts/store-sequence-sheet.png)
![Travel sequence](artifacts/trip-sequence-sheet.png)

The sequence directories contain 180 weigh/settle frames and 120 travel frames
for review; they are ignored and are not committed. The camera and pose code
is in `tests/store_sequences.gd`; `tests/build_store_contacts.py` rebuilds the
contact sheets. Final stills come from `tests/store_capture.gd` and
`tests/store_extra_capture.gd`; the latter uses the current production rim
camera. Sequence sampling uses every fifth physics tick at a fixed 60 Hz,
giving 12 fps, ten seconds of travel and fifteen seconds at the counter.

The revised thirteen-frame storyboard and its original art notes remain in
`artifacts/storyboard/` and the prior review history. It was the entry gate,
not final acceptance. Remaining human review follows the memo: dawn rim,
arrival, Lambert, weigh/settle, ledger, then a live day-30 trip and another on
day 65. The second visit should prompt an unprompted remark about the prices.
No milestone-10 completion commit has been made.

The price board uses Patrick Hand, under SIL Open Font License 1.1; the local
licence is `assets/fonts/PatrickHand-OFL.txt`. Source:
[Google Fonts metadata](https://github.com/google/fonts/blob/main/ofl/patrickhand/METADATA.pb).
Slate and ledger reuse Cedarville Cursive with its existing bundled licence.

## Milestone 11 — tools and the falling river

M10 was committed as `f9e4d93` at the user's request. The subsequent M11 work
implements the Phase 2 tools/river feature list. [MINING_GUIDE.md](MINING_GUIDE.md)
contains immediate playtest commands; [MILESTONE_11.md](MILESTONE_11.md) records
the scope, tuning and two explicit changes to old store assertions.

The river now controls its mesh, physics volume, wet gravel, working bands and
water-contact effects from one seasonal model. Tall boots extend working depth
to .70 m. Lambert sells the crowbar/spoon, pick, shovel, boots and rocker kit.
Crevices have persistent finite reserves. A cradle is built on dry shoreline
gravel with a wet intake, loads faster with a pick, and washes ten normal pan
rolls in 40 seconds after loading. Cancelled or flooded work awards no gold.
Tools, depletion and the built cradle survive store trips. The F4 panel and
command-line scenarios expose these mechanics without playing through summer.

The old gold-map access cutoff expands to the shallow riverbed exposed by this
milestone; its pocket locations, strengths and gradients are unchanged. The
original terrain geometry, panning animations and water shader are unchanged.
The crowbar includes the spoon; the rocker kit travels as a separate lumber
bundle. Those interpretations and the initial reserve/river values are explicit
in the M11 memo. M10 balance findings and M9 deferred notes remain outstanding.

### Verification

Milestones 1–10, M6 notes, M9 models, fishing tension, fishery pressure, camp
layout and camp movement pass. Only the two documented M10 catalogue assertions
changed. M11 model and integration suites pass, including actual G interaction,
flood cancellation, boots access, live fish height, and a real store round trip.

The 133-day equal-time tool comparison records **2.643 oz** from cradle loads
versus **0.655 oz** from hand pans on the same lean ground, and **10.262 oz**
from the two finite crevices. It uses 48-second work sessions and a shared
geological field; it does not replace the M10 whole-economy simulation or claim
to establish its unresolved balance targets. Outputs are `season-tools.csv`
and `season-tools.json` in ignored `artifacts/`.

The actual rocking/rain scene at 1920×1080 on the RTX 5080 measured **2.824 ms
median, 3.272 ms p95**, over 600 uncapped frames after 240 warm-up frames.
All six captures pass the composition guard. Visible miner coverage is
7.40%/7.04% for crowbar/spoon and 6.85%/6.79% for loading/rocking; the cradle
covers 6.16%/6.13%. The review lenses were tightened to give the subjects enough
space in the frame; no existing camera probe was relocated or relaxed.

The cradle is 1,516 triangles; hand tools are 72–80 each. New Blender sources
and five baked work clips are retained. Existing scoop/wash foley accompanies
the work. Engine logs retain the environment's certificate-store and shader-cache
write diagnostics, and store teardown may report retained engine objects; the
passing checks contain no gameplay script errors.

### Visual review

Each final capture was opened and inspected. The earlier upside-down crowbar
and pick were corrected; the spoon now reaches down toward the crack. The
cradle has a two-hand grip, visible hopper gravel, riffles and moving runners.

| Capture | Art review / further polish |
| --- | --- |
| June bank | Water covers the slab; the foreground boulder still draws more attention than the submerged work site. |
| September bank | The matching view clearly reveals exposed slab and new gravel; the old slab silhouette looks too rectangular. |
| Crevice | Crowbar toe is now at the crack and the working pose is readable; fingers need a tighter closure on the shaft. |
| Spoon | The lower reach reads as cleaning rather than prying; a more concave spoon bowl would improve its silhouette. |
| Loading | Pick head faces the gravel and the hopper is readable; the loading arc could show a more deliberate transfer into the box. |
| Rocking | Hands meet the handle area and the cradle rocks independently; the existing rigid backpack and uniform plank wear remain obvious. |

Automated verification does not yet measure hand/tool contact over every frame,
test on a mid-range GPU, or optimize an entire season's tool-buying policy.
These limits are recorded rather than counted as passing coverage. Human motion
review and final sound/art balancing remain appropriate for the polish pass.

![Working the cradle](artifacts/m11-rocking.png)

## Wildlife art and ambient behavior

The claim now includes a seasonal black bear, two black-tailed does, two western
gray squirrels, four California quail and a Steller's jay. They forage, become
alert and retreat from the miner; the jay unfolds its wings and flies away.
Deer visit around dawn and dusk, and the bear appears at dawn during the salmon
run. **F4 → Watch bear/deer/squirrel/quail/jay** provides immediate playtests.

The new wildlife suite, M9, M11 and camp movement checks pass. With ten animals
active, 1080p performance on the RTX 5080 measured 5.15 ms p95. The art remains
stylized: articulated joints and smooth coat surfaces are the most noticeable
limitations in close-ups. [WILDLIFE_REVIEW.md](WILDLIFE_REVIEW.md) records the
assets, captures, checks and remaining hunting/bear-raid work. This pass does
not mark the complete M12 or M13 gameplay milestones finished.
