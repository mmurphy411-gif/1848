extends "res://tests/milestone_11_capture.gd"
## Repeatable real-scene art review: neutral standing, close face, fitted pack,
## then live mining actions. No proxy meshes or replacement lighting materials.
func shot(label: String,eye: Vector3,point: Vector3,fov := 48.0) -> void:
	camera.position=eye;camera.look_at(point);camera.fov=fov;camera.make_current()
	for i in 20: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/miner-art-"+label+".png")
	print("ART CAPTURE ",label)

func run() -> void:
	root.size=Vector2i(1600,1000)
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"75","weather":"clear","hour":"8","crowbar":"1","shovel":"1","pick":"1","boots":"1","rocker":"1"})
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	claim.get_node("Daylight").apply(8)
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	var w: CharacterBody3D=claim.get_node("Walker")
	var v: Node3D=w.get_node("Visual")
	var m: Node3D=claim.get_node("Mining")
	w.position=Vector3(0,Layout.height_at(0,1)+.02,1)
	await frames(30)
	v.rotation.y=0;v.turn_elapsed=.3
	w.set_physics_process(false);v.set_physics_process(false)
	var p := w.position
	await shot("front",p+Vector3(1.7,1.35,-3.3),p+Vector3(0,.93,0),34)
	await shot("face",p+Vector3(.32,1.65,-.85),p+Vector3(0,1.59,0),26)
	if "--diagnostics" in OS.get_cmdline_user_args():
		claim.get_node("Daylight/Sun").shadow_enabled=false
		await shot("face-no-shadow",camera.position,p+Vector3(0,1.59,0),26)
		claim.get_node("Daylight/Sun").shadow_enabled=true
		claim.get_node("Daylight/Sun").shadow_normal_bias=.3
		claim.get_node("Daylight/Sun").shadow_bias=.05
		await shot("face-shadow-bias",camera.position,p+Vector3(0,1.59,0),26)
		claim.get_node("Daylight/Sun").shadow_normal_bias=1.2
		claim.get_node("Daylight/Sun").shadow_bias=.12
		root.use_taa=true
		await shot("face-taa",camera.position,p+Vector3(0,1.59,0),26)
		var env: Environment=claim.get_node("Daylight").environment
		env.sdfgi_enabled=false;env.ssao_enabled=false;env.ssil_enabled=false
		await shot("face-no-gi",camera.position,p+Vector3(0,1.59,0),26)
		for mesh in v.pack_visual.find_children("*","MeshInstance3D",true,false):
			for s in mesh.mesh.get_surface_count():print("PACK MATERIAL ",mesh.mesh.surface_get_material(s).resource_name)
		quit();return
	await shot("back",p+Vector3(-1.6,1.55,2.7),p+Vector3(0,1.15,0),32)
	await shot("profile",p+Vector3(2,1.40,.2),p+Vector3(0,1.25,0),35)
	w.set_physics_process(true);v.set_physics_process(true)
	m.focus_site("crevice");await frames(20);m.interact();await frames(180)
	w.set_physics_process(false);v.set_physics_process(false);m.set_physics_process(false)
	await shot("crevice",w.position+Vector3(2.7,1.7,-1.6),w.position+Vector3(0,.55,-.4),38)
	var hand: Vector3=v.right_hand.global_position
	await shot("grip",hand+Vector3(.65,.3,-.7),hand+Vector3(0,0,-.06),30)
	w.set_physics_process(true);v.set_physics_process(true);m.set_physics_process(true)
	m.cancel();m.focus_site("rocker");await frames(20);m.interact();await frames(370)
	m.focus_site("rocker");await frames(20);m.interact();await frames(60)
	await shot("loading",m.rocker.position+Vector3(-1.5,1.9,3.5),m.rocker.position+Vector3(.35,.68,0),33)
	await frames(500)
	await shot("rocking",m.rocker.position+Vector3(-1.5,1.9,3.5),m.rocker.position+Vector3(.35,.68,0),33)
	m.cancel()
	print("MINER ART CAPTURE COMPLETE")
	quit()
