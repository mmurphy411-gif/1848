extends SceneTree
## 2.0 review renders: the outfit at work, the crew camp at supper, the roll book
## and Lambert's outfitting corner. Saved to artifacts/v2/.
const Crew=preload("res://scripts/crew_model.gd")
const Gold=preload("res://scripts/gold_map.gd")
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
	game.apply_scenario({"day":"44","hour":"10","dollars":"300","crew":"7","pans":"3","bunks":"2","rocker":"1","shovel":"1","crowbar":"1","pick":"1","weather":"clear"})
	for p in Gold.peak_points(): Crew.record_prospect(game.crew,Vector3(p.x,0,p.y),.08,44)
	for x in range(-30,31,7): Crew.record_prospect(game.crew,Vector3(x,0,Layout.shore_z(x)+.5),.02,44)
	game.inventory.goods.flour=60.0;game.inventory.goods.beans=30.0
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	await frames(5)
	game.mining.owned=true
	Crew.site_cradle(game.crew,game.mining,game.water_level())
	game.morning_orders()
	claim.get_node("Mining").refresh()
	var clock: Node=claim.get_node("Daylight/Clock")
	clock.start(10.0);claim.get_node("Daylight").apply(10.0)
	var crew: Node3D=claim.get_node("Crew")
	crew.sync();crew.settle()
	for h in game.crew.hands: print("HAND ",h.name," ",h.job," at ",crew.hands[h.id].global_position," ready '",Crew.job_ready(game.crew,h,game.inventory,game.mining,game.water_level()),"'")
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	claim.get_node("Walker").position=claim.get_node("Camp").position+Vector3(-2,0,-3)
	await frames(90)
	view(Vector3(26,7,4),Vector3(4,-.5,-7),50)
	await shot("crew_wide")
	var rocker: Node3D=claim.get_node("Mining").rocker
	var r: Vector3=rocker.global_position
	view(r+Vector3(4.5,2.2,4.5),r+Vector3(0,.6,.8),45)
	await shot("crew_cradle")
	var panner: Node3D=null
	for id in crew.hands:
		if Crew.hand(game.crew,id).job=="pan": panner=crew.hands[id];break
	if panner:
		var p: Vector3=panner.global_position
		print("PANNER at ",p," target ",panner.target," visible ",panner.visible," clip ",panner.clip)
		view(p+Vector3(2.6,1.4,2.2),p+Vector3(0,.5,-.4),42)
		await shot("crew_panner")
	clock.start(19.6);claim.get_node("Daylight").apply(19.6)
	crew.settle();await frames(90)
	var f: Vector3=crew.fire_point()
	view(f+Vector3(-3,2.6,-7.5),f+Vector3(0,.8,1.5),52)
	await shot("crew_supper")
	claim.get_node("CrewBook").open_book();await frames(5)
	await shot("crew_book")
	claim.get_node("CrewBook").close_book()
	claim.get_node("Soundscape").stop();claim.get_node("Camp").fire_sound.stop();claim.queue_free();await frames(5)
	game.apply_scenario({"day":"44","hour":"13","dollars":"200"})
	var shop: Node3D=load("res://scenes/store.tscn").instantiate();root.add_child(shop)
	shop.walker.set_physics_process(false);shop.walker.position=Vector3(1,0,4)
	camera=Camera3D.new();shop.add_child(camera);camera.attributes=shop.get_node("Daylight").camera_attributes
	view(Vector3(-.4,2.2,5.6),Vector3(-2.6,.6,2.2),50)
	await shot("store_outfitting")
	quit(0)
