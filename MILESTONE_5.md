# Milestone 5 — Assets

Read `ASTRA_BRIEF.md` first. This is the first Blender milestone. The greybox
becomes granite, gravel, pines, and oaks. The light and water from milestones 3
and 4 stay exactly as they are; the assets have to look good under them, not
the other way round.

Do not touch: the miner, pan, and sack models (milestone 6), the day-cycle clock
(milestone 7), sound (milestone 8). Do not change `claim_layout.gd` positions,
`gold_map.gd`, or any boundary or physics behavior. All four existing test suites
must pass unchanged.

## How Blender work is done in this project

**Every asset is produced by a Blender Python script committed in `blender/`,
runnable headless:**

```
blender --background --python blender/build_boulders.py
```

Each script builds its geometry procedurally (primitives, subdivision,
displacement modifiers driven by noise textures, particle or geometry-node
scatter for foliage), assigns materials, bakes what needs baking, and exports
`.glb` and `.png` files into `assets/`. Save the `.blend` beside the script for
inspection, but the script is the source of truth. No hand-sculpting in the GUI.
A human must be able to re-run the script and get the same file, and read the
script to see what was done. Add `blender/README.md` listing each script, what it
produces, and how long it takes.

Blender 5.2 is installed on this machine. Use its bundled Python. Export with the
built-in glTF exporter: `+Y up`, apply modifiers, include normals, tangents,
vertex colors, and materials; no animation; no cameras or lights. Use
`_col` / `-convcol` naming or generate collision in Godot at import, whichever is
cleaner, but the result must be a `ConvexPolygonShape3D` or a small set of them
per boulder, never a trimesh.

## Part 0 — Two fixes carried from the milestone 4 review

**1. The foam is confetti.** On the gently sloped bar the 15 to 60 cm depth band
is two or three meters wide, and the noise threshold fills it with uniform white
dots. Real river foam at a calm shoreline is a thin, streaky line. Change to:

- Full foam only within about 8 cm of contact, fading out by 35 cm.
- Stretch the breakup noise three to four times along the flow direction so
  foam reads as streaks, and threshold it so coverage inside the band is 30 to
  50 percent, not 90.
- **Remove the `dFdx`/`dFdy` bed-normal term.** It produces the triangle-edge
  seams visible in `milestone-4-water-wade.png`. If you want a denser collar at
  steep obstacles (rocks, legs), detect them seam-free by comparing the baked
  analytical depth in the vertex alpha against the depth-buffer depth: where the
  buffer is much shallower than the bar should be, something is standing in the
  water. `obstacle = smoothstep(0.2, 0.6, baked_depth - buffer_depth)`.

**2. The shore render was shot from behind a boulder.** Add a composition guard
to the capture harness for every player-camera render: raycast from the camera
along its forward vector; if it hits anything within 2 m, the shot is invalid
and the harness fails with the offending object's name. Re-shoot
`milestone-4-water-shore.png` under that guard so it shows the waterline, the
foam line, the bed in the shallows, and the far wall.

## Part 1 — Materials and textures (`blender/build_textures.py`)

Author tileable PBR texture sets procedurally in Blender shader nodes, bake to
PNG at 2048, export to `assets/textures/<name>_albedo.png`, `<name>_normal.png`,
`<name>_orm.png` (occlusion, roughness, metallic packed). Sets:

| Set | Look |
|---|---|
| `granite` | Pale grey Sierra granite, coarse crystalline speckle, faint feldspar pink, joint cracks, lichen patches in olive and rust at low frequency |
| `talus` | Broken angular granite scree, mid grey, sharper and darker than the cliff |
| `gravel` | Rounded river cobbles 3 to 15 cm in warm grey, tan, and dark, packed in coarse sand; strong normal map |
| `sand` | Fine tan sand with faint ripple marks and dark mineral streaks |
| `duff` | Pine needles, cones, bark flakes on dark brown soil |
| `bedrock` | Dark grey-green water-polished schist with quartz veins |

Tile sizes in meters: granite 4, talus 3, gravel 1.5, sand 2, duff 2, bedrock 2.
Every set must tile without visible seams at 3 by 3.

## Part 2 — The terrain shader (`shaders/terrain.gdshader`)

The terrain stays procedural in `greybox.gd`; only its surface changes. One
shader on the ground mesh, driven by world position, normal, and the existing
per-surface vertex color (repurpose it as a material index), with:

