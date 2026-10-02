extends Node
signal changed
signal new_day
const Condition = preload("res://scripts/condition_model.gd")
const Cooking = preload("res://scripts/cooking.gd")
const Weather = preload("res://scripts/weather.gd")
const RiverModel = preload("res://scripts/river_model.gd")
const Expedition=preload("res://scripts/expedition_model.gd")
const CrewModel=preload("res://scripts/crew_model.gd")
const Prices=preload("res://scripts/prices.gd")
signal crew_changed
## Hired hands, the worked ground and the prospect log (2.0).
var crew: Dictionary=CrewModel.initial()
## Live play opts into dawn autosaves; tests and tools never write saves.
var autosave := false
var expedition: Dictionary=Expedition.initial()
var start_encounter := ""
var season_ended:=false
var final_ledger: Dictionary={}
signal season_finished
var seed := 1848
var day := 0
var dollars := 0.0
var purchases: Array[Dictionary]=[]
var ledger: Array[Dictionary]=[]
var scene := "claim"
var condition := 85.0
var inventory: Dictionary={"hooks":4,"line_m":20.0,"bait":{"grasshopper":0,"hellgrammite":0,"worm":0,"pork":0},"firewood":0,"fish":[],"knife":true,"meals_today":0,"cache":[],"journal":[],"catches":{},"hooks_lost":0,"midday_checked":false}
# Scenario configuration is separate from owned season state.
var start_hour := 4.75
var weather_override := "auto"
var river_override := INF
var start_work := ""
var mining: Dictionary = {"taken":[0.0,0.0],"crevice_actions":[0,0],"rocker_position":Vector3.ZERO,"rocker_built":false,"rocker_actions":0}
func _ready() -> void:
	inventory.goods={"flour":0.0,"beans":0.0,"pork":0.0,"coffee":0.0,"salt":2.0}
	inventory.rod=false
	inventory.hides=[]
	inventory.rack={}
	inventory.ammo=0
	inventory.catch_log=[]
	inventory.pans=0
	inventory.bunks=0
	inventory.strongbox=false
	inventory.whiskey=0
	inventory.timber=0
	for tool in preload("res://scripts/mining_model.gd").TOOLS: inventory[tool]=false
	var args: Dictionary={}
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=",true,1)
		if parts.size()==2: args[parts[0]]=parts[1]
	apply_scenario(args)
func apply_scenario(args: Dictionary) -> void:
	if args.has("day") and str(args.day).to_int()!=day:
		inventory.meals_today=0
		inventory.midday_checked=false
	# Inventory records use the requested date regardless of argument order.
	if args.has("day"): day=clampi(str(args.day).to_int(),0,132)
	for key in args:
		var value := str(args[key])
		match key:
			"seed": seed=value.to_int()
			"day": day=clampi(value.to_int(),0,132)
			"hour": start_hour=fposmod(value.to_float(),24)
			"dollars": dollars=maxf(0,value.to_float())
			"rod": inventory.rod=value.to_float()>=.5
			"tent","rifle","spear","crowbar","pick","shovel","boots","rocker": inventory[key]=value.to_float()>=.5
			"river": river_override=INF if value=="auto" else clampf(value.to_float(),-.75,.14)
			"encounter": start_encounter=value
			"work": start_work=value if value in ["crevice","rocker"] else ""
			"scene":
				if value in ["claim","store"]: scene=value
			"condition": condition=clampf(value.to_float(),5,100)
			"ammo","hooks","firewood","pans","bunks","whiskey": inventory[key]=maxi(0,value.to_int())
			"strongbox": inventory.strongbox=value.to_float()>=.5
			"crew":
				# Sandbox preset: hire the first N men of the roster, foreman first.
				crew=CrewModel.initial()
				for man in CrewModel.ROSTER.slice(0,clampi(value.to_int(),0,CrewModel.ROSTER.size())): CrewModel.hire(crew,man.id,day)
				if not crew.hands.is_empty(): crew.hands[0].foreman=true
			"line": inventory.line_m=maxf(0,value.to_float())
			"weather":
				if value in ["auto","clear","hot","rain","frost"]: weather_override=value
			_:
				if key.begins_with("goods.") and inventory.goods.has(key.substr(6)): inventory.goods[key.substr(6)]=maxf(0,value.to_float())
				if key.begins_with("bait.") and inventory.bait.has(key.substr(5)): inventory.bait[key.substr(5)]=maxi(0,value.to_int())
				if key in ["fish.fresh","fish.smoked"]:
					var kind: String=key.substr(5)
					var kept: Array=inventory.fish.filter(func(f): return f.state==kind)
					var wanted := clampi(value.to_int(),0,1000)
					inventory.fish=inventory.fish.filter(func(f): return f.state!=kind)
					for i in wanted:
						var f: Dictionary=kept[i] if i<kept.size() else Cooking.fresh("trout",1.0,day)
						f.state=kind
						inventory.fish.append(f)
	# A scenario is an exact snapshot, not simulated travel through skipped hours.
	if args.has("hour"): inventory.midday_checked=start_hour>=13
	if day<132 and season_ended:
		season_ended=false;final_ledger={}
	if args.has("crew") and not args.has("pans"): inventory.pans=maxi(inventory.pans,crew.hands.size())
	if args.has("crew") or args.has("pans"): morning_orders()
	crew.mark=-1.0
	changed.emit()
