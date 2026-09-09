# Milestone 9 — Notes round

Read `PHASE2_BRIEF.md` and the standing rules in `ASTRA_BRIEF.md` first,
including the two new rules at the end of this file, which are to be appended
to the brief before any other work. This round answers the human review of the
milestone 9 review candidate. The architecture landed as specified, every
disclosed deviation was the right call, and the ledger is the best new thing in
the game. The fishery, the run cue, four renders, and the test coverage did not
pass review. This is the notes round the milestone 9 acceptance said to expect.

This round lands **before** `MILESTONE_10.md`. The store depends on the fishery
change in Part 1; do not start milestone 10 until this round's suite passes and
the completion commit for milestone 9 is made.

Do not touch: `gold_map.gd`, `pan_result.gd`, `claim_layout.gd` values, the
boundary physics, the water shader, `WATER_LEVEL`. Do not build the store, tools,
the falling river, or any animal. Suites 1 through 8 and the milestone 6 notes
suite pass unchanged. The milestone 9 suites pass unchanged except for the
assertions named in Part 1 and Part 2.

## Rulings made for this round

These are decisions, not questions. Each may be struck by the user before work
starts; if one is struck, skip the part that depends on it and say so in the
README.

1. **The river depletes.** Catching a fish lowers presence at that spot for
   days, and trout thin out through October. The simulation's careful policy
   took 573 trout and held 189 smoked fish on November 1. That proves food is
   free, and a store nobody needs is not a store. Part 1.
2. **The tension meter becomes a diagnostic.** It stays in the code behind a
   sandbox toggle, off by default. The run is made readable in the world
   instead. Part 2. The `fishing_tension.gd` suite may change only where it
   asserts meter visibility.
3. **`GameState` grows two named fields.** The rule "seed, day, dollars,
   condition, inventory, and nothing else" is amended to add `journal` and
   `catch_log`. Journal entries, catch totals, hooks lost, the cache, and the
   midday flag move out of `inventory`, which returns to being what he carries.
   Milestone 10 will add `ledger` under the same amendment. Part 6.
4. **Hook loss is tuned in the action, not in the policy.** `SNAG_EXPOSURE`
   leaves the simulation. Snags come from where the bait actually goes. Part 1.

## Part 0 — The time economy, written down

Record these in the README under a heading of their own, because every balance
decision from here on depends on them and none of them are stated anywhere:

- One game hour is 76.2 real seconds. A 20-minute real day covers dawn 04:45 to
  dusk 20:30.
- A pan is 11 real seconds, about 8.7 game minutes. A day holds at most about
  100 pans if he never walks.
- The mean dusk trout bite is 16 real seconds, about 12.6 game minutes. One real
  minute at the best pool yields three to four bites.
- Frying is 20 game minutes, 25 real seconds. Smoking is 4 game hours, 5 real
  minutes of fire.

The scarce resource in this game is the player's real minutes, not the fish.
State that sentence in the README. Milestone 10's simulation is built on it.

## Part 1 — The fishery depletes (`fishery.gd`, `game_state.gd`, the simulation)

**Catch pressure.** `GameState.catch_log` is an `Array[Dictionary]` of `{day,
spot_index, species}`, appended by `caught()`. `Fishery.presence` and
`bite_rate` gain a trailing optional argument `catch_log := []` so every
existing call stays pure and unchanged. `static func pressure(species,
spot_index, day, catch_log) -> float` returns

    max(0.15, 1 - sum over matching catches of 0.30 * max(0, 1 - (day - catch_day) / 6))

A catch matches when it is the same species at the same spot within the last
six days. Two trout from one pool today leave it at 0.40; three leave it at the
floor. It recovers to full in six days. `expected_population` takes the same
argument, so the player **sees** a pool go quiet after he has fished it, and
sees it fill back in over the week. That is the map teaching itself.

**Fall decline.** `static func season_factor(species, day) -> float`: trout 1.0
through day 95 (September 29), linear to 0.45 at day 120 (October 24), 0.35 at
day 132. Pikeminnow and hardhead 1.0 through day 100, 0.5 by day 115, 0.4
after. Suckers unaffected. Salmon already follow `salmon_intensity`. The hot
late-July dip stays. Fold the existing weather factors and this into one
commented product in `presence`; the function should read like the gold map's
density: each term named, each with a one-line reason.

**Spot construction.** Pools currently sit at a fixed 5.8 m from shore. Use the
spec's rule: 1.5 radii downstream of the boulder center and 5 to 7 m riverward,
chosen so depth lands in 0.8 to 1.6 m. Bigger boulders make bigger wakes and
their pools sit farther out. Comment the fish map to the standard of
`gold_map.gd`: the first forty lines should let a reader who has never seen the
scene draw the spots.

