# How to fish — Milestone 9 playtest

Start with trout at dusk. This guide describes the current review build, including
its tight strike window and the new line tension meter.

## 1. Give yourself a test kit

Open PowerShell in the `1848` folder and run:

```powershell
.\Play.cmd -- day=20 hour=18.5 weather=clear condition=85 hooks=20 line=40 bait.grasshopper=20 bait.hellgrammite=10 bait.worm=10 firewood=10
```

Or launch normally, press **F4**, and set those values in the sandbox. Scroll down
to **Apply**, click it, then close the panel with **F4**. Applying resets the fishing
action; finish or cancel an attempt before changing the setup. Time keeps passing
while the panel is open.

The default game starts without bait. Supplying bait here lets you test fishing
immediately. There is no save system or hook shop yet.

## 2. Find a trout pool

Walk to the water's edge near a large shoreline boulder. Start with the pool just
downstream of the boulder at world X = −14, toward the negative-X end of the bar.
There is no coordinate display in the player HUD: use the boulder's sheltered water
and visible fish as your landmarks.

Stay on the bank or in shallow water, at most about knee depth (0.45 m). Tap F to
check your position; the aiming ring means you can fish there. There is no idle
fishing prompt. Deep wading and standing too far inland prevent fishing. Finish
any panning or camp action first.

Look into the pool for fish silhouettes. Aim near them, slightly clear of the rock
itself. A fish must be within about four metres of the bait for an attempt to attract
it. Casting into empty water can produce no bite at all.

## 3. Make your first catch

1. **Tap F** to enter the fishing stance. The miner turns toward the river and an
   aiming ring appears on the water.
2. **Choose Grasshopper.** Tap **G**, or turn the mouse wheel, to cycle through bait
   you own. The selected bait and your hook count appear on the HUD.
3. **Aim with the camera.** Move the mouse to put the ring in the pool near the
   fish. Cast range is limited to eight metres.
4. **Tap F again to cast, then release it.** The cast takes about 1.2 seconds.
5. **Wait and watch the bait.** A fish approaches before the bite. Do not strike
   merely because it starts approaching. At the bite, the line twitches sideways
   and a short sound plays.
6. **Press F just after the twitch, then hold it to pull.** The valid strike window
   is **0.15–0.75 seconds after the bite starts**. Think “a short reaction after the
   twitch,” not an instant reflex or a long pause. Do not mash F while waiting.
7. **Watch LINE TENSION and release F when told.** The meter appears during the fight.
   It warns **FISH ABOUT TO RUN**, then **FISH RUNNING · Release F / Y**. Pulling during
   the run raises tension; letting go lowers it. Yellow means caution, red means
   danger, and **100% breaks the line**. Release until the run ends and the meter
   drops, then hold F again when it says to pull. You have roughly half a second to
   react after a run begins at normal working tension. The fish's sideways movement
   is an additional cue; you can now play by watching the meter.
8. **Let the landing finish.** Once the fish is tired and close enough, the miner
   lifts it automatically. After the lift, a close-up appears and the catch is
   recorded. Do not cancel during the lift. The close-up ends automatically after
   about 2.5 seconds; F also returns you to the stance.

A small trout fight should take several seconds; a one-pound fish takes about seven
seconds with well-timed releases. The first run starts roughly 2–4 seconds into the
fight, lasts 0.8 seconds, and subsequent runs start 3.6 seconds apart. These timings
are useful for diagnosing the test; the meter's release warning should be enough to play.

**Gamepad:** Y replaces F; X replaces G; use the right stick to aim the camera.

## 4. Recast, cancel, or recover

| Situation | What to do / what to expect |
| --- | --- |
| No bite after a while | Tap F to retrieve into the stance, adjust the ring, then tap F again to recast. Try nearer a visible fish or another pool. |
| “Snagged” | Hold F continuously for 1.5 seconds. The line either frees or costs one hook and two metres of line. |
| “The bait is gone” | You missed the strike window. One bait is consumed; choose or cast the next bait. |
| “Line broke — 100% tension” | You kept pulling until the meter filled. Expect one hook, two metres of line, and the loaded bait to be lost. Release sooner on the next run. |
| “No hooks” / “Not enough line” / “No bait” | Refill with F4. Fishing needs at least one hook, six metres of line, and an available bait. |
| “Fish from the water's edge” | Move closer to the shoreline or back out of deeper water; finish other activities. |
| Leave fishing | Press Escape. From the catch close-up, Escape first returns to the stance; press it again to leave. |

Retrieving before a bite, striking too early, or cancelling an ordinary cast keeps
the bait. A missed bite or landed catch consumes it. The displayed bait count includes
the bait currently on the line, so it need not drop as soon as you cast.

The measured dusk trout wait averaged about 16 seconds in the model. It is random,
not a countdown or a guaranteed maximum. Position, bait, moving fish and time of day
all matter. Use **F4 → Dusk** to restore evening light and **Refresh fish** to rebuild
the population after catching or frightening fish. Close the panel before playing.

## 5. Test gathering without supplied bait

Leave the fishing stance, walk until a **Gather** prompt appears, and press **G**.
Each attempt takes about two seconds. Bait gathering succeeds about 70% of the time;
“Nothing this time” is an expected result.

| Bait | Where and when | Daily attempt limit |
| --- | --- | --- |
| Grasshopper | Near grass, 09:00–18:00, without rain | 6 |
| Hellgrammite | At wet shoreline rocks or slab edges | 4 |
| Worm | Oak duff before 09:00 or from 18:00 onward | 4 |

Grasshoppers, hellgrammites and worms can all catch trout. Pork is supplied through
the sandbox for now. Salmon in the autumn riffle are scenery for this milestone and
cannot be caught on the handline.

## 6. Check that the catch feeds the camp loop

1. Leave fishing and walk inland to the camp under the central oak.
2. Approach the fire ring and press **G**. Lighting takes three driftwood from your
   inventory. The test kit supplies ten.
3. Approach the skillet on the riverward side of the fire and press **G**, then **F**
   to confirm frying. The miner moves into position and holds the skillet over the
   coals. **Frying fish** appears while it cooks. Allow roughly half a minute; eating
   follows automatically, then the skillet returns to its resting spot.
4. At the crate, press **G** to open the ledger. Check the catch entry and meal count.
   A fried meal restores 20 condition, capped at 100.
5. Close the ledger with G or Escape. At the bedroll, press **G** to sleep.
6. Reopen the ledger next morning. Check the new date and any missed-meal entries.
   A single meal does not satisfy both of the day's meal checks.

If you already carry cooked or smoked food, G may eat that instead of opening the
frying choice. For a clean fry test, begin without stored meals. A fish weighing at
least two pounds yields a second cooked portion. If the catch is proving difficult,
F4 can supply `fish.fresh=1` to test cooking separately; note that it was supplied.

## 7. What to report

Try a normal catch first, then deliberately miss one bite and hold through one run.
Record the starting hook, line and bait counts so losses are easy to verify.

- Could you find fish and follow the approach through the water?
- Was the bite twitch visible or audible enough to react to?
- Could you tell when to release, or did the line seem to break without warning?
- Did waiting feel like fishing? Note roughly how long you waited and the bait used.
- Did the lift, close-up and ledger record match the fish you caught?
- Did frying, sleeping and the next morning's ledger make sense?

For a bug, include **day, hour, weather, bait, location/nearby boulder, and the last
few button presses**. A short clip is especially useful for missed strikes and runs.
The approach, strike timing, thin line and stiff catch grip are particular review
targets in this build.
