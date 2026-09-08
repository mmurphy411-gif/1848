# Milestone 6 — The Miner

Read `ASTRA_BRIEF.md` first, including the new **Standing rules** section. This
milestone replaces the capsule with a man, puts a real pan in his hands, hangs a
sack on his belt, and builds the panning animation that the brief calls the most
important asset in the game. It also carries five fixes from the milestone 5
review, and those come first.

Do not touch: the day-cycle clock (milestone 7), sound (milestone 8). Do not
change `claim_layout.gd` values, `gold_map.gd`, `pan_result.gd`, or the boundary
physics. The walker's collision capsule stays exactly as it is; only the visual
changes.

## Part 0 — Fixes carried from the milestone 5 review

**1. Repository hygiene, before anything else.** Install git LFS tracking for
`*.png`, `*.glb`, `*.blend`, and `*.exr`, migrate the existing binaries into it,
and confirm a fresh clone works. Then re-bake textures at the smallest resolution
that holds up at viewing distance: 2048 for gravel and granite (seen at arm's
length), 1024 for the rest. Convert ORM maps to 8-bit single-channel where the
bake produced 16-bit. Report the before and after size of `assets/`.

**2. The cobbles are a mosaic.** The gravel texture is same-size Voronoi cells
with dark grout. Rebuild it with three stone size classes, roughly 8 to 15 cm
covering 20 percent, 3 to 8 cm covering 40 percent, and pea gravel in a sand
matrix for the rest, irregular spacing, some stones half-buried, grout the color
of sand rather than shadow. Then, in the terrain shader, blend gravel against
sand patches with a 3 to 8 m noise so the bar has cobble areas and sandy areas
rather than uniform paving. The cobble instances on the bar should match the
texture's large class in size.

**3. The canyon walls are dunes.** This is shape, not surface. In `greybox.gd`,
for wall vertices more than 3 m beyond `back_z` on the near bank and beyond the
far shore on the far bank, displace along the normal with layered noise: 0.5 m
amplitude at the apron rising to 2.5 m on the upper cliff bands, plus a stepped
strata function aligned with the existing benches so cliff faces get hard upper
edges and ledges. Recompute normals. `height_at` and the apron stay untouched so
every boundary test still passes. Then scatter 40 to 80 large boulders from the
existing set, scaled 2 to 5 times, on both aprons and at the cliff foot, none on
the bar or within 12 m of the water, with convex collision on any within 20 m of
`back_z`. Increase granite macro variation so the cliff reads as jointed rock at
50 m. The test for this is a person looking at the upstream shot and seeing a
rock canyon.

**4. Oak leaves are paper cutouts.** Replace single 1.5 m lobed-leaf cards with
clusters of five to nine leaves per card at 40 to 60 cm, more cards, same triangle
budget. Switch the foliage material to alpha-to-coverage so edges stop
pixelating. Regenerate the oak and conifer atlases at 2048 where the leaf
detail needs it. The oak shot from underneath is the check.

**5. Sand stripes and grass tufts.** Domain-warp the sand ripple pattern so
wavelength and direction drift, and halve its normal strength. Grass: thinner
blades, more per card, desaturated toward olive, and blend the duff patch edges
so they stop reading as mud puddles.

## Part 1 — The miner model (`blender/build_miner.py`)

`assets/miner/miner.glb`. A man of 1848 in working clothes, built procedurally
and rigged, 8,000 to 15,000 triangles, 1.78 m tall to match the capsule.

**Design guidance.** The player sees him from behind at 3 to 5 m, and from the
side crouched at the water. The silhouette and the clothes carry him; the face
does not. Give him a low-brimmed felt hat and a beard so the face is mostly
hidden, which is both period-correct and forgiving. Spend the budget on:

- Wool trousers, worn at the knees, tucked into or over boots
- Suspenders over a collarless linen shirt, sleeves rolled
- A leather belt with the sack hanging at the left hip
- Hands that can hold a pan: five fingers, not mittens
- Cloth folds baked to normal maps from a higher-resolution source, not modeled

Textures at 2048 for the body, baked from Blender procedural materials: worn
wool, sweat-darkened linen, scuffed leather. Wet legs are handled at runtime, see
Part 4.

