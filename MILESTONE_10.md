# Milestone 10 — The Store

Acceptance checkpoint (2026-09-09): the user authorized committing milestone 10
and starting milestone 11. The three season-balance findings below remain
documented follow-up work; this approval does not turn their failed assertions
into passing tests. M10 model and integration tests were rerun and passed.
The checkpoint also includes the camp clutter step-up fix and its regression test.

Implementation status (2026-09-08): the revised storyboard was approved by
the user's instruction to implement. The playable build and test guide are
now on disk; see `STORE_GUIDE.md` and the README's Milestone 10 section for
verification and the three unresolved season-balance findings. Final human
review and the completion commit remain pending. The acceptance targets below
are preserved, including the stock-depletion target the specified model misses.

Read `PHASE2_BRIEF.md` first, then the standing rules in `ASTRA_BRIEF.md`, then
`MILESTONE_9_NOTES.md`, whose round must be complete and committed before this
one starts. This milestone turns gold into things. It adds the trip, the store
scene, the storekeeper, the gold price, the inflation index, visible finite
stock, hooks and line and a willow rod for sale, food for sale, the recipes
that food unlocks, the pack, the priced pages of the ledger, and a season
simulation that spends real minutes the way a player does.

Do not touch: `gold_map.gd`, `pan_result.gd`, `claim_layout.gd` values, the
boundary physics, the water shader, `WATER_LEVEL` (milestone 11). Do not build
tools, the falling river, the spear, or any animal. Tools sit on the shelves as
stock and cannot be bought; that is intended and Part 5 says how.

Existing scripts may change only as stated: `game_state.gd` gains the fields in
Part 1; `ledger.gd` gains the price column and the visit page (Part 9);
`cooking.gd` gains recipes (Part 8); `camp.gd` gains the pot and the crate's
bait cutting; `hud.gd` gains the store label (Part 6); `sandbox.gd` gains the
fields and buttons in Part 10; `claim.gd` gains the trail head; `soundscape.gd`
gains the store bed; `miner_visual.gd` and `build_miner_animation.py` gain the
clips in Part 7; `fisher.gd` reads the rod (Part 8). Suites 1 through 9 and both
notes suites pass unchanged.

## Goal

On a morning in late July a player with three ounces in the sack and two hooks
left walks to the back of the bar, sets out, sees his own camp from the canyon
rim with the fire smoking, and arrives at noon at a canvas store at the end of
a trail. He reads the price of gold off a board, pours dust onto a scale while a
silent man in an apron sets the weights, watches the slate come up short of
what the sack said, puts flour and hooks and a coil of line on the counter,
settles, and walks home to arrive at dusk. Five weeks later he does it again and
the flour costs twice what it did, and he says so out loud. When this is done a
store trip should feel like a day spent, not a menu opened.

## The storekeeper

**Lambert.** Jean-Baptiste Lambert, French-Canadian, came down to the
Sacramento Valley with the Hudson's Bay Company brigades in the 1830s and stayed
on at French Camp when the brigades stopped. In the spring of 1848 he packed a
mule string up the Yuba to sell to the first men on the river. Everyone calls
him Lambert, said the American way, and he has stopped correcting them. The
French trappers and traders were the men actually on the Yuba that year, which
is why he is French; the reasoning goes in the README, not the game.

He never speaks and has no lines. His name exists in three places: painted on
the canvas above the counter, chalked at the head of the price board, and in
the miner's ledger, which writes `at Lambert's`. He is a figure with an idle and
four working clips (Part 7). He is the thumb on the scale. The name is a single
constant, `Store.KEEPER`, so it can be changed in one place.

## Part 0 — Storyboard first

Before any asset or interaction code, greybox the trip as eleven beats and
render each from its named player camera, using the board, slate and pour focus
cameras below. Where a player camera hides the action, a clearly labelled
review camera may replace it for this gate. Boxes, capsules, and the existing
miner are enough, but pose hands and props so the beat itself is visible.
Captions record beat, action, input, state change and time. Put the frames in
`artifacts/storyboard/` and a contact sheet in the README. Add two supplemental
review frames: the slate reading `SHORT`, and an empty line peg (`Sold out`).
**This is a human review gate.** Parts 3 onward do not start until the sheet is
approved, because the counter in the wrong place is cheapest to find here.

| Beat | Where | On screen | Input | State | Time |
|---|---|---|---|---|---|
| 1 | Trail head, back of the bar | The path into the brush, the prompt `Set out for Lambert's · a day` | `interact` before 09:00 | Trip begins | 0 |
| 2 | The rim | Held shot looking down at the bar, the river, camp, smoke if the fire is lit | none, 4 s | — | clock jumps +6 h across the fade |
| 3 | The clearing, trail end | The tent 14 m ahead, the counter open to the trail, the sign | walk | arrive at H+6 | clock paused |
| 4 | The board, left post | Gold price, the date, goods prices in chalk | stand at counter: camera focus | — | — |
| 5 | The scale, left of counter | Lambert lifts the sack, pours to the pan, sets weights, the beam settles; the slate chalks ounces and dollars | hold `interact` to pour, release to stop | dust to dollars, less the thumb | — |
| 6 | The shelves | Sacks, kegs, papers, coils, a rod in the corner, tools he cannot afford | `interact` on an item | one to the counter | — |
| 7 | The counter | The pile, the slate total, the pack weight | `interact` on the pile | last item back | — |
| 8 | The barrel, right of counter | Smoked fish laid out | `interact` with smoked fish carried | fish credited | — |
| 9 | The slate | Lambert writes, hands the goods over | `interact` at the slate | coin then dust; goods to pack; stock down | — |
| 10 | The rim at dusk | Held shot, the bar in low light, the fire out | none, 4 s | — | clock jumps +6 h |
| 11 | Camp | Standing at the trail head at H+12; the ledger has a new page | — | — | — |

