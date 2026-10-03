# Wave C — C-props (camp, store and props)

Done October 2, 2026 (agent C-props, tour label `c_props`, compared against `merge8`).
Final tour: `artifacts/visual-tour/c_props/` (before/after sheets against merge8);
close-ups, A/B probes and logs: `artifacts/visual-upgrade/c_props_closeups/`.

## What changed, by reviewer finding

1. **Detail parity (store goods).** Sacks are rebuilt as sewn sacks rather than lathes: two
   panels with proud side seams (a pillow section), bottom ears, slight belly, slump and
   seeded creases; flour and salt in coarse osnaburg (new `kit_osnaburg`, from the hessian
   scan, so the weave reads), beans and coffee in burlap with rolled mouths; tied necks with
   a cord end and a flared tuft. Every sack carries a painted shipping mark (SUPERFINE
   FLOUR, SALT, RIO COFFEE, BEANS) as a decal patch on its own surface (`shaders/stencil.gdshader`,
   `assets/props/stencil_mask.png`). New salt-glazed stoneware (`kit_crock`: buff orange-peel
   body, Albany-slip shoulder with drips) jugs and crocks; nailed crates with corner battens
   and a stencilled "J. L. FRENCH CAMP" mark; a nail keg; paper-labelled boxes and tins
   (`kit_labels`: 16 printed 1840s labels, serif type, foxed paper). Stall at distance:
   lighter split-board counter front, canvas backlight raised so the roof underside glows.
2. **Period.** Price board: six butted planks in worn oxblood paint (`kit_paint`) on two
   peeled poles with rope lashings and a two-board roof; the lettering is ochre-cream
   PatrickHand (gameplay text unchanged). The "LAMBERT / FRENCH CAMP" Label3D is gone: the
   name is brush-painted in serif capitals into the canvas sign (`kit_sign`, with rules and
   lozenges). The church-pew bench is replaced by a puncheon bench (split half-log on four
   splayed pegs, `assets/props/bench.glb`, parametric). Counter slate carries wiped chalk ghosts.
3. **Shelves.** Middle shelf: soap and candle boxes, tea canisters, pepper and mustard
   tins, five bolts of cloth, stacked sardine tins and oyster cans, candle and match and
   saleratus boxes, pickle jars, three hanging candle bundles, folded striped trade blankets
   (`kit_blanket`), a lard crock and a jug. Bottom-shelf ends: nail keg, two jugs and a
   crock. Top-shelf ends: tin plates and cups, tin coffee pot, flints and percussion caps.
   Outside the east wall (facing the trail): rope coil, frying pan, tin kettle on pegs.
   All stock items, names, positions and shelves.gd mappings are untouched.
4. **Camp.** Lean-to canvas re-modelled as cloth: catenary sag down the slope, troughs
   between the four hem stakes, tension wrinkles from each stake to the forks, scalloped
   hem, a folded front flap, side wings brought down to staked feet, a bowed ridge pole;
   stakes are pale whittled wood and ropes 7-8 mm so they read. The bought tent and the
   crew bunk tents are a new canvas A-tent (`assets/camp/tent.glb`: sagging slopes, rolled
   door flaps, hem ties, stakes, guy lines) over the expedition tent kept as hidden
   collision (`camp.gd tent_instance()`). Bedroll: red wool roll with striped inner layers
   and leather straps at the shelter mouth, coat pillow, ground cloth. New cook gear
   (tin coffee pot, Dutch oven with flanged lid, legs and bail, tin plates, cups); woodpile
   doubled with stakes, rounds and kindling. Layout and collision frozen (camp tests pass;
   shelter front bound still 3.29 m).
5. **Fire.** Ring of ten separate river cobbles (Poly Haven `stone_01`, normalised to 240
   tris, packed end to end, sunk a third, soot and per-stone tone in vertex colour) round a
   sooty ash bed. When lit: nine crossed flame ribbons (`fire.gdshader` mode 1: noise-torn
   tongues, yellow root, red tips), coals glowing in cracks (mode 2), a thin smoke column;
   the old flame particles re-shaded into stretched, soft licks (mode 0). Intensities are
   kept low so night exposure and AgX keep them orange. The crew's supper light and its
   omni (crew.gd) are untouched, so the fire-lit crew and ground look is preserved.
6. **Ground.** Store clearing: the bar's gravel now in the gravel slot (was duff), litter
   patches kept; the trail's gravel slot no longer takes sand (the near-white strip) and
   its litter slot takes soil. 70 pieces of litter (cobbles, bark) scattered over the yard
   off the trail, apron and props (own seed 184821).