**Snags follow the bait.** Remove `SNAG_EXPOSURE` from the simulation. In
`fisher.gd`, a sunk bait (hellgrammite, worm, pork) has a base 6 percent snag
chance per cast on the cobble bed anywhere, 25 percent within 1 m of a boulder
footprint or a slab as now. A floating grasshopper snags only in the footprint
band. Dawn hellgrammites at the seams cost hooks; dusk grasshoppers at the pools
mostly do not. The simulation uses the same rule by casting at the spot with a
seeded 1.5 m scatter and asking the same function.

**Run interval.** `FightModel` runs come 2 to 4 seconds apart, seeded per fight,
not a fixed 3.6. The fishing guide's sentence about 3.6 seconds goes.

**Simulation changes.** The careful policy rotates: each session it fishes the
spot with the highest pressure-adjusted bite rate for the bait it holds, and
moves when a spot drops under 0.5. Bands, which replace the milestone 9
assertions on trout take and smoked stock:

- Careful season trout take between 150 and 280.
- Smoked fish in store on November 1 between 5 and 40.
- Careful holds condition 60 or above on at least 85 percent of days. If
  rotation cannot hold 85, stop and report the number rather than tuning the
  pressure constants down; that is a design decision.
- October days on which the careful policy eats two meals from the river alone
  are fewer than 70 percent. That gap is what the store fills.
- Hooks lost 8 to 20 over the season from the action's own snag and break rules
  with no policy constant. If it falls outside, tune the sunk-bait base snag
  chance between 4 and 10 percent and record the value.

## Part 2 — The run, seen and heard (`fisher.gd`, `fishing_line.gd`, `hud.gd`)

The meter answered the note, but it is a loading bar with a label. The rule for
phase 2 is that the HUD relaxes inside an action only for bait and hooks. The
run has to be legible in the world:

- **The line.** At the run's start the ribbon snaps from its sag to straight
  taut in under 0.1 s and its angle swings 15 to 25 degrees toward the fish's
  dart. Width doubles for the duration of the run. When the player releases,
  the sag returns over 0.3 s. Tension should be readable from the line alone.
- **The arm.** The `fight` clip gains a 0.3 s `yank` overlay: both hands pulled
  forward and down 20 cm, shoulders following, then recovering. Play it at run
  start. Playback rate of `fight` already follows pull; keep that.
- **Spray.** A short `GPUParticles3D` burst of 12 to 20 water droplets at the
  fish for 0.4 s, lit, falling under gravity, at run start and again at break.
- **Sound.** A `line_sing` one-shot through `ActionAudio` at run start, a rising
  tone under 0.3 s, and a `line_snap` at break. Synthesize both in
  `audio/build_phase2_audio.py`.
- **The warning.** The 0.4 s pre-run surge stays, and the fish's dart is made
  larger: 0.6 m rather than 0.35, with a visible body roll.
- **The meter** moves behind a `Show tension` toggle in the F4 panel, default
  off, and is not shown in any render. The break message becomes `Line broke.`
  with no percentages and no key names.

## Part 3 — The landed fish and the hand (`build_fish.py`, `build_miner_animation.py`)

The close-up passes its coverage gate and is not good. Send-backs:

- **Fingers pass through the body.** Rebuild the `land` and `SHOWING` grip so
  the right hand holds the fish by the tail wrist, thumb over, fingers under,
  the way a man holds a trout he means to keep. Add a geometric test: at the
  `SHOWING` pose every finger tip lies outside the fish mesh's convex hull by at
  least 5 mm, and the palm center is within 3 cm of the surface.
- **The fish is a torpedo.** Give each species a head: the body's first quarter
  tapers in both axes, a mouth notch, a gill plate line in the texture and a
  slight geometric step at the operculum. Fins get root thickness (two quads
  and a ridge, not one plane) and the tail forks. Trout get an adipose fin. The
  parr spots on the atlas should be fewer, larger, and irregular; the current
  scatter reads as noise. Body triangle counts may rise to 700.
- The `SHOWING` camera is fine. Keep the 15 percent coverage gate and add: the
  hand covers no more than 12 percent of the frame.

## Part 4 — The bank trout

Two trout are visible and they read as decals under a ripple pattern. They lie
perfectly level, cast no shadow, and nothing places them at a depth.

- Fish cast shadows. Confirm the sun at 18:30 reaches the bed at 0.8 m; if it
  does not, the render's hour may move to 18:00 and the README says so.