**Rig.** Rigify metarig generated and built by the script, or a hand-authored
humanoid skeleton with IK on hands and feet, whichever the script can produce
reliably. Bone names must follow the Godot humanoid convention so the retarget
works. Export skin weights, no more than 4 influences per vertex.

## Part 2 — The pan and the sack

- `assets/miner/pan.glb`: a steel gold pan, 40 cm across, 8 cm deep, riffle-less
  as in 1848, dark grey with a lighter scuffed interior and rust at the rim.
  Under 1,500 triangles. The interior must have a clearly modeled crease where
  the flecks collect.
- `assets/miner/sack.glb`: a leather or canvas poke, tied at the neck. Under 800
  triangles. Five blend shapes or five scale keys for the sack stages
  0 through 4, from flat and empty to visibly heavy.

Godot side: the pan attaches to the right hand through a `BoneAttachment3D`, the
sack to the hips. `pan_display.gd` keeps its result logic and its fleck MultiMesh
but repositions the flecks along the new pan's crease. The placeholder cylinder
is deleted. The sack reads `Sack.stage()` on the `changed` signal and steps its
shape; nothing else about `sack.gd` changes.

## Part 3 — Animation (`blender/build_miner_animation.py`)

Keyframed in Blender by script on the rig, exported in the miner glb. The pan
and sack are separate objects but the pan must be animated as if in the hand:
export a `pan_socket` bone in the right hand and drive the attachment from it.

Clips:

| Clip | Length | Loop | Notes |
|---|---|---|---|
| `idle` | 4 s | yes | Weight shift, a breath, pan held at his side in the left hand |
| `walk` | 1.0 s | yes | 2.4 m/s cadence, pan carried, slight sway from the sack |
| `wade` | 1.2 s | yes | Higher knees, slower, arms out for balance |
| `pan_enter` | 2.0 s | no | Crouch at the water, switch pan to both hands, scoop gravel |
| `pan_swirl` | 2.0 s | yes | Submerge, circular swirl, shake, tilt to wash the light material over the lip |
| `pan_wash` | 1.5 s | no | Final tilt, the last of the gravel goes, water drains |
| `pan_lift` | 1.5 s | no | Lift the pan, lean over it, look |
| `pan_exit` | 1.0 s | no | Stand, pan back to the left hand |

**The pan sequence is the point of this milestone.** It should look like a man
who has done this a thousand times: unhurried, economical, weight over his heels,
elbows in, wrists doing the work. Watch reference footage of placer panning
before keyframing. The swirl should have a real circular motion with a shake
component, not a wobble. Water contact is where the pan is; the animation must
put the pan below the water surface during `pan_swirl` when the miner is at the
waterline, and the wash tilt must be enough to see into the pan.

**Timing in Godot.** `panner.gd` gets a segment sequence instead of a single
timer: `pan_enter`, then `pan_swirl` repeated `SWIRL_CYCLES` times (start with 3),
then `pan_wash`, then `pan_lift`, and `PAN_DURATION` becomes the sum, which lands
at 10 s. `SHOWING` begins at the end of `pan_lift`, with the camera focus as
before, and `pan_exit` plays on return to `IDLE`. **The milestone 2 test's
hard-coded 358 frames is the one assertion in earlier suites that may change:
make it read `panner.PAN_DURATION` instead.** Nothing else in that suite changes.

`AnimationTree` with a state machine: `idle`, `walk`, `wade` blended by speed and
water depth, and the pan sequence as a sub-state machine. Animation playback rate
for `walk` and `wade` scales with actual horizontal velocity so feet do not slide.

## Part 4 — Runtime details

- **Turning to face the water** at pan start becomes a 0.3 s turn, not a snap.
- **Wet legs.** A material parameter on the miner darkens and glosses the
  trousers and boots up to the current wading depth, with a 20 cm wet line that
  persists and dries over about 60 s after he leaves the water.
- **Wading splashes.** `GPUParticles3D` at each foot, emitting only when depth is
  above 5 cm and horizontal speed above 0.3 m/s, small white droplets that fall
  and die at the surface. The water shader's foam collar already handles the
  contact ring.
- **Shadows.** The miner casts and receives shadows, and his self-shadowing must
  not acne at golden hour; adjust bias on the sun if needed and confirm the
  milestone 3 renders still match.
- The sack on the belt steps at the `Sack.stage()` thresholds. Milestone 2's
  stage tests already cover the numbers.

## Performance

