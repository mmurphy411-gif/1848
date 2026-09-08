# 1848

Milestone 6: a playable panning claim with a rigged miner, animated panning,
procedural canyon assets, flowing water, and golden-hour light.
Built with **Godot 4.7.2 standard**, GDScript, and the Forward+ renderer.

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

Implementation and review evidence are in the working tree. This round is **not
accepted as complete**: the specified nearest-boulder oak-shadow gate still
fails, the engine reports a reflection-atlas texture leak at shutdown, and human
review is outstanding. The completion commit is withheld until those acceptance
items are resolved. No day clock, sound, claim-layout values, gold map, pan-result
rules, boundary physics or walker capsule changed.

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
