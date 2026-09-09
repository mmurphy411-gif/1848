extends SceneTree
const Fight=preload("res://scripts/fight_model.gd")
const Layout=preload("res://scripts/claim_layout.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	# Holding through a run must offer reaction time at ordinary frame rates.
	for hz in [30,60,144]:
		var f := Fight.begin(1,6,0)
		var original := f.duplicate()
		while not f.broken and f.elapsed<4: f=Fight.step(f,1.0/hz,true)
		assert(f.broken and f.tension==1 and f.elapsed>2.5 and f.elapsed<2.7)
		assert(original.tension==.15 and original.elapsed==0)
	var rescued := Fight.begin(1,6,0)
	rescued.elapsed=2;rescued.running=true;rescued.tension=.8
	rescued=Fight.step(rescued,.2,false)
	assert(not rescued.broken and rescued.tension<.5)
	for i in 2000:
		rescued=Fight.step(rescued,.01,rescued.tension<.6)
		if rescued.landed or rescued.broken: break
	assert(rescued.landed and not rescued.broken)
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"20","hour":"18.5","weather":"clear","bait.grasshopper":"10"})
	var claim: Node=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	claim.get_node("Daylight").apply(18.5)
	var walker: Node3D=claim.get_node("Walker")
	var z: float=Layout.shore_z(-9.95)-.8
	walker.position=Vector3(-9.95,Layout.height_at(-9.95,z)+.01,z)
	walker.set_physics_process(false)
	var fisher: Node=walker.get_node("Fisher")
	fisher.press();fisher.change(fisher.State.FIGHT,"fight")
	fisher.set_physics_process(false);fisher.fight=Fight.begin(1,6,0)
	var hud: Node=claim.get_node("HUD")
	for state in ["pull","warning","run","slack"]:
		fisher.fight.tension=.85 if state=="run" else .35
		fisher.fight.elapsed=1.7 if state=="warning" else 2.2 if state=="run" else 0.0
		fisher.fight.running=state=="run"
		hud._update_tension(fisher,false)
		assert(hud.tension_panel.visible and is_equal_approx(hud.tension_bar.value,fisher.fight.tension*100))
		assert(hud.tension_hint.text.contains("Release") if state in ["warning","run"] else hud.tension_hint.text.contains("Hold"))
		if "--capture" in OS.get_cmdline_user_args():
			for i in 45: await process_frame
			await RenderingServer.frame_post_draw
			assert(hud.tension_panel.get_global_rect().end.y<hud.action_label.get_global_rect().position.y)
			root.get_texture().get_image().save_png("res://artifacts/tension-%s.png" % state)
	hud._update_tension(fisher,true);assert(not hud.tension_panel.visible)
	for state in [fisher.State.IDLE,fisher.State.STANCE,fisher.State.LAND,fisher.State.SHOWING]:
		fisher.state=state;hud._update_tension(fisher,false);assert(not hud.tension_panel.visible)
	fisher.cancel()
	print("FISHING TENSION PASS: reaction window, recovery, landing, warnings, visibility and layout")
	claim.get_node("Soundscape").stop();walker.get_node("ActionAudio").stop()
	claim.get_node("Camp").fire_sound.stop();claim.get_node("Rain").sound.stop()
	OS.delay_msec(150)
	quit()