## Architecture rules

One script per responsibility. New scripts:

- `scripts/prices.gd` — pure static. Gold price by day and seed, inflation
  index, goods prices, the thumb, what the store pays for fish.
- `scripts/store_stock.gd` — pure static. The catalogue, stock on a given day
  from the seed and the restock schedule, minus what `GameState.purchases`
  records.
- `scripts/store_layout.gd` — pure static like `claim_layout.gd`: the
  clearing's heights, the trail, the bench, the boundary.
- `scripts/trip.gd` — the journey: eligibility, the rim shots, the clock
  arithmetic, the scene swap, the trail meal.
- `scripts/store.gd` — the store scene controller and `KEEPER`.
- `scripts/shopkeeper.gd` — Lambert's state machine.
- `scripts/price_board.gd`, `scripts/slate.gd` — world text.
- `scripts/beam_scale.gd` — the scale: pour, weights, beam angle.
- `scripts/shelves.gd`, `scripts/counter.gd` — stock objects and the pile.
- `scripts/pack.gd` — pure static. Weights and the limit.
- `scenes/store.tscn`.
- `tests/simulate_season.gd` is rewritten (Part 11).

`GameState` gains: `goods: Dictionary` inside `inventory` with keys `flour`,
`beans`, `pork`, `coffee`, `salt` in pounds (defaults 0 except `salt` 2.0),
`rod: bool` (false); `purchases: Array[Dictionary]` of `{day, item, count}`;
`ledger: Array[Dictionary]` of visits (Part 9); `scene: String` in `claim`,
`store`. `dollars` already exists. `Sack` is untouched and travels with him
because it is an autoload.

## Part 1 — Prices (`prices.gd`)

**Gold.** `static func gold_price(day, seed) -> float` in dollars per ounce.
Properties, all tested:

- Bounded 12.0 to 18.0.
- Trend from 16.0 at day 0 to 14.0 at day 132, with a slow seeded wander around
  it of amplitude about 1.5, built from `Weather.noise` on a five-day bucket and
  blended between buckets, plus daily noise of at most 0.4.
- Consecutive days differ by at most 0.75.
- Across 50 seeds, the mean over days 0 to 30 lies in 15.3 to 16.7 and the
  mean over days 100 to 132 in 13.3 to 14.7.
- Deterministic for seed and day.

**Index.** `static func index(day, seed, item) -> float`. Piecewise linear
between the brief's checkpoints (day 0 1.0, day 36 1.5, day 67 2.5, day 97
4.0, day 128 6.0, held after), times `1 + 0.08 * (2 * n - 1)` where `n` is
`Weather.noise(seed, day, hash(item))`. Each good gets its own daily wobble.

**Goods.** `static func price(item, day, seed) -> float` is the June base from
Part 5 times the index, rounded to the cent.

**The thumb.** `static func credit(ounces, day, seed) -> Dictionary` returns
`{weighed: ounces * 0.92, dollars: weighed * gold_price}`. The board shows the
honest price. The slate shows the weighed ounces. The sack readout drops by what
he poured. The player who compares the two has found the thumb; nothing tells
him.

**Fish.** The store pays `0.12 * index` per pound of smoked fish. A pound of
smoked trout in September is thirty cents. It must never rival gold.

## Part 2 — Stock (`store_stock.gd`)

