# Wildlife pass — September 9, 2026

The claim now has black bear, black-tailed deer (does), western gray squirrels,
California quail and a Steller's jay. This is the animal art and ambient behavior
portion of the planned wildlife work. It does **not** complete milestones 12–13:
spearing, rifle hunting, meat/hides, bear fishing catches, camp raids, cache
consequences and shouting remain future gameplay work.

## Try it

Run the claim, press **F4**, scroll down and choose **Watch bear**, **Watch deer**,
**Watch squirrel**, **Watch quail** or **Watch jay**. These place the miner near
the selected habitat and set dawn. Watch bear also selects season day 99.
The camera remains the normal player camera; walk closer to trigger alert/flee.

| Animal | Normal visits | Behavior |
| --- | --- | --- |
| Black bear | Days 81–127, 04:45–08:00 | One bear near the salmon riffle; slow foraging steps, alert turns, retreats when approached. |
| Black-tailed deer | 04:45–08:00 and 17:30–20:30 | Two does near the water; idle head movement, alert, flee; a separate evening visit. |
| Western gray squirrel | 05:00–20:00 | Two among the oaks; short steps, tail motion, rapid retreat. |
| California quail | 05:00–20:00 | Four ground birds; forage, look up, run away. |
| Steller's jay | 05:00–20:00 | One ground-foraging bird; unfolds its flight feathers and climbs away when disturbed. |

Population, individual sizes, phases and initial spacing use the season seed
and day. Frightened animals stay absent for that visit rather than immediately
respawning. A new day, changed river level or explicit sandbox preset resets the visit. The normal
population is bounded at ten animals. Animals do not damage or physically block
the miner and do not modify owned inventory.

Movement uses local steering around authored boulders, oak trunks and the camp,
plus sphere sweeps against actual solid scenery. Seasonal water level constrains
the dry bank. There is no navigation mesh. Mammals have two-segment legs with
terrain-adjusted foot targets; head, tail and bird wings animate independently.
Local steering can stop at a tight dead end; it is not a general path planner.

## Assets and review

All five models are original procedural Blender geometry. `build_wildlife.py`
retains one inspectable `.blend` per species and exports five articulated GLBs.
Colored coat regions, subtle procedural surface detail, sparse guard hairs and
separate feather geometry provide the material pass. Shared runtime materials
avoid repeatedly creating shaders for individuals. No downloaded art is used.

| Species | Triangles | Candid art review |
| --- | ---: | --- |
| Bear | 29,450 | Low back, small ears and pale muzzle distinguish it from a grizzly; the lower-leg joints still look assembled and the coat is too smooth for a close wildlife portrait. |
| Deer | 28,564 | Long legs, upright ears and the tapered black tail are readable; the muzzle, ear interiors and neck markings remain simplified, and shoulders need a future continuous skin rig. |
| Squirrel | 25,714 | The raised bushy tail gives an immediate silhouette; fur tips are subtle, but the cheeks and paws still feel rounded and stylized. |
| Quail | 22,110 | Topknot, dark face and pale flank marks identify it; the plumage pattern is too regular and some feather boundaries remain conspicuous at close range. |
| Jay | 17,890 | Black head/crest, blue body and long tail work at play distance; folded wings still read as smooth layers, and flight needs more wrist articulation. |

These are recognizable game animals, **not photorealistic final sculpts**.
The final two views of each species were opened and inspected, along with the
river habitat view, the normal player camera and sampled frames of fleeing deer
and the flying jay. Every close-up covers over 9% of the frame with the actual target mesh.
Early review cameras had insufficient coverage; their lenses were tightened,
and the deer profile camera moved to the opposite side to clear the second doe.
The first habitat view was dominated by a boulder and was replaced with a clear
view from across the water. These are new review shots, not changed legacy probes.

![Bear](artifacts/wildlife-bear.png)
![Deer](artifacts/wildlife-deer.png)
![Squirrel](artifacts/wildlife-squirrel.png)
![Quail](artifacts/wildlife-quail.png)
![Steller's jay](artifacts/wildlife-jay.png)

Regional species and color references: [NPS Whiskeytown mammals](https://home.nps.gov/whis/learn/nature/mammals.htm),
[NPS Sequoia and Kings Canyon animals](https://www.nps.gov/seki/learn/nature/animals.htm?fullweb=1),
and [NPS Steller's jay description](https://www.nps.gov/grca/learn/nature/jays.htm).
These references support species selection and identifying features; the visit
times and encounter distances are game tuning from the Phase 2 brief.

## Verification

Run with the bundled Godot console executable and the writable local APPDATA
used by the other project review tools:

```powershell
$env:APPDATA = Join-Path (Get-Location) '.tools/godot-user'
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/wildlife.gd
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/wildlife_capture.gd
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/wildlife_performance.gd
```

- Wildlife model/integration suite passes: season boundaries, deterministic
  variation, population cap, valid habitats, alert/flee, actual solid-obstacle
  avoidance, absence after fleeing, dusk returns, new-day reset, nonblocking
  actors, inventory/condition isolation, jay flight and the bear sandbox preset.
- Standing mammal foot probes against the actual rendered terrain measured
  maximum errors of 1.3 mm (bear), 1.1 mm (deer), and 0.2 mm (squirrel). The
  moving flee probes report less than 0.1 mm penetration against the analytic
  ground. The last side-view review caught fully extended front legs hovering
  on a slope; body alignment to the terrain fixed this. These are contact
  probes, not a claim that every gait is natural or free of sliding.
- M9, M11 and the camp movement regression suites pass, including traversal
  across camp items and mining/store equipment integration.
- Ten close-ups pass the 8% visible-subject coverage gate and composition ray
  checks. Captures and coverage JSON are in ignored `artifacts/`. The capture
  harness also records 20 motion frames each for deer and jay.
- With all ten animals active in the real claim at 1920×1080 on the RTX 5080,
  600 uncapped frames after 240 warm-up frames measured **4.43 ms median,
  5.15 ms p95**. No mid-range GPU measurement is available.

Logs retain the existing certificate-store warning; rendered shutdown reports
seven texture RIDs, and the M11 store round-trip teardown reports retained
objects. Final wildlife runs have no gameplay script or material errors.
