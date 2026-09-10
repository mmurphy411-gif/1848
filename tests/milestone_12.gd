extends SceneTree
const M=preload("res://scripts/expedition_model.gd")
var failures: Array[String]=[]
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node=root.get_node("GameState")
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var e: Node=claim.get_node("Expedition");var a: Node=claim.get_node("Activities")
	e.focus("salmon");claim.get_node("Walker").set_physics_process(false)
	for i in 5: await process_frame
	for fish in claim.get_node("FishSchool").get_children(): fish.set_process(false)
	check(e.prompt()=="Spear salmon","salmon reachable from scenario on actual bank")
	e.interact();check(a.action=="spear" and a.busy,"context starts spearing")
	e.cancel();check(game.inventory.fish.is_empty(),"cancel awards no food")
	e.interact();e.complete("spear");e.cancel()
	check(game.inventory.catches.get("salmon",0)==1,"landed once")
	var mass:=0.0
	for portion in game.inventory.fish: mass+=portion.weight_lb
	check(is_equal_approx(mass,M.salmon_weight(game.seed,99,0)),"landed mass matches deterministic fish")
	e.complete("spear");check(game.inventory.catches.get("salmon",0)==1,"completion cannot duplicate catch")
	var school: Node=claim.get_node("FishSchool")
	school.refresh();var count: int=school.get_children().filter(func(f):return f.species=="salmon" and not f.retired).size()
	school.refresh();check(count==school.get_children().filter(func(f):return f.species=="salmon" and not f.retired).size(),"refresh retains daily depletion")
	game.inventory.cache=game.inventory.fish.duplicate(true);var protected: Array=game.inventory.cache.duplicate(true)
	var condition: float=game.condition;game.resolve_raid()
	check(game.inventory.fish.is_empty() and game.inventory.cache==protected,"night raid preserves hanging cache")
	check(game.condition==condition,"bear never harms miner")
	game.inventory.fish=M.food("salmon",2,99);game.resolve_raid()
	check(game.inventory.fish.size()==2,"same night cannot raid twice")
	game.inventory.rack={"species":"salmon","weight_lb":5.0,"state":"fresh","day":99}
	game.expedition.raided_day=-1;game.expedition.bear_driven_day=99;game.resolve_raid()
	check(game.inventory.fish.size()==2,"shout prevents raid")
	game.expedition.bear_driven_day=-1;game.inventory.meals_today=2;game.end_day()
	check(game.inventory.rack.is_empty(),"exposed smoking rack is raided too")
	check(game.day==100 and game.inventory.fish.is_empty(),"sleep resolves unobserved raid")
	e.focus("raid");e._process(.1)
	check(is_instance_valid(e.raid_bear) and e.clock.running,"night preset spawns an actual raiding bear with running clock")
	check(e.interact() and game.expedition.bear_driven_day==99,"G shouts the live camp bear away")
	claim.get_node("Soundscape").stop();claim.queue_free()
	for i in 3: await process_frame
	print("M12 ","PASS" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
