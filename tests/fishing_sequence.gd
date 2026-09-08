extends SceneTree
const Layout=preload("res://scripts/claim_layout.gd")
const Guard=preload("res://tests/composition_guard.gd")
var claim: Node3D
var walker: CharacterBody3D
var camera: Camera3D
func _initialize() -> void: run.call_deferred()
func save_frame(folder: String,index: int,subject := Vector3.ZERO) -> void:
	await RenderingServer.frame_post_draw
	var ok := Guard.check(self,folder+str(index)) if subject==Vector3.ZERO else Guard.check_subject(self,folder+str(index),walker,subject)
	assert(ok)
	root.get_texture().get_image().save_png("res://artifacts/%s/%03d.png" % [folder,index])
func run() -> void:
	Engine.physics_ticks_per_second=12
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"20","weather":"clear","hour":"18.5","hooks":"20","bait.grasshopper":"10","firewood":"10","fish.smoked":"1"})
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	walker=claim.get_node("Walker")
	claim.get_node("Daylight").apply(18.5)
	var bank_z: float=Layout.shore_z(-9.95)-.8
	walker.position=Vector3(-9.95,Layout.height_at(-9.95,bank_z)+.01,bank_z);walker.velocity=Vector3.ZERO
	var rig: Node3D=claim.get_node("CameraRig")
	rig.yaw=.3;rig.pitch=-.35
	for i in 30: await physics_frame
	walker.set_physics_process(false)
	var fisher: Node=walker.get_node("Fisher")
	assert(fisher.can_fish(),"Catch recording must begin in fishable shallows")
	fisher.reproducible=true;fisher.press();fisher.cast()
	fisher.target=Vector3(-9.95,-.05,-10.9)
	fisher.change(fisher.State.BITE,"fish_wait")
	fisher.fish=claim.get_node("FishSchool").nearest("trout",fisher.target)
	if is_instance_valid(fisher.fish): fisher.fish.approach=true;fisher.fish.approach_target=fisher.target
	DirAccess.make_dir_recursive_absolute("res://artifacts/catch-sequence")
	var showed_fish := false
	for i in (0 if "--camp-only" in OS.get_cmdline_user_args() else 120):
		if fisher.state==fisher.State.BITE and fisher.elapsed>=.25:
			fisher.press()
			fisher.weight=.7
			fisher.fight=preload("res://scripts/fight_model.gd").begin(.7,5,0)
		if fisher.state==fisher.State.FIGHT:
			var upcoming: bool=fisher.fight.elapsed+1.0/12>=fisher.fight.run_at and fisher.fight.elapsed+1.0/12<fisher.fight.run_at+.8
			if upcoming: Input.action_release("fish")
			else: Input.action_press("fish")
		else: Input.action_release("fish")
		await physics_frame
		await save_frame("catch-sequence",i,fisher.trophy.global_position if is_instance_valid(fisher.trophy) else Vector3.ZERO)
		if fisher.state==fisher.State.SHOWING: showed_fish=true
	if not "--camp-only" in OS.get_cmdline_user_args(): assert(showed_fish,"Catch recording must reach SHOWING")
	Input.action_release("fish");fisher.cancel()
	var camp: Node3D=claim.get_node("Camp")
	var activities: Node=claim.get_node("Activities")
	walker.position=camp.position+Vector3(.8,.1,-.9);walker.velocity=Vector3.ZERO
	walker.position.y=Layout.height_at(walker.position.x,walker.position.z)+.02
	walker.get_node("Visual").rotation.y=-.3
	claim.get_node("Daylight").apply(20.25)
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	camera.position=camp.position+Vector3(-4,2,-5);camera.look_at(camp.position+Vector3(0,.7,.5));camera.current=true
	activities.start("fire","tend_fire",2)
	DirAccess.make_dir_recursive_absolute("res://artifacts/camp-sequence")
	for i in 144:
		if i==42:
			camp.eat_stored();activities.start("eat","eat",3)
		await physics_frame
		await save_frame("camp-sequence",i)
	claim.get_node("Soundscape").stop();walker.get_node("ActionAudio").stop();camp.fire_sound.stop();claim.get_node("Rain").sound.stop()
	for i in 10: await process_frame
	print("SEQUENCES PASS: 120 catch frames and 144 camp frames at 12fps")
	quit()
