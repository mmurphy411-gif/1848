# Milestone 9 — Fishing, Camp, and the Sandbox

Read `PHASE2_BRIEF.md` first, then the standing rules in `ASTRA_BRIEF.md`. This
milestone starts phase 2 and closes the first loop: the day becomes the unit of
play, and a fish caught in the river is cooked at a fire and eaten. It adds the
game-state autoload and the calendar, the fish map, visible fish, bait
gathering, the hand-line fishing action, hook loss, the camp with sleep,
condition, cooking and smoking, the ledger, weather, the F4 sandbox panel,
command-line scenarios, and a headless season simulation.

Do not touch: `gold_map.gd`, `pan_result.gd`, `claim_layout.gd` values, the
boundary physics, the water shader. Do not build the store, tools, the falling
river, or any animal. Hooks run out in this milestone and cannot be bought; the
sandbox sets them. That is intended.

Three existing scripts may change, and only as stated: `panner.gd` gains a
playback speed scale and a post-roll tier demotion driven by condition;
`walker.gd` gains a wade speed scale driven by condition; `daylight.gd` gains
one `overcast` parameter driven by weather. Milestone 2, 6, and 7 suites must
pass unchanged, with condition at its default.

## Goal

A player at dusk can stand on the bar, see a trout holding in the eddy below a
boulder, gather a grasshopper from the grass, cast to the fish, watch it come,
strike, fight it in, and hold it up. Then walk to camp, light the fire with
driftwood, fry the trout, eat it, sleep, and next morning open the ledger and
read the date, the weather, and what he ate. When this is done, fishing should
feel like fishing, and a day should feel like a day.

## Architecture rules

Keep the one-script-per-responsibility pattern. New scripts:

- `scripts/game_state.gd` — **autoload `GameState`.** Owns `seed`, `day`,
  `dollars`, `condition`, `inventory`, and nothing else. `Sack` stays as it is;
  `GameState` does not duplicate ounces. Emits `changed`. Parses command-line
  scenarios.
- `scripts/calendar.gd` — pure static. Day number to date, month, weekday;
  season predicates such as `salmon_run(day)`.
- `scripts/weather.gd` — pure static. Day and seed to a weather state.
- `scripts/condition_model.gd` — pure static. Meal and skipped-meal arithmetic
  and the effect curves.
- `scripts/cooking.gd` — pure static. Recipes and their inputs, outputs, times.
- `scripts/fishery.gd` — pure static. Spots, species presence, bite rates,
  size rolls. **This is the fish map. Comment it the way the gold map is
  commented.**
- `scripts/fight_model.gd` — pure static. Stamina, pull, run, and break rules,
  shared by the action and the simulation.
- `scripts/fish_school.gd` — the visible fish. Reads the fishery for the current
  day and hour and drives fish nodes.
- `scripts/fish.gd` — one fish's behavior: hold, dart, flee, return.
- `scripts/bait_sources.gd` — where bait and firewood can be gathered and how
  much is left today.
- `scripts/fisher.gd` — the fishing action state machine on the walker, a
  sibling of `Panner`.
- `scripts/fishing_line.gd` — renders the line and bait.
- `scripts/camp.gd` — the camp scene: props, fire, interactions, sleep.
- `scripts/ledger.gd` — the ledger UI.
- `scripts/rain.gd` — rain particles and the overcast hand-off.
- `scripts/sandbox.gd` — the F4 panel, debug builds only.
- `tests/simulate_season.gd` — headless season simulation.

`Panner` and `Fisher` are mutually exclusive: neither may start while the other
is not `IDLE`. Put the check in each `can_*`. Camp interactions require both
idle.

## Part 1 — Game state and calendar

`GameState` fields: `seed: int` (default 1848), `day: int` (0 = June 26, 1848),
`dollars: float` (default 0), `condition: float` (default 85), `inventory:
Dictionary` with keys `hooks` (default 4), `line_m` (default 20.0), `bait`
(a Dictionary of bait type to count, all 0), `firewood` (0), `fish` (an Array
of Dictionaries: `species`, `weight_lb`, `day`, `state` of `fresh` or
`smoked`), `knife` (true), and `meals_today` (0).

**Day advance.** `day_clock.gd` gains a `day_ended` signal emitted once when
`elapsed` wraps past `CYCLE_SECONDS`, and an `end_day()` method that jumps
`elapsed` to the start of the next cycle and emits the same signal once.
`start(hour)` does not emit it. `GameState` connects to it, increments `day`,
applies the sleep condition check (Part 8), spoils old fish, and resets daily
budgets. Nothing else in the clock changes; the milestone 7 suite must still
pass.

