extends SceneTree
const Lighting=preload("res://tests/lighting_capture.gd")
const Layout=preload("res://scripts/claim_layout.gd")
func _initialize() -> void:_run.call_deferred()
func _run() -> void:
	root.content_scale_size=Vector2i(1920,1080)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var w: CharacterBody3D=claim.get_node("Walker")
	var rig: Node3D=claim.get_node("CameraRig")
	await Lighting._place(self,w,rig,Vector2(-20,Layout.shore_z(-20)+8),-1.1475,-.08)
	for i in 240:await process_frame
	var ok:=await Lighting._sample(self,"M6 real-time downstream")
	await Lighting._place(self,w,rig,Vector2(0,-8.5),PI*.5,-.18)
	Input.action_press("move_forward")
	for i in 90:await process_frame
	ok=await Lighting._sample(self,"M6 real-time moving wade with splashes") and ok
	Input.action_release("move_forward")
	var camera:=Camera3D.new();claim.add_child(camera)
	camera.position=Vector3(95,100,18);camera.look_at(Vector3(-15,0,-3));camera.fov=60;camera.far=600
	camera.attributes=claim.get_node("Daylight").camera_attributes;camera.current=true
	for i in 240:await process_frame
	ok=await Lighting._sample(self,"M6 real-time overview") and ok
	quit(0 if ok else 1)
