# Milestone 2 — The Panning Loop

Read `ASTRA_BRIEF.md` first. This document narrows milestone 2 to concrete work
against the code that already exists. Do not touch lighting, water, assets, or
animation. Do not start milestone 3.

## Goal

Add the hidden gold map, the pan action, a placeholder pan result with the
five-tier gradient, and the sack readout. When this is done, a player who pans
ten spots should be able to say where the gold is and why.

## Architecture rules

Keep the milestone 1 pattern: one script per responsibility, and every system
samples the same shared layout. Specifically:

- **Move `BOULDERS` out of `greybox.gd` into `claim_layout.gd`.** The gold map
  needs boulder positions, and the brief says the map and the scene must agree.
  One source of truth. `greybox.gd` reads the constant from the layout.
- **Add bedrock outcrops to the layout** as a second constant, `BEDROCK`, with
  two or three entries near the shore. Each is a low, dark, flat slab placed by
  `greybox.gd` (a scaled box, sunk into the gravel so a few centimeters show).
  They are the visual tell for the crevice pockets.
- New scripts, each small:
  - `scripts/gold_map.gd` — static density field. Pure functions, no nodes.
  - `scripts/panner.gd` — the pan action state machine on the walker.
  - `scripts/pan_result.gd` — turns a density value into a tier and an ounce amount.
  - `scripts/sack.gd` — accumulates ounces, exposes stages, emits a signal.
  - `scripts/hud.gd` — the one label.
- Comment the gold map logic. It is the core of the game.

## The gold map (`gold_map.gd`)

`static func density_at(x: float, z: float) -> float` returning 0.0 to 1.0.
Deterministic. No randomness in the map itself.

Downstream is +X. Inland is +Z. The shore is `Layout.shore_z(x)`. The bar is a
point bar on the inside of the bend, so the whole bar is the inside of the bend;
richness varies across it as follows.

Build the density as a lean base plus pockets:

**Base (most of the bar):** 0.03 to 0.15.
- Higher toward the water, falling off inland: full strength within 3 m of the shore, near zero beyond 12 m inland.
- Higher at the upstream end (negative X), lower downstream. Coarse gravel drops out first at the head of the bar.
- Fine sand is poor: anything more than 12 m inland is 0.0 to 0.03.

**Pockets (three to five, Gaussian bumps peaking 0.75 to 1.0):**
1. **Head of the bar.** One pocket at the upstream end, near the shore, around X = -28 to -22. This is the richest pocket.
2. **Boulder lees.** For each boulder in `Layout.BOULDERS` that sits within 6 m of the shore, a pocket centered 1.5 to 2.5 m **downstream** (+X) of the boulder, hugging the water side. The upstream face of the same boulder is slightly poorer than base.
3. **Bedrock crevices.** For each entry in `Layout.BEDROCK`, a tight pocket (radius about 1.5 m) at its downstream edge.

Combine with `max`, not sum, so overlapping pockets do not exceed 1.0. Clamp to 0..1.

Beyond the bar (in the river past wading depth, on the canyon slope) return 0.0.

Add `static func peak_points() -> Array[Vector2]` returning the pocket centers,
for tests and the debug view only.

## Where you can pan

The player may pan when all of the following hold:

- Water depth at the walker is between 0.0 and 0.45 m, **or** the walker is on dry gravel within 1.5 m of the waterline (`z - Layout.shore_z(x)` between -0.7 and 1.5).
- `absf(x) < 40`.
- Not already panning.

When the player is in a valid spot, nothing is shown yet except that the pan
input works. No prompt, no highlight. Later milestones may add a subtle cue.

## The pan action (`panner.gd`, attached to the walker or as a child node)

Input action `pan`: **E** key, **left mouse button** while captured, gamepad **A / cross**. Add it to `project.godot`.

State machine: `IDLE → PANNING → SHOWING → IDLE`.

- **PANNING:** lasts `PAN_DURATION` (constant, 6.0 s for now; milestone 6 tunes it to the animation). Movement input is ignored. The walker turns to face the water (toward `-Layout.inland_normal(x)`). The current still applies if he is in the water; he must not drift into deep water while panning, so if depth exceeds 0.45 during PANNING, cancel back to IDLE with no result.
- On entering PANNING, sample `GoldMap.density_at` at the walker position **once** and hold it. Compute the result with `PanResult.roll(density, rng)`.
- **SHOWING:** lasts 3.0 s. The camera dollies to the pan (see below). The pan mesh shows the result. Then the sack receives the ounces and the state returns to IDLE.
- Escape during SHOWING skips ahead to IDLE (still awards the gold).

Use a seeded `RandomNumberGenerator` on the panner, seeded from the walker's
spawn so runs are reproducible in tests, and re-seeded from time in normal play.

## Pan results (`pan_result.gd`)

Five tiers, as in the brief. `static func roll(density: float, rng: RandomNumberGenerator) -> Dictionary` returning `{ "tier": int, "ounces": float }`.

