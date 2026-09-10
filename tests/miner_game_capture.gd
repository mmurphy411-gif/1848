extends SceneTree
const Layout = preload("res://scripts/claim_layout.gd")
var claim: Node3D
var camera: Camera3D
var visual: Node3D
var walker: CharacterBody3D
func _initialize() -> void:run.call_deferred()
func frames(n: int) -> void:
	for i in n:await process_frame
func shot(label: String, eye: Vector3, target: Vector3, fov := 35.0) -> void:
	camera.global_position=eye;camera.look_at(target);camera.fov=fov;camera.make_current()
	await frames(24);await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/miner-game/"+label+".png")
	print("GAME CAPTURE ",label)
func pose(clip: String, time: float) -> void:
	visual.tree.active=false;visual.player.play(clip);visual.player.seek(time,true);visual.player.pause()
	await frames(2)
func run() -> void:
	root.size=Vector2i(1440,1000)
	root.get_node("GameState").apply_scenario({"day":"75","weather":"clear","hour":"8","crowbar":"1","shovel":"1","pick":"1","boots":"1","rocker":"1"})
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	walker=claim.get_node("Walker");visual=walker.get_node("Visual")
	walker.position=Vector3(0,Layout.height_at(0,1)+.02,1)
	claim.get_node("Daylight").apply(8)
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	await frames(30);walker.set_physics_process(false);visual.set_physics_process(false);visual.rotation.y=0;visual.turn_elapsed=.3
	var p:=walker.position
	await pose("idle",.5);visual._apply_carry_grips()
	await shot("expedition_front",p+Vector3(1.6,1.3,-3.4),p+Vector3(0,.95,0))
	await shot("expedition_back",p+Vector3(-1.7,1.4,3.2),p+Vector3(0,1.0,0))
	await shot("face",p+Vector3(.35,1.65,-.95),p+Vector3(0,1.59,0),28)
	for key in visual.equipment:visual.set_equipment(key,false)
	await pose("idle",.5)
	await shot("base_front",p+Vector3(1.6,1.3,-3.4),p+Vector3(0,.95,0))
	for key in visual.equipment:visual.clear_equipment_override(key)
	await pose("walk",.25);visual._apply_carry_grips()
	await shot("walk",p+Vector3(2.4,1.3,-2.4),p+Vector3(0,.95,0))
	for clip in ["pan_swirl","cast","pick","cook","lie_down"]:
		visual.activity_clip="" if clip=="pan_swirl" else clip;visual.active_pan="pan_swirl" if clip=="pan_swirl" else "";visual._update_equipment()
		await pose(clip,.5 if clip!="lie_down" else 2.0)
		await shot(clip,p+Vector3(2.0,1.5,-3.1),p+Vector3(0,.72,0),36)
	claim.get_node("Soundscape").stop();claim.queue_free();await frames(8)
	print("MINER GAME CAPTURE COMPLETE");quit()
