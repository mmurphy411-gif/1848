extends SceneTree
const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
const Vegetation = preload("res://scripts/vegetation.gd")
var failures: Array[String] = []

func _initialize() -> void: _run.call_deferred()

func _check(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures.append(label)

func _asset(path: String, low: int, high: int, wind := false) -> void:
	_check(FileAccess.file_exists(path),path+" exists")
	var packed = load(path)
	_check(packed is PackedScene,path+" loads as PackedScene")
	if not packed is PackedScene: return
	var mesh := Assets.mesh(path)
	var triangles := 0
	var min_weight := 1.0
	var max_weight := 0.0
	var all_colors := true
	for s in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(s)
		_check(arrays[Mesh.ARRAY_NORMAL]!=null and arrays[Mesh.ARRAY_TANGENT]!=null and arrays[Mesh.ARRAY_TEX_UV]!=null,path+" normals, tangents and UVs")
		triangles += arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX] != null else arrays[Mesh.ARRAY_VERTEX].size()/3
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR] if arrays[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		all_colors = all_colors and colors.size()==arrays[Mesh.ARRAY_VERTEX].size()
		for color in colors:
			min_weight = minf(min_weight,color.r)
			max_weight = maxf(max_weight,color.r)
	_check(triangles>=low and triangles<=high,"%s: %d triangles in [%d,%d]" % [path,triangles,low,high])
	if wind: _check(all_colors and min_weight<.01 and max_weight>.8,path+" has base-to-tip wind weights")
	var config := ConfigFile.new()
	config.load(path+".import")
	_check(config.get_value("params","meshes/generate_lods",false),path+" automatic mesh LOD enabled")

func _run() -> void:
	# Stage 3: thirteen normalised scans (seven bar boulders, boulder_08 for the cliff and store
	# rings, five margin rocks) and ten cobbles; ranges unchanged, coverage extended.
	for i in 13: _asset("res://assets/boulders/boulder_%02d.glb" % (i+1),1500,3000)
	for i in 2: _asset("res://assets/bedrock/ledge_%02d.glb" % (i+1),1,3000)
	for i in 10: _asset("res://assets/boulders/cobble_%02d.glb" % (i+1),1,199)
	for species in Vegetation.SPECIES:
		_asset("res://assets/trees/%s.glb" % species,3000,6000,true)
		var atlas: Texture2D = load("res://assets/textures/foliage_%s_albedo.png" % species)
		_check(atlas!=null and atlas.get_size()==Vector2(2048,2048),species+" 2048 alpha atlas")
		_check(atlas.get_image().detect_alpha()!=Image.ALPHA_NONE,species+" foliage texture has alpha")
		var height := Assets.mesh("res://assets/trees/%s.glb" % species).get_aabb().size.y
		var limits: Vector2 = {"ponderosa":Vector2(25,35),"incense_cedar":Vector2(20,30),"douglas_fir":Vector2(25,40),"black_oak":Vector2(12,18)}[species]
		_check(height>=limits.x and height<=limits.y,"%s height %.2f m" % [species,height])
	for set_name in Assets.SETS:
		for suffix in ["albedo","normal","orm"]:
			var path := "res://assets/textures/%s_%s.png" % [set_name,suffix]
			var tex: Texture2D = load(path)
			# Visual upgrade Stage 1 amendment: granite scan set is 1024 (VISUAL_UPGRADE_NOTES.md).
			var size := 2048 if set_name=="gravel" else 1024
			_check(tex!=null and tex.get_size()==Vector2(size,size),path+" %d texture" % size)
	for name in ["textures","boulders","bedrock","trees","ground_cover"]:
		_check(FileAccess.file_exists("res://blender/build_%s.py" % name) and FileAccess.file_exists("res://blender/build_%s.blend" % name),name+" script and inspectable Blender source")
	_check(FileAccess.file_exists("res://blender/README.md"),"Blender pipeline README exists")
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	await _frames(40)
	for i in Layout.BOULDERS.size():
		var b: Vector4 = Layout.BOULDERS[i]
		var rock: MeshInstance3D = claim.get_node("Greybox/Boulder%02d" % (i+1))
		_check(Vector2(rock.position.x-b.x,rock.position.z-b.y).length()<.001,"Boulder %d layout position" % i)
		var box := rock.get_aabb()
		var radius := maxf(box.size.x,box.size.z)*.5
		_check(radius>=b.z*.85 and radius<=b.z*1.15,"Boulder %d AABB radius %.3f versus %.3f" % [i,radius,b.z])
		_check(box.position.y+rock.position.y<=Layout.height_at(b.x,b.y),"Boulder %d sunk below terrain" % i)
		var convex := false
		var no_trimesh := true
		for shape in rock.find_children("*","CollisionShape3D",true,false):
			convex = convex or shape.shape is ConvexPolygonShape3D
			no_trimesh = no_trimesh and not shape.shape is ConcavePolygonShape3D
		_check(convex and no_trimesh,"Boulder %d convex collision" % i)
	var ground: MeshInstance3D = claim.get_node("Greybox/CanyonAndGravelBar")
	var material := ground.mesh.surface_get_material(0)
	_check(material is ShaderMaterial and material.shader.resource_path=="res://shaders/terrain.gdshader","Ground terrain ShaderMaterial")
	for set_name in Assets.SETS: _check(set_name+"_albedo" in material.shader.code,"Terrain references "+set_name)
	var vegetation: Node3D = claim.get_node("Vegetation")
	var river: Area3D = claim.get_node("Greybox/River")
	var conifers := 0
	var cobbles := 0
	var legal := true
	for key in vegetation.placements:
		var group: MultiMeshInstance3D = vegetation.get_node(NodePath(key))
		_check(group.multimesh.instance_count==vegetation.placements[key].size(),key+" uses MultiMesh")
		if key in ["ponderosa","incense_cedar","douglas_fir"]: conifers+=group.multimesh.instance_count
		if key.begins_with("cobble"): cobbles+=group.multimesh.instance_count
		for transform in vegetation.placements[key]:
			var p: Vector3 = transform.origin
			legal = legal and river.depth_at(p)<=0 and absf(p.z-Layout.shore_z(p.x))>=(1.499 if key.begins_with("cobble") else 11.999) and Vegetation.normal_at(p.x,p.z).y>=cos(deg_to_rad(45))
			if key.begins_with("cobble"): legal=legal and Vegetation.clear_of_boulders(p)
	_check(legal,"Every instance respects depth, shore, slope and boulder exclusions")
	_check(conifers==600,"Conifer count %d" % conifers)
	_check(cobbles>=400 and cobbles<=900,"Cobble count %d" % cobbles)
	# Stage 3 ground clutter is visual only and stays out of the panning strip and the camp.
	var clutter: Node3D = claim.get_node("GroundClutter")
	var pieces := 0
	var clutter_ok: bool = clutter.find_children("*","CollisionObject3D",true,false).is_empty()
	for key in clutter.placements:
		for transform in clutter.placements[key]:
			pieces += 1
			var p: Vector3 = transform.origin
			if key == "stump_01": clutter_ok = clutter_ok and p.z > Layout.back_z(p.x)
			else: clutter_ok = clutter_ok and p.z-Layout.shore_z(p.x) >= 3.999 and clutter.clear_of_camp(p)
	_check(clutter_ok and pieces>=40,"%d clutter pieces: no collision, clear of the panning strip and camp" % pieces)
	var cards: int = vegetation.placements.grass.size()*7+(vegetation.placements.lupine.size()+vegetation.placements.poppy.size()+vegetation.placements.yarrow.size())*21
	_check(cards<3000,"Ground cover %d cards below 3000" % cards)
	var oaks: Array = vegetation.placements.black_oak
	_check(oaks.size()>=8 and oaks.size()<=15,"Oak count %d" % oaks.size())
	var spacing := true
	var colliders := true
	for i in oaks.size():
		for j in range(i): spacing=spacing and oaks[i].origin.distance_to(oaks[j].origin)>=6
		var body: Node3D = vegetation.get_node("OakTrunk%02d" % (i+1))
		colliders=colliders and body.position.distance_to(oaks[i].origin)<.5 and body.get_child(0).shape is CylinderShape3D and body.collision_layer==1
	_check(spacing,"Oaks spaced at least 6 m")
	_check(colliders,"Every walkable oak has a terrain-layer trunk cylinder")
	var walker: CharacterBody3D = claim.get_node("Walker")
	var rig: Node3D = claim.get_node("CameraRig")
	var nearest: Vector3 = oaks[0].origin
	for oak in oaks:
		if oak.origin.distance_to(walker.position)<nearest.distance_to(walker.position): nearest=oak.origin
	walker.position=nearest+Vector3(0,.1,-3)
	walker.position.y=Layout.height_at(walker.position.x,walker.position.z)+.04
	walker.velocity=Vector3.ZERO
	rig.yaw=0
	rig.rotation.y=0
	await _frames(30)
	Input.action_press("move_back")
	await _frames(180)
	Input.action_release("move_back")
	_check(walker.position.z<nearest.z-.55 and walker.position.distance_to(nearest)> .55,"Walker cannot pass through nearest oak in 3 seconds")
	var b: Vector4 = Layout.BOULDERS[1]
	walker.position=Vector3(b.x,Layout.height_at(b.x,b.y-3.6)+.04,b.y-3.6)
	walker.velocity=Vector3.ZERO
	rig.yaw=0
	rig.rotation.y=0
	rig.pitch=-.22
	await _frames(60)
	var arm: SpringArm3D = rig.get_node("SpringArm3D")
	_check(arm.get_hit_length()<arm.spring_length-.2,"Camera boom retracts against real boulder index 1")
	print("MILESTONE 5: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _frames(count: int) -> void:
	for i in count: await physics_frame
