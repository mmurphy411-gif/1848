# 1848 — Phase 2 Design Brief for Astra

Read `ASTRA_BRIEF.md` first. Phase 1 built the place: a canyon, a river, a bar, a
man, a pan, and a day. Phase 2 builds the reason to stay. It **supersedes the
"What this is NOT" list** in the original brief. Everything else in that brief
still stands: the art direction, the character, the hidden gold map, the
boundary, the working rules, and every standing rule learned since.

---

## One-line pitch

One season on the North Yuba, June to first snow, 1848. You pan, fish, cook, and
walk to the store. The gold gets harder to find and the flour gets dearer. What
you have when the snow comes is your score.

## What changed in our thinking

Phase 1 proved that standing on the bar at golden hour is worth looking at.
Looking only takes a game so far. Phase 2 adds a small **aggregate, then
upgrade** loop: gold accumulates, a trip to the store turns it into tools and
food, and the tools change where on the bar it is worth working. The hidden gold
map stays the core of the game. Every upgrade must change *where* gold is worth
chasing, not just multiply a number.

The second change is about time. In phase 1 the day cycle was scenery. In phase
2 **the day is the unit of play.** Sleeping ends a day. Prices, weather, river
level, hunger, fish, and animals all roll on that tick.

## What this is still NOT

- No other miners, no dialogue trees. The storekeeper is a counter, a scale, and
  shelves, not a character with lines
- No death. Failure is a poor season, never a corpse
- No quests, objectives, tutorial text, or map
- No music
- No save system yet. The sandbox (below) covers testing; a save comes after the
  loop is proven

If a feature is not in this brief or a `MILESTONE_N.md`, do not build it.

---

## The calendar and the season

- Day 0 is **June 26, 1848**. The season ends with the first snow around
  **November 5** (day 132). Days are numbered from 0 and displayed as dates
- The existing clock (20 real minutes of day, 3 of night) keeps its lengths for
  now. Day length may later shorten toward fall; not in this phase
- A day ends when the clock wraps at dawn, or when the miner sleeps at camp
- The calendar is **diegetic**: a pocket ledger the miner opens at camp. It shows
  the date, the weather, what he sold and at what price, what he bought, and his
  running totals. The HUD stays minimal. The ledger is where the player reads
  the economy

**The river drops.** Snowmelt falls through July. By mid August the two bedrock
slabs and the lower boulder lees stand clear of the water. September low water
is the best mining of the year. October rains raise the river again and end
crevicing. The gold map does not change; the reachable part of it grows and
then shrinks. `WATER_LEVEL` becomes a function of the day. Everything that
samples it (depth, water surface, wet gravel band, eligibility bands) must move
with it. This is a refactor, and it lands in the tools milestone because
crevicing needs exposed bedrock.

**Weather** has four states: clear, hot, rain, frost. Rain raises the river and
makes fish bite. Frost arrives in late October and is the countdown. Weather is
deterministic from the world seed and the day.

## Camp

Camp sits on the bar above the high-water line under the oaks. A fire ring, a
bedroll, a hanging food cache, a drying rack, a skillet and a pot. The lean-to
becomes a canvas tent as a store upgrade. Firewood is driftwood left on the bar
by high water; it is gathered, not bought.

At camp the miner can: **sleep** (ends the day), **cook and eat**, **open the
ledger**, **store food in the cache**, and **set out for the store**.

## Condition, food, and cooking

There is no hunger meter that kills. There is one **condition** value, 0 to 100,
that governs how well the miner works:

| Condition | Effect |
|---|---|
| 70 to 100 | Full speed |
| 40 to 70 | Pan sequence up to 1.3 times longer; wading slows toward 0.8 m/s |
| Below 40 | As above, plus a chance each pan that a result drops one tier as flakes wash over the lip |

Two meals a day hold condition steady. Each skipped meal costs about 15 points.
A good meal restores about 20. Condition never reaches zero and never kills.

Food comes from the river (fish, later deer), and from the store (flour, beans,
salt pork, coffee, salt). Cooking at the fire uses a short list of real camp
recipes: fried trout, beans, biscuits, jerky, smoked salmon. Salt turns fresh
fish or meat into stores that keep. Fresh fish keeps one day; smoked keeps the
season. Coffee is a small morning bonus and strong period flavor.

## Fishing