**Command-line scenarios.** At startup `GameState` reads
`OS.get_cmdline_user_args()` and applies `key=value` pairs: `seed`, `day`,
`hour`, `dollars`, `condition`, `hooks`, `line`, `firewood`, `bait.<type>`,
`fish.fresh`, `fish.smoked`, and `weather` (an override). `hour` is applied by
calling `Daylight/Clock.start(hour)` after the claim starts play; the clock is
already started in `claim.gd`, so `claim.gd` asks `GameState` for a start hour
and passes it. `Play.cmd` forwards `%*` after `--`.

`calendar.gd`: `date_string(day)` gives `"June 26, 1848"`; `month(day)`,
`day_of_month(day)`; `salmon_run(day)` is true from September 15 (day 81) to
October 31 (day 127), with `salmon_intensity(day)` peaking at 1.0 on October 3
and falling to 0.15 at either end.

## Part 2 — The fish map (`fishery.gd`)

Downstream is +X, inland is +Z, the shore is `Layout.shore_z(x)`. Water depth
follows `Layout.height_at`: about 0.78 m at 5 m out, deepening to 4.78 m by
roughly 14.5 m out. Wading stops at 0.45 m, about 3 m out. The hand line casts
8 m, so a knee-deep miner reaches 11 m from shore.

**Spots.** `static func spots() -> Array[Dictionary]`, each with `position:
Vector2` (X, Z), `type`, `depth`. Derive them from the layout, do not type
coordinates:

- **Boulder pools.** For each boulder in `Layout.BOULDERS` whose center is within
  6 m of the shore, one `pool` spot 1.5 boulder radii downstream (+X) of the
  center and 5 to 7 m riverward of `shore_z`, in water 0.8 to 1.6 m deep. These
  are trout water.
- **Bedrock seams.** For each `Layout.BEDROCK` slab, one `seam` spot at the
  slab's downstream edge, 2.5 m riverward of the slab center, 0.65 to 0.9 m
  deep. Trout at dawn and dusk, hellgrammite bait.
- **Head riffle.** One `riffle` spot at X = -36, 6 to 8 m riverward, where the
  bar narrows and the channel quickens. Salmon in season; trout on the seam
  otherwise.
- **The run.** Two `run` spots along the deep channel at X = -10 and X = 12,
  11 to 13 m out, 3 to 4.2 m deep. Pikeminnow and hardhead by day, suckers on
  the bottom any time.
- **The tail-out.** One `flat` spot at X = 30, 5 m out, slow and shallow.
  Suckers.

Every spot must be in water at least 0.6 m deep and none inland. Add
`static func spot_at(x, z, radius := 2.5)` returning the nearest spot within
`radius` or an empty Dictionary.

**Species.**

| Species | Weight (lb) | Water | Hours | Bait |
|---|---|---|---|---|
| `trout` | 0.3 to 1.8, rare to 3 | pool, seam, riffle | peak 05 to 08 and 17 to 21, low midday | grasshopper 1.0, hellgrammite 0.9, worm 0.6, pork 0.2 |
| `sucker` | 1 to 3 | run, flat, pool bottom | flat all day | worm 1.0, pork 0.8, others 0.2 |
| `pikeminnow` | 1 to 4 | run | midday peak 10 to 16 | pork 1.0, hellgrammite 0.7, grasshopper 0.5 |
| `hardhead` | 1 to 3 | run | midday | hellgrammite 0.8, worm 0.6 |
| `salmon` | 10 to 20 | riffle | dawn, in season only | none: not catchable on a line |

**Presence.** `static func presence(species, spot, day, hour, seed) -> float`
gives the expected count of that species at that spot right now. It is the
product of a base count for the water type, an hour curve, a season factor
(trout hold deeper and bite less in the hot late-July water; salmon follow
`salmon_intensity`), a weather factor (Part 9), and a small deterministic
per-day variation hashed from `seed` and `day` so a given date always looks the
same. No `RandomNumberGenerator` in the map.

**Bite rate.** `static func bite_rate(species, spot, day, hour, bait, seed) ->
float` in bites per second: presence times the bait preference times 0.04. At
the best pool at dusk with a grasshopper on a clear day the mean time to a
trout bite must fall between 15 and 40 s. At midday in the run with pork a
pikeminnow should take 40 to 90 s. Poor water and wrong bait land above 120 s.

**Size.** `static func roll_weight(species, rng) -> float` from the table, with
the rare large trout at 3 percent.

`static func expected_population(day, hour, seed) -> Array[Dictionary]` returns
the fish that should be visible right now: for each spot and species, a count
rounded from presence, capped so the total never exceeds 24. This is what the
scene shows.

