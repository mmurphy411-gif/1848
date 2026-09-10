extends SceneTree
const M=preload("res://scripts/expedition_model.gd")
var failures: Array[String]=[]
func _initialize() -> void: run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("PASS " if ok else "FAIL ",label)
	if not ok: failures.append(label)
func run() -> void:
	var game: Node=root.get_node("GameState")
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var e: Node=claim.get_node("Expedition");var w: Node=claim.get_node("Wildlife")
	e.focus("deer");e.walker.set_physics_process(false)
	for i in 5: await physics_frame
	for actor in w.actors: actor.set_physics_process(false)
	var target: Node3D=e.animal_near("deer",30)
	check(target!=null,"deer scenario faces real target")
	if target==null: quit(1);return
	target.walking=false;target.state=target.State.ALERT
	check(e.clear_shot(target),"actual habitat has clear sightline")
	e.interact();check(claim.get_node("Activities").action=="rifle","rifle starts through contextual interaction")
	e.cancel();check(game.inventory.ammo==20 and game.expedition.shots==0,"cancelling does not spend ammunition")
	game.condition=100
	# Select a replayable hit, not a mocked damage result.
	while not M.shot(game.seed,game.day,game.expedition.shots,100,e.walker.position.distance_to(target.position),3): game.expedition.shots+=1
	e.interact();claim.get_node("Activities")._process(3.1)
	check(game.inventory.ammo==19 and game.expedition.deer_dead.size()==1,"hit spends one shot and records season kill")
	w.refresh(true)
	check(w.actors.filter(func(a):return a.species=="deer").size()==1,"refresh cannot respawn killed deer")
	var record: Dictionary=game.expedition.carcasses[0]
	e.walker.position=record.position;game.inventory.goods.flour=24
	e.harvest()
	check(record.meat>0 and not record.hide and game.inventory.hides.size()==1,"pack-limited harvest leaves finite meat at carcass")
	game.inventory.goods.flour=0;e.harvest();var count: int=game.inventory.fish.size();e.harvest()
	check(record.meat==0 and game.inventory.fish.size()==count and game.inventory.hides.size()==1,"exhausted carcass cannot duplicate food or hide")
	var counter: Node=load("res://scripts/counter.gd").new();root.add_child(counter)
	game.dollars=0;root.get_node("Sack").ounces=0
	counter.toggle_fish();var credit: float=counter.hide_credit()
	check(counter.hide_offer.size()==1 and credit>0,"store offers fresh hide independently of smoked food")
	check(counter.settle() and is_equal_approx(game.dollars,credit) and game.inventory.hides.is_empty(),"hide-only sale settles once into coin")
	check(not counter.settle() and game.expedition.hides_sold==1,"repeated settlement cannot resell hide")
	game.inventory.rifle=false;game.inventory.fish=[];game.inventory.goods.flour=0
	check(counter.select("rifle")=="","rifle sold as unique gear")
	var before: Dictionary=game.inventory.duplicate(true)
	check(not counter.settle() and game.inventory==before,"unaffordable weapon settlement remains atomic")
	game.inventory.rifle=true;game.inventory.ammo=1;e.selected=null;e.fire_rifle()
	check(game.inventory.ammo==0 and game.expedition.deer_spooked_until==game.day+3,"miss spends ammunition and spooks deer for days")
	w.refresh(true);check(w.actors.filter(func(a):return a.species=="deer").is_empty(),"miss survives refresh")
	game.day+=3;w.refresh(true);check(w.actors.filter(func(a):return a.species=="deer").size()==1,"surviving deer returns after three days")
	e.focus("bear");game.condition=100
	for actor in w.actors: actor.set_physics_process(false);actor.walking=false;actor.state=actor.State.ALERT
	var bear: Node3D=e.animal_near("bear",30)
	check(bear!=null and e.prompt().begins_with("Aim rifle at bear"),"bear has a reachable rifle target")
	if bear:
		check(e.clear_shot(bear),"bear preset chooses a clear firing lane")
		while not M.shot(game.seed,game.day,game.expedition.shots,100,e.walker.position.distance_to(bear.position),3): game.expedition.shots+=1
		e.interact();claim.get_node("Activities")._process(3.1)
		check(game.expedition.bear_dead,"actual rifle action kills the season bear")
		game.day+=1;w.refresh(true)
		check(w.actors.filter(func(actor):return actor.species=="bear").is_empty() and not M.raid_due(game.expedition,game.day),"dead bear never returns or raids")
	e.sound.stop()
	claim.get_node("Soundscape").stop();claim.queue_free();counter.queue_free()
	for i in 4: await process_frame
	print("M13 ","PASS" if failures.is_empty() else failures);quit(0 if failures.is_empty() else 1)