7. **Notice.** The board right of the crew fire is the claim notice (crew.gd text
   "NOTICE / <bar> claimed and worked by the undersigned & Co."). It is now a torn,
   nailed paper on a weathered board under two shakes on a peeled post (`notice.glb`).

## Gates

| Gate | Target | Measured | Result |
| --- | --- | --- | --- |
| Blind check (store, store_shelves, camp_10h, camp_close_10h, crew_supper_1936) | pass | orchestrator | pending |
| GPU A/B vs merge8 meshes, camp_10h framing | ≤ +0.1 ms | +0.015 median / −0.001 low-quantile | pass |
| GPU A/B, camp_close framing | ≤ +0.1 ms | +0.018 / −0.002 | pass |
| GPU A/B, supper framing, all camp+crew changes | ≤ +0.1 ms | −0.009 / +0.008 (null ±0.01) | pass |
| GPU A/B, store_performance framing (stall, goods, bench, freight, litter) | inside 4.5 ms | +0.027 / +0.024; store total 3.33 ms GPU | pass |
| Full suite | 37/37 | 37/37 (re-run of camp/store suites after last tweak 8/8) | pass |
| `store_capture` probes | board ≥22 px, contrast ≥4; slate ≥20 | board 34 px, 8.55; slate 29 px; Lambert 0.0665 (now passes) | pass (stock-thinning probe fails as on base) |
| `audit_assets.py` | exit 0 | 137 files, 0 failing | pass |
| Stage 1 colour gates | 10:00/13:00 unchanged | pass; golden hour 0.877 (S-sky's, as merge8) | unchanged |

A/B method: `artifacts/visual-upgrade/c_props_closeups/ab.gd` and `ab_store.gd` swap the
merge8 GLBs (extracted from HEAD) for the new ones in place, 30 (camp) / 24 (store) cycles
alternating order, GPU time per half from `viewport_get_measured_render_time_gpu`; "low" is
the per-half 20th percentile, robust to the other agents' load. Draws: camp +5 (+11
shadow), supper +2, store +37 (more materials on the shelf stock). Wall-clock
`store_performance` p95 was 7.1-13.4 ms on the contended machine (not a valid absolute).

## Regression amendments

Art budgets only (`tools/art/budgets.json`); no rules assertion changed. New `camp_kit`
category (2,600 tris) for `lean_to.glb` (2,312: a 24 x 18 cloth grid plus wings) and
`fire_ring.glb` (2,540: ten scanned stones plus the ash bed) — each one draw, measured
above. `building_kit` 12,000 → 17,000 (store.glb 16,786: shelf stock and wall goods) and
`goods_kit` 18,000 → 20,000 (18,996: seamed sacks with marks, freight). The store has
1.2 ms of GPU headroom under its 4.5 ms budget and the A/B cost is +0.02 ms.

## Shared files touched (small hunks)

- `scripts/crew.gd` (C-characters): `_build_notice` uses `notice.glb` (same node chain:
  stake → paper → Label3D, same text); bunk-tent creation calls `camp.tent_instance()`
  instead of loading `tent.glb` and building trimesh collision itself (same collision).
- `tools/art/budgets.json`, `assets/CC0_MANIFEST.json` (fire_ring.glb now an output of
  `stone_01`; removed from `stone_fire_pit` and `painted_wooden_bench`, no longer used).

## Assets

Added/changed: kit 3.01 → 4.36 MB (osnaburg, blanket, paint, sign, tin, crock, ash, labels),
camp −0.22 MB (lean-to, bedroll, coffee, woodpile up 0.22 MB; fire ring 1.04 → 0.46 MB;
new flames, tent, notice 0.15 MB), store/goods +0.88 MB, bench 0.74 → 0.02 MB, stencil
mask 0.13 MB. Net about +1.4 MB. Lettered sources come from `tools/art/build_prop_labels.py` (system Python
+ Pillow; written to the cache, not committed; uses a local KaTeX_Main serif, SIL OFL,
falling back to PatrickHand). Rebuild: `python tools/art/build_prop_labels.py`, then
`blender/prop_kit.py`, `blender/build_store.py`, `blender/build_camp_kit.py` (fire_ring
needs the normalised stone first; command in its docstring).

## Still weak

- The fire is modest at supper distance: the tongues are small next to the omni light's
  pool, and their cores still go pale yellow under AgX; ash bed looks a little glossy.
- The lean-to reads as cloth close up; from camp_10h it is still a cream flap over a
  shaded underside. Tents sag only gently. No cloth simulation was used.
- The store clearing's large tan soil areas depend on C-ground's plain-ground path; my
  part is the texture slots and the scattered litter.
- Ring stones are one scan copied ten times; up close a few show sharp scan edges.
- The outfitting sign is still a paper on a box post.
