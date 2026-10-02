extends SceneTree
## Seed: loads un-imported GLBs at runtime (GLTFDocument) and places them in the live
## claim for a quick look. Expects the GLBs in artifacts/visual-audit/proof/.
const Layout = preload("res://scripts/claim_layout.gd")
const DIR := "C:/Users/mmurp/1848/artifacts/visual-audit/proof/"
func _initialize() -> void: run.call_deferred()
func glb(name: String) -> Node3D:
	var doc := GLTFDocument.new();var state := GLTFState.new()
	doc.append_from_file(DIR+name,state)
	return doc.generate_scene(state)
func put(node: Node3D, parent: Node, x: float, inland: float, height: float, sink := 0.0, yaw := 0.0, absolute := false) -> void:
	parent.add_child(node)
	var box := AABB()
	for m in node.find_children("*","MeshInstance3D",true,false): box=box.merge(m.global_transform*m.get_aabb()) if box.size!=Vector3.ZERO else m.global_transform*m.get_aabb()
	node.scale=Vector3.ONE*height/box.size.y
	var z := inland if absolute else Layout.shore_z(x)+inland
	node.position=Vector3(x,Layout.height_at(x,z)-box.position.y*node.scale.y-sink,z);node.rotation.y=yaw
func run() -> void:
	root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.get_node("GameState").apply_scenario({"day":"10","hour":"10","weather":"clear"})
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	for i in 10: await process_frame
	var light: Node3D=claim.get_node("Daylight");light.apply(10.0)
	claim.get_node("Walker").position=Vector3(-30,Layout.height_at(-30,Layout.shore_z(-30)+6),Layout.shore_z(-30)+6)
	put(glb("boulder_01_game.glb"),claim,2,0,2.6,.5,.6,true)
	put(glb("boulder_01_game.glb"),claim,4.5,3,1.4,.3,2.4,true)
	put(glb("rock_face_01_game.glb"),claim,-1,6,3.4,.5,0.0,true)
	var bark := StandardMaterial3D.new();bark.albedo_color=Color(.23,.17,.12);bark.roughness=.95
	var leaf := StandardMaterial3D.new();leaf.albedo_color=Color(.20,.33,.09);leaf.roughness=.8;leaf.cull_mode=BaseMaterial3D.CULL_DISABLED
	for pair in [["oak_1.glb",-24.0,17.0,13.0],["oak_2.glb",-8.0,18.0,15.0],["pine_7.glb",-16.0,22.0,26.0]]:
		var tree := glb(pair[0])
		for m in tree.find_children("*","MeshInstance3D",true,false):
			m.set_surface_override_material(0,bark);m.set_surface_override_material(1,leaf)
		put(tree,claim,pair[1],pair[2],pair[3])
	var cam := Camera3D.new();claim.add_child(cam);cam.attributes=light.camera_attributes;cam.far=600
	var z0 := Layout.shore_z(-14)
	cam.position=Vector3(-5,1.8,-4.5);cam.fov=60;cam.look_at(Vector3(4,1.1,-.5));cam.current=true
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR+"proof_rocks.png")
	cam.position=Vector3(-16,3.0,z0-6);cam.fov=60;cam.look_at(Vector3(-16,7,z0+18))
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(DIR+"proof_trees.png")
	claim.get_node("Soundscape").stop();claim.queue_free()
	for i in 5: await process_frame
	quit(0)
