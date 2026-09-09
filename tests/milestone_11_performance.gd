extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"75","hour":"8","weather":"rain","rocker":"1","shovel":"1","pick":"1"})
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var mining: Node3D=claim.get_node("Mining")
	var p:=Vector3(0,0,claim.get_node("Greybox/River").shore_z(0)+.6)
	p.y=preload("res://scripts/claim_layout.gd").height_at(p.x,p.z)+.02
	game.mining.rocker_position=p;game.mining.rocker_built=true;game.changed.emit()
	mining.focus_site("rocker")
	for i in 20: await physics_frame
	mining.interact()
	var camera:=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	camera.position=p+Vector3(-1.5,1.9,3.5);camera.look_at(p+Vector3(.35,.55,0));camera.fov=42;camera.make_current()
	claim.get_node("Rain").current=1;claim.get_node("Rain").particles.amount_ratio=1
	for i in 510: await physics_frame
	for i in 240: await process_frame
	var samples: Array[float]=[];var previous:=Time.get_ticks_usec()
	for i in 600:
		await process_frame
		var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
	samples.sort()
	var result:={"median_ms":samples[300],"p95_ms":samples[570],"budget_ms":16.667,"resolution":"1920x1080","rocking":mining.visual.activity_clip=="rock"}
	FileAccess.open("res://artifacts/m11-performance.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("M11 PERFORMANCE ",result)
	quit(0 if samples[570]<16.667 and result.rocking else 1)