- Holding fish roll 5 to 10 degrees on the sway and pitch a few degrees on each
  dart. A trout holding in current is never flat.
- Add a faint wake: nothing on the surface, but the fish shader darkens the
  belly toward the bed with depth so the fish reads below the surface rather
  than on it.
- The framing was a telephoto from the bank. Take it from standing eye height,
  2 m back from the water, 50 mm equivalent, looking down into the pool at
  about 35 degrees, so the bank, the surface, and the fish are all in frame.
  The 0.8 percent coverage probe stays.

## Part 5 — Camp: canvas, duff, fire

- **Canvas.** The lean-to sheet is a flat orange plane at dusk. Give the sheet a
  second noise on the sag (three scales, per the uniformity rule), a seam down
  the middle, grommet points where it ties to the poles, and a material that
  transmits light: two-sided, with the sun and the fire visible as warmth
  through the cloth from the shadow side. Stains and a darker weathered band
  along the ridge. The `camp-rework-dusk` render is the check: the cloth must
  read as cloth from 8 m.
- **Duff patch.** The disc has a hard circular edge visible from the sandbox
  camera. The boundary radius varies with a noise between 1.8 and 3.2 m, and
  the material fades over the last 0.5 m into the gravel with a dithered
  alpha, the same approach as the fish fade. No visible circle from any angle.
- **Fire light.** The omni sits at 0.55 m with range 9 and casts long bar
  shadows from every ring cobble across the bar. Raise it to 0.9 m, reduce
  energy so ground luminance at 2 m is about 1.6 times that at 8 m and no more,
  soften shadows with a larger `shadow_blur`, and add a second omni without
  shadows at 0.3 m and a third of the energy to fill the ring's own shadows. The
  dusk probe (1.6 times at 2 m versus 8 m) stays; add: no shadow edge longer
  than 3 m on the ground within the camp circle.
- **Flame.** The particles are visible spheres. Use flat quads facing the
  camera, 30 to 40 of them, 8 to 20 cm, with the fire shader shaping each as a
  tapered tongue that erodes with a noise over its life, additive, warm-to-dark
  over the lifetime. The "no single-color run wider than 6 pixels" probe stays
  and gains: no circular silhouette wider than 12 pixels in the flame region.

## Part 6 — Small fixes

- **G eats before it gathers.** Away from camp `interact` gathers if there is
  anything to gather; it never eats. Eating a carried portion or smoked fish is
  a camp action at the skillet, or, away from camp, a `fish`+`interact` chord
  is not wanted either; simply make it the skillet and the crate. The HUD line
  at the crate reads `Eat · smoked fish` when one is carried and the ledger is
  reached with a second press. Order the crate's cycle: eat first when food is
  carried, ledger otherwise.
- **`GameState` fields** per ruling 3: `journal: Array[Dictionary]`,
  `catch_log: Array[Dictionary]`. `catches` totals and `hooks_lost` become
  functions over `catch_log` and `journal`. `cache` stays in `inventory`; it is
  something he owns. `midday_checked` becomes a private field on `GameState`.
  The scenario parser and the sandbox keep working; the milestone 9 assertions
  that read these through `inventory` may be updated to the new fields and are
  the only test changes permitted in this part.
- **Fish map comments** per Part 1.
- **The sack in the ledger** reads in ounces and the line in yards. Keep both;
  they are period. But the HUD bait line during fishing says `bait`, which is a
  word he would not use; it reads `Grasshopper · 9 · 20 hooks`.
