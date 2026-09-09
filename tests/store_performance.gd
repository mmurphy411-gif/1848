extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1920,1080);DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game: Node=root.get_node("GameState");game.apply_scenario({"day":110,"hour":13,"weather":"rain"})
	var store: Node3D=load("res://scenes/store.tscn").instantiate();root.add_child(store)
	store.walker.position=Vector3(0,0,1.3);store.walker.set_physics_process(false)
	store.camera_rig.focus(Vector3(.5,2,4.7),Vector3(0,1.4,-.7),55)
	store.get_node("Rain").current=1.0;store.get_node("Rain").particles.amount_ratio=1.0
	for i in 240: await process_frame
	store.get_node("Rain").set_process(false);store.get_node("Rain").particles.amount_ratio=1.0
	var samples: Array[float]=[];var previous:=Time.get_ticks_usec()
	for i in 600:
		await process_frame
		var now:=Time.get_ticks_usec();samples.append((now-previous)/1000.0);previous=now
	samples.sort()
	var result:={"median_ms":samples[300],"p95_ms":samples[570],"budget_ms":4.5,"resolution":"1920x1080","day":110,"rain":true}
	FileAccess.open("res://artifacts/store-performance.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print("STORE PERFORMANCE ",result)
	store.get_node("Soundscape").stop();store.get_node("Rain").sound.stop();store.queue_free()
	for i in 8: await process_frame
	quit(0 if samples[570]<4.5 else 1)
