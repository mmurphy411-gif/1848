extends SceneTree
## 2.0 review renders: the wing dam rising and standing, the crew in the channel,
## and the title screen. Saved to artifacts/v2/.
const Crew=preload("res://scripts/crew_model.gd")
const Layout=preload("res://scripts/claim_layout.gd")
var claim: Node3D
var camera: Camera3D
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await frames(10);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/v2/"+name+".png")
	print("CAPTURE ",name)
func view(from: Vector3, at: Vector3, fov := 50.0) -> void:
	camera.position=from;camera.look_at(at);camera.fov=fov;camera.make_current()
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/v2")
	root.size=Vector2i(1600,900)
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"64","hour":"10.5","dollars":"300","crew":"8","pans":"2","bunks":"2","shovel":"1","pick":"1","weather":"clear"})
	game.inventory.timber=1;game.inventory.goods.flour=80.0
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	await frames(5)
	var clock: Node=claim.get_node("Daylight/Clock")
	clock.start(10.5);claim.get_node("Daylight").apply(10.5)
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	claim.get_node("Walker").position=Vector3(-4,Layout.height_at(-4,Layout.shore_z(-4)+2),Layout.shore_z(-4)+2)
	game.crew.dam.progress=Crew.DAM_HOURS*.45
	game.morning_orders();game.crew_changed.emit()
	claim.get_node("Crew").settle();await frames(60)
	view(Vector3(14,6,4),Vector3(-5,-1.5,-11),55)
	await shot("dam_building")
	game.crew.dam.progress=Crew.DAM_HOURS;game.crew.dam.built=true;game.crew.dam.day=66
	game.morning_orders();game.crew_changed.emit()
	claim.get_node("Crew").settle();await frames(90)
	for h in game.crew.hands: print("HAND ",h.name," ",h.job)
	view(Vector3(14,6,4),Vector3(-5,-1.5,-11),55)
	await shot("dam_channel")
	view(Vector3(-4,2.2,Layout.shore_z(-4)+1.5),Vector3(-4,-2,Layout.shore_z(-4)-8),60)
	await shot("dam_channel_low")
	claim.get_node("Walker").position=Vector3(-4,Layout.height_at(-4,Layout.shore_z(-4)-6),Layout.shore_z(-4)-6)
	await frames(30)
	claim.get_node("CameraRig/SpringArm3D/Camera3D").make_current()
	print("WALKER depth ",claim.get_node("Walker").water_depth," pan ",claim.get_node("Walker/Panner").can_pan())
	await shot("dam_player_in_channel")
	claim.queue_free();await frames(5)
	game.apply_scenario({"day":"0","crew":"0"})
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	await frames(5)
	var title: Node=preload("res://scripts/title.gd").new();title.name="Title";claim.add_child(title)
	await frames(200)
	await shot("title")
	quit(0)
