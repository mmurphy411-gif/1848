extends SceneTree
const Mining=preload("res://scripts/mining_model.gd")
const Layout=preload("res://scripts/claim_layout.gd")
var claim: Node3D
var camera: Camera3D
var failures := 0
var coverage: Dictionary={}
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func shot(label: String,eye: Vector3,point: Vector3,fov := 48.0) -> void:
	camera.position=eye;camera.look_at(point);camera.fov=fov;camera.make_current()
	for i in 30: await process_frame
	await RenderingServer.frame_post_draw
	if not preload("res://tests/composition_guard.gd").check(self,label): failures+=1
	root.get_texture().get_image().save_png("res://artifacts/m11-"+label+".png")
	if label in ["crevice","spoon","loading","rocking"]:
		# Freeze gameplay during the identity pass; its changes must not advance work.
		tree_pause(true)
		var result: Dictionary=await preload("res://tests/mining_coverage.gd").measure(self,claim)
		tree_pause(false)
		coverage[label]=result
		if result.get("miner",0)<.06 or (label in ["loading","rocking"] and result.get("cradle",0)<.03): failures+=1
func tree_pause(value: bool) -> void: paused=value
func run() -> void:
	root.size=Vector2i(1280,720)
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"0","weather":"clear","hour":"8","crowbar":"1","shovel":"1","pick":"1","boots":"1","rocker":"1"})
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	claim.get_node("Daylight").apply(8)
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	var m: Node3D=claim.get_node("Mining")
	var w: CharacterBody3D=claim.get_node("Walker")
	var a: Node=claim.get_node("Activities")
	var slab := Mining.slab_point(0)
	w.position=Vector3(0,1,5)
	await shot("june-bank",slab+Vector3(8,5,6),slab+Vector3(-1,0,0),52)
	game.apply_scenario({"day":"75"})
	await shot("september-bank",slab+Vector3(8,5,6),slab+Vector3(-1,0,0),52)
	m.focus_site("crevice");await frames(20);m.interact();await frames(180)
	await shot("crevice",w.position+Vector3(2.7,1.7,-1.6),w.position+Vector3(0,.55,-.4),38)
	await frames(500)
	await shot("spoon",w.position+Vector3(2.7,1.7,-1.6),w.position+Vector3(0,.55,-.4),38)
	m.cancel();m.focus_site("rocker");await frames(20);m.interact();await frames(370)
	m.focus_site("rocker");await frames(20);m.interact();await frames(60)
	await shot("loading",m.rocker.position+Vector3(-1.5,1.9,3.5),m.rocker.position+Vector3(.35,.68,0),33)
	await frames(500)
	await shot("rocking",m.rocker.position+Vector3(-1.5,1.9,3.5),m.rocker.position+Vector3(.35,.68,0),33)
	m.cancel()
	FileAccess.open("res://artifacts/m11-coverage.json",FileAccess.WRITE).store_string(JSON.stringify(coverage,"\t"))
	print("M11 CAPTURES: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
