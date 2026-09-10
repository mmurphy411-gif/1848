# Phase 2 closeout — September 10, 2026

The remaining Phase 2 gameplay systems are implemented and tested as a playable candidate. **Phase 2 is not yet fully accepted:** the unchanged season simulator still reports three economic findings, and several art/audio acceptance checks remain open. This checkpoint does not declare the miner's reference match or the whole game's art complete.

## What is now playable

- **Salmon:** a purchased spear, a dedicated two-handed animation, finite daily catches during days 81–127, and deterministic 10–20 lb fish. Landing produces usable food portions without losing or duplicating weight. The hand line still cannot land salmon.
- **Bear:** holds the dawn riffle, can be shouted away, appears at camp at night, and eats exposed fish/meat after a twelve-second opportunity to intervene. Sleeping also resolves an unobserved raid once. The hanging cache protects food; the smoking rack does not. The bear never damages the miner.
- **Hunting:** a purchased rifle and twenty-shot powder packages, dedicated aiming animation, standing-target and line-of-sight checks, condition-dependent accuracy, cancellation, and three-day deer flight after a miss. The two deer and one bear have persistent season identities. A killed bear never returns or raids again.
- **Game dressing:** finite meat and one hide per carcass. Taking supplies respects the 40 lb pack limit; the remainder stays at the carcass. Uncollected meat spoils overnight. Salt and four lit hours preserve a rackful of up to 20 lb of salmon or meat, using the existing cooking/cache paths.
- **Trading:** hides and smoked food can be exchanged together or by themselves. Credits appear on the slate and settlement remains atomic. Rifles, spears and tents cannot be purchased twice. The store uses the authored rifle/spear props and displays offered hides.
- **Shelter and ending:** a purchased canvas tent replaces the lean-to, retaining the bedroll and open entrance. November 5 stops the season once, adds falling snow and a ground dusting, and opens the final ledger. The ledger records retained coin, gold, edible food, purchases, catches, game, shots, hides and equipment. Closing it permits looking around; G reopens it. F4 can rewind the session for review.
- **Assets:** separately editable Blender sources, small GLBs, two new miner clips, and four original synthesized encounter sounds. The Pass 17 character and its optional equipment remain intact.

## Reach every new mechanic

Run from the project directory:

```bat
Play.cmd encounter=salmon
Play.cmd encounter=raid
Play.cmd encounter=deer
Play.cmd encounter=bear
Play.cmd day=132 tent=1
Play.cmd scene=store day=30 dollars=200
```

The encounter presets supply the relevant tool and choose a suitable season/time and viewing position. These are explicit development presets, not normal-play rewards. F4 provides **Spear salmon**, **Camp raid**, **Hunt deer**, **Hunt bear**, and **First snow**, plus spear/rifle/ammunition/tent fields. Normal purchases are made at Lambert's.

G / gamepad X performs the displayed action. Near a bear, F / gamepad Y switches between shouting and rifle aim if a rifle is owned. Esc cancels a spear thrust or aimed shot before completion. G near fallen game dresses it; G at the store barrel offers smoked food and hides, then G at the slate settles. Nearby camp furniture and mining equipment take priority over distant hunting targets.

## Verification

The headless suites below passed. Logs are under `artifacts/phase2-*.log`; generated artifacts are intentionally ignored by Git.

| Area | Suites |
| --- | --- |
| Existing foundation | `milestone_1` through `milestone_8` |
| Fishery and camp | `milestone_9_models`, `milestone_9`, `camp_layout`, `camp_movement`, `fishing_tension`, `fishery_pressure` |
| Store and mining | `milestone_10_models`, `milestone_10`, `milestone_11_models`, `milestone_11`, `simulate_tools` |
| New systems | `expedition_models`, `milestone_12`, `milestone_13`, `milestone_14` |
| Character and animals | `miner_game`, `wildlife` |
| Actual startup path | `phase2_launch` with salmon, raid, deer, bear and first-snow arguments |

The new tests cover deterministic results, date boundaries, canceled actions, duplicate completion, daily salmon depletion, food mass, cache/rack raids, live night-bear spawning and shouting, pack-limited harvesting, ammunition, deer flight, season-long kills, hide-only sales, failed settlement, batch smoking, the tent, natural/sleep endings, immutable final totals, and sandbox rewind. The miner test evaluates all thirty imported animations and all thirty-two existing travel-equipment combinations.

At 1920×1080, VSync disabled, with 600 warmed frames per scene, the isolated run on this RTX 5080 recorded:

