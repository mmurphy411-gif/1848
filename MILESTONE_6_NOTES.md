# Milestone 6 — Notes round

Read `ASTRA_BRIEF.md` first, including the two new standing rules at the end of
this file, which are to be appended to the brief before any other work. This
round answers the human review of milestone 6. Every automated gate passed and
the canyon fix landed. The pan sequence and the miner did not pass review, and
the gravel and oak fixes are half done. This is the notes round the milestone
6 acceptance said to expect.

Do not touch: the day-cycle clock (milestone 7), sound (milestone 8),
`claim_layout.gd` values, `gold_map.gd`, `pan_result.gd`, the boundary physics,
or the walker's collision capsule. Every earlier suite passes unchanged, with the
exceptions named below.

## Rulings made for this round

These are decisions, not questions. Each may be struck by the user before work
starts; if one is struck, skip the part that depends on it and say so in the
README.

1. **Base mesh exception.** The "everything procedural" rule was about not
   shipping other people's art. A nude humanoid base mesh under a CC0 licence,
   loaded once by `build_miner.py` and then dressed, textured and rigged by the
   script, keeps that spirit. It is permitted for this round. Record the source
   and licence in `blender/README.md`. If no suitable mesh is available offline,
   fall back to Part 2's sculpt pass on the procedural body.
2. **The forest comes back.** The 600 conifers of milestone 5 are restored. The
   overview budget was missed by 0.14 ms; fix that with a distant variant, not
   with deletion. If 600 still does not fit after Part 5, the overview budget
   alone rises to 6.0 ms. The downstream and wade budgets stay at 5.5 ms.
3. **Panning camera.** During `PANNING` the player camera dollies to a side view
   so the swirl is visible. Details in Part 3. `SHOWING` keeps its own close-up.
4. **LFS history is rewritten.** There is no remote yet, so this is the cheapest
   it will ever be. Details in Part 0.

## Part 0 — Repository, before anything else

Clone the repository to a sibling directory as a backup, then run
`git lfs migrate import --everything --include="*.png,*.glb,*.blend,*.exr"`.
Confirm `git lfs ls-files` covers every historical binary, that a fresh local
clone passes all six suites, and report `.git` size before and after in the
README. This rewrites every commit hash; note the new hash for
`Complete milestone 6 miner` in the README.

Also in this part: fix the two leaked texture RIDs reported at exit by
`tests/miner_performance.gd`, and correct the milestone 2 test labels that still
say "six seconds" without changing what they assert.

## Part 1 — Review cameras (`tests/miner_capture.gd`)

The contact sheets from the player camera showed a small dark shape for 115 of
144 frames. Nothing about the posture or the swirl could be judged. The review
material has to show the work.

- Add a **side review camera**: fixed, 2.0 m from the miner's hips on his left
  side, at hip height, level, 50 mm equivalent. Record the full pan from it as a
  second 12 fps image sequence into `artifacts/pan-sequence-side/`. Build the
  same contact sheets from it.
- Add a **front three-quarter review camera** at 1.5 m, 30 degrees above the
  pan, looking into it, recorded only for `pan_swirl`, `pan_wash` and
  `pan_lift`.
- Both review cameras are review-only. They do not exist in the game.

## Part 2 — The miner model

The miner reads as a mannequin: boxy torso, flat-shaded face polygons, a
beard that is one dark wedge, hands that are blocks with a thumb, a pan carried
like a disc. The player sees him from behind at 3 to 5 m and from the side
crouched, and at those distances the silhouette is still a capsule with a hat.

Whether the base mesh ruling is used or not, the deliverable is the same:

- **Smooth shading everywhere on skin.** No visible facets on face, neck or
  hands at the `SHOWING` distance.
- **Hands with five separated fingers**, each at least two segments, curled
  around the pan rim during the pan clips. The `pan-lift` render is the check.
- **Beard as geometry**: a shaped volume with a baked hair-strand normal and
  albedo, not a flat polygon. It should break the jaw silhouette from the side.
- **Shirt with volume.** Sleeves fuller than the arm, a gather at the rolled
  cuff, fabric bunching at the suspenders and above the belt. Bake folds from a
  high-resolution source as before, but the low mesh itself must have the
  volume; a normal map cannot fix a box.
- **Hat brim** wide enough to shade the face in the golden hour standing
  render; currently it is a narrow ring.
- **The pan is carried by its rim**, fingers over the lip, hanging at his side
  with the bowl facing his leg. From behind it reads as a shallow dish, not a
  frisbee.