`static func stock(item, day, seed, purchases) -> int` is opening stock plus
every restock on or before `day` minus purchases of that item on or before
`day`, floored at zero. Restock happens every seven days starting day 3, in the
amounts in Part 5, until each item's last restock day. After that, what is gone
is gone. `static func catalogue() -> Array[Dictionary]` returns every item with
its base price, unit, pounds per unit, opening stock, restock, last restock, and
whether it is `for_sale` this milestone.

Stock is visible. The shelf shows one object per unit for hooks papers, coils,
rods and tools, and a sack or keg whose fill level steps with the pounds
remaining for flour, beans, pork, coffee, and salt. When the last coil of line
is bought the peg is empty. A player who arrives to an empty peg has learned
something about October.

## Part 3 — The trip (`trip.gd`)

**Leaving.** A trail head sits at the bar's back edge, 6 m inland of camp,
where a gap in the brush and a worn path decal 1.2 m wide fade in over 6 m.
Within 1.5 m, facing it, the HUD line reads `Set out for Lambert's · a day`.
Eligible when the hour is 09:00 or earlier, `Panner` and `Fisher` are idle, and
no camp action is running. After 09:00 it reads `Too late to be back by dark`.

**The walk.** The walk is six game hours each way. It is not played. On
`interact`: a 1 s fade to black, then **the rim shot** (beat 2): a fixed camera
on the canyon rim above the bar's inland edge at the trail's height, looking
down the bar and along the river toward downstream, held 4 s with the
soundscape thinned to wind and a jay. If the fire is burning at camp its smoke
is visible. The existing claim scene renders this; no new geometry. Then 1 s
fade, scene swap to `store.tscn`, fade in at the trail end.

**Clock.** Leave at hour H; arrive at the store at H + 6. **The clock does not
run at the store.** The visit is a bubble: what he does at the counter is not
what the season measures. `Daylight` in the store scene is posed at the arrival
hour and the weather is the day's weather. Leaving the store returns him to the
trail head at H + 12. Leave at 05:00 and he is home at 17:00 with an hour of
dusk to fish; leave at 09:00 and he arrives in the dark. That is the decision.

**The trail meal.** At store arrival, if he carries a cooked portion, smoked
fish, or biscuits, one is eaten and the journal writes `Ate on the trail.` The
midday check then passes. Otherwise it applies as usual.

**What he carries.** Everything. The sack, the pack, hooks, line, bait, fish.
The fire burns down while he is gone, smoking pauses, and the day's fresh fish
spoil at day end as they would have anyway.

**Return.** Beat 10 is the rim shot again at H + 12 light, fire out. Then camp.
The ledger writes the visit page (Part 9). The day ends at the clock wrap or
when he sleeps.

## Part 4 — The store scene (`store.tscn`, `store_layout.gd`, `build_store.py`)

**Place.** A bench on the canyon's inland side above the river, out of sight of
it and within earshot: a clearing about 36 by 36 m of duff and thin grass, a
few ponderosas from the existing set, talus and brush at the edges, the trail
entering from the river side and the tent at the far side with its counter
facing the trail. The river is heard below, distant rapids in the soundscape,
never seen. The boundary is talus slope and brush with the claim's soft
push-back; no wall.

**The tent.** An open-fronted canvas store of the kind that stood at every 1848
diggings: two log walls and a canvas roof on a ridge pole, the front open under
an awning on two posts. A log counter 3.2 m long across the opening. Behind it
three tiers of plank shelves on the back wall and a barrel row on the floor.
On the counter: the beam scale at the left, the slate at the right, a pair of
brass weights, a ledger book of his own. On the left post: the price board. On
the right of the counter outside: a barrel with a plank on it for fish. Above
the counter on the canvas: `LAMBERT` in painted black capitals with a smaller
`FRENCH CAMP` under it. A picket line with no mule on it; the string is off
selling somewhere else.

`blender/build_store.py` exports `assets/store/store.glb` under 14,000
triangles with one 2048 atlas for canvas, log, plank, iron, brass, chalk, and
slate, and `assets/store/goods.glb` under 6,000 triangles for the goods: flour
sack, bean sack, small coffee sack, salt sack, pork keg, hook paper, line coil,
willow rod, and the display tools: crowbar, pick, shovel, boots, spear, a rifle,
a powder keg, a lumber bundle with iron strapping, a rolled canvas tent. Every
sack and the keg have four fill states. The canvas uses the Part 5 material
from the milestone 9 notes: two-sided, light through it, seams, stains.

**Light.** The store scene has its own `Daylight` posed at the arrival hour.
Under the awning is the first interior shade in the game; SDFGI and the ambient
must make the shelves readable without a fill light. The rain system from
milestone 9 runs here in rain, and the canvas roof sheds it: streaks die at the
canvas plane.