| Scene | Median | p95 | 5.5 ms budget |
| --- | ---: | ---: | --- |
| Live salmon riffle | 3.31 ms | 3.89 ms | Pass |
| Fire and raiding bear | 3.32 ms | 4.22 ms | Pass |
| Snow, tent and camp | 3.32 ms | 3.64 ms | Pass |

See `artifacts/expedition-performance-isolated.log`. The first run, with the earlier debug game still running, exceeded budget (7.20–8.07 ms p95); its log is retained. These are local-machine timings, not a minimum-hardware claim. Godot still reports the previously documented reflection-texture cleanup warning in rendered runs; some headless teardown paths also report ObjectDB cleanup warnings. Functional pass lines are separate from those engine warnings.

## Render review

All nine final captures were opened and visually inspected. Each passed the existing camera composition ray guard. Close-up material/subject segmentation coverage has **not** been added for these new shots; the ray guard is not an art-quality or subject-coverage score.

| Capture in `artifacts/phase2/` | Visual critique |
| --- | --- |
| `m12_spear_detail.png` | Both hands now meet the shaft and the fork reads as metal, but the catch is difficult to distinguish beneath the water. |
| `m12_spear_player.png` | The action stays grounded at the bank; the normal camera still gives the salmon and spear tip too little visual emphasis. |
| `m12_raid.png` | The bear, miner, cache and fire are readable together, though the bear's approach/eating performance remains simple. |
| `m13_rifle_detail.png` | The rifle has a shaped stock, barrel and lock with a shoulder-height hold; cheek contact, support-hand grip and recoil/reloading still need animation refinement. |
| `m13_rifle_player.png` | The standing deer are readable in a clear lane, but the shot needs stronger visual feedback. |
| `m13_hide_trade.png` | The slate includes hide credit and the hide lies on the barrel; the offered rifle stands too upright on the counter and the hide needs richer surface treatment. |
| `m14_tent.png` | The open canvas shelter replaces the lean-to, but plain canvas, missing guy lines and strong fire tint leave it visually unfinished. |
| `m14_snow.png` | Falling flakes and a pale ground layer establish the ending; snow deposition on rocks, foliage and shelter is still rudimentary. |
| `m14_final_ledger.png` | The final account is legible and belongs to the camp ledger; it is a functional ending rather than a finished cinematic sequence. |

`contact_sheet.jpg` collects the views. These are engine renders, not concept mockups.

## What remains open

1. **Existing economy findings.** The unchanged full-season simulation still returns `SEASON DESIGN FINDINGS`: the first two careful trips are less than thirty days apart, starting salt is replenished before it runs out, and the spendthrift never encounters sold-out stock. Careful ends at $19,325.34 equivalent value / condition 100; careless at $15,121.48 / condition 5; spendthrift at $173.32 / condition 100. No policies, depletion thresholds or acceptance assertions were relaxed to force a pass. See `artifacts/season-summary.md` and the three CSVs.
2. **Simulation scope.** That established 132-day simulation covers the earlier fishing/camp/store economy. The new encounters are tested directly, but there is not yet a new whole-season policy simulation that chooses between hand-line fishing, salmon, hunting, cache use and purchases together. It should precede final economic sign-off.
3. **Visual acceptance.** Improve fish visibility from the ordinary camera before accepting the fishery. Existing M9 live pressure-wiring and visual findings remain open. Finish the rifle's hand/cheek contact, firing/reload feedback, bear performance, tent construction detail and snow deposition. Add the missing new-shot coverage probes; do not count the composition ray guard as a substitute.
4. **Audio and extended playtesting.** The four generated sounds are wired into actions, but the synthesized shout and rifle report need listening/mix review. Long controller-only play, all 47 salmon-run dates under varying water/weather, repeated multi-day store/encounter round trips, and a continuous real-time season have not been exhaustively exercised.

Model choices needing balance review are recorded in [MILESTONE_12.md](MILESTONE_12.md), [MILESTONE_13.md](MILESTONE_13.md), and [MILESTONE_14.md](MILESTONE_14.md). Regression amendments only release newly available goods and change the bear's old proximity-flight expectation to deliberate shouting; economic thresholds remain unchanged.

## Rebuild

```powershell
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python blender/build_expedition_props.py
& 'C:/Program Files/Blender Foundation/Blender 5.2/blender.exe' --background --python blender/build_expedition_animation.py
python audio/build_expedition_audio.py
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --editor --path . --import --quit
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/milestone_12.gd
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/milestone_13.gd
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --headless --fixed-fps 60 --path . --script tests/milestone_14.gd
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/expedition_capture.gd
& ./.tools/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/expedition_performance.gd
```

The Blender animation builder adds only new clip branches to the shared solver; the existing exported animations are not regenerated. Major character components remain separate and editable.
