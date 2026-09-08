extends SceneTree
const Lighting = preload("res://tests/lighting_capture.gd")
const Layout = preload("res://scripts/claim_layout.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.content_scale_size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var walker: CharacterBody3D = claim.get_node("Walker")
	var rig: Node3D = claim.get_node("CameraRig")
	var light: Node3D = claim.get_node("Daylight")
	await Lighting._place(self,walker,rig,Vector2(-20,Layout.shore_z(-20)+8),-1.1475,-.08)
	for pair in [[6.0,"dawn"],[12.0,"noon"],[19.25,"golden"],[20.7,"dusk"],[0.0,"night"],[4.75,"next-dawn"]]:
		light.apply(pair[0])
		await Lighting._save(self,"milestone-7-"+pair[1]+".png")
		if pair[1]=="night": await Lighting._sample(self,"night with moon and stars")
	light.clock.start(19.25)
	await Lighting._sample(self,"live day cycle")
	print("DAY CYCLE CAPTURE: ","FAIL" if preload("res://tests/composition_guard.gd").failed else "PASS")
	quit(1 if preload("res://tests/composition_guard.gd").failed else 0)