**Text in the world** (`price_board.gd`, `slate.gd`). `Label3D` with a hand
lettering face for the board (chalk on a dark plank) and a second for the
slate. Both fonts under a permissive licence recorded in the README with the
Cedarville note. The board lists: the date; `GOLD` and the price per ounce;
then one line per for-sale item with unit and price. The slate lists: weighed
ounces and dollars during a pour; the counter pile with prices and the total,
the pack weight, and `SHORT $x.xx` in a different hand when he cannot cover it.
The player reads prices here and nowhere else. Standing within 1.5 m of the
counter, `CameraRig.focus` frames the board on the left and the slate on the
right depending on which he faces; `ui_cancel` or stepping back releases.

**Camera and staging amendment — storyboard review, September 8, 2026.**
The board and slate each have a dedicated close focus camera, with the whole
reading surface inside the frame and the miner clear of the text. The named
**pour focus camera** is a three-quarter view from Lambert's side of the counter:
beam, receiving pan, pouring sack, miner's hands and Lambert's thumb must be
visible together. Begin this focus on pour and retain it until release and
settling; return smoothly to the counter camera afterward. Review cameras may
use a labelled wall cutaway in the greybox, but the final player pour camera
must fit the tent without clipping walls or bodies.

Lambert's working marks are fixed relative to the interaction, not the shelves:
at the scale he stands directly opposite the receiving pan, his front about
0.15 m behind the counter's rear edge; at the slate he shifts laterally to the
mark directly opposite it at the same counter clearance. His hands reach over
the counter, with the thumb at the pan's rim in the weighing pose. The scale,
slate and standing marks are reviewed as one arrangement before finished art.

## Part 5 — The catalogue

June base prices before the index, from the brief. Weights are for the pack.

| Item | Unit | June price | lb | Opening | Restock | Last restock | For sale |
|---|---|---|---|---|---|---|---|
| `hook` | each | 0.25 | 0 | 24 | 24 | day 112 (Oct 16) | yes |
| `line` | 20 m coil | 1.00 | 0.2 | 6 | 4 | day 112 | yes |
| `rod` | willow rod | 3.00 | 1.5 | 1 | 1 on day 36 only | — | yes |
| `flour` | lb | 0.10 | 1 | 200 | 150 | day 119 | yes |
| `beans` | lb | 0.08 | 1 | 120 | 80 | day 119 | yes |
| `pork` | lb | 0.20 | 1 | 80 | 60 | day 119 | yes |
| `coffee` | lb | 0.25 | 1 | 20 | 15 | day 105 | yes |
| `salt` | lb | 0.10 | 1 | 40 | 30 | day 119 | yes |
| `crowbar` | each | 6 | 5 | 2 | 1 | day 98 | no, 11 |
| `pick` | each | 8 | 7 | 2 | 1 | day 98 | no, 11 |
| `shovel` | each | 8 | 5 | 2 | 1 | day 98 | no, 11 |
| `boots` | pair | 12 | 3 | 2 | 1 | day 84 | no, 11 |
| `rocker` | lumber and iron | 25 | 40 | 1 | 1 | day 84 | no, 11 |
| `spear` | each | 6 | 2 | 1 | 1 | day 91 | no, 12 |
| `rifle` | each | 60 | 9 | 1 | 0 | — | no, 13 |
| `powder` | 20 shots | 4 | 1 | 3 | 2 | day 112 | no, 13 |
| `tent` | canvas tent | 20 | 18 | 1 | 1 | day 84 | no, 14 |

Food is sold by the pound in whole pounds. Hooks are sold singly. Items not for
sale sit on the shelves with their price on the board; `interact` on one gives
the HUD line `Not this trip` and nothing else. Their stock model runs from day
0 so that when milestone 11 turns them on, the shelf history is already true.

## Part 6 — The counter (`beam_scale.gd`, `shelves.gd`, `counter.gd`, `store.gd`)

The controls at the store are the same two keys as everywhere else.

- **Scale, weighing out.** Facing the scale within 1.5 m with dust in the sack,
  the HUD line reads `Weigh out · hold`. Holding `interact` pours at 0.25 oz per
  second; the sack readout falls, Lambert plays `weigh`, the pan drops, he adds
  weights in 0.25 oz steps as the beam swings, the slate chalks weighed ounces
  and dollars. Releasing stops the pour. `dollars` is credited on release, the
  visit record logs `sold_oz` and `weighed_oz`. He can pour again.
