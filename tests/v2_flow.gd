extends SceneTree
## 2.0 player flow on the real claim: title, a new season, letting time pass, a
## man hired at the trail, the roll book, the pause book, and a save that loads
## back exactly. Writes only to a throwaway save path.
const Crew=preload("res://scripts/crew_model.gd")
const SaveGame=preload("res://scripts/save_game.gd")
const Layout=preload("res://scripts/claim_layout.gd")
var failures: Array[String]=[]
var claim: Node3D
func check(ok: bool, label: String) -> void:
	print(("PASS: " if ok else "FAIL: ")+label)
	if not ok: failures.append(label)
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func key(code: Key) -> void:
	var press:=InputEventKey.new();press.physical_keycode=code;press.keycode=code;press.pressed=true
	Input.parse_input_event(press)
	var release:=press.duplicate();release.pressed=false
	await process_frame
	Input.parse_input_event(release)
	await process_frame

func run() -> void:
	SaveGame.path="user://v2_flow_test.save"
	if SaveGame.exists(): DirAccess.remove_absolute(SaveGame.path)
	var game: Node=root.get_node("GameState")
	var sack: Node=root.get_node("Sack")
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	current_scene=claim
	await frames(3)
	check(claim.has_node("PauseMenu") and claim.has_node("TimeSkip"),"live launch adds the pause book and the time skip")
	check(not game.autosave,"headless launches never autosave")
	var clock: Node=claim.get_node("Daylight/Clock")
	# The title, created as a windowed launch would.
	var title: Node=preload("res://scripts/title.gd").new();title.name="Title";claim.add_child(title)
	await frames(5)
	check(not clock.running and claim.get_node("Activities").ui_open(),"the title holds the world still")
	check(not claim.open_pause(),"Esc does not open the pause book over the title")
	check(game.condition==85.0 and not game.inventory.midday_checked and game.inventory.journal.is_empty(),"the title's golden hour costs the miner no meal")
	Input.action_press("pause");await frames(2);Input.action_release("pause")
	check(not claim.get_node("PauseMenu").opened and not paused,"gamepad Start does not open the pause book over the title")
	title._begin({})
	await create_timer(1.6).timeout
	check(clock.running and game.day==0 and is_equal_approx(sack.ounces,0.0),"a new season starts on June 26 with an empty sack")
	await create_timer(6.5).timeout
	check(not claim.has_node("Title"),"the title steps aside")
	# Letting time pass.
	var walker: CharacterBody3D=claim.get_node("Walker")
	var before: float=clock.hour_at(clock.elapsed)
	Input.action_press("wait")
	await frames(60)
	Input.action_release("wait")
	var gained: float=clock.hour_at(clock.elapsed)-before
	check(gained>.2 and gained<.6,"holding T runs the day at 24x (%.2f h in a second)" % gained)
	await frames(2)
	check(is_equal_approx(clock.rate,root.get_node("Settings").day_rate()),"releasing T restores the pace")
	# A man waiting at the trail.
	game.day=6;game.changed.emit()
	await frames(2)
	var crew: Node3D=claim.get_node("Crew")
	check(crew.waiting.has("pike"),"Jem Pike waits at the trailhead on July 2")
	walker.global_position=crew.waiting["pike"].global_position+Vector3(0,.05,1.0)
	walker.velocity=Vector3.ZERO
	await frames(3)
	check(crew.prompt().begins_with("Hire Jem Pike"),"the prompt offers to hire him: "+crew.prompt())
	await key(KEY_G)
	await frames(3)
	check(Crew.has_hand(game.crew,"pike") and crew.hands.has("pike") and not crew.waiting.has("pike"),"G hires him and he joins the outfit")
	await key(KEY_C)
	check(claim.get_node("CrewBook").opened,"C opens the roll book")
	await key(KEY_C)
	check(not claim.get_node("CrewBook").opened,"C closes it")
	# The pause book.
	check(claim.open_pause() and paused,"Esc opens the pause book and the world holds")
	claim.get_node("PauseMenu").close()
	check(not paused,"closing it resumes")
	claim.get_node("Walker/Fisher").state=1
	check(not claim.open_pause(),"Esc during fishing cancels the cast instead of pausing")
	claim.get_node("Walker/Fisher").state=0
	# Save and load back.
	game.inventory.pans=1;game.dollars=42.5;sack.ounces=3.25
	Crew.take(game.crew.worked,-25,-3,1.5)
	Crew.record_prospect(game.crew,Vector3(-25,0,-3),.12,6)
	clock.start(15.5)
	check(SaveGame.write(game,claim),"the season writes to disk")
	var saved:=SaveGame.snapshot(game,claim)
	game.apply_scenario({"day":"40","dollars":"0","crew":"0"});sack.ounces=0
	var data:=SaveGame.read()
	check(not data.is_empty() and data.version==SaveGame.VERSION,"the save reads back")
	SaveGame.apply(game,data);SaveGame.place(claim,data)
	check(game.day==6 and is_equal_approx(game.dollars,42.5) and is_equal_approx(sack.ounces,3.25),"day, coin and dust restored")
	check(Crew.has_hand(game.crew,"pike") and int(game.inventory.pans)==1,"the outfit and its kit restored")
	check(is_equal_approx(Crew.remaining(game.crew.worked,-25,-3),Crew.remaining(saved.crew.worked,-25,-3)) and game.crew.spots.size()==saved.crew.spots.size(),"worked ground and the prospect log restored")
	check(walker.global_position.distance_to(saved.walker)<.01,"the miner stands where he was")
	check(SaveGame.summary(data).begins_with("July 2, 1848"),"title summary: "+SaveGame.summary(data))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path))
	claim.get_node("Soundscape").stop();claim.get_node("Camp").fire_sound.stop()
	print("V2 FLOW ","PASS" if failures.is_empty() else failures)
	quit(0 if failures.is_empty() else 1)