func weather() -> String: return Weather.state(day,seed) if weather_override=="auto" else weather_override
func water_level() -> float: return RiverModel.level(day,seed,weather()) if is_inf(river_override) else river_override
func event(message: String) -> void:
	inventory.journal.append({"day":day,"text":message})
	changed.emit()
func check_midday(hour: float, at_camp := true) -> void:
	if hour>=13 and not inventory.midday_checked:
		inventory.midday_checked=true
		if inventory.meals_today<1 and at_camp: cook_feeds()
		if inventory.meals_today<1:
			condition=Condition.missed(condition)
			event("No midday meal.")
func resolve_raid() -> void:
	if not Expedition.raid_due(expedition,day): return
	expedition.raided_day=day
	var result:=Expedition.raid_food(inventory.fish)
	inventory.fish=result.kept
	if not inventory.get("rack",{}).is_empty():
		var rack_food:=Expedition.raid_food([inventory.rack])
		if rack_food.lost_lb>0: inventory.rack={}
		result.lost_lb+=rack_food.lost_lb
	if result.lost_lb>0: event("A bear took %.2f lb of exposed food. The hanging cache was safe." % result.lost_lb)
## The camp cook keeps a plate for the boss when there is flour in the barrel.
func cook_feeds() -> bool:
	if not CrewModel.cooked(crew) or CrewModel.provisions(inventory)<.75: return false
	CrewModel.eat_rations(inventory,.75)
	condition=Condition.eat(condition);inventory.meals_today+=1
	var cook: Dictionary=crew.hands.filter(func(h): return h.job=="cook")[0]
	event("%s had a hot plate waiting." % cook.name.get_slice(" ",0))
	return true
## Called from the claim clock: the outfit works whenever game hours pass.
func crew_tick(hour: float) -> void:
	var now:=CrewModel.abs_hour(day,hour)
	if crew.mark<0 or now<crew.mark or now-crew.mark>30: crew.mark=now;return
	if now-crew.mark>=.1: _crew_work(now)
func _crew_work(until: float) -> void:
	if crew.hands.is_empty() or season_ended: crew.mark=until;return
	var from_hour: float=crew.mark-day*24.0
	var progress: float=crew.dam.progress
	var result:=CrewModel.work(crew,inventory,mining,day,from_hour,until-day*24.0,seed,water_level(),inventory.catch_log)
	crew.mark=until
	if crew.dam.progress!=progress: crew_changed.emit()
	if not result.fish.is_empty():
		inventory.fish.append_array(result.fish)
		crew["fish_total"]=int(crew.get("fish_total",0))+result.fish.size()
	if result.ounces>0: get_node("/root/Sack").add(result.ounces)
	for note in result.notes: event(note)
	if result.ounces>0 or not result.fish.is_empty() or not result.notes.is_empty(): crew_changed.emit()
## The foreman's dawn: set each man to work and sample new ground.
func morning_orders() -> void:
	if crew.hands.is_empty(): return
	if not CrewModel.foreman(crew).is_empty():
		_foreman_prospects()
		if inventory.get("rocker",false) and crew.hands.size()>=2:
			mining.owned=true
			if CrewModel.site_cradle(crew,mining,water_level()): event("%s had the cradle carried down to better gravel." % CrewModel.foreman(crew).name.get_slice(" ",0))
		CrewModel.auto_assign(crew,inventory,mining,water_level(),day,seed)
	CrewModel.assign_spots(crew,water_level())
	crew_changed.emit()
func _foreman_prospects() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=hash([seed,day,"prospect"])
	var river=preload("res://scripts/river_model.gd")
	for i in 4:
		var x:=rng.randf_range(-38,38)
		var z: float=river.shore_z(x,water_level())+rng.randf_range(-.4,1.6)
		var sample: float=0.0
		for n in 3: sample+=preload("res://scripts/pan_result.gd").roll(CrewModel.worked_density(crew.worked,x,z),rng).ounces
		if CrewModel.workable(Vector2(x,z),water_level()): CrewModel.record_prospect(crew,Vector3(x,0,z),sample/3.0,day)