- Budget rises to 20,000 triangles for the miner. Body atlases may return to
  2048 if Part 5 leaves room.

## Part 3 — The pan sequence

`build_miner_animation.py` currently keys a crouch with the hips at 0.40 m and
the torso pitched 72 degrees, and a swirl of 6 cm radius. At 4 m that is a
ball that trembles. Reference footage shows a man whose back is fairly straight,
whose weight is over his heels, and whose upper body sells the circular motion.

**Posture, measured on the rig at the midpoint of `pan_swirl`:**

| Measure | Now | Required |
|---|---:|---|
| Hip height above the feet | 0.40 m | 0.48 to 0.60 m |
| Torso pitch from vertical | 72 degrees | 30 to 45 degrees |
| Knee separation | 31 cm | at least 40 cm |
| Head pitch from vertical | follows torso | 20 degrees more than the torso, looking into the pan |
| Pan rim, lowest point, during swirl | just below Y = 0 | 2 to 6 cm below the surface, never the whole pan |

One knee may drop toward the gravel if it reads better; the other stays up. Feet
stay planted on the same spot for the whole sequence.

**Motion.** The swirl radius at the pan centre rises to 9 to 12 cm, and the
shoulders and elbows carry it: shoulder joints move at least 3 cm in a circle in
phase with the pan, elbows stay inside the line of the hips. The shake component
stays short and sharp, two or three shakes per cycle, with a pause after each so
the rhythm is not a metronome. Each of the three `pan_swirl` cycles differs from
the others by at least a phase offset and a small change in radius, so the loop
is not recognisable on the third pass. `pan_wash` tilts far enough that the front
three-quarter review camera can see the crease. `pan_lift` brings the pan up to
chest height and tilts it toward the face; the head comes down to meet it.

**Panning camera (ruling 3).** On entering `PANNING`, `orbit_camera.gd` blends
over 0.6 s to a side view: 2.2 m from the hips on the miner's left, 0.4 m above
hip height, aimed at the pan. It holds there for the sequence. Mouse orbit is
disabled while held. On `SHOWING` it blends to the close-up; on return to
`IDLE` it blends back to the orbit over 0.6 s. The boom sphere test still
applies; if the side position is blocked by a boulder, mirror to the right side.

**SHOWING close-up.** The current `focus()` in `orbit_camera.gd` parks the
camera 50 cm beside the shoulder to clear the collision capsule, and the frame
is mostly forearm and neck. Replace it: exclude the walker from the boom test
during focus (the arm already excludes `target`; confirm the miner's meshes are
under it), and place the camera 0.55 m in front of the pan centre along the
miner's facing, 0.35 m above it, looking down into the pan. The miner is behind
the pan in the frame, hat and beard visible above it, hands on the rim at the
sides. The pan interior is the subject.

## Part 4 — Carried fixes, second pass

- **Foliage shadows.** The oak's shadow on the boulders in the standing render
  is bare branches. Leaf cards cast no shadow. Enable shadow casting on the
  foliage MultiMesh instances with the alpha-to-coverage cutout respected in the
  shadow pass. Check the standing render: the oak shadow is a canopy, not a
  skeleton.
- **Gravel palette.** The gravel albedo is near-black, slate blue and white,
  which reads as aquarium gravel. Rebuild the stone colours from a Sierra
  palette: warm greys, tan, buff, white quartz, a few dark green-grey stones,
  with the darkest stone no darker than 25 percent luminance and the lightest no
  lighter than 85 percent under neutral light. Reduce saturation across the set.
  The `gravel-close` render is the check; it should read as a river bar, not a
  fish tank.
- **Gravel-to-sand blend.** The terrain shader's `sand_band` produces a hard
  straight edge across the close-up. Widen every transition in it to at least
  1.5 m of smoothstep and add a second, finer noise on the edge so the boundary
  wanders. No straight line of any length in the `gravel-close` render.
- **Oak limbs.** The branches seen from below are flat blue-grey ribbons. Model
  the trunk and the first two orders of limbs as tapered cylinders with the bark
  material; only the twigs stay as cards. Increase leaf cards inside the crown so
  the `oak-under` render shows sky through gaps, not everywhere.
- **Sack render.** Re-frame `milestone-6-sack-stage-3.png` from the left rear
  quarter so the poke is not hidden behind the pan. The poke itself needs a
  visible neck tie and a crease where it hangs from the belt.

## Part 5 — Forest and budget (ruling 2)