Same proxy: p95 under 5.5 ms at 1080p on the 5080 with the miner, particles,
the wall displacement, and the scattered boulders all in. If it does not fit,
reduce scattered boulder count first, then particle count, then miner texture
resolution to 1024.

## Tests — `tests/milestone_6.gd`

- Milestone 1 to 5 suites pass, with the single permitted change in milestone 2
  noted above.
- Files exist: `miner.glb`, `pan.glb`, `sack.glb`, and their build scripts;
  triangle counts within budget; the miner has a `Skeleton3D` and the eight clips
  named above with lengths within 10 percent of the table.
- The walker's `Visual` no longer contains a capsule mesh; it contains the miner
  scene, an `AnimationTree`, and `BoneAttachment3D` nodes for pan and sack.
- Miner AABB height between 1.72 and 1.85 m; feet within 3 cm of terrain when
  idle on the bar.
- Idle on the bar: the tree's current state is `idle`. Hold `move_forward` for
  two seconds on dry gravel: state is `walk`. Do the same knee-deep: state is
  `wade`. Walk playback speed scales with velocity (compare at full speed and
  while wading).
- Start a pan at the waterline: the sequence passes through `pan_enter`,
  `pan_swirl` (at least twice), `pan_wash`, `pan_lift` in that order;
  `PAN_DURATION` is between 8 and 12 s; `SHOWING` begins within 0.1 s of the
  end of `pan_lift`; `pan_exit` plays on return to idle.
- During `pan_swirl` at the waterline, the pan's global position dips below
  Y = 0 at least once per cycle, and its horizontal position traces a loop
  (standard deviation of X and Z each above 3 cm across one cycle).
- Turn to face water at pan start takes between 0.2 and 0.5 s (place him facing
  inland first; check yaw at 0.1 s is not yet final).
- Sack visual scale or blend weight increases monotonically across stages
  0 through 4.
- Splash particles are emitting only when wading and moving; not when standing
  in water; not on dry gravel.
- Wet-line parameter rises with depth while wading and decays after leaving the
  water.
- The camera focus during `SHOWING` still lands within 1 m of the pan (the pan
  moved to the hand, so re-verify).
- The composition guard passes on every render.

## Renders and probes

All at golden hour, 1080p, guard on. For each, write the art-director sentence
in the README.

- `milestone-6-miner-standing.png`: three-quarter rear view from the player
  camera, idle on the bar, sun raking. **Probe:** the miner's shadow on the
  gravel is contiguous (no light leaks through the mesh at the torso).
- `milestone-6-miner-walk.png`: mid-stride from the side.
- `milestone-6-miner-wade.png`: knee-deep and moving, splashes visible, foam
  collar at the shins, wet line above the water.
- `milestone-6-pan-swirl.png`: side view, crouched, pan in the water mid-swirl.
  **Probe:** pan center below Y = 0 in this frame.
- `milestone-6-pan-lift.png`: the `SHOWING` close-up with a tier 3 result, flecks
  along the real crease.
- `milestone-6-sack-stage-3.png`: rear view with `Sack.ounces` set to 3.5 so the
  poke hangs heavy.
- `milestone-6-downstream.png`: the hero shot with the miner in it.
- `milestone-6-upstream.png`: the upstream shot, to judge the canyon wall fix.
  This is the render that decides Part 0 item 3.
- `milestone-6-oak-under.png`: under the oak looking up, to judge the leaf fix.
- `milestone-6-gravel-close.png`: to judge the cobble fix.

Also record a 12-second clip of one full pan from the player camera as an image
sequence at 12 fps into `artifacts/pan-sequence/`, so a human can flip through
the motion. Do not commit it; `artifacts/` is ignored.

## Acceptance

- All six suites pass; harness passes probes, guard, and budget.
- `assets/` is under 40 MB on disk and all binaries are in LFS.
- **Human review**, in this order: the pan sequence image flip, the upstream
  canyon shot, the gravel close-up, the oak from underneath. The pan sequence
  is the one that matters. Expect a round of notes on timing and posture; a
  swirl that is too fast or a crouch that looks like a squat are the likely
  ones.
- README updated: the miner pipeline, the animation clips and state machine,
  the Part 0 fixes with before and after sizes, and the art-director sentence
  for every render.
- Commit as `Complete milestone 6 miner`.
