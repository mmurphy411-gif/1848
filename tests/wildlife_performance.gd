extends SceneTree
const Lighting=preload("res://tests/lighting_capture.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.get_node("GameState").apply_scenario({"day":"99","hour":"6.5","weather":"clear"})
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	claim.get_node("Daylight/Clock").start(6.5);claim.get_node("Daylight").apply(8)
	claim.get_node("Wildlife").refresh(true)
	claim.get_node("Walker").position=Vector3(31,2,21)
	var camera := Camera3D.new();claim.add_child(camera)
	camera.position=Vector3(-5,22,30);camera.look_at(Vector3(-10,0,8));camera.fov=70
	camera.attributes=claim.get_node("Daylight").camera_attributes;camera.make_current()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for i in 240: await process_frame
	print("ACTIVE WILDLIFE ",claim.get_node("Wildlife").actors.filter(func(a): return a.visible).size())
	var ok: bool=await Lighting._sample(self,"Wildlife: ten animals, live claim, 1080p")
	quit(0 if ok else 1)