## Part 3 — Visible fish

**Meshes** (`blender/build_fish.py`): five species, 300 to 600 triangles each,
one 1024 atlas, exported to `assets/fish/fish.glb`. Trout with parr-like spots
and a pink lateral band; sucker grey-brown with an underslung mouth; pikeminnow
long, olive, forked tail; hardhead bronze; salmon deep-bodied, dark back, olive
and red flanks of a fall fish in the river. Sizes scale with weight. Body sway is
a **vertex shader**, a sine along the body length, amplitude rising toward the
tail, speed set per fish; no bones.

**Behavior** (`fish.gd`). Each fish holds facing upstream (-X) at its spot with a
gentle sway, drifts within a 1.5 m radius, and every 6 to 15 s darts 1 to 2 m
and returns. Depth in the water: trout hold 0.3 to 0.6 m under the surface in
pools, suckers on the bed, pikeminnow mid-water, salmon near the bed of the
riffle. **Flee:** when the miner is within 4 m in water, or within 2.5 m on the
shore, or when a pan starts within 6 m, the fish darts riverward out of its spot
and is hidden after 1.5 s, then returns 20 to 40 s later. Fish never leave the
water and never cross the bed.

**Salmon** appear only when `Calendar.salmon_run(day)` is true, 6 to 14 fish in
the riffle by intensity. They hold, then surge 2 to 3 m upstream and drop back.
They are not catchable in this milestone; a cast landing among them gets no
bite. They are here so the sandbox can show the run arriving.

`fish_school.gd` rebuilds the population when the day changes or when the hour
crosses a whole-hour boundary, fading fish in and out over 2 s rather than
popping. Fish are ordinary `MeshInstance3D` nodes; 24 is few enough that a
`MultiMesh` is not needed.

## Part 4 — Bait and firewood

`bait_sources.gd` defines three gatherable baits and driftwood, each with a
daily budget reset on `day_ended`:

| Item | Where | When | Per day |
|---|---|---|---|
| `grasshopper` | the grass and wildflower band where `vegetation.gd` places grass | 09:00 to 18:00, not in rain | 6 across the bar |
| `hellgrammite` | wet rocks within 1 m of the shore, within 3 m of a boulder or bedrock slab | any hour | 4 |
| `worm` | duff under the oaks at the bar edge | before 09:00 or after 18:00 | 4 |
| `firewood` | the high-water line, 3 to 6 m inland of the shore, anywhere on the bar | any hour | 10 |

Standing on eligible ground with budget left, the `interact` input plays a 2 s
`gather` clip and adds one item with a 70 percent success chance for bait and
100 percent for firewood. Show what was gathered for 1.5 s in the HUD line. No
markers on the ground; the player learns where bait and driftwood lie the way
they learned where gold lies.

## Part 5 — The fishing action (`fisher.gd`)

**Inputs.** Add `fish` (F, gamepad Y) and `interact` (G, gamepad X). While
fishing, `pan` is ignored. `ui_cancel` leaves the stance.

**Eligibility.** `can_fish()` uses the same band as `Panner.can_pan()`: on the
shore within 1.5 m of the water or in the shallows to 0.45 m, inside the bar,
`Panner.state == IDLE`, `hooks > 0`, `line_m >= 6`, and at least one bait. With
zero hooks the HUD line reads `No hooks` for 1.5 s and nothing happens.

**States.** `IDLE, STANCE, CAST, DRIFT, BITE, FIGHT, LAND, SHOWING, SNAGGED`.

- `STANCE`: `fish` pressed. He turns to face the water in 0.3 s (reuse
  `turn_to`), plays `fish_idle`. A cast ring appears on the water where the
  camera's forward ray meets the surface, clamped to 8 m from him. Scroll or
  `interact` cycles the bait type among those in inventory; the HUD line shows
  bait type, bait count, and hooks.
- `CAST`: `fish` pressed in stance. `cast` clip, 1.2 s. The bait lands at the
  ring. One bait leaves inventory. Landing within 1.0 m of a boulder footprint
  or a bedrock slab has a 25 percent chance of `SNAGGED`.
- `DRIFT`: `fish_wait` loop. Grasshoppers float and drift downstream at 0.6 of
  the local current speed from the water surface's vertex data, stopping when
  the line is taut at 8 m. Hellgrammites, worms, and pork sink to 60 percent of
  depth and drift at 0.25. The bite clock samples `Fishery.bite_rate` at the
  bait's current position each second and rolls a seeded exponential wait
  (`Fisher.reproducible`, seeded like `Panner`). Two seconds before the bite the
  nearest visible fish of that species leaves its hold and swims to the bait,
  so the player sees it coming. Recasting is allowed with `fish` during drift;
  the bait is kept.
