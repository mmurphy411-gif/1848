extends SceneTree
## 2.0 frame cost with a working outfit in view: ten hands, the cradle team,
## the wing-dam channel, and supper at the crew fire. Same sampler as Phase 2.
const Lighting=preload("res://tests/lighting_capture.gd")
const Crew=preload("res://scripts/crew_model.gd")
const Gold=preload("res://scripts/gold_map.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"66","hour":"10","dollars":"500","crew":"10","pans":"4","bunks":"3","rocker":"1","shovel":"1","pick":"1","crowbar":"1","weather":"clear"})
	for p in Gold.peak_points(): Crew.record_prospect(game.crew,Vector3(p.x,0,p.y),.08,66)
	game.inventory.goods.flour=100.0
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	for i in 5: await process_frame
	game.mining.owned=true;Crew.site_cradle(game.crew,game.mining,game.water_level());game.morning_orders()
	claim.get_node("Mining").refresh()
	var clock: Node=claim.get_node("Daylight/Clock");clock.start(10.0)
	var walker: Node3D=claim.get_node("Walker")
	walker.position=Vector3(2,.4,-3);claim.get_node("CameraRig").yaw=PI*.9;claim.get_node("CameraRig").pitch=-.25
	claim.get_node("Crew").settle()
	for i in 240: await process_frame
	var ok: bool=await Lighting._sample(self,"2.0 ten hands at work")
	game.crew.dam.built=true;game.crew.dam.day=66;game.morning_orders();game.crew_changed.emit();claim.get_node("Crew").settle()
	walker.position=Vector3(-4,.3,-3)
	for i in 240: await process_frame
	ok=await Lighting._sample(self,"2.0 wing dam channel") and ok
	clock.start(19.8);claim.get_node("Crew").settle()
	walker.position=claim.get_node("Crew").fire_point()+Vector3(-2,0,-5)
	for i in 240: await process_frame
	ok=await Lighting._sample(self,"2.0 crew supper") and ok
	claim.get_node("Soundscape").stop();claim.get_node("Camp").fire_sound.stop();claim.queue_free()
	for i in 8: await process_frame
	quit(0 if ok else 1)
