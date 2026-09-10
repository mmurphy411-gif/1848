extends SceneTree
const Lighting=preload("res://tests/lighting_capture.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var e: Node=claim.get_node("Expedition");e.focus("salmon")
	for i in 240: await process_frame
	var ok: bool=await Lighting._sample(self,"M12 live salmon riffle")
	e.focus("raid");claim.get_node("Camp").fire_hours=4
	for i in 240: await process_frame
	ok=await Lighting._sample(self,"M12 fire and raiding bear") and ok
	root.get_node("GameState").apply_scenario({"tent":"1","day":"132"});root.get_node("GameState").finish_season()
	claim.get_node("SeasonEnd").book_delay=0
	for i in 240: await process_frame
	ok=await Lighting._sample(self,"M14 snow, tent and camp") and ok
	claim.get_node("Soundscape").stop();e.sound.stop();claim.get_node("Camp").fire_sound.stop();claim.queue_free()
	for i in 8: await process_frame
	quit(0 if ok else 1)