- `BITE`: the line jerks (a 15 cm twitch on the bait, a `line_twitch` sound
  through `ActionAudio`), the fish is visible at the bait. **Strike window:**
  `fish` pressed between 0.15 and 0.75 s after the jerk hooks it. Earlier
  spooks the fish, which flees; the bait is kept. Later than 0.75 s and the
  bait is stolen: bait lost, fish flees, back to `DRIFT` with no bait, which
  returns to `STANCE`.
- `FIGHT`: `fight` loop, driven by `fight_model.gd`. The fish has stamina
  `S = 4 + 3 * weight_lb` seconds. Holding `fish` pulls: distance to the miner
  closes at 1.2 m/s and stamina drops at 1 per second. Releasing lets the fish
  recover 0.4 per second and regain 0.5 m/s. Every 2 to 4 s the fish **runs**
  for 0.8 s, visible as a dart: if `fish` is held during a run, tension
  exceeds the line and the line breaks. A break loses the hook, 2 m of line,
  and the fish. Fights should land in 3 to 8 s for trout, up to 15 s for a
  4 lb pikeminnow.
- `LAND`: the fish is within 1 m and stamina is 0. `land` clip 2.0 s, the fish
  in his hand.
- `SHOWING`: camera focuses on the fish for 2.5 s using
  `CameraRig.focus(transform)` and `release_focus()`, as the panner does. The
  fish is appended to `GameState.inventory.fish` as `fresh`. `ui_cancel` ends
  it early. Back to `STANCE` with the same hook.
- `SNAGGED`: the line stops. Holding `fish` for 1.5 s tries to free it: 50
  percent recovers the hook, otherwise the hook and 2 m of line are lost. Back
  to `STANCE`.

Movement is held from `CAST` through `SHOWING`, and current still applies as it
does for panning. Entering water deeper than 0.45 m cancels back to `STANCE`
with the bait kept.

**The line** (`fishing_line.gd`): an `ImmediateMesh` ribbon from the hand-line
winder to the bait, sagging as a simple catenary with 12 segments, drawn after
water so it is visible through the surface where it enters. The bait is a small
mesh from the fish glb (a hook with a grasshopper, a sunk hook). Floating bait
bobs with the water shader's displacement amplitude.

## Part 6 — Miner clips and props

`blender/build_miner_animation.py` gains:

| Clip | Length | Loop | Notes |
|---|---|---|---|
| `fish_idle` | 3 s | yes | Standing, weight back, line coiled in the left hand |
| `cast` | 1.2 s | no | Underhand swing of the hand line, release, watch |
| `fish_wait` | 4 s | yes | Line held between thumb and finger, small adjustments, a look upstream |
| `strike` | 0.4 s | no | Sharp lift of the arm |
| `fight` | 1.0 s | yes | Hand over hand, leaning back; playback speed follows pull |
| `land` | 2.0 s | no | Lift the fish by the line, take it in the right hand, look |
| `gather` | 2.0 s | no | Crouch, reach, stand. Used for bait and firewood |
| `tend_fire` | 2.0 s | no | Kneel, lay wood, blow, sit back |
| `eat` | 3.0 s | no | Seated, skillet on the knee, two bites, look at the river |
| `lie_down` | 2.0 s | no | Sit on the bedroll, lie back |

`miner_visual.gd` adds them to `CLIPS` and the state machine gains a fishing
sub-state machine and a camp sub-state machine beside the pan sequence.
`assets/miner/handline.glb`: a wooden hand-line winder, under 400 triangles,
attached to the left hand through the existing attachment pattern, shown only in
fishing states.

## Part 7 — Camp

**Placement.** Camp is anchored to the black oak nearest X = 0 whose trunk
stands at least 10 m inland of `shore_z`. `camp.gd` reads the trunk from
`vegetation.gd`'s placements at ready and lays the camp on a 5 m circle 3 m
riverward of the trunk: the fire ring at the center, the lean-to and bedroll
inland of it with its open side to the river, the drying rack beside the fire
on the downstream side, a small crate holding the ledger by the bedroll, and
the cache bag hung by a rope from the oak's lowest limb at 2.5 m. All props are
`StaticBody3D` on the terrain layer with convex collision. Camp ground gets the
duff material within the circle.

**Props** (`blender/build_camp.py`, exported to `assets/camp/camp.glb`, under
6,000 triangles total, one 2048 atlas): a lean-to of three cut poles and a
canvas sheet; a wool bedroll; a ring of river cobbles from the existing boulder
material family; a cast-iron skillet and a small pot on an iron tripod; a
drying rack of forked sticks and a crossbar; a canvas cache bag with a rope; a
wooden crate; a small stack of driftwood that grows with `firewood` in three
steps.

