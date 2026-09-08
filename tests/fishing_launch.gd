extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var claim: Node=load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim);current_scene=claim
	await create_timer(1).timeout
	assert(claim.get_node("Daylight/Clock").is_processing())
	print("M9 MAIN SCENE LAUNCH AND GRACEFUL QUIT: PASS")
	claim.request_quit()