- **Shelves.** Facing a shelf item within 2 m, the HUD line names it with its
  price: `Flour · $0.40 a pound`. `interact` moves one unit to the counter
  pile, physically: the object slides to the counter, or a one-pound measure
  is scooped into a paper on the counter for food. `Not this trip` for display
  items. `Sold out` for an empty peg. `Too heavy` if the pack limit would be
  exceeded.
- **Counter pile.** `interact` facing the pile returns the last item. The
  slate keeps the running total and `PACK 31 lb`.
- **Fish barrel.** With smoked fish carried, facing the barrel, `Sell smoked
  fish` lays them all out; the slate adds the credit. `interact` again takes
  them back.
- **Settle.** Facing the slate with a pile, `interact` pays: coin first, then
  dust from the sack at the board price less the thumb for the shortfall,
  poured by Lambert without the hold. If he cannot cover it, the last item goes
  back to the shelf and the slate shows `SHORT` until he can. On success Lambert
  plays `write` then `hand_over`; goods enter `inventory.goods`, hooks and line
  and the rod enter their fields, `purchases` records each, stock objects leave
  the shelf, and the slate is wiped.
- **Leaving.** The trail end has the prompt `Home · by dusk` and starts the
  return. Leaving with a pile on the counter returns it to the shelves.

**HUD at the store.** The one-label rule relaxes for shopping: the label reads
`2.10 oz · $31.40` and nothing else, bottom right, same face as the sack total.

**Pack** (`pack.gd`). `LIMIT_LB = 40`. Goods, fish by weight, the rod, and line
count; hooks, bait, and gold do not. `static func weight(inventory) -> float`.
The limit is checked at the shelf, not at settle.

## Part 7 — Lambert and the miner's clips

**Lambert** (`blender/build_shopkeeper.py`). Reuse the miner's body and rig from
`build_miner.py` with a different dressing: no hat, hair cut short and grey at
the sides, a moustache, a red flannel shirt with sleeves rolled, a dark wool
waistcoat, a canvas apron to the knee, and a woven sash at the waist, the
voyageur's ceinture fléchée, in red and blue: the one thing that says where he
came from. Same triangle budget as the miner. He stands behind the counter and
never leaves it.

| Clip | Length | Loop | Notes |
|---|---|---|---|
| `keep_idle` | 4 s | yes | Leans on the counter, wipes his hands on the apron, looks down the trail |
| `weigh` | 3 s | no, retriggered while pouring | Steadies the pan, sets a weight, watches the beam; the thumb rests on the pan's edge on the last beat |
| `write` | 1.5 s | no | Chalk on the slate, a glance at the board |
| `hand_over` | 1.5 s | no | Pushes the pile across the counter, one hand flat on the wood |
| `shelve` | 2 s | no | Turns to the shelf and back; plays when an item is returned |

**The miner** gains: `pour` 3 s loop, the sack held over the scale pan in both
hands, tipping; `take` 1.5 s, reaching to the counter and drawing back; `walk`
is reused with the pack: a canvas pack on his back appears when
`Pack.weight` exceeds 5 lb and its silhouette steps at 15 and 30 lb, the way the
sack steps with gold.

## Part 8 — What the goods do

**Recipes** (`cooking.gd`, `camp.gd`). The pot on its tripod becomes an
interaction like the skillet. Coffee and beans are the pot; biscuits and pork
are the skillet.

| Recipe | Needs | Time | Gives |
|---|---|---|---|
| Biscuits | 0.5 lb flour, a pinch of salt (0.02 lb), the skillet, a burning fire | 15 game minutes | 1 meal, +20; a second batch in the same sitting makes a carried portion that keeps two days |
| Beans | 1 lb beans, 0.05 lb salt, the pot, the fire burning the whole time | 2 game hours | 3 portions: one eaten, two carried, keep two days |
| Fried pork | 0.5 lb pork, the skillet | 10 game minutes | 1 meal, +20 |
| Coffee | 0.1 lb coffee, the pot, a burning fire | 10 game minutes | +5 condition once per day before 10:00; not a meal; the journal says `Coffee.` |
| Fried fish, smoked fish | as milestone 9 | | |

**Salt matters.** Smoking now takes 0.1 lb of salt per fish. The starting 2 lb
smokes twenty fish. Without salt the rack prompt reads `Need salt to smoke`.
This is the first thing that makes the store a need instead of a want.

**Pork is bait.** At the crate, `Cut bait` turns 0.25 lb of pork into 4 `pork`
baits with the knife. The crate's cycle is: eat carried food, cut bait, ledger.

