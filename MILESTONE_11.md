# Milestone 11 — Tools and the falling river

Implementation scope, September 9, 2026. The user authorized starting M11 after
committing the playable M10 build. No earlier M11 memo existed; this implementation
uses `PHASE2_BRIEF.md`, especially the calendar and tools sections. M10's unresolved
economy findings and the deferred M9 notes remain separate follow-up work.

## Playable behavior

- Water falls through July, exposes both slabs by mid-August, stays low through
  September, and rises with October rain. Depth, mesh, trigger volume, wet gravel,
  panning/fishing eligibility, fishing aim/bait, fish height, splashes, shin foam,
  and shoreline bait gathering use the same elevation.
- Lambert sells crowbar with horn spoon, pick, shovel, boots, and a rocker kit.
  Existing stock and prices apply. Duplicate purchases are refused. Spear, rifle,
  ammunition, and tent remain reserved for later work.
- Boots raise working depth from .45 to .70 m. The existing smooth current shifts
  with that threshold; the miner still cannot swim.
- G at an exposed slab starts an 18-second crowbar/spoon sequence. Slab reserves
  persist in GameState across days and trips. Flooding or Escape cancels without
  consuming the reserve or awarding a partial result.
- G on suitable shoreline gravel builds the owned rocker kit in six seconds.
  With a shovel, loading takes 14 seconds, or eight with a pick. Rocking takes
  another 40 seconds and processes ten normal pan rolls from the loading position.
  The cradle needs dry footing and a wet intake. When the river shifts, G packs
  it for rebuilding at a new shoreline. The kit is reusable; rewards are per load.
- The pocket ledger records work and tools. F4 exposes equipment and automatic
  or overridden river elevation, plus shortcuts to the slab and rocker bank.

## Authored tuning and interpretations

These are initial game values, not historical measurements or new acceptance
targets imposed on earlier work.

Water checkpoints in metres relative to the original June datum:
`0:0, 20:-.12, 50:-.55, 75:-.68, 96:-.68, 115:-.15, 132:.04`.
Linear interpolation is deterministic; rain adds .10 m. The sandbox override
range is -.75 to .14 m. Terrain heights and the water shader remain unchanged.

The old gold field mixed geology with a June accessibility cutoff at 45 cm.
Its cutoff now extends to seven metres riverward of the terrain's shore datum;
all pocket centres, strengths, gradients, and normal pan yields remain unchanged.
This exposes the existing geological field as water falls and boots extend reach.
Deep central riverbed remains outside the gold field. All M2 geology tests pass
unchanged.

Each slab starts with 4–6 oz according to seed, and individual crevice yields
decline with the remaining reserve. The rocker uses ten unchanged `PanResult`
rolls; it has no blanket gold multiplier. Loading at the cradle samples nearby
gravel rather than adding a separate hauling minigame.

The crowbar purchase includes the horn spoon. Pick, shovel and crowbar count
toward the existing 40 lb pack limit. Boots are worn. The 40 lb rocker materials
travel as a separate tied bundle and stay at camp/claim; they do not consume the
food pack allowance. This makes the existing kit purchasable without changing
the M10 food carrying limit. Only one kit can be owned.

## Regression changes and verification

Two old M10 assertions change because tools are now for sale:
`tests/milestone_10.gd` checks the spear, instead of the pick, remains unavailable;
`tests/milestone_10_models.gd` expects the original eight goods plus five tools.
All other earlier assertions remain unchanged.

`milestone_11_models.gd` checks seasonal exposure, floods, deterministic levels
and rewards, shoreline geometry, finite depletion, tool speed/depth and site
eligibility. `milestone_11.gd` drives G through actual crevicing, cancellation,
building, loading, rocking, packing, purchases, depth access and sandbox fields.
`simulate_tools.gd` compares equal work time on the same lean shoreline ground
over 133 days and writes `artifacts/season-tools.csv` and JSON. It is a mining
comparison, not a replacement for the M10 food/travel economy simulation.

The new Blender sources retain the cradle, four hand tools, and five mining clips.
Visual review uses `milestone_11_capture.gd` with the composition guard and visible
miner/cradle coverage gates. Performance uses the actual running cradle at 1080p.

No M11 requirement was omitted from the Phase 2 feature list. This is initial
mechanic/asset tuning; human motion review, broader mining-economy balancing and
final sound/art polish remain appropriate before the season-end polish milestone.
The deferred M9 tests are not being claimed as newly completed.
