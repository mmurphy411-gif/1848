# 1848 · 2.0 — The Outfit

Phase 2 gave the miner a season. 2.0 gives him the choice to stop being one man
on one bar. Panning is still the heart of the game, and you can still play the
whole season alone. But by August, men are coming up the Yuba looking for work,
and a claim can grow into a small company that runs itself while you fish, hunt,
take daguerreotypes, or sit by the fire and let the day pass.

This branch (`2.0`) forks from `master` at `9e7656c`.

## What's new

### Hired hands
- **Fourteen men** come up the trail on their own schedule, from July 2 (a sailor
  off an abandoned ship) to October (a Methodist exhorter who has signed the
  pledge). Each one waits at the trailhead above camp for five days, then moves on.
  Walk up and press **G** to hire him, or hire from the roll book.
- They are the men who were really on the rivers in 1848: a Mormon Battalion
  veteran who dug Sutter's millrace, a Californio vaquero, a Kanaka from Honolulu,
  Lambert's voyageur cousin, an Oregon farmer, a discharged New York Volunteer, a
  Sonoran *gambusino*, a Chilean miner from Copiapó, a New Bedford ship's cook.
  Each has skills (pan, cradle, crevice, fish, cook, haul) and a loyalty.
- **Jobs:** panning, the cradle (up to three men; one rocks, one shovels, one
  picks), crevicing (one man per exposed slab), fishing, camp cook, hauling, the
  wing dam, the channel, or resting. Every man needs his own tools: Lambert now
  sells **tin pans**.
- **The roll book (C / LB)** shows each man's job, mood, terms and today's take.
  Here you change jobs, switch a man between **wages** and **shares** (he keeps
  40% of what he washes), name a **foreman**, or let him go.
- **The foreman** runs the claim. Each dawn he sets every man to the best work
  the tools allow, has the cradle carried to better gravel, prospects four new
  spots on the bar, and sends a hauler to Lambert's when rations run short. With
  a foreman the claim truly runs itself.
- **Your pans teach the crew.** Every pan you take is written into a prospect log,
  and panners work the best ground you have found. Find the gold; they work it.
- **The camp cook** feeds you too, so your condition holds while you work.
- **Nights:** each man eats two pounds a day (fresh fish first, then flour,
  beans and pork) and is paid in coin, then in dust at the day's price. Bunk
  tents shelter four men apiece. Sundays are a day of rest unless you overrule
  it. Saturday whiskey cheers everyone except the teetotaler.
- **Grievances:** hunger, unpaid wages, rain on unsheltered men, Sunday work and
  plain homesickness all wear morale down. A sullen man quits, and a disloyal one
  may leave in the night with some of the camp's dust. An **iron strongbox** stops that.
- **Haulers** carry a week of rations for the whole outfit (plus hooks, salt and
  coffee) back from Lambert's. They buy from his real, finite stock, so his
  shelves run low.
- **The bar gets a name.** As the take grows, men downriver call it Greenhorn
  Bar, then Shirt-Tail Bar, Good Hope Bar, Rich Bar and finally Nabob's Bar. A claim
  notice goes up on a stake by the trail.
