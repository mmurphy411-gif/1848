extends SceneTree
## Seed for tests/visual_tour.gd (see VISUAL_UPGRADE_PLAN.md, Stage 0). Gameplay-camera
## stills across place, hour and season. Known flaws: rig yaw 0 faces the river and PI
## faces inland, so the a3/a4/a5 names are swapped; "weather=rain" showed no rain.
const Layout = preload("res://scripts/claim_layout.gd")
const OUT := "res://artifacts/visual-tour/seed/"
var claim: Node3D
var walker: CharacterBody3D
var rig: Node3D
var light: Node3D
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await frames(30);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(OUT+name+".png")
	print("CAPTURE ",name)
func place(x: float, inland: float, yaw: float, pitch: float) -> void:
	var z := Layout.shore_z(x)+inland
	walker.position=Vector3(x,Layout.height_at(x,z)+.05,z);walker.velocity=Vector3.ZERO
	rig.yaw=yaw;rig.pitch=pitch;walker.get_node("Visual").rotation.y=yaw
	for i in 45: await physics_frame
func open(scenario: Dictionary) -> void:
	root.get_node("GameState").apply_scenario(scenario)
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	walker=claim.get_node("Walker");rig=claim.get_node("CameraRig");light=claim.get_node("Daylight")
	rig.get_node("SpringArm3D/Camera3D").current=true
	await frames(10)
func close() -> void:
	claim.get_node("Soundscape").stop()
	if claim.get_node("Camp").get("fire_sound"): claim.get_node("Camp").fire_sound.stop()
	claim.queue_free();await frames(5)
func run() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	root.content_scale_size=Vector2i(1600,900)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	await open({"day":"10","hour":"10","weather":"clear"})
	light.apply(10.0)
	await place(-20,8,-1.1475,-.08);await shot("a1_downstream_10h")
	await place(20,8,1.4,-.08);await shot("a2_upstream_10h")
	await place(0,2,3.14159,-.10);await shot("a3_across_river_10h")
	await place(0,2,3.14159,.35);await shot("a4_far_wall_up_10h")
	await place(0,6,0.0,-.05);await shot("a5_inland_camp_10h")
	await place(-8,18,0.0,.30);await shot("a6_near_wall_up_10h")
	light.apply(6.0);await place(-20,8,-1.1475,-.08);await shot("b1_downstream_06h")
	light.apply(13.0);await shot("b2_downstream_13h")
	light.apply(19.25);await shot("b3_downstream_golden")
	light.apply(0.0);await shot("b4_downstream_night")
	light.apply(16.0)
	var cam := Camera3D.new();claim.add_child(cam);cam.far=900;cam.attributes=light.camera_attributes
	cam.position=Vector3(95,100,18);cam.fov=60;cam.look_at(Vector3(-15,0,-3));cam.current=true
	await shot("c1_overview_16h")
	cam.position=Vector3(-60,6,2);cam.fov=55;cam.look_at(Vector3(60,8,-10));await shot("c2_valley_low_16h")
	var wildlife: Node=claim.get_node_or_null("Wildlife")
	if wildlife:
		for actor in wildlife.actors:
			var t: Vector3=actor.global_position+Vector3(0,.5,0)
			cam.position=t+Vector3(2.4,.6,1.6);cam.fov=40;cam.look_at(t)
			await shot("d_"+actor.species+"_"+str(actor.get_index()))
	await close()
	await open({"day":"100","hour":"15","weather":"rain"})
	light.apply(15.0)
	await place(-20,8,-1.1475,-.08);await shot("e1_downstream_rain_day100")
	await place(0,2,3.14159,-.10);await shot("e2_across_lowwater_day100")
	await close()
	quit(0)
