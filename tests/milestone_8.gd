extends SceneTree
const Layout = preload("res://scripts/claim_layout.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func frames(count: int) -> void:
	for i in count: await physics_frame
func run() -> void:
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	await frames(30)
	var w: CharacterBody3D = claim.get_node("Walker")
	var visual: Node3D = w.get_node("Visual")
	var p: Node = w.get_node("Panner")
	var sound: Node3D = w.get_node("ActionAudio")
	var rig: Node3D = claim.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("SpringArm3D/Camera3D")
	claim.get_node("Soundscape").start()
	check(AudioServer.get_bus_index("Ambience")>0 and AudioServer.get_bus_index("Foley")>0,"Separate ambience and action mix buses")
	check(AudioServer.get_bus_effect_count(0)==1 and AudioServer.get_bus_effect(0,0) is AudioEffectLimiter,"Master limiter retains output headroom")
	Input.action_press("move_right")
	await frames(120)
	Input.action_release("move_right")
	check(sound.steps_played>=2 and sound.last_step_kind=="gravel","Distance-driven dry footsteps play during actual movement")
	await frames(30)
	var stopped: int = sound.steps_played
	await frames(30)
	check(sound.steps_played==stopped,"Standing still produces no footsteps")
	w.position = Vector3(0,Layout.height_at(0,-8.5)+.01,-8.5)
	w.velocity = Vector3.ZERO
	rig.yaw=PI*.5
	await frames(30)
	Input.action_press("move_forward")
	await frames(90)
	Input.action_release("move_forward")
	check(sound.last_step_kind=="step_water","Wading uses water steps")
	w.position=Vector3(0,Layout.height_at(0,-6.7)+.01,-6.7)
	w.velocity=Vector3.ZERO
	await frames(30)
	check(p.start_pan(),"Panning starts for audio timeline check")
	await frames(190)
	check(sound.swirl.playing and sound.swirl.volume_db>=-21,"Swirl loop follows submerged pan animation")
	w.position=Vector3(0,-.7,Layout.shore_z(0)-4)
	await frames(65)
	check(p.state==p.State.IDLE and not sound.swirl.playing and not sound.pan.playing,"Deep-water cancellation stops panning sounds")
	for tier in 5:
		p.pan.show_result(tier,42)
		check(p.pan.concentrate.visible and p.pan.nugget.visible==(tier==4),"Concentrate and nugget visibility for tier %d" % tier)
		var count: int=p.pan.flecks.multimesh.instance_count
		p.pan.show_result(tier,42)
		check(count==p.pan.flecks.multimesh.instance_count,"Cosmetic count reproduces for tier %d" % tier)
	p.pan.clear()
	check(not p.pan.concentrate.visible and not p.pan.nugget.visible,"Old contents clear before a new pan")
	var sack: Node = root.get_node("Sack")
	for amount in [0.0,.25,1.0,3.0,8.0]:
		sack.ounces=amount
		sack.changed.emit(amount)
		check(visual.sack_material.get_shader_parameter("growth")==visual.sack_visual.scale,"Sack neck compensation follows stage %.2f" % amount)
	w.position=Vector3(0,Layout.height_at(0,-6.7)+.01,-6.7)
	w.velocity=Vector3.ZERO
	await frames(65)
	p.start_pan()
	while p.state!=p.State.SHOWING: await frames(1)
	await frames(40)
	check(is_equal_approx(camera.fov,38),"Showing FOV completes in the same .6 seconds as the dolly")
	p._finish()
	await frames(40)
	check(is_equal_approx(camera.fov,65) and is_equal_approx(rig.arm.spring_length,4.6),"Exit restores orbit FOV and boom")
	print("MILESTONE 8: ","PASS" if failures.is_empty() else "FAIL")
	claim.get_node("Soundscape").stop()
	sound.stop()
	await frames(8)
	quit(0 if failures.is_empty() else 1)
