extends SceneTree
var claim: Node3D
var camera: Camera3D
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await process_frame
func shot(name: String) -> void:
	await frames(12);await RenderingServer.frame_post_draw
	if not preload("res://tests/composition_guard.gd").check(self,name):
		quit(1);return
	root.get_texture().get_image().save_png("res://artifacts/phase2/"+name+".png")
	print("CAPTURE ",name)
func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://artifacts/phase2")
	root.size=Vector2i(1440,1000)
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var e: Node=claim.get_node("Expedition");var walker: Node3D=claim.get_node("Walker")
	e.focus("salmon");await frames(40)
	walker.set_physics_process(false)
	for fish in claim.get_node("FishSchool").get_children(): fish.set_process(false)
	e.interact();claim.get_node("Activities").set_process(false)
	await frames(40)
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	var p: Vector3=walker.position
	camera.position=p+Vector3(2.9,1.5,-2.8);camera.look_at(p+Vector3(0,.45,-.65));camera.fov=48;camera.make_current()
	await shot("m12_spear_detail")
	claim.get_node("CameraRig/SpringArm3D/Camera3D").make_current()
	await shot("m12_spear_player")
	e.cancel();e.focus("raid");claim.get_node("Camp").fire_hours=4;await frames(30)
	if is_instance_valid(e.raid_bear): e.raid_bear.set_physics_process(false)
	p=claim.get_node("Camp").position
	print("RAID BEAR ",e.raid_bear.global_position if is_instance_valid(e.raid_bear) else "missing")
	camera.position=p+Vector3(-6,4,-13);camera.look_at(p+Vector3(2,.6,-2));camera.fov=52;camera.make_current()
	await shot("m12_raid")
	e.focus("deer");await frames(15)
	for actor in claim.get_node("Wildlife").actors:
		actor.set_physics_process(false);actor.walking=false;actor.state=actor.State.ALERT
	e.interact();await frames(40)
	p=walker.position;camera.position=p+Vector3(2.3,1.6,-2.7);camera.look_at(p+Vector3(0,1.0,-.2));camera.fov=38;camera.make_current()
	await shot("m13_rifle_detail")
	claim.get_node("CameraRig/SpringArm3D/Camera3D").make_current()
	await shot("m13_rifle_player")
	e.cancel()
	var game: Node=root.get_node("GameState");game.apply_scenario({"tent":"1","weather":"clear"})
	claim.get_node("Daylight").apply(9);p=claim.get_node("Camp").props.LeanTo.global_position
	camera.position=p+Vector3(3,1.6,-5);camera.look_at(p+Vector3(0,.65,0));camera.fov=46;camera.make_current()
	await shot("m14_tent")
	game.day=132;game.finish_season();await frames(80)
	p=claim.get_node("Camp").position;camera.position=p+Vector3(5,3,-8);camera.look_at(p+Vector3(0,1,1));camera.fov=50;camera.make_current()
	await shot("m14_snow")
	claim.get_node("Ledger").open_book();await shot("m14_final_ledger")
	claim.get_node("Soundscape").stop();e.sound.stop();claim.get_node("Camp").fire_sound.stop();claim.queue_free();await frames(5)
	game.apply_scenario({"day":"30","hour":"13","dollars":"200","rifle":"0","tent":"0","spear":"0"})
	game.inventory.hides=[{"id":"deer0","species":"deer","weight_lb":3}]
	var shop: Node3D=load("res://scenes/store.tscn").instantiate();root.add_child(shop)
	shop.walker.set_physics_process(false);shop.walker.position=Vector3(-2,0,3)
	shop.counter.select("rifle");shop.counter.select("powder");shop.counter.select("tent");shop.counter.toggle_fish()
	camera=Camera3D.new();shop.add_child(camera);camera.attributes=shop.get_node("Daylight").camera_attributes
	camera.position=Vector3(2.8,2.9,3.5);camera.look_at(Vector3(.8,1.2,.15));camera.fov=52;camera.make_current()
	await shot("m13_hide_trade")
	shop.queue_free();await frames(8);quit()
