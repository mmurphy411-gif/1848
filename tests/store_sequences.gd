extends SceneTree
const Guard=preload("res://tests/composition_guard.gd")
var report: Dictionary={}
func _initialize() -> void: run.call_deferred()
func save(path: String) -> void:
	await RenderingServer.frame_post_draw
	Guard.check(self,path)
	root.get_texture().get_image().save_png("res://artifacts/"+path+".png")
func run() -> void:
	root.size=Vector2i(1920,1080)
	DirAccess.make_dir_recursive_absolute("res://artifacts/trip-sequence")
	DirAccess.make_dir_recursive_absolute("res://artifacts/store-sequence")
	var game: Node=root.get_node("GameState");var trip: Node=root.get_node("Trip");var sack: Node=root.get_node("Sack")
	game.apply_scenario({"day":30,"hour":7,"hooks":2,"goods.salt":.2});sack.ounces=2
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim);current_scene=claim
	for i in 10: await process_frame
	claim.get_node("Camp").fire_hours=2;claim.get_node("Camp").smoke.preprocess=7
	claim.get_node("Walker").position=trip.trail-Vector3(0,0,1.3)
	claim.get_node("Walker/Visual").rotation.y=PI;claim.get_node("CameraRig").yaw=PI
	for i in 60: await process_frame
	claim.get_node("Daylight/Clock").start(7)
	var trip_tick:=Engine.get_physics_frames()
	for frame in 120:
		if frame==12: trip.depart()
		while Engine.get_physics_frames()<trip_tick+frame*5: await physics_frame
		await save("trip-sequence/frame-%03d" % frame)
		if frame==36:
			await save("milestone-10-rim-dawn")
			var fire: Vector3=claim.get_node("Camp").global_position
			report.rim_fire_inside=Rect2(Vector2.ZERO,Vector2(root.size)).has_point(root.get_camera_3d().unproject_position(fire)) and not root.get_camera_3d().is_position_behind(fire)
	while trip.travelling: await process_frame
	var store: Node3D=trip.shop
	store.walker.position=Vector3(-1.35,0,.7)
	store.interact("scale")
	var mount:=Node3D.new();root.add_child(mount);var review:=Camera3D.new();mount.add_child(review)
	review.position=Vector3(-2.25,2.35,-.7);review.look_at(Vector3(-1.05,1.35,.15));review.fov=42;review.attributes=store.get_node("Daylight").camera_attributes;review.make_current()
	var store_tick:=Engine.get_physics_frames()
	for frame in 180:
		if frame==96: store.finish_pour();store.counter.select("flour");store.counter.select("hook");store.counter.select("line")
		if frame==132: store.interact("slate")
		while Engine.get_physics_frames()<store_tick+frame*5: await physics_frame
		await save("store-sequence/frame-%03d" % frame)
	mount.queue_free()
	while store.busy: await process_frame
	trip.home()
	for i in 180: await process_frame
	await save("milestone-10-rim-dusk")
	while trip.travelling: await process_frame
	report.return_hour=claim.get_node("Daylight/Clock").hour_at(claim.get_node("Daylight/Clock").elapsed)
	report.return_fire=claim.get_node("Camp").fire_hours
	report.frames_per_second=12;report.trip_frames=120;report.store_frames=180
	game.day=65;claim.get_node("Daylight/Clock").start(7);sack.ounces=3
	await trip.depart(true);store=trip.shop
	store.counter.credit_pour(1);sack.ounces-=1;store.counter.select("pork");store.counter.settle()
	await trip.home(true)
	claim.get_node("Ledger").open_book();await save("milestone-10-ledger-prices")
	claim.get_node("Ledger").close_book()
	# The rod variant reuses the original motion with a 40-degree forearm offset.
	game.inventory.rod=true
	var walker: Node3D=claim.get_node("Walker");walker.position=Vector3(0,.03,-5)
	var visual: Node3D=walker.get_node("Visual");visual.rotation.y=0;visual.play_activity("cast")
	var camera:=Camera3D.new();claim.add_child(camera);camera.position=Vector3(-3,2.7,-1);camera.look_at(walker.position+Vector3(0,1.5,0));camera.fov=55;camera.attributes=claim.get_node("Daylight").camera_attributes;camera.make_current()
	for i in 36: await process_frame
	await save("milestone-10-rod-cast")
	FileAccess.open("res://artifacts/store-sequence-report.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	print("SEQUENCES ",report)
	claim.get_node("Soundscape").stop();claim.get_node("Camp").fire_sound.stop();claim.get_node("Rain").sound.stop()
	quit(1 if Guard.failed else 0)
