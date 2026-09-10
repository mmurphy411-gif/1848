# Milestone 13 — hunting

Release the rifle and twenty-shot powder/ball package. G starts a three-second aimed shot at a standing deer or bear, F switches a nearby bear from shouting to rifle aim, and Esc cancels before ammunition is spent. Line of sight and range are checked both before aiming and before resolving a shot. A miss consumes a shot and spooks deer for three days. Each of the two resident deer and the single bear can be killed only once in the season. Corpses yield finite food and one hide; the 40 lb carried limit also applies while dressing game. Uncollected meat spoils overnight. The hide remains collectible.

Provisional model choices, exposed for balancing: a dressed deer yields 12 lb of usable meat and a 3 lb hide; the bear yields 30 lb and a 6 lb hide. Hide credits start at $2/$5 and follow the store price index. No claim is made that these are historically measured yields or prices.

Regression amendment: M10's catalogue assertion gains rifle and powder. All stock, price, scarcity and settlement checks retain their thresholds. New tests cover misses, ammunition, season persistence, carcass depletion, hide-only exchanges, and atomic failed settlement.

The rifle prop is authored separately from the miner. Dedicated spear and rifle clips now use the existing analytic limb solver. The aiming pose remains subject to visual review; it is not final animation acceptance.
