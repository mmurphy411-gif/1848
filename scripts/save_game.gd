extends RefCounted
## One season on disk. The save is a plain Variant snapshot of GameState, the
## sack and the few live claim facts (clock, fire, the miner's footing), written
## at each dawn in live play and on request from the pause menu.
## Tests point this elsewhere so they never touch a real season.
static var path := "user://season.save"
const VERSION := 2

static func exists() -> bool: return FileAccess.file_exists(path)

static func snapshot(game: Node, claim: Node = null) -> Dictionary:
	var data := {"version":VERSION,"saved_at":Time.get_datetime_string_from_system(),
		"seed":game.seed,"day":game.day,"dollars":game.dollars,"condition":game.condition,
		"purchases":game.purchases.duplicate(true),"ledger":game.ledger.duplicate(true),
		"inventory":game.inventory.duplicate(true),"mining":game.mining.duplicate(true),
		"expedition":game.expedition.duplicate(true),"crew":game.crew.duplicate(true),
		"season_ended":game.season_ended,"final_ledger":game.final_ledger.duplicate(true),
		"ounces":game.get_node("/root/Sack").ounces,"hour":4.75}
	if claim and is_instance_valid(claim) and claim.has_node("Daylight/Clock"):
		var clock: Node=claim.get_node("Daylight/Clock")
		data.hour=clock.hour_at(clock.elapsed)
		data.walker=claim.get_node("Walker").global_position
		var camp: Node=claim.get_node("Camp")
		data.camp={"fire_hours":camp.fire_hours,"ember_hours":camp.ember_hours,"smoke_hours":camp.smoke_hours,"coffee_day":camp.coffee_day,"biscuit_day":camp.biscuit_day}
		data.fire_hours=camp.fire_hours
		data.bait_used=claim.get_node("BaitSources").used.duplicate()
	return data

static func write(game: Node, claim: Node = null) -> bool:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return false
	file.store_string(var_to_str(snapshot(game,claim)))
	return true

## Dawn saves start the new day at the bedroll, as if the miner just woke.
static func write_autosave(game: Node) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	if file==null: return
	var data := snapshot(game)
	data.hour=4.75
	file.store_string(var_to_str(data))

static func read() -> Dictionary:
	if not exists(): return {}
	var file := FileAccess.open(path,FileAccess.READ)
	if file==null: return {}
	var data=str_to_var(file.get_as_text())
	if typeof(data)!=TYPE_DICTIONARY or int(data.get("version",0))!=VERSION: return {}
	return data

static func summary(data: Dictionary) -> String:
	if data.is_empty(): return ""
	var hands: int=data.get("crew",{}).get("hands",[]).size()
	return "%s · %.2f oz · $%.2f%s" % [preload("res://scripts/calendar.gd").date_string(int(data.day)),float(data.ounces),float(data.dollars),
		(" · %d %s" % [hands,"hand" if hands==1 else "hands"]) if hands>0 else ""]

## Restore owned season state. Scenario settings (overrides, presets) are cleared.
static func apply(game: Node, data: Dictionary) -> void:
	game.seed=int(data.seed);game.day=int(data.day);game.dollars=float(data.dollars);game.condition=float(data.condition)
	game.purchases.assign(data.purchases);game.ledger.assign(data.ledger)
	var inventory: Dictionary=game.inventory.duplicate(true)
	for key in data.inventory: inventory[key]=data.inventory[key]
	game.inventory=inventory
	game.mining=data.mining;game.expedition=data.expedition
	var crew: Dictionary=preload("res://scripts/crew_model.gd").initial()
	for key in data.crew: crew[key]=data.crew[key]
	crew.mark=-1.0
	game.crew=crew
	game.season_ended=bool(data.season_ended);game.final_ledger=data.final_ledger
	game.weather_override="auto";game.river_override=INF;game.start_encounter="";game.start_work=""
	game.start_hour=float(data.hour);game.scene="claim"
	var sack: Node=game.get_node("/root/Sack")
	sack.ounces=float(data.ounces);sack.changed.emit(sack.ounces)
	game.changed.emit();game.crew_changed.emit()

## Live claim facts, once the scene exists.
static func place(claim: Node, data: Dictionary) -> void:
	var walker: Node3D=claim.get_node("Walker")
	if data.has("walker") and float(data.hour)!=4.75: walker.global_position=data.walker
	else: walker.global_position=claim.get_node("Camp").wake_position()
	walker.velocity=Vector3.ZERO
	var camp: Node=claim.get_node("Camp")
	camp.fire_hours=float(data.get("fire_hours",0.0))
	if data.has("camp") and float(data.hour)!=4.75:
		for key in data.camp: camp.set(key,data.camp[key])
	claim.get_node("Camp").last_hour=float(data.hour)
	if data.has("bait_used"): claim.get_node("BaitSources").used=data.bait_used
	claim.get_node("Mining").refresh()
	claim.get_node("FishSchool").refresh()
	claim.get_node("Wildlife").refresh(true)