- **Fishing guide.** Update `FISHING_GUIDE.md` for the run cues, the removed
  meter, snags on sunk bait, the eating change, and depletion ("a pool you have
  fished today is a poor pool").

## Part 7 — The tests the spec asked for

These were in `MILESTONE_9.md` and were not shipped, and the README did not say
so. Add them to `tests/milestone_9_notes.gd`:

- Walk the miner to within 2 m of a pool fish on the shore: it flees and is
  hidden within 2 s; it returns within 45 s.
- `interact` on the grass band at 12:00 adds a grasshopper on a seeded success;
  at 20:00 it does not; in rain it does not; the daily budget stops at 6;
  `day_ended` resets it. Firewood at the high-water line always succeeds and
  stops at 10.
- `presence` differs for seed + 1 on at least half the spots.
- On a rain day `overcast` reaches the intensity within 35 s and returns to 0
  within 35 s of a clear day; rain particles emit only in rain; frost triples
  the mist density at 07:00 and restores it by 10:00.
- HUD shows bait and hooks only in fishing states and action names only when an
  interaction is eligible; idle on the bar, the sack total is the only label.
- WASD does nothing while the sandbox is open and works after it closes.
- Camp props overlap no boulder footprint and none stands in water.
- Stance turn completes in 0.2 to 0.5 s (currently asserted at one frame count;
  assert the band).

New for this round:

- `pressure`: two same-day trout at a pool give 0.40; three give 0.15; six days
  later it is 1.0; a sucker catch does not affect trout at the same spot.
- `season_factor("trout", 95)` is 1.0, at 120 is within 0.02 of 0.45.
- `expected_population` at the best pool at dusk after three trout today shows
  at most one trout there; the scene matches within 1 after the next refresh.
- Sunk bait cast in open water snags on a seeded 6 percent roll; floating bait
  does not; both snag in the footprint band.
- Run intervals across 50 seeded fights all fall in 2 to 4 s and are not all
  equal.
- At run start the line ribbon's sag is under 0.05 m and its width doubled; a
  `line_sing` playback occurred; spray particles emitted; the `yank` overlay
  played.
- Finger tips outside the fish hull at `SHOWING`; palm within 3 cm.
- Away from camp with a smoked fish carried, `interact` on the grass band
  gathers and does not eat; at the crate it eats first.
- `GameState.journal` and `catch_log` exist; `inventory` has no `journal`,
  `catches`, `hooks_lost`, or `midday_checked` keys.
- The simulation passes its new bands with no policy snag constant, and its
  careful policy's per-spot take never exceeds 3 at one spot on one day.

## Renders and probes

Re-shoot at 1080p, guard on, art-director sentence for each:

- `milestone-9-trout-holding.png` from the Part 4 camera. Probe unchanged.
- `milestone-9-landed.png`. Probes: fish at least 15 percent, hand at most 12
  percent, hull test passed in the same pose.
- `milestone-9-run.png`: the frame at run start from the player camera, line
  taut, spray visible, arm yanked. **Probe:** the line's on-screen angle differs
  from the frame 0.2 s earlier by at least 10 degrees; spray particle count
  above 8.
- `milestone-9-camp-dusk.png` and `camp-rework-frying.png` re-shot with the
  Part 5 changes. Probes as before plus the shadow-length and circle probes.
- `milestone-9-pool-fished.png`: the pool at X = -14 at 19:00 on day 20 with
  no catches, and beside it `milestone-9-pool-fished-after.png` after three
  logged trout. **Probe:** at least two fewer fish bodies in the second frame.

**Sequences.** The catch sequence is re-recorded from two review cameras, per
the milestone 6 notes rule: the player's over-shoulder fishing camera, and a
side camera 2.5 m off his casting side at chest height, 50 mm equivalent, that
pans to keep the bait in frame. Twelve frames per second from cast to
`SHOWING`. **Probe:** in at least 12 frames of the side sequence the fish mesh
covers more than 0.1 percent of the frame, and the run frame shows the taut
line. Build the contact sheets from both. If the fish cannot be seen in the
sheets, the sequence is not done.

## Acceptance

- Suites 1 through 9, the milestone 6 notes suite, `milestone_9_models`,
  `fishing_tension` (amended), `camp_layout`, and `milestone_9_notes` pass.
  The simulation passes its new bands. Harness passes probes, guard, and
  budget.
- **Human review**, in this order: the side-camera catch contact sheet, the
  run frame, the landed close-up, the bank trout, the camp at dusk. Then a
  live session from `Play.cmd -- day=20 hour=18 hooks=6 bait.grasshopper=8
  firewood=10`: three trout from the same pool, watch it go quiet, one run
  held through to a break, a fry, a sleep, the morning ledger. The questions
  are whether the run can be read without the meter, and whether the emptied
  pool is noticed.
- README: the time-economy section, the depletion model with its reasoning in
  the fish map section, the omitted-tests admission and its closure, the
  simulation's new summary with the tuned snag value, and a sentence per
  re-shot render.
- Commit as `Complete milestone 9 fishing and camp`. Then begin
  `MILESTONE_10.md`.

## Standing rules to append to `ASTRA_BRIEF.md`

- **A band met by a policy constant has not been met.** When a simulation
  target is missed, tune the model the spec names, or stop and report. Do not
  add a parameter to the scripted policy that produces the number. Milestone 9
  met its hook-loss band with a 16 percent snag exposure that exists nowhere
  in the game.
- **List the tests you did not write.** When a milestone ships fewer assertions
  than its spec lists, the README names each omission and why. Silence reads
  as coverage. Milestone 9 shipped about two thirds of its listed assertions
  without a note.