**The rod.** With `rod` true, `Fisher` casts 12 m instead of 8, the cast ring
clamps at 12, and `FightModel` tension rises at 0.8 of the hand-line rate
during a run, so a run gives about 0.7 s to release instead of 0.6. The rod
mesh (`assets/miner/rod.glb`, under 300 triangles, a peeled willow with the line
tied at the tip) is held in the left hand in every fishing state; the winder
stays on his belt. The existing clips are reused with the rod attached at the
hand socket; `cast` becomes an overhead flick by rotating the forearm track 40
degrees further in the rod variant, which is the only animation change. If the
reused clips look wrong with the rod, stop and say so; do not build new ones
this milestone.

**Line** is bought in 20 m coils and added to `line_m`. The hand line still
needs 6 m to fish.

## Part 9 — The ledger

Each visit appends to `GameState.ledger`: `{day, gold_price, sold_oz,
weighed_oz, dollars_in, fish_lb, bought: [{item, count, price}], prices:
{flour, beans, pork, hook}}`.

**Left page**, the day of a visit, written in the same hand as before:

    Walked to Lambert's.
    Sold 2.10 oz at $15.60. He called it 1.93.
    Bought 20 lb flour at $0.40, 12 hooks at $1.00, a coil of line at $4.
    $12.80 in coin.
    Home at dusk.

The thumb line appears only if he poured. `He called it` is the only editorial
the ledger allows itself.

**Right page** fills its Prices column. Under `Prices`, the last visit's date,
then `Gold $15.60`, `Flour $0.40`, `Beans $0.32`, `Pork $0.80`, `Hooks $1.00`.
When there have been two visits, the previous visit's figures are written
smaller in the margin beside the current ones. That margin is how the phase's
acceptance criterion is met: two trips a month apart, and the change is on the
page. Below: `Spent this season $x`, `Sold this season x oz`.

The right page also lists the pack: goods in pounds, hooks, line in yards, rod
or hand line.

## Part 10 — The sandbox and scenarios

`sandbox.gd` gains: `SpinBox` fields for `goods.flour`, `goods.beans`,
`goods.pork`, `goods.coffee`, `goods.salt`, a `rod` toggle; a read-only line
showing today's gold price and flour price from `Prices`; buttons **Go to
store** (runs the trip from any hour, bypassing the 09:00 rule and the rim
shot) and **Home** (available in the store scene). The panel works in both
scenes; `Trip` finds it by name.

Command-line scenarios gain `goods.<item>=lb`, `rod=1`, `scene=store` (start at
the store at 13:00 of the given day), and `dollars` already exists.

## Part 11 — The season simulation, rebuilt (`tests/simulate_season.gd`)

The milestone 9 simulation counts fish. This one spends minutes, because the
scarce thing is real time. Each policy has 1,200 real seconds per day and pays
for every action at the game's real durations:

| Action | Real seconds |
|---|---|
| Pan | 11 at default condition, divided by `ConditionModel.speed` |
| Walk between spots | distance at 2.4 m/s over `Layout` positions |
| Gather one bait or wood | 2 |
| Fish | seeded bite waits from `Fishery` with catch pressure, the fight from `FightModel` |
| Fry, cook, eat | the recipe's game time at 76.2 s per hour |
| Store day | the whole day; arrival home at H + 12 leaves the remainder |

Gold comes from `GoldMap.density_at` and `PanResult.roll` at the spots a policy
knows, read only, seeded per pan, with `ConditionModel.demote` applied. The
simulation may read `gold_map.gd` and `pan_result.gd`; it may not change them.

Policies over 132 days:

- **Careful.** Fishes at dawn and dusk rotating spots, pans the two richest
  known pockets otherwise, gathers wood daily, smokes surplus while salt lasts,
  goes to the store when hooks fall under 3 or food on hand covers under two
  days or salt under 0.3 lb, sells dust when the price is 15.5 or better or
  when settling requires it, buys flour and salt and hooks first, coffee if
  coin allows.
- **Careless.** Pans all day at one spot, never fishes, never goes to the
  store, never eats. Unchanged from milestone 9.
- **Spendthrift.** Goes to the store every seven days regardless, buys pork and
  coffee, fishes little, pans a middling pocket.

Writes `artifacts/season-careful.csv`, `season-careless.csv`,
`season-spendthrift.csv` with `day, date, weather, hour, action, spot, item,
amount, ounces, dollars, condition`, and `artifacts/season-summary.md` with the
per-policy table that goes in the README. Asserts:

- Careful ends with total value (dollars plus dust at the day 132 price)
  greater than careless, and careless ends at condition 5.
- Careful makes between 3 and 9 store trips. Its first two trips at least 30
  days apart show flour prices differing by at least 20 percent.
