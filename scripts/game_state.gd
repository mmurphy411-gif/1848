extends Node
signal changed
signal new_day
const Condition = preload("res://scripts/condition_model.gd")
const Cooking = preload("res://scripts/cooking.gd")
const Weather = preload("res://scripts/weather.gd")
const RiverModel = preload("res://scripts/river_model.gd")
const Expedition=preload("res://scripts/expedition_model.gd")
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
			"rod": inventory.rod=value=="1"
			"tent","rifle","spear","crowbar","pick","shovel","boots","rocker": inventory[key]=value=="1"
			"river": river_override=INF if value=="auto" else clampf(value.to_float(),-.75,.14)
			"encounter": start_encounter=value
			"work": start_work=value if value in ["crevice","rocker"] else ""
			"scene":
				if value in ["claim","store"]: scene=value
			"condition": condition=clampf(value.to_float(),5,100)
			"ammo","hooks","firewood": inventory[key]=maxi(0,value.to_int())
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
	changed.emit()
func weather() -> String: return Weather.state(day,seed) if weather_override=="auto" else weather_override
func water_level() -> float: return RiverModel.level(day,seed,weather()) if is_inf(river_override) else river_override
func event(message: String) -> void:
	inventory.journal.append({"day":day,"text":message})
	changed.emit()
func check_midday(hour: float) -> void:
	if hour>=13 and not inventory.midday_checked:
		inventory.midday_checked=true
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
func end_day() -> void:
	if season_ended: return
	resolve_raid()
	# Sleeping before noon still closes both of the day's meal checks.
	check_midday(13)
	if inventory.meals_today<2:
		condition=Condition.missed(condition)
		event("No evening meal.")
	for container in ["fish","cache"]:
		var kept: Array=[]
		for f in inventory[container]:
			if Cooking.spoiled(f,day): event("A %s spoiled." % f.species)
			else: kept.append(f)
		inventory[container]=kept
	day=mini(day+1,132)
	inventory.meals_today=0
	inventory.midday_checked=false
	event(weather().capitalize()+".")
	new_day.emit()
	if day>=132: finish_season()
	changed.emit()
func eat(smoked := false) -> void:
	condition=Condition.eat(condition,smoked)
	inventory.meals_today+=1
	event("Ate smoked food." if smoked else "Ate a hot meal.")
func caught(fish: Dictionary) -> void:
	inventory.fish.append(fish)
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
	final_ledger=preload("res://scripts/season_model.gd").summary(inventory,purchases,ledger,expedition,dollars,get_node("/root/Sack").ounces,condition,seed)
	event("November 5. First snow. Time to leave the river.")
	season_finished.emit()
