# Tools and the falling river

At Lambert's, buy a crowbar (the horn spoon comes with it), boots, a shovel,
a pick, or the lumber and iron for a rocker. Use the same G selection and slate
settlement as food. You only need one of each.

The river falls through summer. By mid-August, the two bedrock slabs beside the
boulder lees are exposed. Stand near the downstream edge and press **G / X** to
work the crevice. The miner loosens the crack with the crowbar and cleans it with
the spoon. Gold goes into the sack after 18 seconds. A worked-out slab stays
worked out. October high water prevents crevicing.

Boots let you work in water up to about 70 cm deep. They do not let you swim.

With a rocker kit, walk along dry gravel just beside the water and face the river.
The **Build rocker** prompt appears where there is room and running water.
Press G to build, then approach its handle with a shovel and press G again.
Loading takes 14 seconds, or eight with a pick; rocking takes another 40 seconds.
Each load washes ten pans' worth of gravel from the loading position. Choose
your ground: the rocker still uses the claim's gold geology.

If the river moves away or floods the site, the prompt becomes **Move rocker**.
Pack it with G, walk to the new bank, and build it there. Escape stops active
work without awarding gold. The ledger records finished work and owned tools.

## Quick playtests

From PowerShell in the project directory:

```powershell
.\Play.cmd day=75 hour=8 weather=clear crowbar=1 boots=1 work=crevice
.\Play.cmd day=75 hour=8 weather=clear rocker=1 shovel=1 pick=1 work=rocker
.\Play.cmd day=120 hour=8 weather=rain crowbar=1 boots=1 work=crevice
.\Play.cmd scene=store day=30 dollars=150
```

The first two place you directly at the work areas with equipment. The third
shows the flooded slab. F4 also provides **Crevice** and **Rocker bank** shortcuts,
equipment fields (0/1), and **Seasonal river level**. Uncheck that option to apply
the numeric river field; keep it checked to follow the date and weather.

The kit is a separate lumber bundle. Pick, shovel and crowbar weigh 17 lb
together in the ordinary pack; boots are worn. Session state persists through
store trips and days, but the project still has no disk save system.