Restore the 600 conifers by removing the `m6-forest-reduction` slice in
`vegetation.gd` and restoring the milestone 5 placement. Then, for instances
beyond 60 m from the bar centre, use a distant variant of each species: under
600 triangles, a single crown card cluster, the same atlas. Build it in
`build_trees.py` beside the full model. The overview render must not show the
switch. Report overview p95 with 600 trees before and after the variant. If it
is still above 5.5 ms, the overview budget is 6.0 ms and the number is recorded.

## Tests — `tests/milestone_6_notes.gd`

- Milestone 1 to 6 suites pass. The only permitted changes: milestone 5's
  conifer count assertion returns to 600 if it was changed; milestone 6's miner
  triangle ceiling becomes 20,000.
- Posture at the midpoint of `pan_swirl`, measured on the skeleton: hip height,
  torso pitch, knee separation and head pitch within the table in Part 3.
- Swirl: pan centre X/Z standard deviation each above 6 cm; the lowest rim
  point between 2 and 6 cm below Y = 0 and the highest rim point above Y = 0
  at every frame; shoulder joint travel at least 3 cm per cycle.
- The three swirl cycles are not identical: the pan path of cycle 2 differs from
  cycle 1 by more than 1 cm RMS.
- Hands: at least five distinct finger bones per hand, each with a child; during
  `pan_swirl` every fingertip within 3 cm of the pan rim surface.
- Panning camera: within 0.8 s of `PANNING`, the camera is between 1.8 and 2.6 m
  from the hips and its forward vector is within 25 degrees of the direction to
  the pan. Mouse motion during `PANNING` does not change it.
- SHOWING close-up coverage probe: render the `SHOWING` frame; the pan interior
  covers at least 15 percent of the frame, skin-toned pixels cover at most 20
  percent, and no single material covers more than 40 percent.
- Foliage shadow: in the standing render, sample the oak's shadow on the
  nearest boulder; the shadowed region is at least 60 percent contiguous, not a
  branch skeleton.
- Gravel: over the `gravel-close` render, stone luminance between 0.25 and 0.85
  for 95 percent of gravel pixels; no run of more than 200 pixels along any row
  where the gravel/sand mix crosses 0.5.
- Conifer count is 600; overview p95 within the ruled budget.
- Composition guard on every render, as before.

## Renders and probes

All at golden hour, 1080p, guard on. Art-director sentence for each in the
README, as the standing rules require.

- `notes-6-pan-side-swirl.png`: side review camera, mid `pan_swirl`.
- `notes-6-pan-front-wash.png`: front three-quarter review camera, mid `pan_wash`,
  the crease visible.
- `notes-6-pan-showing.png`: the new `SHOWING` close-up with a tier 3 result.
  **Probe:** the coverage probe above.
- `notes-6-miner-standing.png`: same view as milestone 6. **Probe:** the oak
  shadow probe.
- `notes-6-miner-side.png`: side view at 2 m, idle, to judge the silhouette and
  the carried pan.
- `notes-6-hands.png`: from the front camera, hands on the rim, 0.8 m.
- `notes-6-sack-stage-3.png`: re-framed as in Part 4.
- `notes-6-gravel-close.png`, `notes-6-oak-under.png`, `notes-6-overview.png`.

Record both 12 fps sequences, player and side, into `artifacts/`. Not committed.

## Acceptance

- All suites pass; harness passes probes, guard and the ruled budgets.
- `.git` no longer holds the pre-LFS binaries; fresh clone passes.
- **Human review**, in this order: the side-camera flip of the pan sequence,
  the `SHOWING` close-up, the standing and side miner renders, gravel-close,
  oak-under. The side flip is the one that matters.
- README: a "Milestone 6 notes round" section with the posture numbers before
  and after, the camera changes, the forest and budget numbers, the LFS rewrite
  result, and the art-director sentences.
- Commit as `Complete milestone 6 notes round`.

## Standing rules to append to `ASTRA_BRIEF.md`

- **Every close-up render gets a coverage gate for its subject.** If a shot
  exists to show a thing, a probe asserts that thing covers a minimum of the
  frame and that no other single surface dominates it. Milestone 4 shipped a
  hero shot that was 60 percent boulder; milestone 6 shipped a pan close-up that
  was 60 percent forearm. Both passed the composition guard.
- **When a milestone's fallback list is exhausted, stop and report.** Do not
  reach into an earlier milestone's fallbacks or its floors. Milestone 6 halved
  the forest to save 0.14 ms because milestone 5 had listed conifer count as a
  fallback. That was a design decision, and design decisions are made in the
  spec, not in the budget pass.