- **Triplanar projection** for granite and talus so the cliffs do not stretch.
- **Blending by geology, not by hand:** slope above about 55 degrees is granite
  cliff; the apron and benches are talus fading to granite; the bar beyond 3 m
  from the water is gravel; the last 1.5 m to the water and 30 cm below it is the
  darker, glossier wet gravel; the strip of sand at the waterline where the bar
  is nearly flat; duff under the tree line on the benches. Bedrock slabs keep
  their own material.
- **Macro variation:** a low-frequency world-space noise that shifts albedo by a
  few percent and roughness slightly, so no tile repeats visibly at 30 m. A
  second, higher, noise breaks the gravel/sand boundary into a natural line.
- **Distance blend:** past about 60 m, fade normal-map strength so the far walls
  read as form and light, not texture.
- Keep it under about 8 texture samples per fragment in the common case.

The bar seen at golden hour from standing height should look like cobbles you
could pick up. The cliff across the river should look like granite, not concrete.

## Part 3 — Boulders (`blender/build_boulders.py`)

A set of eight granite boulders, `assets/boulders/boulder_01.glb` through `_08`.
Each: an icosphere or cube base, two levels of subdivision, displaced by layered
noise for rounded water-worn forms, flattened faces on one or two sides, a small
amount of edge wear. 1,500 to 3,000 triangles. Shared granite material using the
texture set above via triplanar in Godot (export with a simple material; the
Godot side assigns the real one). Vertex color: paint darker "water-polished"
tint on the lower third and lichen on upper faces via geometry attributes.

**Placement rules are strict** because the gold map and the boundary tests depend
on them:

- Replace each placeholder in `Layout.BOULDERS` at the same position with one of
  the eight, choosing rotation and one of the eight meshes deterministically from
  the boulder index.
- The new boulder's horizontal footprint radius must be within 0.85 to 1.15 of
  the placeholder radius, and it must be sunk into the gravel so no underside
  shows.
- Convex collision that matches the mesh closely enough that the walker cannot
  walk into it or stand inside it.
- The two bedrock slabs become low, flat, jointed schist ledges from
  `blender/build_bedrock.py`, `assets/bedrock/ledge_01.glb` and `_02`, same
  footprints, a few centimeters proud of the gravel, with a visible downstream
  crevice edge.

## Part 4 — Trees (`blender/build_trees.py`)

Four species, `assets/trees/ponderosa.glb`, `incense_cedar.glb`,
`douglas_fir.glb`, `black_oak.glb`. Built procedurally: a trunk with a few
branch levels (a simple recursive script or the sapling add-on driven from
Python), foliage as textured cards in clusters, alpha-scissor, with normals
bent outward for soft shading. Budgets: 3,000 to 6,000 triangles per tree
including cards. Foliage textures baked from Blender particle or node setups to
`assets/textures/foliage_<species>_albedo.png` with alpha, 1024.

- **Ponderosa:** tall, orange-plated bark, long needles in open tufts, bare lower
  trunk. 25 to 35 m.
- **Incense cedar:** conical, dense flat sprays, reddish fibrous bark. 20 to 30 m.
- **Douglas fir:** dense, drooping branch tips, dark green. 25 to 40 m.
- **Black oak:** broad, crooked, 12 to 18 m, dark bark, lobed leaves in bright
  green. Only at the bar edge.

Bake **wind weight into vertex color red** (0 at the trunk base, rising toward
branch tips and card edges). Godot side: one `shaders/foliage.gdshader` that sways
by that weight with two frequencies, world-position phase offset so trees do not
move in unison, subtle, never more than about 15 cm at the tips.

## Part 5 — Placement (`scripts/vegetation.gd`)

A new node that scatters instances deterministically from a seed using
`MultiMeshInstance3D` per species, sampling `Layout.height_at` and its slope:

- **Conifers** on both canyon walls: on benches and apron where slope is under
  about 40 degrees, from just above the talus foot to the rim, density falling
  with height. Species by band: cedar and Douglas fir lower and near the water,
  ponderosa higher and on the sunnier far bank. Random yaw, scale 0.8 to 1.2,
  slight tilt to the slope. Between 300 and 1,200 conifer instances total.
- **Black oaks** only in the band from about 12 m inland to `back_z`, eight to
  fifteen of them, spaced at least 6 m apart. **Each oak within the walkable bar
  gets a trunk collision cylinder** in the terrain layer; the walker must not
  pass through it. Conifers on the walls get no collision; the walker cannot
  reach them.