- Careful buys hooks at least twice and runs out of salt at least once before
  its first purchase if it starts with the default 2 lb.
- Spendthrift finds at least one item sold out on at least one visit.
- The trail meal fires on at least half of careful's trips.
- Careful's October days with two meals reach at least 85 percent with store
  food, against the milestone 9 notes band of under 70 percent without.
- Gold price bands from Part 1 across 50 seeds; index at day 67 within 8
  percent of 2.5 for every item.
- Identical output for the same seed; different for seed + 1.

If careful cannot end ahead of careless, or cannot afford hooks by its second
trip, stop and report the numbers. Those are balance findings for the user,
not constants to tune alone.

## Performance

Store scene p95 under 4.5 ms at 1080p on the 5080 with Lambert animating, all
goods on the shelves, rain at full intensity. Claim scene budgets unchanged. If
the store does not fit, drop the rain first, then goods fill-state meshes to
two states, then the atlas to 1024.

## Tests — `tests/milestone_10.gd` and `tests/milestone_10_models.gd`

Models:

- `gold_price` bounded, trend, step, and 50-seed band assertions from Part 1;
  deterministic.
- `index` at days 0, 36, 67, 97, 128 within the 8 percent wobble of the
  checkpoints; monotone in the mean across 50 seeds.
- `price("flour", 0, seed)` in 0.09 to 0.11; `price("flour", 97, seed)` in
  0.37 to 0.43.
- `credit(2.0, day, seed)` weighs 1.84 and pays 1.84 times the price.
- `stock("hook", 0)` is 24; on day 3 is 48; after 30 purchases on day 5 is 18;
  on day 130 with no purchases equals opening plus every restock through day
  112; `stock("rod", 0)` is 1, day 36 is 2, and buying two leaves 0 forever.
- Every catalogue item has a positive price, a unit, and a weight; exactly the
  eight Part 5 items are `for_sale`.
- `Pack.weight` of 20 lb flour, a rod, two coils, six hooks is 21.9.

Scene:

- Suites 1 through 9 and both notes suites pass unchanged.
- `GameState` has `goods`, `rod`, `purchases`, `ledger`, `scene`; `salt`
  defaults to 2.0; the scenario parser sets `goods.flour=20`, `rod=1`,
  `scene=store`.
- Trail head exists 6 m inland of camp; the prompt is eligible at 08:59 and
  not at 09:01, not while panning, not while fishing, not while cooking.
- Leaving at 07:00 arrives at the store with the clock posed at 13:00 and not
  running; `Daylight` reports 13:00; leaving the store lands at the trail head
  at 19:00 with the clock running; `Sack.ounces`, `dollars`, and `inventory`
  identical across both swaps.
- The rim camera's forward ray passes the composition guard and the frame
  contains the camp's fire ring position within the viewport.
- Trail meal: with one smoked fish carried, arrival eats it, `meals_today` is
  1, the journal has the line; with nothing carried the 13:00 check applies.
- Store scene: the walker cannot leave the clearing; push-back, no stop.
- Board text contains today's date string, `GOLD`, and the flour price to the
  cent; slate text is empty on arrival.
- Pour: holding `interact` for 2 s at the scale with 3 oz removes 0.5 oz from
  the sack, credits `0.46 * gold_price` dollars, logs `sold_oz` 0.5 and
  `weighed_oz` 0.46; Lambert is in `weigh`; releasing stops within one physics
  frame.
- Shelf: `interact` on flour adds one pound to the pile and the slate total
  equals the price; on a display pick the HUD says `Not this trip` and the
  pile is unchanged; on an empty peg `Sold out`; at 40 lb `Too heavy`.
- Pile: `interact` returns the last item; Lambert plays `shelve`.
- Settle: with $10 coin and a $14 pile and 1 oz dust, coin goes to 0, the sack
  loses the shortfall at the thumbed rate, goods arrive in `inventory.goods`,
  `purchases` has one row per item, stock objects on the shelf drop by the
  count, `write` then `hand_over` played. With nothing to pay, the last item
  returns and the slate shows `SHORT`.
- Fish barrel: three smoked trout of known weight credit `0.12 * index * lb`
  and leave inventory on settle.
- Ledger after a visit: left page contains `Walked to Lambert's.` and `He
  called it`; right page contains `Gold $` and the flour price; after a second
  visit on day + 35 the margin figures are present and differ.
- HUD at the store shows exactly one label with ounces and dollars; back at
  camp idle, the sack total is the only label.
