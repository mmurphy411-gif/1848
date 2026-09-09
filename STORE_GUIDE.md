# Testing Lambert's store

Start with:

```bat
Play.cmd day=30 hour=6.5 dollars=0 hooks=2 goods.salt=0.2
```

Press **F4** for the sandbox, set **gold to 3**, add one smoked fish, and
press **Apply**. Close F4. Keep this session running for the second visit;
purchases and the ledger belong to the current session.

## First trip

1. Walk behind camp, inland from the river. The worn trail begins six meters
   behind the fire. Face along it and press **G** at **Set out for Lambert's**.
   Leave before 09:00, with fishing, panning, and cooking finished. A carried
   smoked fish or cooked portion is eaten on the trail.
2. Watch the rim shot, then follow the curved path to the counter. Arrival
   is six game hours after departure. Shopping pauses the clock.
3. Approach and look at the board left of the counter. Its reading camera
   should make the date, gold rate, and eight prices clear. **Esc** releases
   a reading camera so you can look around again.
4. Look at the scale on the counter's left. **Hold G** to pour, then release
   to stop. Two seconds pours 0.50 oz; Lambert calls it 0.46 oz. Watch the
   sack, gold stream, moving beam, weights, and slate. The credited coin
   appears on release. You can sell as much or as little as you wish.
5. Aim at a shelf item and press **G** once per unit. Flour, beans, pork,
   coffee, and salt sell by the pound; hooks individually; line in 20 m coils.
   Buy a few pounds of flour and pork, salt, hooks, and one coil. Look down
   at the counter pile and press **G** to return the last item.
6. Look at the slate and press **G** to settle. Coin pays first. If more is
   needed, the miner pours the exact dust shortfall automatically. Lambert
   writes and hands the purchase over. The slate clears and goods enter
   your pack. **Esc** releases the slate camera.
7. Walk back to the approach trail, face away from the tent, and press **G**
   at **Home · by dusk**. The return view should have evening light and no
   burning campfire. Departure at 07:00 returns at 19:00.

The counter total is a pending purchase. Walking home returns everything
still in the pile. Smoked fish offered at the barrel also remain yours until
settlement; **G** at the barrel toggles the offer on and off.

## Cook and check the ledger

Gather wood and light the fire. Aim at the skillet and press **G** to open
its recipe choices; **G** cycles and **F** cooks the selected recipe. Pork
uses 0.5 lb and takes ten game minutes. Biscuits use 0.5 lb flour and 0.02 lb
salt and take fifteen minutes. A second biscuit batch while staying at camp
becomes a carried portion.

The pot offers beans and coffee. Beans require two hours of remaining fire
and leave two carried portions after eating. Coffee takes ten minutes and
gives +5 condition once before 10:00. Smoking requires 0.1 lb salt per fish.

At the crate, **G** cycles through eating carried food, cutting pork bait,
and the ledger when those actions are available. Each bait cutting consumes
0.25 lb pork and makes four baits. Sleep at the bedroll, then read the ledger.
Check the actual ounces sold, Lambert's lower weighed amount, purchases,
remaining coin, and the price page.

For the second visit, use F4 to move to **day 65**, set the hour to **07:00**
and gold to **3**, and Apply. Keep the existing goods. Visit again, buy an
item, return, and read the ledger. Compare the board and the prior prices
written in the ledger margin.

## Focused checks

| Check | Setup and expected result |
| --- | --- |
| Direct store entry | `Play.cmd scene=store day=100` opens at the counter with October prices. |
| Cannot pay | F4 sets gold and dollars to zero; select flour and settle. `SHORT` appears and the last item returns. |
| Display goods | Aim at a pick, rifle, or other display item and press G: `Not this trip`. |
| Pack limit | Set flour to 39 lb, salt to zero, line to zero, rod off. The first pound fits; the next says `Too heavy`. Fish also weigh something. |
| Finite stock | Buy both rods across day 36 using fresh test ownership in F4; the peg becomes empty. A second owned rod is refused. There is no debug stock editor. |
| Fish sale | Set three smoked fish in F4, offer them at the barrel, settle; inspect coin and inventory. Toggle the offer twice first to verify undo. |
| Rod | `Play.cmd day=40 rod=1 bait.grasshopper=6`: enter fishing with F, use G to choose bait, cast with F. Aim far across the water; the limit is 12 m. Release F during a run. |
| Travel shortcut | F4 **Go to store** and **Home** bypass the late-departure rule and transition shots. Use the trail for testing the real trip. |
| Rain | In the store, set weather to rain in F4 and Apply; allow thirty seconds for the weather blend. Rain should stop at the canvas. |

Current balance findings: starting without food produces early repeat trips;
the careful policy replenishes salt before exhausting it; the specified
shipments accumulate faster than the spendthrift buys stock. October shelves
therefore remain stocked. These rules have been preserved for review.
