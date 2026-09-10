extends SceneTree
const Model=preload("res://scripts/wildlife_model.gd")
const Layout=preload("res://scripts/claim_layout.gd")
var failures := 0
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func run() -> void:
	check(not Model.active("bear",80,6) and Model.active("bear",81,6) and Model.active("bear",127,6) and not Model.active("bear",128,6),"Bear salmon-season boundaries")
	check(Model.active("deer",0,6) and not Model.active("deer",0,12) and Model.active("deer",0,19) and not Model.active("deer",0,22),"Deer dawn/dusk windows")
	check(Model.population(1848,99,6.5,-.68)==Model.population(1848,99,6.5,-.68),"Repeatable population")
	check(Model.population(1848,99,6.5,-.68)!=Model.population(1849,99,6.5,-.68),"Seed changes spacing and individual scale")
	check(Model.population(1848,99,6.5,-.68).size()==10 and Model.population(1848,99,23,-.68).is_empty(),"Bounded daytime population and quiet nights")
	var game: Node=root.get_node("GameState");game.apply_scenario({"day":"99","hour":"6.5"})
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var clock: Node=claim.get_node("Daylight/Clock");clock.start(6.5);clock.running=false
	var wildlife: Node3D=claim.get_node("Wildlife");wildlife.refresh(true);wildlife.set_process(false)
	var walker: CharacterBody3D=claim.get_node("Walker");walker.set_physics_process(false)
	for actor in wildlife.actors: actor.set_physics_process(false)
	for i in 5: await physics_frame
	check(wildlife.actors.size()==10,"All ten animals find valid habitat in live claim")
	var inventory: Dictionary=game.inventory.duplicate(true)
	var condition: float=game.condition
	for species in Model.SPECIES:
		var actor: Node3D
		for candidate in wildlife.actors:
			if candidate.species==species: actor=candidate;break
		check(actor!=null,"Loaded "+species)
		if actor==null: continue
		check(wildlife.safe(actor.position,species),species+" spawns clear of rocks, trunks, camp and water")
		check(actor.find_children("*","CollisionObject3D",true,false).is_empty(),species+" cannot snag the miner")
		if not actor.legs.is_empty():
			actor.rotation.y=.35;actor.animate(1.0/60)
			var standing_gap := 0.0
			for key in actor.legs:
				var p: Vector3=actor.foot_world(key)
				standing_gap=maxf(standing_gap,absf(p.y-claim.get_node("Vegetation")._surface(p.x,p.z).w))
			check(standing_gap<.025,species+" standing feet match rendered slope within 2.5 cm: %.4f" % standing_gap)
		walker.position=actor.position+Vector3.RIGHT*(Model.ALERT[species]+Model.FLEE[species])*.5
		actor._physics_process(1.0/60)
		check(actor.state==actor.State.ALERT,species+" alerts before fleeing")
		walker.position=actor.position+Vector3.RIGHT*(Model.FLEE[species]*.65)
		var start: Vector3=actor.position
		var initial: float=start.distance_to(walker.position)
		var penetration := 0.0
		for i in 60:
			actor._physics_process(1.0/60)
			for key in actor.legs:
				var foot: Vector3=actor.foot_world(key)
				penetration=maxf(penetration,Layout.height_at(foot.x,foot.z)-foot.y)
		if not actor.legs.is_empty(): check(penetration<.035,species+" foot contact stays within 3.5 cm of ground: %.4f" % penetration)
		if species=="jay": check(actor.parts.FlightL.visible and not actor.parts.WingL.visible and actor.position.y>Layout.height_at(actor.position.x,actor.position.z)+1,"Jay opens flight feathers and gains altitude")
		check(actor.state==actor.State.FLEE and actor.position.distance_to(walker.position)>initial+.6,species+" flees away from approaching miner")
		check(Model.dry_clear(actor.position,game.water_level(),.065),species+" stays on navigable bank")
		check(actor.parts.has("Head") and actor.parts.has("Tail") and actor.parts.has("FrontL"),species+" has articulated anatomy")
		for i in 520: actor._physics_process(1.0/60)
		check(actor.departed and not actor.visible,species+" leaves without immediate respawn")
	check(game.inventory==inventory and game.condition==condition,"Wildlife does not damage miner or mutate inventory")
	for i in 20: wildlife.refresh()
	check(wildlife.actors.size()==10,"Routine refresh does not replenish frightened wildlife")
	game.day=100;wildlife.refresh()
	check(wildlife.actors.size()==10 and wildlife.actors.all(func(a): return not a.departed),"New day replaces departed population")
	for actor in wildlife.actors: actor.set_physics_process(false)
	clock.start(12);clock.running=false;wildlife.refresh()
	check(wildlife.actors.filter(func(a): return a.retiring).size()==3,"Bear and deer leave at end of morning window")
	for actor in wildlife.actors:
		actor.set_physics_process(false)
		if actor.retiring:
			for i in 550: actor._physics_process(1.0/60)
	wildlife.refresh()
	clock.start(19);clock.running=false;wildlife.refresh()
	check(wildlife.actors.filter(func(a): return a.species=="deer" and not a.departed).size()==2,"Deer return for the separate dusk visit")
	game.day=80;clock.start(6.5);clock.running=false;wildlife.refresh()
	check(wildlife.actors.filter(func(a): return a.species=="bear").is_empty(),"Changing to pre-run date removes bear")
	game.river_override=.14;wildlife.refresh()
	check(wildlife.actors.all(func(a): return Model.dry_clear(a.position,game.water_level(),.10)),"Raising river in the sandbox relocates wildlife to the new dry bank")
	game.river_override=INF;wildlife.refresh()
	# Put a new solid obstacle into an otherwise clear lane; steering must use the
	# actual physics world, not just the authored boulder list.
	var barrier := StaticBody3D.new();barrier.collision_layer=1
	var shape := CollisionShape3D.new();var box := BoxShape3D.new();box.size=Vector3(.5,2,2);shape.shape=box;barrier.add_child(shape)
	claim.add_child(barrier);barrier.position=Vector3(-8,Layout.height_at(-8,8)+1,8)
	for i in 3: await physics_frame
	var probe: Node3D=wildlife.actors[0];probe.set_physics_process(false);probe.position=Vector3(-9,Layout.height_at(-9,8),8)
	var step: Vector3=wildlife.steer(probe,Vector3.RIGHT,.35)
	check(step!=Vector3.RIGHT*.35,"Steering rejects a direct step into new solid furniture")
	barrier.queue_free()
	wildlife.focus("bear")
	check(game.day==99 and wildlife.actors.any(func(a): return a.species=="bear"),"F4 bear preset selects salmon season and spawns bear")
	print("WILDLIFE: ","PASS" if failures==0 else "FAIL", " (",failures," failures)")
	quit(0 if failures==0 else 1)
