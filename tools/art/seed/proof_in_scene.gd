extends SceneTree
## Loads un-imported GLBs at runtime (GLTFDocument) into the live claim for a quick look.
## godot --path . --resolution 1600x900 --script tools/art/seed/proof_in_scene.gd -- [args]
##   glb=a.glb[,b.glb,c.glb]  up to three rock-slot GLBs, paths relative to the project root
##                            (default: the audit proof set in artifacts/visual-audit/proof/)
##   out=dir/name.png         capture path (default artifacts/visual-audit/proof/proof_rocks.png)
##   native=1                 keep each GLB's own size (normalised assets) instead of the slot height
##   hour=10  trees=0|1       time of day; the tree shot (default on only for the audit set)
##   cam=x,y,z look=x,y,z     camera override for the rock shot
const Layout = preload("res://scripts/claim_layout.gd")
const AUDIT := "artifacts/visual-audit/proof/"
## x, absolute z, slot height, sink, yaw
const SLOTS := [[2.0, 0.0, 2.6, .5, .6], [4.5, 3.0, 1.4, .3, 2.4], [-1.0, 6.0, 3.4, .5, 0.0]]
var args := {}
func _initialize() -> void: run.call_deferred()
func path(p: String) -> String: return p if p.is_absolute_path() else ProjectSettings.globalize_path("res://").path_join(p)
func vec(s: String) -> Vector3:
	var p := s.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))
func glb(file: String) -> Node3D:
	var doc := GLTFDocument.new();var state := GLTFState.new()
	var err := doc.append_from_file(path(file),state)
	assert(err==OK,"cannot load "+file)
	return doc.generate_scene(state)
func put(node: Node3D, parent: Node, x: float, inland: float, height: float, sink := 0.0, yaw := 0.0, absolute := false) -> void:
	parent.add_child(node)
	var box := AABB()
	for m in node.find_children("*","MeshInstance3D",true,false): box=box.merge(m.global_transform*m.get_aabb()) if box.size!=Vector3.ZERO else m.global_transform*m.get_aabb()
	node.scale=Vector3.ONE*(height/box.size.y if height>0 else 1.0)
	var z := inland if absolute else Layout.shore_z(x)+inland
	node.position=Vector3(x,Layout.height_at(x,z)-box.position.y*node.scale.y-sink,z);node.rotation.y=yaw
	print("placed %s: %.2f m tall at (%.1f, %.1f)" % [node.name, box.size.y*node.scale.y, x, z])
func shot(file: String) -> void:
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(path(file).get_base_dir())
	root.get_texture().get_image().save_png(path(file))
	print("wrote ", path(file))
func run() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.split("=",true,1)
		if kv.size()==2: args[kv[0]]=kv[1]
	var files: Array = Array(args.glb.split(",")) if args.has("glb") else [AUDIT+"boulder_01_game.glb",AUDIT+"boulder_01_game.glb",AUDIT+"rock_face_01_game.glb"]
	var native: bool = args.get("native","0")=="1"
	var hour := float(args.get("hour","10"))
	var out: String = args.get("out",AUDIT+"proof_rocks.png")
	root.content_scale_size=Vector2i(1600,900);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.get_node("GameState").apply_scenario({"day":"10","hour":str(int(hour)),"weather":"clear"})
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	for i in 10: await process_frame
	var light: Node3D=claim.get_node("Daylight");light.apply(hour)
	claim.get_node("Walker").position=Vector3(-30,Layout.height_at(-30,Layout.shore_z(-30)+6),Layout.shore_z(-30)+6)
	for i in mini(files.size(),SLOTS.size()):
		var s: Array = SLOTS[i]
		var node := glb(files[i]);node.name=files[i].get_file().get_basename()
		var h: float = 0.0 if native else s[2]
		var sink: float = s[3]
		if native:
			var box := AABB()
			for m in node.find_children("*","MeshInstance3D",true,false): box=box.merge(m.get_aabb()) if box.size!=Vector3.ZERO else m.get_aabb()
			sink*=box.size.y/s[2]
		put(node,claim,s[0],s[1],h,sink,s[4],true)
	var cam := Camera3D.new();claim.add_child(cam);cam.attributes=light.camera_attributes;cam.far=600
	cam.position=vec(args.cam) if args.has("cam") else Vector3(-5,1.8,-4.5);cam.fov=60
	cam.look_at(vec(args.look) if args.has("look") else Vector3(4,1.1,-.5));cam.current=true
	await shot(out)
	if args.get("trees","0" if args.has("glb") else "1")=="1":
		var bark := StandardMaterial3D.new();bark.albedo_color=Color(.23,.17,.12);bark.roughness=.95
		var leaf := StandardMaterial3D.new();leaf.albedo_color=Color(.20,.33,.09);leaf.roughness=.8;leaf.cull_mode=BaseMaterial3D.CULL_DISABLED
		for pair in [["oak_1.glb",-24.0,17.0,13.0],["oak_2.glb",-8.0,18.0,15.0],["pine_7.glb",-16.0,22.0,26.0]]:
			var tree := glb(AUDIT+pair[0])
			for m in tree.find_children("*","MeshInstance3D",true,false):
				m.set_surface_override_material(0,bark);m.set_surface_override_material(1,leaf)
			put(tree,claim,pair[1],pair[2],pair[3])
		var z0 := Layout.shore_z(-14)
		cam.position=Vector3(-16,3.0,z0-6);cam.fov=60;cam.look_at(Vector3(-16,7,z0+18))
		await shot(out.get_base_dir().path_join("proof_trees.png"))
	claim.get_node("Soundscape").stop();claim.queue_free()
	for i in 5: await process_frame
	quit(0)
