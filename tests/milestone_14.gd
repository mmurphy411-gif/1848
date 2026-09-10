extends SceneTree
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func run() -> void:
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"131","dollars":"12.5","tent":"1","rifle":"1","ammo":"20"})
	root.get_node("Sack").ounces=2.25
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var camp: Node=claim.get_node("Camp");var clock: Node=claim.get_node("Daylight/Clock")
	check(is_instance_valid(camp.tent) and camp.tent.visible and not camp.props.LeanTo.visible and camp.props.LeanTo.collision_layer==0,"purchased tent replaces shelter")
	check(camp.props.Bedroll.visible and camp.tent.find_children("*","StaticBody3D",true,false).size()>0,"tent has collision and retains bedroll")
	game.inventory.fish=preload("res://scripts/expedition_model.gd").food("venison",12,131);camp.fire_hours=4
	check(camp.hang() and is_equal_approx(camp.smoking.weight_lb,12),"smoking rack batches a multi-day meat supply")
	camp.advance(4);check(game.inventory.fish.size()==12 and game.inventory.fish.all(func(f):return f.state=="smoked"),"four lit hours preserve all portions")
	game.inventory.meals_today=2
	clock.day_ended.connect(game.end_day);clock.start(23);clock.end_day()
	check(game.day==132 and game.season_ended and not clock.running,"sleep stops exactly at first snow")
	check(game.final_ledger.coin==12.5 and game.final_ledger.gold==2.25 and game.final_ledger.food_lb==12,"final ledger reports retained wealth and food")
	var model=preload("res://scripts/season_model.gd")
	check(not model.closes(131) and model.closes(132),"season boundary model")
	check(game.final_ledger==model.summary(game.inventory,game.purchases,game.ledger,game.expedition,game.dollars,2.25,game.condition,game.seed),"deterministic final summary")
	var snapshot: Dictionary=game.final_ledger.duplicate(true)
	game.end_day();game.finish_season();clock.advance(3000)
	check(game.day==132 and game.final_ledger==snapshot,"ending is idempotent and clock cannot roll onward")
	claim.get_node("Ledger").open_book()
	check("First snow" in claim.get_node("Ledger").left.text and "Rifle" in claim.get_node("Ledger").right.text,"final ledger renders season totals")
	game.apply_scenario({"day":"130","hour":"8"});await process_frame
	check(not game.season_ended and not claim.get_node("SeasonEnd").snow.emitting,"F4 can rewind season for review")
	game.day=131;game.inventory.meals_today=2;clock.start(4.75);clock.elapsed=clock.CYCLE_SECONDS-.01;clock.advance(.02)
	check(game.day==132 and game.season_ended,"natural day rollover also ends season")
	claim.get_node("Soundscape").stop();claim.queue_free()
	for i in 5: await process_frame
	print("M14 ","PASS" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