**Fire.** Lighting the fire needs 3 firewood and `interact` at the ring, 2 s
`tend_fire`. It burns for 2 game hours, then drops to embers for 1 game hour,
then goes out. Flame and smoke are `GPUParticles3D`; an `OmniLight3D` at 2200 K
flickers with a smoothed noise, range 9 m, casting shadows. Smoke leans with the
existing wind direction. From across the bar at night the fire must read as a
point of warmth; from 2 m the flame must not look like a sprite sheet. Sound: a
fire loop through the soundscape, spatialized at the ring.

**Interactions** (`interact` while idle, within 1.5 m, facing the prop; the HUD
line names the action when eligible):

- **Fire ring:** light the fire, or add wood while burning to extend by 1 game
  hour per piece, up to 4 hours.
- **Skillet at a burning fire:** cook (Part 8). A short menu of what can be
  cooked from inventory appears as the HUD line cycling with `interact`;
  `fish` confirms. No new UI panel.
- **Drying rack while the fire burns:** hang a fresh fish to smoke (Part 8).
- **Cache bag:** move all fresh and smoked fish into the cache, or take them
  out. In this milestone the cache changes nothing about spoilage; it exists
  so the bear milestone has a reason for it and the ledger can count what is
  hung.
- **Bedroll:** sleep. Allowed at any hour. `lie_down`, a 1.5 s fade to black,
  `Clock.end_day()`, the day-end bookkeeping, a 1.5 s fade in at dawn standing
  by the bedroll. Sleeping at noon is allowed; it wastes the day, which is a
  real choice.
- **Crate:** open the ledger (Part 10).

## Part 8 — Condition, food, and cooking

`GameState.condition` runs 0 to 100, starts at 85, never drops below 5. Meals
are the only input in this milestone.

- **Eating** a meal adds 20, capped at 100, and increments `meals_today`.
- **Checks.** At 13:00 and at sleep, if `meals_today` is below 1 and then
  below 2 respectively, condition loses 15. Two meals a day holds steady. At
  `day_ended`, `meals_today` resets.
- **Effects** (`condition_model.gd`, curves smooth between the bands):

| Condition | Pan playback speed | Wade speed | Tier demotion |
|---|---|---|---|
| 70 to 100 | 1.0 | 1.05 m/s | none |
| 40 to 70 | 1.0 down to 0.77 (the sequence up to 1.3 times longer) | 1.05 down to 0.8 m/s | none |
| below 40 | 0.77 | 0.8 m/s | 25 percent of pans drop one tier as flakes wash over the lip; tier 0 stays 0 |

`panner.gd` reads a `speed_scale` from `condition_model.gd` at pan start and
applies it to the animation and the segment timers; `PAN_DURATION` stays the
nominal constant and the milestone 2 timing test runs at default condition.
The demotion is applied to the rolled result before display and before the
sack, seeded from the panner's rng. `walker.gd` scales `WADE_SPEED` by the
condition curve.

**Food** (`cooking.gd`). Fish are the only food in this milestone; flour, beans,
and pork arrive with the store.

| Recipe | Needs | Time | Gives |
|---|---|---|---|
| Fried fish | 1 fresh fish, a burning fire | 20 game minutes, `eat` plays at the end | 1 meal; a fish of 2 lb or more gives 2 meals, the second stored as `fresh` cooked and eaten with `interact` any time that day |
| Smoked fish | 1 fresh fish on the rack, the fire burning for the whole time | 4 game hours | 1 `smoked` fish, keeps all season, worth 15 condition when eaten cold, no fire needed |

Cooking holds the miner at the fire; the clock runs. If the fire goes out while
a fish is on the rack, smoking pauses and resumes when it is relit; if it is
not finished by `day_ended` the fish spoils.

**Spoilage.** At `day_ended`, any `fresh` fish caught before the ending day is
removed and the ledger records it. A fish caught today is good tomorrow and
gone the morning after.

## Part 9 — Weather

`weather.gd`: `static func state(day, seed) -> String` in `clear`, `hot`,
`rain`, `frost`, deterministic from a hash of `seed` and `day`, and
`rain_intensity(day, seed)` in 0.3 to 1.0 on rain days. Monthly odds:

