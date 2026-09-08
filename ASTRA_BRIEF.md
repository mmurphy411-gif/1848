# 1848 — Design Brief for Astra

Working title: **1848**
Engine: **Godot 4 (latest stable, GDScript, standard build)**
Assets: **Blender 4 → glTF (.glb)**
Version control: **git**, commit after every milestone

---

## One-line pitch

A man, a river, a pan, and nature. Summer 1848 on the North Yuba River, before the
world arrived. You prospect one gravel bar by panning, learning where the gold hides.
That is the whole game.

## What this is

A small, beautiful, third-person prospecting minigame. The purpose of this first build
is to find out whether standing in a pristine Sierra canyon with a gold pan is
compelling on its own. Visual quality is the first priority. Everything else serves it.

## What this is NOT (do not build these)

- No economy, no shop, no assay office, no prices
- No upgrades, no sluice, no rocker, no tools other than the pan
- No other characters, animals with AI, or dialogue
- No menus beyond a start screen and quit
- No inventory UI beyond the sack
- No quests, objectives, tutorial text, or map
- No save system

If a feature is not listed under **Mechanics** below, do not add it.

---

## Setting

**Place:** North Yuba River, upstream of where Downieville will later stand, Sierra
Nevada, California.

**Time:** Late June 1848. Snowmelt is dropping, the gravel bars are exposed, the days
are long. Gold was found at Sutter's Mill five months ago and word has barely reached
here. Nobody else is on this river.

**The claim:** One gravel bar on an inside bend of the river, roughly 80 by 40 meters,
hemmed in by:

- steep granite canyon walls on the far side and behind the bar
- deep fast water upstream and downstream
- the river itself along the long edge of the bar (wadeable to about knee depth, then deep)

The boundary is the landscape. There is no fence. See **Boundary** below.

## Art direction

Target feel: the wilderness scenes of *Red Dead Redemption 2*, achieved with simple
geometry and excellent light. Think of 19th-century landscape painting (Bierstadt,
the Hudson River School): grand light, atmosphere, scale, and clear water.

**Where the effort goes, in order:**

1. Sky, sun, and time-of-day lighting
2. Atmosphere: volumetric fog in the canyon, god rays through the trees, haze on distant walls
3. Water: clear, green-tinted, visible riverbed, foam at rocks, refraction, gentle sparkle
4. Rocks: a small set (5 to 8) of large granite boulders, instanced and rotated. Pale grey, rounded, water-polished near the river, lichen and sharper faces higher up
5. Trees: two or three conifer types (ponderosa pine, incense cedar, Douglas fir), instanced, plus a few black oaks at the bar edge. Simple silhouettes, good bark and needle textures, wind sway
6. Ground: gravel bar (rounded cobbles and sand), then grass and wildflowers at the edges, then duff under the trees
7. The miner himself (see **Character**)

**Explicit constraints for asset generation:**

- Prefer fewer, better assets, heavily instanced, over many mediocre ones
- Do not attempt photogrammetry-grade detail. Meshes stay simple; lighting and materials do the work
- Hide repetition with fog, scale variation, and rotation
- Everything must render at 60 fps on a mid-range gaming GPU at 1080p
- Use the built-in Godot sky, volumetric fog, SDFGI or VoxelGI, SSR, and SSAO. Do not write custom rendering pipelines

**Palette:** granite grey, river green, pine dark green, sand gold, sky blue, warm gold
light at dawn and dusk. The scene should look like a place you want to stay.

## Character

- Third-person camera, over the shoulder, slight distance, with a slow orbit on mouse or right stick
- A man in 1848 working clothes: wool trousers, suspenders, collarless linen shirt, battered felt hat, boots. Weathered but not a caricature
- **The panning animation is the most important asset in the game.** The player will watch it hundreds of times. Crouch at the water's edge, scoop gravel, submerge, swirl, tilt, wash the light material over the lip, repeat, then lift and look into the pan. It should take 8 to 12 seconds and look unhurried and real. Spend more time here than on the walk cycle
- Walk cycle can be simple. Wading through shallow water should slow him and produce splashes
- A leather or canvas sack hangs from his belt. It visibly grows as gold accumulates (see **Sack**)

## Mechanics

### Movement

- Walk, no run. Wade into shallow water. Cannot swim; deep water pushes him back (see **Boundary**)

### Panning

- Standing at the water's edge (within about 1.5 m of the river on the bar side), one input starts panning
- The panning animation plays. At the end, the camera moves closer to the pan and the result is shown for about 3 seconds before returning
- Panning at the same spot repeatedly gives similar results with small random variation

### The hidden gold map

This is the core of the game.

- A hidden 2D density field covers the gravel bar. It is never shown to the player
- It must follow **real placer geology**, so a thoughtful player can learn to read the river:
  - richest on the **inside of the bend**, where the current slows
  - rich in the **lee of large boulders** (downstream side)
  - rich where **bedrock is exposed** in crevices and cracks
  - rich at the **upstream head of the bar** where coarse gravel drops out
  - poor in fine sand, poor on the outside of the bend, poor far from the water
- Design 3 to 5 clearly rich pockets and a gradient between them. Most of the bar should be lean
- Place the boulders and bedrock in the scene so the visual tells are true. The map and the scene must agree

### Pan results

The pan must show a **readable gradient** so two pans can be compared at a glance:

| Result | What the player sees in the pan |
|---|---|
| Nothing | dark sand, no color |
| A few specks | two or three tiny bright flecks |
| Color | a clear thin line of flakes along the crease |
| A good showing | a bright crescent of flakes and small grains |
| A nugget | a distinct pea-sized nugget among flakes, rare |

Result is drawn from the density value at the pan location plus noise. Nuggets only
occur in the top density band and should be rare enough to feel like an event.

### Sack

- Gold from every pan is added to the sack. There is a small on-screen readout of the total in ounces (this is the only HUD element)
- The sack model on his belt scales up in a few visible steps as gold accumulates
- Nothing can be done with the gold. Finding it is the point

### Boundary

The claim boundary is the landscape, not a fence:

- Canyon walls: unclimbable slope
- Deep water: at wading depth beyond the knee, movement slows and the current pushes him gently back toward the bar. No death, no message
- Upstream and downstream: the bar narrows to nothing against the wall and the river
- If the player somehow reaches an edge, a soft push-back. Never an invisible wall he can walk into and stop dead

### Day cycle

- A full dawn-to-dusk cycle over roughly 20 real minutes, then a short night with stars and moonlight on the water, then dawn again
- Sun direction, color temperature, fog density, and sky all animate
- Golden hour should be spectacular. This is the moment that sells the game
- No gameplay depends on time of day in this build

### Sound (keep small)

- River: continuous, spatialized, louder near rapids
- Wind in pines
- Birds by day, crickets and an owl at night
- Gravel and water sounds for panning and wading
- No music

---

## Milestones — build in this order and commit after each

1. **Greybox.** Godot project. Blockout of canyon, bar, river volume, boulders. Capsule character with third-person camera and walk. Boundary push-back working. Commit.
2. **Panning loop.** Hidden density map. Pan input at the water's edge. Placeholder result display with the five-tier gradient. Sack total readout. Commit.
3. **Light and atmosphere.** Sky, sun, volumetric fog, SDFGI, SSAO. Static golden-hour lighting first. This milestone should already look good with grey boxes. Commit.
4. **Water.** River shader: clear, refracting, riverbed visible, foam at rocks, flow direction. Commit.
5. **Assets.** In Blender, build and export: boulder set, three conifers, oak, gravel, sand, and grass materials, canyon rock material. Replace greybox. Commit.
6. **Miner.** In Blender, build and rig the miner, the pan, and the sack. Walk cycle. Wade. **Panning animation, done well.** Commit.
7. **Day cycle.** Animate sun, sky, fog, and sound over the cycle. Night with stars. Commit.
8. **Polish pass.** Pan result visuals, sack growth, camera feel, wind sway, sound mix. Commit.

## Acceptance criteria

- Launch to playable in one click, no console errors
- 60 fps at 1080p on a mid-range GPU
- Standing on the bar at golden hour makes you want to take a screenshot
- A player who pans ten spots can tell you where the gold is and why
- The panning animation looks like a man who knows what he is doing
- He cannot leave, and it never feels like a wall

## Working rules for the AI

- Commit after every milestone with a short message. Never leave the repo in a broken state
- Keep scripts small and readable. One script per responsibility. Comment the gold map logic
- Do not add features not in this brief, even if they seem obvious
- If a milestone cannot be reached, stop and explain what blocked it instead of working around it with something out of scope
- When generating assets in Blender, export to `assets/` as `.glb` and keep the `.blend` source in `blender/`
- Each `MILESTONE_N.md` narrows this brief for one milestone. Where they conflict, the milestone file wins. Earlier test suites pass unchanged unless the milestone file names the exact assertion that may change
- When a spec is self-contradictory, pick the interpretation that honors its intent and write the reasoning in the README, as was done for the gold-map pocket count

## Standing rules learned from milestones 1 to 5

These come from review of what was shipped. They apply to every milestone from now on.

- **Look at every render before committing.** Tests and pixel probes are regression gates. They do not judge whether a picture is good. For each render you produce, open it and write one sentence in the README review section saying what a demanding art director would send back. If you cannot name anything, look again. Milestone 3 shipped an overview that was solid fog, milestone 4 shipped a hero shot that was 60 percent boulder, and milestone 5 shipped canyon walls that read as sand dunes. All three passed their tests.
- **Uniformity is the tell of procedural work.** Anything repeated must vary in size, spacing, and orientation. Same-size Voronoi cobbles read as a mosaic. Evenly spaced joint cracks read as a soccer ball. Regular ripple marks read as stripes. Mix three scales and break every regular pattern with a second noise.
- **Shape before surface.** A texture cannot fix a silhouette. If a wall looks like a dune, it needs rock geometry, not a better granite map.
- **Every player-camera render passes the composition guard** (nothing within 2 m of the camera along its forward ray). This is already in the harness. Keep it there.
- **Foliage cards are judged from underneath.** A card that reads at 20 m is not done until it reads at 2 m. Use leaf clusters, not single giant leaves, and alpha-to-coverage rather than hard scissor edges.
- **Repository hygiene.** Binary files over 1 MB go through git LFS. Textures are baked at the smallest resolution that holds up at the distance they are seen. Do not commit 87 MB of PNGs again.
- **Do not move a probe to make it pass** unless the spec change made the old location meaningless, and then say so in the README, as was done for the water transmission probe in milestone 5.

## Standing rules learned from milestone 6


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