- **Nothing** in the river, on the gravel within 12 m of the water, or on
  slopes steeper than 45 degrees.
- **Cobbles:** three small rock meshes (`assets/boulders/cobble_01.glb` to `_03`,
  under 200 tris each) scattered on the bar as a MultiMesh, 400 to 900 of them,
  denser near the water, none within 1.5 m of the waterline where the pan
  happens, none inside a boulder footprint.
- **Grass and wildflowers:** a MultiMesh of grass cards with the foliage shader
  in the band from 8 m inland to `back_z`, thinning toward the water, none on
  bare gravel. Two or three wildflower card variants at low density, June
  colors: lupine blue, poppy orange, white yarrow. Keep the total under 3,000
  cards.

Godot's automatic mesh LOD is on for everything imported; set visibility ranges
so grass fades by 40 m and cobbles by 60 m.

## Performance

Same proxy: p95 under 5.5 ms at 1080p on the 5080 in the harness, with
vegetation, cobbles, grass, the terrain shader, water, GI, and fog all on. This
milestone is where the budget starts to matter. If it does not fit, reduce in
this order: grass count, cobble count, conifer count, texture resolution to
1024, foliage card count per tree. Record what you did.

## Tests — `tests/milestone_5.gd`

- Milestone 1 to 4 suites pass **unchanged**.
- Files exist: eight boulder `.glb`, two ledges, three cobbles, four trees, six
  terrain texture sets (three PNGs each), four foliage albedos, and a
  `blender/*.py` for each group plus `blender/README.md`.
- Each `.glb` loads as a `PackedScene`; triangle counts within the budgets above
  (read the arrays and count).
- For each `Layout.BOULDERS` entry: a placed boulder exists at that position; its
  AABB horizontal radius is within 0.85 to 1.15 of the placeholder radius; it has
  at least one `CollisionShape3D` whose shape is `ConvexPolygonShape3D`; and its
  AABB bottom is at or below the local terrain height.
- The ground mesh's material is a `ShaderMaterial` on `shaders/terrain.gdshader`
  whose code references all six texture sets.
- Vegetation: conifer instances between 300 and 1,200; oaks between 8 and 15,
  pairwise at least 6 m apart; **no instance of anything** with `depth_at` above
  0 or within 12 m of the shore, except cobbles, which may come within 1.5 m;
  no instance on a slope above 45 degrees; every oak inside the bar has a
  collision cylinder within 0.5 m of its trunk.
- Walk test: drive the walker into the nearest oak trunk for 3 seconds; it does
  not pass through.
- Camera boom still retracts against a real boulder mesh (drive the milestone 1
  camera check against boulder index 1).

## Renders and probes

All at golden hour, 1080p, under the composition guard. Print the measured
numbers.

- `milestone-5-downstream.png`: the milestone 3 downstream camera. The hero shot.
- `milestone-5-upstream.png`: the milestone 3 upstream camera, far wall lit,
  tree line visible on the benches.
- `milestone-5-gravel-close.png`: camera at 1.2 m height, pitched down 35
  degrees at the waterline, cobbles and wet band in frame. **Probe:** luminance
  standard deviation in a 64 by 64 gravel patch above 0.05 (texture, not flat
  tone).
- `milestone-5-boulder-close.png`: 3 m from boulder index 1, sun raking across
  it. **Probe:** granite patch luminance standard deviation above 0.04.
- `milestone-5-treeline.png`: from the bar looking up at the near wall, conifers
  on the benches against the sky. **Probe:** a canopy patch has green above red
  by at least 20 percent; a granite patch beside it does not.
- `milestone-5-oak.png`: standing under a black oak at the bar edge, looking
  toward the river through the branches.
- `milestone-5-overview.png`: the overview camera.
- `milestone-5-noon.png`: `apply(12.0)`, the downstream shot, restore.
- Re-shot `milestone-4-water-shore.png` under the guard.

## Acceptance

- All five suites pass; the harness passes probes, guard, and budget.
- Every asset regenerates from its script with no manual steps.
- **Human review**, and this is the milestone where it counts most. The
  questions: is that granite; are those cobbles; do the trees look like trees or
  like green lollipops; does the downstream shot still make you want to stand
  there, now that there is something to stand on. Expect two rounds of notes.
  Tree foliage is the most likely thing to need a second pass. If a species
  will not come right, make the other three good rather than four mediocre.
- README updated: the Blender pipeline, the terrain shader, the vegetation
  rules, what was reduced for budget.
- Commit as `Complete milestone 5 assets`.