Fishing is the first phase 2 mechanic to build and the one we care most about
getting right. It is the low-effort, high-charm counterpart to panning.

- **Fish are visible.** The water is clear enough to read the riverbed; a trout
  holding in a boulder's shadow should be the charm moment of the game. Fish
  live in a hidden **fish map** built like the gold map: spots derived from the
  shared layout, with populations that depend on species, date, and hour
- **The good water is the same water as the gold.** Trout hold in the eddies
  below the same boulders whose lees hold gold. The head riffle that drops
  coarse gravel is where the salmon hold. The river teaches itself twice
- **Gear.** He starts with a hand line, a few hooks, some line, and a knife. Hooks
  are lost to snags and break-offs and **must be replenished at the store**. A
  willow rod and better line are store upgrades. A spear is the salmon tool
- **Bait** is gathered on the bar (grasshoppers in the grass by day, hellgrammites
  under wet shoreline rocks, worms in the oak duff at dawn and dusk) or bought at
  the store (salt pork, later salmon roe). Species have bait preferences
- **The action** is light interaction, not a simulation: aim the cast, wait,
  watch the fish come, strike when the line jerks, then hold and give against a
  fish that runs. Strike early and it spooks; late and the bait is gone. Hold
  through a run and the line breaks and the hook is lost
- **Species** of the North Yuba in 1848: rainbow trout (the prize), Sacramento
  sucker, Sacramento pikeminnow, hardhead (edible but poor), and fall-run
  Chinook salmon, 10 to 20 pounds, which a hand line cannot hold. Salmon arrive
  in mid September, peak in early October, and are speared at the riffle
- **What a fish is for.** Food first. Smoked salmon is how a careful player eats
  through October without a store trip. The store buys smoked salmon at a poor
  price so a lucky run has an outlet that never rivals gold

## The store

The store is a place you travel to. The nearest trading post is a day's walk, so
a trip costs a **full day** of the season: leave camp at dawn, arrive, trade,
return by dusk, no panning that day. That makes each visit a decision.

The store is a second small scene: canvas and logs, a counter, a beam scale, and
shelves whose stock is visible and finite. No dialogue. The miner sets his dust
on the scale and the day's price is written on a board behind the counter.

**Two currencies.** Gold in ounces (the sack) and dollars in coin. The store buys
dust at the day's price, and the storekeeper's thumb takes a percentage. Goods
are priced in dollars. Buying directly with dust at the same rate is allowed for
convenience.

**Prices.** The gold price drifts around 16 dollars an ounce, day to day, bounded
between 12 and 18, and tends downward toward 14 by fall as dust becomes common.
Goods carry an **inflation index** tied to the calendar that models word of the
strike spreading. Target checkpoints, smooth between them, with plus or minus
8 percent daily noise:

| Date | Index |
|---|---|
| June 26 | 1.0 |
| August 1 | 1.5 |
| September 1 | 2.5 |
| October 1 | 4.0 |
| November 1 | 6.0 |

June base prices, before the index: hook 0.25, line 1.00 per 20 m, willow rod 3,
spear 6, pick 8, shovel 8, crowbar 6, boots 12, rocker lumber and iron 25,
rifle 60, powder and ball 4 per 20 shots, flour 0.10 a pound, beans 0.08, salt
pork 0.20, coffee 0.25, salt 0.10, canvas tent 20. These are balance targets, not
scholarship; tune them in the sandbox.

**Scarcity.** The store carries a few of each item and restocks on a fixed
schedule from the seed. Buy the last pick and it is gone until resupply. Late in
the season some things never come back.

## Tools and what they unlock

Each tool changes where the map is worth working:

- **Crowbar and horn spoon** unlock **crevicing** on exposed bedrock. The richest
  pockets in the game live in those cracks and cannot be reached without them.
  Each slab depletes over the season
- **Boots** raise the wading limit from 0.45 m to about 0.7 m, reaching the
  boulder lees that are currently just out of range
- **Pick and shovel** speed moving gravel from the bar to a rocker
- **Rocker (cradle)** is built at a spot with steady water from store lumber and
  iron. One load takes about 40 s and processes roughly ten pans of gravel, which
  makes lean ground worth working for the first time. It needs two hands and a
  shovel; the miner alternates loading and rocking
- **Rifle** is very expensive, most of a good season, and is the only way to take
  a deer. Powder and ball are consumables
