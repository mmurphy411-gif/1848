extends SceneTree
var claim: Node3D
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"95","weather":"rain","hour":"23","bait.grasshopper":"6","firewood":"10"})
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var camp: Node3D=claim.get_node("Camp")
	camp.fire_hours=4
	var rain: Node=claim.get_node("Rain");rain.current=1
	claim.get_node("Daylight").overcast=1;claim.get_node("Daylight").apply(23)
	var school: Node=claim.get_node("FishSchool")
	school.refresh()
	var data: Array=preload("res://scripts/fishery.gd").expected_population(95,6,game.seed)
	while school.get_child_count()<24:
		var fish := preload("res://scripts/fish.gd").new();fish.configure(data[school.get_child_count()%data.size()],school.sources.trout,claim.get_node("Walker"));school.add_child(fish)
	var camera := Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	camera.position=camp.position+Vector3(5,3,-7);camera.look_at(camp.position+Vector3(0,1,0));camera.current=true
	var line: Node=claim.get_node("Walker/Fisher").line;line.show();line.mesh.show()
	line.draw_line(camp.position+Vector3(0,1,0),camp.position+Vector3(5,0,-2),false)
	for i in 300: await process_frame
	var ok: bool=await preload("res://tests/lighting_capture.gd")._sample(self,"M9 night fire, rain, 24 fish")
	print("MILESTONE 9 PERFORMANCE: ","PASS" if ok else "FAIL")
	claim.get_node("Soundscape").stop();claim.get_node("Walker/ActionAudio").stop();camp.fire_sound.stop();rain.sound.stop()
	for i in 10: await process_frame
	quit(0 if ok else 1)