| Month | clear | hot | rain | frost |
|---|---|---|---|---|
| July | 0.65 | 0.33 | 0.02 | 0 |
| August | 0.60 | 0.35 | 0.05 | 0 |
| September | 0.80 | 0.08 | 0.12 | 0 |
| October 1 to 15 | 0.72 | 0 | 0.28 | 0 |
| October 16 to 31 | 0.60 | 0 | 0.25 | 0.15 |
| November | 0.45 | 0 | 0.15 | 0.40 |

Weather changes only at `day_ended`. A command-line or sandbox `weather`
override wins over the model.

**Effects in this milestone:**

- **Rain.** Bite rates times 1.5. No grasshoppers. `rain.gd` runs a
  `GPUParticles3D` volume following the camera, streaks that die at the water
  and at the ground, count scaled by intensity, a rain loop in the soundscape,
  and sets `Daylight.overcast` to intensity. In `daylight.gd`, `overcast` at 1.0
  halves sun energy, raises ambient sky contribution, doubles volumetric
  density, and sets turbidity to 6, all blended over 30 s of real time. At 0 the
  look is exactly the current one; the milestone 3 and 7 probes must still pass
  with `overcast` at 0.
- **Hot.** Trout presence times 0.6 between 11:00 and 16:00. Turbidity 5 for
  haze through the same parameter at 0.35. Nothing else; heat is mostly an
  excuse to fish at dusk.
- **Frost.** Before 09:00 the river mist fog volume density triples and fades
  back by 10:00. Fish presence times 0.7 all day. The ledger notes it. Frost is
  the countdown the player should learn to read.

## Part 10 — The ledger

`ledger.gd`, a `CanvasLayer` opened from the crate and closed with `ui_cancel`
or `interact`. A two-page book filling about 60 percent of the screen height,
a paper texture baked in Blender, and a period script font with a permissive
license recorded in the README. Text is written, not laid out as a table: the
left page is today, the right page is the season.

Left page: the date, the weather in a word, condition in words only (`Fit` at
70 and above, `Tired` from 40 to 70, `Weak` below), meals eaten today, fish
caught today by species and weight, hooks and line remaining, bait on hand, and
events since the last page such as `Rain. River up.`, `A trout spoiled.`, `Line
broke at the pool.`

Right page: day count and the date the season started, fish taken by species,
smoked fish in store, gold in the sack in ounces, dollars (0 for now), and the
number of hooks lost. No prices yet; that column is drawn but blank, the way a
ledger has ruled lines waiting.

The ledger releases the mouse while open and recaptures on close. The clock
keeps running while it is open.

## Part 11 — The sandbox

`scripts/sandbox.gd`, a `CanvasLayer` added to `claim.tscn` as `Sandbox`,
active only when `OS.is_debug_build()`, toggled by a new `debug_sandbox` action
on F4. A single panel, right side, plain theme: `SpinBox` or `LineEdit` for
seed, day (date shown beside it), hour, dollars, gold ounces, condition, hooks,
line, firewood, each bait count, fresh fish, smoked fish; an `OptionButton` for
weather (`auto`, `clear`, `hot`, `rain`, `frost`); a fire toggle; buttons
**Apply**, **Dawn**, **Dusk**, **Next day**, **Sleep**, **Refresh fish**. Apply
writes `GameState`, `Sack.ounces`, and calls `Clock.start(hour)`; fish, weather,
and daily budgets rebuild. The panel releases the mouse while open and
recaptures on close. It must not steal WASD or the `fish` key when closed.

## Part 12 — Headless simulation (`tests/simulate_season.gd`)

Runs without a scene against `Fishery`, `Calendar`, `Weather`,
`ConditionModel`, `Cooking`, and `FightModel`. Two policies over 130 days:

- **Careful:** gather firewood and bait in the morning, fish the best spot with
  the best bait at 06:00 and 19:00 for 60 game minutes each, strike inside the
  window, release on every run, fry one fish per session, smoke the surplus,
  eat smoked fish when the river gives nothing, sleep at 21:00.
- **Careless:** pan all day, never fish, sleep at dusk.

Writes `artifacts/season-careful.csv` and `artifacts/season-careless.csv` with
`day, date, weather, hour, spot, species, weight, hooks_lost, meals, condition`.
Prints per-policy summaries: fish per day by species, hooks lost per week,
smoked stock on November 1, condition trajectory, first and last salmon
sighting. Asserts:

- Salmon presence is zero outside days 81 to 127 and peaks within 3 days of
  October 3.
- Dusk trout catch rate is at least 1.5 times the midday rate at the same pool
  on clear days.
- Mean time to bite at the best pool at dusk with grasshopper on a clear day is
  15 to 40 s; on rain days it is at least 1.4 times faster.