- Long tom, sluice, and quicksilver are out of scope for this phase

## Wildlife

**Ambient tier**, cheap: black-tailed deer come to drink at dawn and dusk, gray
squirrels in the oaks, quail in the grass, a Steller's jay. Three states each:
idle, alert, flee. They see or hear the miner and leave. No navigation mesh; they
move along authored paths and away from the miner.

**Deer can be hunted, only with the rifle.** One shot at a standing deer.
Steadiness scales with condition; a miss spooks the deer for days. A deer yields
several days of meat that must be salted or smoked to keep, and a hide the store
buys.

**The bear comes with the salmon.** When the run arrives a black bear fishes the
head riffle at dawn and claims it while present. It raids camp at night if fish
or meat are left out of the cache and eats them. Shouting drives it off. It never
harms the miner. The rifle can kill it, for a large haul of meat and a hide; that
is a choice with a cost in powder, and a risk of a miss and a season without a
riffle at dawn.

## The sandbox (development requirement)

We must be able to jump into any point in the season and test any situation.
This is a hard requirement from milestone 9 on, and it shapes the architecture:

- **Every model is a pure function of the world seed, the day, and its inputs.**
  Prices on September 15 for seed 7 are the same every run. Fish populations,
  weather, river level, and store stock are all deterministic the same way.
  Randomness in *actions* (a pan roll, a bite time) is seeded per action as the
  panner already does
- A **`GameState` autoload** owns seed, day, dollars, and inventory. The clock
  reports the hour. Nothing else holds game state
- **An in-game sandbox panel** on F4, debug builds only, like the F3 density
  overlay: set seed, day, hour, dollars, gold, every inventory count, condition,
  weather, and river level, and apply instantly. Buttons for dawn, dusk, and
  next day
- **Command-line scenarios.** Arguments after `--` such as `day=80 dollars=40
  hooks=2` apply at startup so `Play.cmd` can launch straight into a situation
- **Headless season simulations** in `tests/` run a scripted policy over 130
  days against the pure models and write a CSV ledger to `artifacts/`. These
  are how we tune balance without playing 40 hours

## Milestones — build in this order and commit after each

9. **Fishing, camp, and the sandbox.** `GameState`, the calendar, the fish
   map, visible fish, bait gathering, the hand-line action, hook loss, camp
   props, sleep, condition, cooking and smoking, the ledger, weather, the F4
   panel, command-line scenarios, and a headless season simulation. The day
   becomes the unit and the first loop closes: catch, cook, eat, sleep.
   `MILESTONE_9.md`.
10. **The store.** The store scene, the day-long trip, gold price, inflation,
    stock and scarcity, hooks and line and rod for sale, food for sale.
11. **Tools and the falling river.** `WATER_LEVEL` by day, exposed bedrock,
    crevicing, boots, pick and shovel, the rocker.
12. **The salmon run and the bear.** Salmon in the riffle by date, the spear,
    the bear at the riffle and at camp, the cache that matters.
13. **Deer and the rifle, ambient wildlife.** Deer, squirrels, quail, jay; the
    rifle, powder and ball, hides.
14. **Season's end and polish.** First snow, the final ledger page, balance pass
    from the simulations, sound for every new action.

## Acceptance criteria for the phase

- A player can describe the season in a sentence: what they earned, what they
  bought, and what they wished they had bought sooner
- A trout is visible in the water from the bank before the line goes in
- Two store trips a month apart show prices the player notices
- Every mechanic can be reached in under a minute from `Play.cmd` with arguments
- The 130-day headless simulation under a sensible policy ends with more dollars
  than it started with, and under a careless one ends hungry

## Working rules added for phase 2

All phase 1 rules and standing rules apply. In addition:

- **Pure models first.** Before a mechanic touches a scene, its model exists as
  static functions with a headless test. The scene consumes the model
- **Determinism is a test.** Every milestone asserts that its model returns
  identical results for identical seed and day
- **The one-label HUD rule is relaxed only inside an action.** During fishing the
  HUD may show bait and hook count; during shopping, the scale. Idle on the bar,
  the sack total is still the only element
- **Historical numbers are balance targets.** Where the record and the fun
  disagree, the fun wins and the README says so
- **Do not build ahead.** Milestone 9 builds the fishery and the camp. It does
  not build the store even though hooks run out and fish is the only food. The
  sandbox sets hook counts until then