- Cooking: biscuits from 0.5 lb flour with the fire lit give +20 and consume
  the flour and 0.02 salt; beans take 2 game hours of fire and leave two
  portions; pork fries in 10 game minutes; coffee gives +5 once before 10:00
  and nothing at 10:01 or a second time; smoking with `salt` 0 is refused and
  with 0.5 consumes 0.1.
- `Cut bait` turns 0.25 lb pork into 4 pork baits; refused under 0.25.
- Rod: `aim()` clamps at 12 m with `rod` true and 8 m without; the run break
  time from working tension is at least 0.68 s with the rod; the rod mesh is
  visible in `STANCE` and not in `IDLE`.
- Pack silhouette: the pack mesh is hidden at 4 lb, visible at 6, and steps at
  15 and 30.
- Sandbox: **Go to store** from 15:00 arrives at the store; **Home** returns;
  the goods fields apply; the price line matches `Prices`.
- `simulate_season.gd` passes its assertions and writes the four files.
- The composition guard passes on every render.

## Renders and probes

All 1080p, guard on, art-director sentence for each in the README.

- `storyboard-01.png` through `storyboard-11.png`: the Part 0 greybox, one per
  beat, plus `storyboard-12.png` (`SHORT`), `storyboard-13.png` (empty line peg),
  and `storyboard-sheet.png`. Reviewed before Part 3.
- `milestone-10-rim-dawn.png`: beat 2 at 07:00, day 30, fire lit. **Probe:**
  the bar and river together cover at least 30 percent of the frame; the smoke
  column is present above the ring's projected position; no single surface
  over 60 percent. This shot has been wanted since milestone 3; it should be
  the best picture in the game.
- `milestone-10-arrival.png`: beat 3, the tent 14 m ahead, 13:00.
- `milestone-10-board.png`: the board focused. **Probe:** the smallest text
  line is at least 22 px high; chalk against plank contrast at least 4 to 1.
- `milestone-10-weighing.png`: Lambert mid-`weigh`, the miner pouring, from
  the named pour focus camera. **Probe:** scale, hands, and sack together at least 12
  percent; counter at most 50 percent.
- `milestone-10-lambert.png`: three-quarter at the counter in `keep_idle`.
  **Probe:** face and hands at least 6 percent; no single surface over 50
  percent. The sash must be legible.
- `milestone-10-shelves-june.png` and `milestone-10-shelves-october.png`: the
  same camera on day 0 and day 110 with the spendthrift policy's purchases
  applied. **Probe:** at least six fewer goods objects in October.
- `milestone-10-counter.png`: a pile of flour, hooks, and a coil, slate
  legible. **Probe:** slate text lines at least 20 px.
- `milestone-10-rain-store.png`: day 100, rain 0.8, under the awning. **Probe:**
  no rain particle alive below the canvas plane within the tent footprint.
- `milestone-10-rim-dusk.png`: beat 10 at 19:00, fire out.
- `milestone-10-ledger-prices.png`: the ledger after visits on day 30 and day
  65, both pages legible, the margin figures visible.

Record a 15 s sequence at 12 fps of a full weigh-out and settle from a review
camera 2 m to the miner's left at counter height, and a 10 s sequence of beats
1, 2, and 3 from the player camera, into `artifacts/store-sequence/` and
`artifacts/trip-sequence/`. Do not commit them. Contact sheets in the README.

## Acceptance

- All suites pass; harness passes probes, guard, and budget; the simulation
  passes and its summary table is in the README.
- `Play.cmd -- day=30 hour=6.5 dollars=0 hooks=2 goods.salt=0.2` puts 3 oz in
  the sack via the sandbox and a trip is possible before 09:00; `Play.cmd --
  scene=store day=100` opens at the counter with October prices and thinned
  shelves; `Play.cmd -- day=40 rod=1 bait.grasshopper=6` fishes at 12 m.
- **Human review**, in this order: the storyboard sheet (gate, before Part 3),
  then the rim at dawn, the arrival, Lambert at the counter, the weighing
  sequence, the ledger after two visits. Then a live session from day 30 with
  three ounces and two hooks: set out, sell, buy, come home, fry pork, sleep,
  read the ledger. Then from the sandbox jump to day 65 with the same kit and
  go again. The question for the second trip is whether the tester remarks on
  the prices before being asked. If they do not, the board, the slate, or the
  margin figures are not doing their job, and that is a send-back, not a
  balance note.
- README: Lambert and why he is French; the trip's clock rule and the bubble;
  the price model with its bands; the catalogue and restock table; the pack;
  the recipes and the salt rule; the ledger's visit page; the sandbox and
  scenario additions; the simulation's method and summary; the art-director
  sentence for every render; the font licences.
- Commit as `Complete milestone 10 the store`.
