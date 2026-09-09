extends SceneTree
const Layout=preload("res://scripts/claim_layout.gd")
const Cooking=preload("res://scripts/cooking.gd")
const Fight=preload("res://scripts/fight_model.gd")
const Fishery=preload("res://scripts/fishery.gd")
var failures: Array[String]=[]
func _initialize() -> void:
	run.call_deferred()
	create_timer(75).timeout.connect(func():push_error("M9 timed out");quit(2))
func check(value: bool,label: String) -> void:
	print("PASS: " if value else "FAIL: ",label)
	if not value: failures.append(label)
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	var game: Node=root.get_node("GameState")
	check(game.condition==85 and game.inventory.hooks==4 and game.day==0,"Default season state")
	game.apply_scenario({"fish.fresh":"1","day":"95"})
	check(game.inventory.fish[0].day==95,"Scenario inventory date is independent of argument order")
	game.inventory.fish=[]
	game.apply_scenario({"day":"20","hour":"19","hooks":"12","bait.grasshopper":"6","firewood":"10","weather":"clear","fish.smoked":"2"})
	check(game.day==20 and game.inventory.fish.size()==2 and game.weather()=="clear","Scenario parser")
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim);current_scene=claim
	await frames(5)
	var w: CharacterBody3D=claim.get_node("Walker")
	var p: Node=w.get_node("Panner")
	var f: Node=w.get_node("Fisher")
	var camp: Node=claim.get_node("Camp")
	var clock: Node=claim.get_node("Daylight/Clock")
	clock.set_process(false)
	var day: int=game.day
	clock.start(19);check(game.day==day,"Posing hour never ends a day")
	clock.advance(clock.CYCLE_SECONDS*2)
	check(game.day==day+2,"Multi-wrap emits one calendar tick per cycle")
	game.day=20;game.condition=85;game.inventory.meals_today=0;game.inventory.midday_checked=false
	clock.start(19)
	w.position=Vector3(-9.95,Layout.height_at(-9.95,Layout.shore_z(-9.95)-.8)+.01,Layout.shore_z(-9.95)-.8)
	w.velocity=Vector3.ZERO
	await frames(30)
	f.reproducible=true
	check(f.can_fish(),"Fishing available in shallows with gear and bait")
	game.inventory.hooks=0
	check(not f.can_fish(),"No hooks blocks fishing")
	game.inventory.hooks=12
	f.press()
	check(f.state==f.State.STANCE and not p.can_pan(),"Fishing excludes panning")
	await frames(25)
	check(absf(wrapf(w.get_node("Visual").rotation.y-atan2(Layout.inland_normal(w.position.x).x,Layout.inland_normal(w.position.x).z),-PI,PI))<.02,"Stance turns to river in .3 seconds")
	var aimed: Vector3=f.aim()
	check(Vector2(aimed.x-w.position.x,aimed.z-w.position.z).length()<=8.01 and aimed.z<Layout.shore_z(aimed.x),"Cast ring clamped to water within eight metres")
	var bait_before: int=game.inventory.bait.grasshopper
	f.cast()
	check(game.inventory.bait.grasshopper==bait_before-1,"Cast reserves exactly one bait")
	await frames(75)
	check(f.state in [f.State.DRIFT,f.State.SNAGGED],"Cast reaches drift or snag")
	f.change(f.State.BITE,"fish_wait");f.elapsed=.05;f.press()
	check(f.state==f.State.STANCE and f.bait_loaded,"Early strike keeps bait")
	f.change(f.State.BITE,"fish_wait");f.elapsed=.4;f.press()
	check(f.state==f.State.FIGHT,"Valid strike hooks fish")
	f.set_physics_process(false)
	f.fight=Fight.begin(1,5,0);f.fight.elapsed=2
	f.fight.tension=.35
	Input.action_press("fish");f._physics_process(.02)
	check(f.state==f.State.FIGHT and game.inventory.hooks==12,"Run gives time to release before tension breaks line")
	f._physics_process(.6);Input.action_release("fish")
	check(game.inventory.hooks==11 and game.inventory.line_m==18 and f.state==f.State.STANCE,"Holding through run loses hook and two metres")
	f.bait_type="grasshopper";f.bait_loaded=true
	f.change(f.State.BITE,"fish_wait");f.elapsed=.4;f.press()
	f.fight=Fight.begin(1,5,0);f.weight=1
	var inventory_before: int=game.inventory.fish.size()
	for i in 2000:
		if f.state!=f.State.FIGHT: break
		var running: bool=f.fight.elapsed+.01>=f.fight.run_at and f.fight.elapsed+.01<f.fight.run_at+.8
		if running: Input.action_release("fish")
		else: Input.action_press("fish")
		f._physics_process(.01)
	Input.action_release("fish")
	check(f.state==f.State.LAND,"Releasing on runs lands trout")
	f._physics_process(2.01)
	check(f.state==f.State.SHOWING and game.inventory.fish.size()==inventory_before+1,"Landed fish awarded once with fresh record")
	f._physics_process(.1)
	check(game.inventory.fish.size()==inventory_before+1,"Showing does not duplicate award")
	f.cancel();f.set_physics_process(true)
	check(p.start_pan() and not f.can_fish(),"Panning excludes fishing")
	p._reset();await frames(65)
	check(camp.props.size()==9 and camp.oak.z-Layout.shore_z(camp.oak.x)>=10,"Camp seated under inland oak")
	game.inventory.firewood=2;check(not camp.light_fire(),"Two wood cannot light fire")
	game.inventory.firewood=10;check(camp.light_fire() and game.inventory.firewood==7,"Three wood lights fire")
	camp.advance(2);check(not camp.burning() and camp.ember_hours==1,"Fire becomes embers after two hours")
	camp.advance(1);check(camp.ember_hours==0,"Embers end after third hour")
	game.inventory.firewood=10;camp.light_fire()
	game.inventory.fish=[Cooking.fresh("trout",2.5,game.day)]
	game.condition=60;game.inventory.meals_today=0
	check(camp.fry(),"Fresh fish can fry at lit fire")
	camp.advance(1.0/3.0+.001)
	check(game.condition==80 and game.inventory.meals_today==1 and game.inventory.fish.size()==1 and game.inventory.fish[0].cooked,"Large fried fish gives meal and cooked portion")
	check(camp.eat_stored() and game.condition==100 and game.inventory.meals_today==2,"Cooked portion eaten without another fire")
	game.inventory.fish=[Cooking.fresh("trout",1,game.day)]
	camp.fire_hours=4;check(camp.hang(),"Fresh fish hung on rack")
	camp.fire_hours=0;camp.advance(2);check(camp.smoke_hours==0,"Smoking pauses without fire")
	camp.fire_hours=4;camp.advance(4)
	check(game.inventory.fish.size()==1 and game.inventory.fish[0].state=="smoked","Four lit hours preserve fish")
	game.condition=60;camp.eat_stored();check(game.condition==75,"Cold smoked fish restores fifteen")
	game.inventory.fish=[Cooking.fresh("trout",1,game.day)]
	game.condition=85;game.inventory.meals_today=0;game.inventory.midday_checked=false
	clock.end_day()
	check(game.condition==55 and game.inventory.fish.size()==1,"Sleep applies both missed meals; today's fish survives")
	clock.end_day();check(game.inventory.fish.is_empty(),"Fish spoils on the second morning")
	var book: Node=claim.get_node("Ledger")
	book.open_book()
	check(book.opened and book.left.text.contains("1848") and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE,"Ledger displays date and releases mouse")
	book.close_book()
	var sandbox: Node=claim.get_node("Sandbox")
	sandbox.refresh_fields();sandbox.fields.day.value=95;sandbox.fields.hour.value=6;sandbox.command("Apply")
	await frames(125)
	var salmon:=0
	for fish in claim.get_node("FishSchool").get_children():
		if not fish.retired and fish.species=="salmon": salmon+=1
	check(salmon>=6,"Sandbox day 95 rebuilds salmon population")
	print("MILESTONE 9: ","PASS" if failures.is_empty() else "FAIL "+str(failures))
	claim.get_node("Soundscape").stop();w.get_node("ActionAudio").stop()
	camp.fire_sound.stop();claim.get_node("Rain").sound.stop()
	await frames(10)
	# --fixed-fps can finish ten frames before the audio thread gets a turn.
	OS.delay_msec(150)
	quit(0 if failures.is_empty() else 1)
