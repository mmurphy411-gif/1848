extends SceneTree
const Layout=preload("res://scripts/claim_layout.gd")
const Cooking=preload("res://scripts/cooking.gd")
var failures: Array[String]=[]
var claim: Node3D
var camera: Camera3D
func _initialize() -> void:
	run.call_deferred()
	create_timer(60).timeout.connect(func():push_error("Camp test timeout");quit(2))
func check(ok: bool,label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func capture(label: String,eye: Vector3,at: Vector3) -> void:
	if not "--capture" in OS.get_cmdline_user_args(): return
	camera.position=eye;camera.look_at(at);camera.current=true
	for i in 40: await process_frame
	await RenderingServer.frame_post_draw
	check(preload("res://tests/composition_guard.gd").check(self,label),label+" composition")
	root.get_texture().get_image().save_png("res://artifacts/camp-rework-%s.png" % label)
func interact(activities: Node,action: String) -> void:
	var event := InputEventAction.new();event.action=action;event.pressed=true
	activities._unhandled_input(event)
func run() -> void:
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"20","hour":"19","weather":"clear","firewood":"10"})
	game.inventory.fish=[Cooking.fresh("trout",1.2,20)]
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	claim.get_node("Daylight").apply(19)
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	var camp: Node3D=claim.get_node("Camp")
	var activities: Node=claim.get_node("Activities")
	var walker: CharacterBody3D=claim.get_node("Walker")
	var visual: Node3D=walker.get_node("Visual")
	var shelter: MeshInstance3D=camp.props.LeanTo.get_child(0)
	var bounds: AABB=shelter.global_transform*shelter.get_aabb()
	check(bounds.position.z-camp.global_position.z>3,"Entire shelter is over three metres inland of fire")
	check(camp.props.Bedroll.global_position.z>bounds.position.z,"Bedroll is behind open shelter front")
	check(camp.props.LeanTo.get_child(1).shape is ConcavePolygonShape3D,"Shelter collision keeps doorway open")
	walker.position=camp.global_position+Vector3(-1.15,0,0)
	walker.position.y=Layout.height_at(walker.position.x,walker.position.z)+.02
	visual.rotation.y=-PI/2
	check(camp.target(walker)=="FireRing","Fire can be selected independently")
	interact(activities,"interact");await frames(140)
	check(camp.burning() and game.inventory.firewood==7,"Fire interaction lights ring and consumes three wood")
	walker.position=camp.global_position+Vector3(.95,0,-1.8)
	walker.position.y=Layout.height_at(walker.position.x,walker.position.z)+.02
	walker.velocity=Vector3.ZERO;visual.rotation.y=PI;visual.turn_elapsed=.3
	check(camp.target(walker)=="Skillet","Skillet can be selected independently from fire")
	interact(activities,"interact");check(activities.cooking_menu,"Skillet opens frying choice")
	interact(activities,"fish");await frames(40)
	check(activities.action=="cook" and visual.activity_clip=="cook","Fry confirmation starts dedicated cooking loop")
	var maximum := 0.0
	var min_height := INF
	for i in 180:
		await physics_frame
		var offset: Vector3=camp.props.Skillet.global_position-camp.global_position
		maximum=maxf(maximum,Vector2(offset.x,offset.z).length())
		min_height=minf(min_height,offset.y)
	check(maximum<.22 and min_height>.25,"Skillet stays above coals for full animation loop (%.3fm offset, %.3fm height)" % [maximum,min_height])
	check(camp.cooking_food.visible and camp.props.Skillet.collision_layer==0,"Fish is visible in skillet while held")
	check(walker.position.distance_to(camp.work_position())<.01,"Cooking holds miner at fire station")
	await capture("layout",camp.position+Vector3(8,5,-9),camp.position+Vector3(0,1,1.8))
	await capture("frying",camp.position+Vector3(-2.8,1.8,-2.5),camp.position+Vector3(0,.6,-.2))
	camp.advance(1.0/3+.001)
	check(activities.action=="eat" and game.inventory.meals_today==1,"Frying completes into eating and awards meal")
	check(camp.props.Skillet.transform.is_equal_approx(camp.skillet_rest) and not camp.cooking_food.visible,"Skillet returns to its station after cooking")
	check(not camp.props.Skillet.visible,"Resting skillet stays hidden while miner eats from carried skillet")
	await capture("meal",camp.position+Vector3(-3,2,-3),camp.position+Vector3(0,.6,-.5))
	await frames(190)
	check(not activities.busy and not activities.holds_at_fire(),"Movement unlocks after meal")
	check(camp.props.Skillet.visible and camp.props.Skillet.collision_layer==1,"Skillet is set down once after eating")
	claim.get_node("Daylight").apply(20.25)
	await capture("dusk",camp.position+Vector3(8,4,-10),camp.position+Vector3(0,1,1.8))
	walker.position=camp.wake_position();walker.velocity=Vector3.ZERO
	visual.rotation.y=PI;visual.turn_elapsed=.3
	check(camp.target(walker)=="Bedroll","Bedroll is reachable from the open shelter front")
	interact(activities,"interact")
	check(activities.action=="sleep","Bedroll interaction actually starts sleep")
	await frames(200)
	check(not activities.busy and walker.position.z<camp.props.LeanTo.position.z+camp.position.z,"Sleep returns miner outside the low roof")
	print("CAMP REWORK: ","PASS" if failures.is_empty() else failures)
	claim.get_node("Soundscape").stop();walker.get_node("ActionAudio").stop();camp.fire_sound.stop();claim.get_node("Rain").sound.stop()
	OS.delay_msec(150);quit(0 if failures.is_empty() else 1)
