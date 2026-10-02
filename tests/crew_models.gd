extends SceneTree
## 2.0 outfit rules: hiring, step-independent work, depletion, nights, hauls,
## the foreman, and a whole season run by a crew.
const Crew=preload("res://scripts/crew_model.gd")
const Gold=preload("res://scripts/gold_map.gd")
const Layout=preload("res://scripts/claim_layout.gd")
const Prices=preload("res://scripts/prices.gd")
var failures: Array[String]=[]
func check(ok: bool, label: String) -> void:
	if not ok: failures.append(label)
	print(("PASS: " if ok else "FAIL: ")+label)

func _initialize() -> void:
	_run.call_deferred()

func _mining() -> Dictionary:
	return {"taken":[0.0,0.0],"crevice_actions":[0,0],"rocker_position":Vector3.ZERO,"rocker_built":false,"rocker_actions":0}

func _inventory() -> Dictionary:
	return {"hooks":4,"line_m":20.0,"fish":[],"goods":{"flour":40.0,"beans":20.0,"pork":10.0,"coffee":0.0,"salt":2.0},"pans":4,"bunks":1,"whiskey":0,"strongbox":false,"shovel":true,"crowbar":true}

func _run() -> void:
	# Hiring windows.
	var state:=Crew.initial()
	check(Crew.applicants(state,5).is_empty(),"nobody comes before word spreads")
	check(Crew.applicants(state,6).map(func(m): return m.id)==["pike"],"Pike waits at the trail on day 6")
	check(not Crew.applicants(state,11).any(func(m): return m.id=="pike"),"an applicant moves on after five days")
	check(Crew.hire(state,"pike",6) and not Crew.hire(state,"pike",6),"a man is hired once")
	Crew.dismiss(state,"pike")
	check(not Crew.hire(state,"pike",7) and Crew.applicants(state,7).is_empty(),"a dismissed man does not come back")
	check(Crew.wage("ruiz",120,1848)>Crew.wage("ruiz",56,1848)*1.2,"wages climb with the rush")
	check(Crew.abs_hour(3,2.0)==3*24+26.0 and Crew.abs_hour(3,6.0)==78.0,"night hours belong to the evening's day")
	check(Crew.work_hours(Crew.abs_hour(0,5),Crew.abs_hour(0,23)).size()==2,"two shifts a day")

	# Step-independent, deterministic work.
	var spots: Array=[]
	for p in Gold.peak_points(): spots.append({"x":p.x,"z":p.y,"samples":3,"ounces":.3,"day":0})
	var results: Array=[]
	for steps in [1,130]:
		var s:=Crew.initial();s.spots=spots.duplicate(true)
		for id in ["boyle","soto","kalama"]: Crew.hire(s,id,30)
		var inv:=_inventory();var log: Array=[]
		Crew.assign_spots(s,0.0)
		var total:=0.0
		for i in steps:
			total+=Crew.work(s,inv,_mining(),30,6.0+13.0*i/steps,6.0+13.0*(i+1)/steps,1848,0.0,log).ounces
		results.append(total)
	check(results[0]>0 and is_equal_approx(results[0],results[1]),"a day's take does not depend on frame steps (%.3f / %.3f)" % results)

	# The ground gives out.
	var worked: Dictionary={}
	var peak: Vector2=Gold.peak_points()[0]
	var before:=Crew.worked_density(worked,peak.x,peak.y)
	Crew.take(worked,peak.x,peak.y,Crew.cell_reserve(Crew.cell(peak.x,peak.y))*.5)
	check(is_equal_approx(Crew.worked_density(worked,peak.x,peak.y),before*.5),"half the reserve taken halves the ground")
	Crew.take(worked,peak.x,peak.y,999)
	check(Crew.worked_density(worked,peak.x,peak.y)==0.0,"worked-out ground is barren")
	check(Crew.worked_density(worked,peak.x+6,peak.y)==Gold.density_at(peak.x+6,peak.y),"other cells untouched")

	# Spots: panners spread out and avoid the river.
	var s2:=Crew.initial();s2.spots=spots.duplicate(true)
	for id in ["pike","boyle","soto","kalama"]: Crew.hire(s2,id,30)
	Crew.assign_spots(s2,0.0)
	var used: Array[Vector2]=[]
	for h in s2.hands:
		var spot: Dictionary=s2.spots[h.spot]
		check(Crew.workable(Vector2(spot.x,spot.z),0.0),"%s works reachable ground" % h.name)
		check(not used.any(func(u): return u.distance_to(Vector2(spot.x,spot.z))<2.4),"%s keeps his elbow room" % h.name)
		used.append(Vector2(spot.x,spot.z))
	var inv2:=_inventory();inv2.pans=2
	check(Crew.job_ready(s2,s2.hands[2],inv2,_mining(),0.0)=="needs a pan","the third panner needs a third pan")

	# Nights: wages from coin then dust, hunger, desertion, theft and the strongbox.
	var s3:=Crew.initial()
	for id in ["pike","boyle"]: Crew.hire(s3,id,10)
	var inv3:=_inventory()
	var paid:=Crew.night(s3,inv3,{"dollars":5.0,"ounces":2.0,"gold_price":16.0},10,1848,"clear",true)
	check(is_equal_approx(paid.dollars,5.0) and paid.ounces>0,"coin first, then dust at the day's price")
	check(s3.hands.all(func(h): return h.unpaid==0 and h.hungry==0),"paid and fed")
	var inv_empty:=_inventory();inv_empty.goods={"flour":0.0,"beans":0.0,"pork":0.0,"salt":0.0,"coffee":0.0}
	for night in 2: Crew.night(s3,inv_empty,{"dollars":0.0,"ounces":0.0,"gold_price":16.0},11+night,1848,"rain",false)
	check(s3.hands.is_empty(),"unpaid, hungry men leave after two nights")
	var thefts:=0;var boxed:=0
	for trial in 40:
		for box in [false,true]:
			var s4:=Crew.initial();Crew.hire(s4,"pike",20);s4.hands[0].morale=5
			var inv4:=_inventory();inv4.strongbox=box
			var night:=Crew.night(s4,inv4,{"dollars":50.0,"ounces":4.0,"gold_price":16.0},20+trial,1848,"clear",false)
			if night.stolen>0:
				if box: boxed+=1
				else: thefts+=1
	check(thefts>10 and boxed==0,"a disloyal man can rob the camp; the strongbox stops him (%d)" % thefts)

	# Hauling: a week of rations within stock, funds and a strong back.
	var s5:=Crew.initial()
	for id in ["soto","boyle","pike"]: Crew.hire(s5,id,40)
	s5.hands[0].job="haul"
	var inv5:=_inventory();inv5.goods={"flour":0.0,"beans":0.0,"pork":0.0,"salt":0.0,"coffee":0.0}
	var purchases: Array=[]
	var run:=Crew.haul(s5,inv5,purchases,{"dollars":20.0,"ounces":3.0},40,1848,s5.hands[0])
	check(run.pounds<=Crew.HAUL_LB*1.4+.001 and run.pounds>30,"the hauler carries a full load (%.1f lb)" % run.pounds)
	check(not purchases.is_empty() and Crew.provisions(inv5)>20,"bought goods reach camp and the store's stock")
	check(run.dollars<=20.0+.001,"coin is spent before dust")

	# The foreman sets the outfit to work.
	var s6:=Crew.initial();s6.spots=spots.duplicate(true)
	for man in Crew.ROSTER.slice(0,8): Crew.hire(s6,man.id,60)
	var mining:=_mining();mining.rocker_built=true
	var bank: float=preload("res://scripts/river_model.gd").shore_z(0,-.6)+.3
	mining.rocker_position=Vector3(0,Layout.height_at(0,bank),bank)
	var inv6:=_inventory();inv6.pans=3
	Crew.auto_assign(s6,inv6,mining,-.6,60,1848)
	var jobs: Dictionary={}
	for h in s6.hands: jobs[h.job]=jobs.get(h.job,0)+1
	check(jobs.get("cook",0)==1 and jobs.get("pan",0)<=3 and jobs.get("rest",0)==0,"a cook, no more panners than pans, nobody idle %s" % jobs)
	check(jobs.get("rocker",0)>=3 and jobs.get("crevice",0)>=1,"cradle team and bedrock crevicers %s" % jobs)
	check(s6.hands.filter(func(h): return h.job=="cook")[0].id=="brandt","the best cook takes the skillet")

	# The wing dam: labour, low water, the dry channel, and the autumn rise.
	var s7:=Crew.initial()
	for man in Crew.ROSTER.slice(0,6): Crew.hire(s7,man.id,60)
	var inv7:=_inventory();inv7.pick=true;inv7.timber=0
	check(Crew.dam_blocker(s7,inv7,-.6)=="needs dam timber","no timber, no dam")
	inv7.timber=1
	check(Crew.dam_blocker(s7,inv7,-.2)=="river too high" and Crew.dam_blocker(s7,inv7,-.6)=="","the dam waits for low water")
	for h in s7.hands: h.job="dam"
	var log7: Array=[]
	Crew.work(s7,inv7,_mining(),60,6.0,19.0,1848,-.6,log7)
	check(not s7.dam.built and s7.dam.progress>40,"a day's labour raises part of the crib (%.0f man-hours)" % s7.dam.progress)
	for d in 4: Crew.work(s7,inv7,_mining(),61+d,6.0,19.0,1848,-.6,log7)
	check(s7.dam.built and inv7.timber==0,"the crib closes and uses the timber")
	var mid:=Vector2(-4,Layout.shore_z(-4)-6.4)
	check(Crew.in_channel(s7,mid.x,mid.y) and not Crew.in_channel(s7,-4,Layout.shore_z(-4)-12) and not Crew.in_channel(s7,20,mid.y),"the channel is the bed inside the crib")
	check(Crew.channel_density(mid.x,mid.y)>.6,"the pay streak lies on the old thalweg")
	for h in s7.hands: h.job="channel"
	var washed: float=Crew.work(s7,inv7,_mining(),66,6.0,19.0,1848,-.6,log7).ounces
	check(washed>15,"a crew in the channel washes a bonanza day (%.1f oz)" % washed)
	var rise:=Crew.night(s7,inv7,{"dollars":500.0,"ounces":0.0,"gold_price":16.0,"water":-.2},66,1848,"rain",true)
	check(not s7.dam.built and s7.dam.progress==0 and rise.notes.any(func(n): return "took the wing dam" in n),"the autumn rise takes the dam")
	var s8:=Crew.initial();s8.dam.built=true;s8.dam.progress=Crew.DAM_HOURS
	check(Crew.washout(s8,-.6)=="" and Crew.washout(s8,-.1)!="" and not s8.dam.built,"the rise takes a dam even with no men left")
	s8.dam.built=true
	check(not Crew.best_fish_spot(70,7.0,1848,[],s8).is_empty() and not Crew.in_channel(s8,Crew.best_fish_spot(70,7.0,1848,[],s8).position.x,Crew.best_fish_spot(70,7.0,1848,[],s8).position.y),"fishermen never fish the dry channel")
	var s9:=Crew.initial();Crew.hire(s9,"pike",10)
	for i in 48: Crew.record_prospect(s9,Vector3(-38+i*1.7,0,Layout.shore_z(-38+i*1.7)+.5),.001*i,10)
	s9.hands[0].spot=3;var held: Dictionary=s9.spots[3]
	Crew.record_prospect(s9,Vector3(39,0,Layout.shore_z(39)+.5),.9,11)
	check(s9.hands[0].spot==-1 or s9.spots[s9.hands[0].spot]==held,"a trimmed prospect log never moves a panner to other ground")
	var reckless: float=await _season(12,false)
	var prudent: float=await _season(6,true)
	check(prudent>reckless,"a lean, tooled outfit beats hiring every drifter ($%.0f vs $%.0f)" % [prudent,reckless])
	check(prudent>2500,"a well-run claim makes the season pay ($%.0f)" % prudent)
	print("CREW MODELS ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)

## A boss's season: hire up to `cap` men as they come, pans and bunks for all, a
## foreman from the first hire, and only the miner's early prospecting to guide
## them. A tooled boss also buys the cradle, shovel and crowbar and keeps the
## cradle beside running water as the river falls and rises.
func _season(cap: int, tooled: bool) -> float:
	var game: Node=root.get_node("GameState")
	var sack: Node=root.get_node("Sack")
	game.crew=Crew.initial()
	game.apply_scenario({"day":"0","dollars":"60","crowbar":"0","shovel":"0","rocker":"0","pans":"0","bunks":"0"})
	game.mining={"taken":[0.0,0.0],"crevice_actions":[0,0],"rocker_position":Vector3.ZERO,"rocker_built":false,"rocker_actions":0}
	game.season_ended=false
	game.inventory.goods={"flour":0.0,"beans":0.0,"pork":0.0,"coffee":0.0,"salt":2.0}
	sack.ounces=0
	for p in Gold.peak_points(): Crew.record_prospect(game.crew,Vector3(p.x,0,p.y),.08,0)
	for x in range(-36,37,6): Crew.record_prospect(game.crew,Vector3(x,0,Layout.shore_z(x)+.6),.01,0)
	var lines: Array[String]=[]
	var peak_hands:=0
	var spend:=func(cost: float) -> bool:
		if game.dollars+sack.ounces*14<cost: return false
		var from_coin: float=minf(game.dollars,cost);game.dollars-=from_coin;sack.ounces-=(cost-from_coin)/14.0
		return true
	for d in 132:
		for man in Crew.applicants(game.crew,game.day):
			if game.crew.hands.size()<cap: Crew.hire(game.crew,man.id,game.day)
		if game.crew.hands.size()>0 and Crew.foreman(game.crew).is_empty(): game.crew.hands[0].foreman=true
		if tooled and game.day>=12 and not game.inventory.get("rocker",false):
			var kit: float=0.0
			for item in ["rocker","shovel","crowbar"]: kit+=Prices.price(item,game.day,game.seed)
			if spend.call(kit): game.inventory.rocker=true;game.inventory.shovel=true;game.inventory.crowbar=true
		if tooled and game.day>=48 and game.crew.dam.progress==0 and not game.crew.dam.built and int(game.inventory.timber)==0 and game.water_level()<-.45:
			if spend.call(Prices.price("timber",game.day,game.seed)+Prices.price("pick",game.day,game.seed)): game.inventory.timber=1;game.inventory.pick=true
		if false:
			for x in range(-30,31,2):
				var z: float=Crew.RiverModel.shore_z(x,game.water_level())+.25
				var p:=Vector3(x,Layout.height_at(x,z),z)
				if preload("res://scripts/mining_model.gd").rocker_site(p,game.water_level()):
					game.mining.rocker_position=p;game.mining.rocker_built=true;break
		var short_pans: int=maxi(0,game.crew.hands.size()-int(game.inventory.pans))
		var short_bunks: int=maxi(0,Crew.bunks_needed(game.crew)-int(game.inventory.bunks))
		if short_pans+short_bunks>0 and spend.call(short_pans*Prices.price("pan",game.day,game.seed)+short_bunks*Prices.price("bunk",game.day,game.seed)):
			game.inventory.pans+=short_pans;game.inventory.bunks+=short_bunks
		game.morning_orders()
		game.crew.fire_tonight=true
		for half in range(12,40): game.crew_tick(half*.5)
		peak_hands=maxi(peak_hands,game.crew.hands.size())
		if d%15==0 or d==131:
			var morale:=0.0
			for h in game.crew.hands: morale+=h.morale/maxf(1,game.crew.hands.size())
			lines.append("day %3d  hands %2d  sack %7.2f oz  coin $%8.2f  take %7.2f  wages $%8.2f  morale %3.0f  food %.0f lb  %s" % [game.day,game.crew.hands.size(),sack.ounces,game.dollars,game.crew.take_total,game.crew.wages_paid,morale,Crew.provisions(game.inventory),game.crew.bar_name])
		game.end_day()
		await process_frame
	print("--- season: up to %d hands, %s" % [cap,"tooled" if tooled else "pans only"])
	for line in lines: print(line)
	var worth: float=game.dollars+sack.ounces*16
	print("SEASON WITH A CREW: worth $%.2f, take %.1f oz, %d hauls, %d departed, title '%s'" % [worth,game.crew.take_total,game.crew.hauls,game.crew.departed.size(),game.final_ledger.get("title","")])
	check(game.season_ended and game.final_ledger.has("title"),"the season ends with a verdict")
	check(game.crew.take_total>100,"a crew washes real gold (%.1f oz)" % game.crew.take_total)
	check(game.crew.take_total<2200,"the bar is finite (%.1f oz)" % game.crew.take_total)
	check(peak_hands>=mini(cap,6),"a claim can grow to %d hands (%d)" % [mini(cap,6),peak_hands])
	return worth
