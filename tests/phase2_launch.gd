extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var game: Node=root.get_node("GameState")
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim);current_scene=claim
	for i in 60: await process_frame
	var ok:=true;var e: Node=claim.get_node("Expedition")
	if game.day==132: ok=game.season_ended and not claim.get_node("Daylight/Clock").running
	elif game.start_encounter=="salmon": ok=game.inventory.spear and e.salmon_near()!=null and e.clock.running
	elif game.start_encounter=="raid": ok=is_instance_valid(e.raid_bear) and e.clock.running
	elif game.start_encounter in ["deer","bear"]: ok=game.inventory.rifle and e.animal_near(game.start_encounter,30)!=null and e.clock.running
	else: ok=false
	print("PHASE 2 LAUNCH ",game.start_encounter if game.day!=132 else "first snow"," PASS" if ok else " FAIL")
	claim.get_node("Soundscape").stop();claim.get_node("Walker/ActionAudio").stop();e.sound.stop();claim.get_node("Camp").fire_sound.stop()
	claim.queue_free();current_scene=null
	for i in 8: await process_frame
	quit(0 if ok else 1)