- The careful policy holds condition at 60 or above on at least 90 percent of
  days and loses between 8 and 20 hooks over the season. If hook loss is
  outside that band, tune the snag and break parameters and record the values.
- The careless policy reaches the floor of 5 within 7 days and stays there.
- Rain days in August across 50 seeds fall between 3 and 8 percent.
- Identical results for two runs with the same seed; different for seed + 1.

## Performance

p95 under 5.5 ms at 1080p on the 5080 with 24 fish, the line, the fire lit and
shadow-casting at night, rain at full intensity, and the sandbox closed. If it
does not fit, drop the fire shadow first, then rain count, then the fish cap to
16, then fish texture to 512.

## Tests — `tests/milestone_9.gd`

- Suites 1 through 8 pass unchanged at default condition and `overcast` 0.
- `GameState` autoload exists with the default fields; `Sack` is untouched.
- `day_ended` fires exactly once per `CYCLE_SECONDS` of `advance` and exactly
  once per `end_day()`; `GameState.day` increments; `start(hour)` does not fire
  it; after `end_day()` the hour is within 0.05 of `DAWN`.
- `Calendar.date_string(0)` is `June 26, 1848`; `date_string(132)` is
  `November 5, 1848`; `salmon_run` is false on day 80, true on 81 and 127, false
  on 128.
- Command-line parsing: a `Dictionary` of args produces the expected state,
  including `weather` and `fish.smoked` (test the parser directly).
- Every spot is in water at least 0.6 m deep, none inland, at least four pools,
  one riffle, two runs, one flat, two seams.
- `presence` and `bite_rate` are identical across two calls with the same
  arguments, and differ for a different seed on at least half the spots.
- Trout presence at the best pool at 19:00 is at least twice that at 13:00 on
  a clear day; times 1.5 in rain; times 0.6 at 13:00 on a hot day.
- Mean of 200 seeded exponential waits from the best pool at dusk with
  grasshopper falls in 15 to 40 s.
- `expected_population` totals never exceed 24 across all hours of days 0, 60,
  95, and 130; salmon count is 0 on day 60 and at least 6 on day 95 at 06:00.
- Visible fish count in the scene matches `expected_population` within 2 after
  the fade; fish Y is below the water surface and above the bed at their
  position.
- Walk the miner to within 2 m of a pool fish on the shore: it flees and is
  hidden within 2 s; it returns within 45 s.
- Bait: `interact` on the grass band at 12:00 adds a grasshopper on a seeded
  success; at 20:00 it does not; in rain it does not; the daily budget stops at
  6; `day_ended` resets it. Firewood at the high-water line always succeeds and
  stops at 10.
- `can_fish` false with zero hooks, false when `Panner` is not idle, false
  inland of the band; `can_pan` false while `Fisher` is not idle; no camp
  interaction fires while either is busy.
- Stance turns to face the water in 0.2 to 0.5 s; the cast ring never exceeds
  8 m from the miner and is always on water.
- Cast removes one bait; a seeded snag on a boulder-adjacent cast enters
  `SNAGGED`; the failed-free branch decrements hooks and line.
- Seeded bite: strike at 0.05 s spooks (bait kept, fish flees); strike at 0.4 s
  hooks; no strike by 0.9 s loses the bait.
- Fight: holding through a run breaks the line, loses a hook and 2 m; releasing
  on runs and pulling otherwise lands a 1 lb trout in 3 to 8 s; `SHOWING`
  camera focus within 1 m of the fish; inventory gains one `fresh` entry with
  species, weight, and day.
- Camp: props exist under an oak at least 10 m inland; the fire ring, bedroll,
  rack, cache, and crate are within 5 m of each other; nothing overlaps a
  boulder or stands in water.
- Fire: `interact` with 2 firewood does nothing and the HUD says so; with 3 it
  lights, firewood drops by 3, the light is on, particles emit; after 2 game
  hours it is embers, after 3 out; adding wood extends it.
- Cooking: frying with no fresh fish is not offered; frying one 1 lb trout
  removes it, plays `eat`, adds 20 condition capped at 100, increments
  `meals_today`; a 2.5 lb fish leaves one cooked portion.
- Smoking: a fish on the rack with the fire burning becomes `smoked` after 4
  game hours; with the fire out it does not progress; eating a smoked fish
  adds 15 and needs no fire.
- Condition: default 85; sleeping with `meals_today` 0 loses 30 in total (one
  check at 13:00 already applied plus the sleep check) and the ledger records
  it; two meals hold it; the floor is 5.
- Effects: at condition 85 pan `speed_scale` is 1.0 and wade speed 1.05; at 40
  they are 0.77 and 0.8; at 30, over 400 seeded pans on tier 3 ground, between
  18 and 32 percent are displayed and banked as tier 2; at 85 none are.