- **The camp grows too:** bunk tents, a crew fire, and men gathering at supper.
  From the second hand on, someone plays harmonica after dark: *Oh! Susanna*
  (published 1848, the forty-niners' anthem), *Arkansas Traveler*, and later
  *Home! Sweet Home!*. All three are original, numerically pitch-verified
  syntheses, played from the fire as diegetic sound.

### The wing dam (crew only)
At late-summer low water, an outfit of five or more with a pick, a shovel and
**dam timber** from Lambert's can build a log-crib wing dam. It takes about 200
man-hours, about three days for six men, and you can watch the logs rise. When
it closes, the river inside the crib is cut away. The dry channel bed lies
open, and the richest gold on the claim lies in the pay streak on bedrock.
Your men work it, and so can you: walk down into the channel and pan. The October
rise takes the dam, so it is a race against the rains.

### The ground runs out
Every 2 m patch of gravel holds about 600 pans. Your pans, your cradle and the
crew all draw down the same ground. A pocket that pays an ounce a day for a week
is lean by the next. The untouched bar matches the original geological map
exactly. Depletion only changes ground that has been worked.

### Playing the game
- **Title screen:** a slow drift over the river at golden hour. Choose Continue
  (with the saved date, dust, coin and hands), Begin a new season, or Settings.
  A season opens on a date card.
- **Saving:** the season saves at every dawn, and from the pause menu. It holds
  the outfit, the worked ground, the prospect log, the dam, inventory, money and
  the miner's place. Development presets (`Play.cmd encounter=…`) never write a save.
- **Pause (Esc / Start):** the world holds still. From here: the roll book, the
  ledger, settings, Save, and Save and quit.
- **Letting time pass (hold T / RB):** while you stand idle the day runs 24×
  faster. The sun, the river, the fire and the outfit all keep their pace in
  game hours, and a pocket watch shows the time.
- **Settings:** mouse look and invert, four volume buses (including the
  harmonica's), day length (20, 12 or 6 minutes), an always-on pocket watch, and
  full screen.
- **Daguerreotype photo mode (P / Back):** a free camera tethered to the miner,
  three-second "Hold still…" exposures, and three plate processes (silver
  daguerreotype in a brass case mat, salt print, cyanotype). Each plate is
  saved with a cursive caption to `user://daguerreotypes/`.

### Store and rules
- **Lambert's outfitting corner:** tin pans, bunk tents, an iron strongbox,
  whiskey by the bottle, and dam timber by mule, laid out with a hand-lettered
  sign beside the stall.
- **Rule change:** the 40 lb pack limit now counts only what you carry home that
  day. Stores already at camp stay at camp, since an outfit needs more than 40 lb.
- **Rule change:** spearing salmon and dressing game check the *field* pack:
  your catch, hides, rod, line, tools and powder. Flour and outfit gear left at
  camp no longer block a harvest.
- **Fix:** live fishing now records catch pressure, which was an open Phase 2
  finding. The fish you take thin out their own water for six days, and the
  visible school reflects it.
- **Fix:** Lambert's price board no longer runs off the bottom of the board.
- **Final ledger:** a verdict on the season, from *A Greenhorn, Going Home* to
  *Nabob of the North Yuba*, along with the outfit's take, wages and roll.

## What the numbers say

`tests/crew_models.gd` plays two whole seasons with a crew, using the real rules:

| Boss | Hands | Washed | Wages | Worth on Nov 5 | Verdict |
| --- | ---: | ---: | ---: | ---: | --- |
| Hires every drifter (up to 12), pans only | 12 at peak | 390 oz | about $5,300 | about $16 | Greenhorn, going home. The payroll outruns the gold and the men drift off in October. |
| Six good men, cradle, crowbar, a wing dam in August | 6 | 935 oz | $5,727 | about $7,990 | Nabob of the North Yuba |

The rich pockets carry an outfit through July and August. After that only the
cradle on lean ground, crevices at low water, and the wing dam keep a big payroll
honest. Shares are the hedge when the ground goes thin. This is a tuning
baseline, not a final balance pass.

## Controls added in 2.0

| Input | Action |
| --- | --- |
| C / gamepad LB | Crew roll book |
| G beside a man | Hire him (at the trail) or open his page |
| Hold T / gamepad RB | Let time pass |
| P / gamepad Back | Daguerreotype photo mode |
| Esc / gamepad Start | Pause menu (Esc still cancels an action first) |

## Under the hood
- `scripts/crew_model.gd`: every rule as a pure, seeded function of the season.
  Work is simulated in game hours and is independent of frame steps (tested), so
  the crew keeps the same pace whether you watch, fast-forward, sleep through
  the afternoon or spend the day at Lambert's.
- `scripts/crew.gd`, `crew_hand.gd`: the visible outfit. Animated miners with
  per-man tint, hair, build and gear, walking to work and playing the real
  panning, cradle, crevice, fishing, cooking and sleeping clips, with tools posed
  in both hands.
- `scripts/crew_book.gd`, `wing_dam.gd`, `save_game.gd`, `settings.gd`,
  `title.gd`, `pause_menu.gd`, `settings_panel.gd`, `menu_style.gd`,
  `time_skip.gd`, `photo_mode.gd`, `shaders/daguerreotype.gdshader`.
- `audio/build_camp_music.py`: a deterministic numpy harmonica synthesizer
  (Richter reeds, cupped-hand tremolo, breath and tongued onsets, chord reeds).
  It writes `assets/audio/tune_*.wav`.
- The water shader cuts away the river surface inside a standing dam. The river
  node reports zero depth there, so the miner, the boundary and the panner all
  agree.

## Tests
New suites: `crew_models` (rules, determinism, depletion, nights, hauling, the
foreman, the dam, two full seasons), `v2_flow` (title → new season → time skip →
hiring at the trail → roll book → pause → save/load round trip), and
`photo_mode` (45 checks). Two existing assertions changed on purpose: the
catalogue now lists the outfitting goods, and the pack-limit check reflects
the new carry rule. All suites are listed in `artifacts/v2/run_suite.sh`.

Review renders (not committed, regenerate with the scripts):
`tests/crew_capture.gd`, `tests/dam_capture.gd`, `tests/photo_mode_capture.gd`.

## Review pass
A separate review of the 2.0 code found 18 issues, 9 of them confirmed with
probes. All are fixed, and the confirmed ones have regression checks:
- The title's golden hour charged a missed meal on day 0.
- Gamepad Start opened the pause menu (and Save) over the title.
- Esc paused instead of cancelling a cast.
- A dam outlived its crew.
- Trimming the prospect log moved panners onto other ground.
- Dam logs only appeared at dawn.
- Camp stores blocked harvests.
- Crew fishermen fished the dry channel.
- Sandbox Apply cleared every tool.

Also fixed:
- Back wages are now owed until paid.
- Settling twice could beat the carry limit.
- Clicks and Esc on the title reached the game behind it.
- Mid-day saves now keep the fire, rack and coffee.
- The dry-bed margins now match the water shader.
- Save and quit no longer quits when the save fails.
- A mid-day hire no longer reshuffles everyone's jobs.

## Known gaps
- Hands have no physical collision with the miner; you can walk through them.
- Dam builders and channel men reuse the shovel, pick and pan clips. There is no
  dedicated log-carrying animation.
- The economy numbers above come from simulated bosses, not human play.
- The older Phase 2 open items (fish visibility, rifle feedback, tent detail)
  are unchanged.