Roll a value `v = density + rng.randfn(0.0, 0.08)`, clamped to 0..1, then:

| Tier | Name | Condition on `v` | Ounces (uniform in range) |
|---|---|---|---|
| 0 | Nothing | v < 0.12 | 0 |
| 1 | A few specks | 0.12 to 0.30 | 0.002 to 0.006 |
| 2 | Color | 0.30 to 0.55 | 0.010 to 0.030 |
| 3 | A good showing | 0.55 to 1.0 | 0.050 to 0.150 |
| 4 | A nugget | tier 3 rolled **and** density > 0.75 **and** rng.randf() < 0.08 | 0.25 to 1.00, plus the tier 3 amount |

Nuggets are an event. Do not make them more common than this.

These amounts are placeholders for feel. Keep them in constants at the top of the file.

## Placeholder pan display

Build a placeholder now that the real pan and animation can replace in milestone 6
without changing the camera or result code.

- A flattened cylinder "pan" mesh (radius 0.22 m, height 0.04 m, dark grey, matte)
  as a child of the walker's `Visual`, held in front of the capsule at about
  0.9 m height, hidden when IDLE.
- Result flecks: a `MultiMeshInstance3D` of tiny spheres (radius 0.004 m) with a
  bright warm emissive material, scattered inside the pan according to tier:
  - Nothing: 0 flecks
  - Specks: 2 to 3, scattered
  - Color: 12 to 20, arranged along one arc of the pan's crease
  - Good showing: 40 to 60, a dense crescent along the crease
  - Nugget: the crescent plus one sphere of radius 0.012 m
- The crease is the low arc of the pan nearest the miner. Place flecks in a
  band along that arc, jittered.

## Camera during SHOWING

Add a `focus` mode to `orbit_camera.gd`: given a target transform, it eases the
rig to a point about 0.6 m from the pan, looking down at it at roughly 45
degrees, over 0.4 s, and eases back when focus is released. Mouse and stick
orbit are ignored while focused. Do not create a second camera.

## Sack (`sack.gd`) and HUD (`hud.gd`)

- `sack.gd` is an autoload named `Sack`. It holds `ounces: float`, has
  `add(amount: float)`, emits `changed(ounces)`, and exposes `stage() -> int`
  returning 0 to 4 at thresholds 0, 0.25, 1.0, 3.0, 8.0 ounces. The stage is for
  the belt sack model in milestone 6. Nothing uses it yet beyond tests.
- `hud.gd` is a `CanvasLayer` with a single `Label` in the lower right, small,
  reading `0.00 oz`, updated from the `Sack.changed` signal. Warm off-white text,
  no background, no panel. This is the only HUD element.

## Debug view (not for players)

A top-down density overlay toggled with **F3**, available only when
`OS.is_debug_build()` is true. Draw it as a grid of small quads over the bar,
colored from dark to warm gold by density, at 1 m resolution, hovering 0.05 m
above the gravel. Off by default. This exists so a human can confirm the map
matches the scene: boulder lees, bedrock edges, and the bar head should visibly
glow. Remove nothing from it in later milestones; it is a permanent tool.

## Tests — `tests/milestone_2.gd`

Same harness style as milestone 1. Include at least:

- Density is 0.0 off the bar, on the canyon slope, and in deep water.
- Density at each `peak_points()` entry is above 0.7.
- Density at the bar head pocket exceeds density at the mirrored downstream position by at least 0.3.
- For every near-shore boulder, density 2 m downstream exceeds density 2 m upstream by at least 0.3.
- Density 15 m inland at X = 0 is below 0.05.
- Pan input does nothing 8 m inland; pan input starts PANNING at the waterline.
- Movement input during PANNING does not move the walker more than 0.1 m.
- Entering deep water during PANNING cancels without adding to the sack.
- With a fixed seed, 20 pans at a peak yield at least 15 of tier 2 or higher, and 20 pans at a lean spot yield at least 15 of tier 0 or 1.
- Repeated pans at one spot vary by no more than one tier in at least 16 of 20 rolls.
- No nugget in 200 rolls at density 0.5. At least one nugget in 400 rolls at density 0.95.
- `Sack.ounces` equals the sum of awarded results after a sequence of pans, and `stage()` steps at the thresholds.
- Camera focus mode moves the camera within 1.0 m of the pan during SHOWING and returns within 5.0 m of its spring length afterward.

Extend `tests/capture_greybox.gd` to also save a frame during SHOWING with a
tier 3 result, and a frame of the F3 debug overlay from above, as
`artifacts/milestone-2-pan.png` and `artifacts/milestone-2-density.png`.

## Acceptance

- `tests/milestone_1.gd` still passes unchanged.
- `tests/milestone_2.gd` passes.
- Both new renders exist and the density render visibly shows glow at the bar head, behind the near-shore boulders, and at the bedrock edges.
- Update `README.md`: the pan control, what the readout is, and the F3 debug key.
- Commit as `Complete milestone 2 panning loop`.