func _crew_night() -> void:
	if crew.hands.is_empty():
		var lost: String=CrewModel.washout(crew,water_level())
		if lost!="": event(lost);crew_changed.emit()
		return
	var sack: Node=get_node("/root/Sack")
	var washed: float=crew.take_today
	if washed>0: event("The outfit washed %.2f oz today." % washed)
	var hauler: Array=crew.hands.filter(func(h): return h.job=="haul")
	if not hauler.is_empty() and not CrewModel.rest_day(crew,day):
		var run:=CrewModel.haul(crew,inventory,purchases,{"dollars":dollars,"ounces":sack.ounces},day,seed,hauler[0])
		dollars=maxf(0,dollars-run.dollars);sack.ounces=maxf(0,sack.ounces-run.ounces)
		var goods: Array=[]
		for line in run.bought: goods.append("%d %s" % [line.count,line.item])
		event("%s back from %s's: %s." % [hauler[0].name.get_slice(" ",0),preload("res://scripts/store.gd").KEEPER,", ".join(goods) if not goods.is_empty() else "the shelves were bare"])
	var night:=CrewModel.night(crew,inventory,{"dollars":dollars,"ounces":sack.ounces,"gold_price":Prices.gold_price(day,seed),"water":water_level()},day,seed,weather(),crew.get("fire_tonight",false))
	dollars=maxf(0,dollars-night.dollars)
	sack.ounces=maxf(0,sack.ounces-night.ounces-night.stolen);sack.changed.emit(sack.ounces)
	if night.dollars+night.ounces>0: event("Paid the men $%.2f%s." % [night.dollars+night.ounces*Prices.gold_price(day,seed)," partly in dust" if night.ounces>0 else ""])
	for note in night.notes: event(note)
	var named:=CrewModel.bar_name(crew)
	if named!=crew.bar_name and crew.bar_name!="":
		event("Men downriver have started calling this place %s." % named)
	crew.bar_name=named
	crew.fire_tonight=false
	crew_changed.emit()
func end_day() -> void:
	if season_ended: return
	resolve_raid()
	if crew.mark>=0: _crew_work(CrewModel.abs_hour(day+1,4.75))
	# Sleeping before noon still closes both of the day's meal checks.
	check_midday(13)
	while inventory.meals_today<2 and cook_feeds(): pass
	if inventory.meals_today<2:
		condition=Condition.missed(condition)
		event("No evening meal.")
	for container in ["fish","cache"]:
		var kept: Array=[]
		for f in inventory[container]:
			if Cooking.spoiled(f,day): event("A %s spoiled." % f.species)
			else: kept.append(f)
		inventory[container]=kept
	_crew_night()
	inventory.catch_log=inventory.catch_log.filter(func(c): return day-int(c.day)<6)
	day=mini(day+1,132)
	inventory.meals_today=0
	inventory.midday_checked=false
	event(weather().capitalize()+".")
	if crew.mark>=0: crew.mark=CrewModel.abs_hour(day,4.75)
	morning_orders()
	new_day.emit()
	if autosave and day<132: preload("res://scripts/save_game.gd").write_autosave(self)
	if day>=132: finish_season()
	changed.emit()
func eat(smoked := false) -> void:
	condition=Condition.eat(condition,smoked)
	inventory.meals_today+=1
	event("Ate smoked food." if smoked else "Ate a hot meal.")
func caught(fish: Dictionary, spot_index := -1) -> void:
	inventory.fish.append(fish)
	if spot_index>=0: inventory.catch_log.append({"species":fish.species,"spot_index":spot_index,"day":day})
	inventory.catches[fish.species]=inventory.catches.get(fish.species,0)+1
	event("Caught a %s, %.2f lb." % [fish.species,fish.weight_lb])
func lose_hook() -> void:
	inventory.hooks=maxi(0,inventory.hooks-1)
	inventory.line_m=maxf(0,inventory.line_m-2)
	inventory.hooks_lost+=1
	event("Line broke at the water.")
func finish_season() -> void:
	if season_ended: return
	day=132;season_ended=true
	final_ledger=preload("res://scripts/season_model.gd").summary(inventory,purchases,ledger,expedition,dollars,get_node("/root/Sack").ounces,condition,seed,crew)
	event("November 5. First snow. Time to leave the river.")
	season_finished.emit()
