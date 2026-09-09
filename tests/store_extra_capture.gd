extends SceneTree
const Guard=preload("res://tests/composition_guard.gd")
var landscape_pass := false
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1920,1080)
	var game: Node=root.get_node("GameState");game.apply_scenario({"day":30,"hour":7,"rod":1})
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var camp: Node=claim.get_node("Camp");camp.fire_hours=2;camp.smoke.preprocess=7
	claim.get_node("Daylight").apply(7)
	var camera:=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes;camera.make_current()
	for hour in [7,19]:
		camera.position=Vector3(12,28,40);camera.look_at(Vector3(0,2,0));camera.fov=44
		claim.get_node("Daylight").apply(hour)
		if hour==19: camp.fire_hours=0;camp.ember_hours=0;camp.smoke.restart();camp.smoke.emitting=false;camp.flame.restart();camp.flame.emitting=false
		for i in 30: await process_frame
		await physics_frame;await RenderingServer.frame_post_draw
		Guard.check(self,"rim-final")
		root.get_texture().get_image().save_png("res://artifacts/milestone-10-rim-%s.png" % ("dawn" if hour==7 else "dusk"))
		if hour==7:
			var coverage: Dictionary=await preload("res://tests/store_landscape_probe.gd").measure(self,claim)
			landscape_pass=coverage.bar_and_river>=.3
			FileAccess.open("res://artifacts/store-landscape-probe.json",FileAccess.WRITE).store_string(JSON.stringify(coverage,"\t"));print(coverage)
	var walker: Node3D=claim.get_node("Walker");walker.position=Vector3(0,.03,-5)
	var visual: Node3D=walker.get_node("Visual");visual.rotation.y=0;visual.play_activity("cast")
	camera.position=Vector3(-3,2.7,-1);camera.look_at(walker.position+Vector3(0,1.5,0));camera.fov=55
	for i in 36: await process_frame
	await physics_frame;await RenderingServer.frame_post_draw;Guard.check(self,"rod-cast")
	root.get_texture().get_image().save_png("res://artifacts/milestone-10-rod-cast.png")
	claim.get_node("Soundscape").stop();camp.fire_sound.stop();claim.get_node("Rain").sound.stop();quit(1 if Guard.failed or not landscape_pass else 0)