- Spoilage: a fish caught on day N is present after the first `end_day()` and
  gone after the second; the ledger lists it.
- Sleep: `interact` at the bedroll fades, ends the day, and leaves the miner
  standing within 1.5 m of the bedroll at dawn.
- Weather: `state` deterministic; over days 36 to 66 across 50 seeds the rain
  fraction is 3 to 8 percent; frost never before October 16; on a rain day
  `overcast` reaches the intensity within 35 s and returns to 0 within 35 s of
  a clear day; rain particles emit only in rain; frost triples the mist density
  at 07:00 and restores it by 10:00.
- Ledger: opens from the crate, closes on `ui_cancel`, releases and recaptures
  the mouse; its text contains today's date string and weather word; the clock
  advances while it is open.
- HUD shows bait and hooks only in fishing states and action names only when an
  interaction is eligible; idle on the bar, the sack total is the only label.
- Sandbox: F4 toggles in a debug build; applying day 95, hour 6 rebuilds the
  fish with salmon present; applying `rain` starts the rain; **Sleep** ends the
  day; WASD does nothing while it is open and works after it closes.
- `simulate_season.gd` passes its own assertions and writes both CSVs.
- The composition guard passes on every render.

## Renders and probes

All 1080p, guard on, art-director sentence for each in the README.

- `milestone-9-trout-holding.png`: from the bank at 18:30, day 20, clear,
  looking down into the pool below the boulder at X = -14. Two or more trout
  visible through the water. **Probe:** subject coverage for the fish of at
  least 0.8 percent of the frame and no single surface over 70 percent. This is
  the render that decides whether visible fish work.
- `milestone-9-cast.png`: side view mid-cast, line in the air.
- `milestone-9-wait.png`: over the shoulder, line on the water, a fish
  approaching the bait.
- `milestone-9-fight.png`: fish running, line taut, spray.
- `milestone-9-landed.png`: the `SHOWING` close-up of a trout. **Probe:** the fish
  covers at least 15 percent of the frame; no other surface dominates.
- `milestone-9-salmon-riffle.png`: day 100, 06:30, the head riffle from the bar
  with salmon holding. **Probe:** at least six fish bodies in frame.
- `milestone-9-camp-dusk.png`: 20:15, fire lit, the miner seated eating, the
  lean-to and oak behind. **Probe:** ground luminance within 2 m of the ring is
  at least 1.6 times that at 8 m on the shadow side, and the flame region has
  no single-color pixel run wider than 6 pixels (it should not read as a flat
  card).
- `milestone-9-camp-night.png`: 23:00 from the shore 40 m downstream; the fire
  is the warmest point in the frame. **Probe:** the brightest warm cluster lies
  within 20 pixels of the ring's projected position.
- `milestone-9-rain-pool.png`: day 100, 17:00, rain at 0.8, the pool at X = -14.
  **Probe:** sun energy at most 55 percent of the clear value; rain particles
  alive; the water still reads as water (transmission probe from milestone 5
  still passes with the lower light).
- `milestone-9-ledger.png`: the ledger open on day 40 after a catch and a rain
  day, both pages legible at 1080p.
- `milestone-9-sandbox.png`: the F4 panel open over the scene.

Record a 10-second image sequence at 12 fps of one full catch from bite to
`SHOWING` into `artifacts/catch-sequence/`, and a 12-second sequence of
lighting the fire and eating into `artifacts/camp-sequence/`. Do not commit
them.

## Acceptance

- All nine suites pass; harness passes probes, guard, and budget.
- `Play.cmd -- day=95 hour=6` opens on a riffle full of salmon; `Play.cmd --
  hooks=0` refuses to fish and says why; `Play.cmd -- day=120 weather=frost
  hour=7` opens in heavy mist with a frost line in the ledger.
- **Human review**, in this order: the trout-holding render from the bank, the
  catch flip sequence, the camp at dusk, the ledger, then a live session at
  dusk with the sandbox at day 20 that runs through a catch, a fry, a sleep,
  and the next morning's ledger. The questions for the live session are
  whether the wait feels like fishing or like a loading bar, and whether the
  camp feels like a place he lives. Expect notes on how visible the fish's
  approach is, on the strike window, and on the fire.
- README updated: the fish map with its geology-style reasoning, the species
  table, the action state machine, the camp layout rule, the condition and
  cooking arithmetic, the weather table, the ledger, the sandbox and
  command-line usage, the simulation summaries with the tuned hook-loss values,
  and the art-director sentence for every render.
- Commit as `Complete milestone 9 fishing and camp`.
