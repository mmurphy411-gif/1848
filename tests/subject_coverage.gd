extends RefCounted
## Capture material identities in the same frozen camera for objective coverage
## measurements. This diagnostic pass never changes the saved beauty render.
const LABELS := ["terrain","rock","foliage","shirt","trousers","leather","skin","hat","beard","suspenders","pan_outer","pan_interior","pan_rim","sack","pan_contents","other","nearest_boulder","water"]
static var nearest_boulder := ""
static func classify(node: Node, surface: int) -> String:
	var path := str(node.get_path())
	if node.name=="WaterSurface":return "water"
	if node.name==nearest_boulder:return "nearest_boulder"
	if path.ends_with("/Skeleton3D/Miner"):
		return ["shirt","trousers","leather","skin","hat","beard","suspenders","leather","skin"][surface]
	if "/PanSocket/" in path:return ["pan_outer","pan_interior","pan_rim"][surface]
	if "/SackSocket/" in path:return "sack"
	if "/Visual/Pan/" in path:return "pan_contents"
	if "/Vegetation/" in path:return "rock" if "cobble" in path else "foliage"
	if "Boulder" in path or "TalusBlock" in path or "Bedrock" in path:return "rock"
	if "CanyonAndGravelBar" in path:return "terrain"
	return "other"

static func capture(tree: SceneTree, claim: Node3D, label: String) -> Dictionary:
	var camera := tree.root.get_camera_3d()
	if label=="miner-standing":
		var nearest := INF
		for node in claim.get_node("Greybox").get_children():
			if not str(node.name).begins_with("Boulder"):continue
			if camera.is_position_behind(node.global_position):continue
			if not Rect2(Vector2.ZERO,Vector2(tree.root.content_scale_size)).has_point(camera.unproject_position(node.global_position)):continue
			var distance := camera.global_position.distance_to(node.global_position)
			if distance<nearest:nearest=distance;nearest_boulder=str(node.name)
		var target_file:=FileAccess.open("res://artifacts/notes-6-shadow-target.json",FileAccess.WRITE)
		target_file.store_string(JSON.stringify({"boulder":nearest_boulder,"distance":nearest}));target_file.close()
	var environment := camera.environment
	var attributes := camera.attributes
	var neutral := Environment.new()
	neutral.background_mode=Environment.BG_COLOR
	neutral.background_color=Color.BLACK
	neutral.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	camera.environment=neutral
	var exposure := CameraAttributesPractical.new()
	exposure.exposure_multiplier=1.0
	camera.attributes=exposure
	var shader := Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, fog_disabled, cull_disabled; uniform vec3 code; uniform bool cutout=false; uniform sampler2D atlas; uniform bool sack=false; uniform vec3 growth=vec3(1.0); void vertex(){ if(sack) VERTEX*=mix(vec3(.65,.85,.28)/growth,vec3(1.0),smoothstep(.025,.10,-VERTEX.y)); } void fragment(){ ALBEDO=code; ALPHA=(cutout && COLOR.g>.5)?texture(atlas,UV).a:1.0; ALPHA_SCISSOR_THRESHOLD=.38; }"
	var materials: Dictionary={}
	var legend: Dictionary={}
	for i in LABELS.size():
		var rgb := Color8(32+(i%4)*64,32+((i/4)%4)*64,96+(i/16)*96)
		var linear:=rgb.srgb_to_linear()
		var m := ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("code",Vector3(linear.r,linear.g,linear.b))
		materials[LABELS[i]]=m
		legend[LABELS[i]]=[roundi(rgb.r*255),roundi(rgb.g*255),roundi(rgb.b*255)]
	var saved: Array=[]
	for node in claim.find_children("*","GeometryInstance3D",true,false):
		# Retain a distinct water identity for background dominance and gravel
		# segmentation. The three wet-pan reviews measure the subject transmitted
		# through water, so only those diagnostic passes omit the water surface.
		if node is GPUParticles3D or node is FogVolume or (node.name=="WaterSurface" and label in ["pan-side-swirl","pan-front-swirl","pan-front-wash"]):
			saved.append({"node":node,"visible":node.visible});node.hide();continue
		if node is MeshInstance3D:
			var old: Array=[]
			for s in node.mesh.get_surface_count():old.append(node.get_surface_override_material(s))
			saved.append({"node":node,"override":node.material_override,"surfaces":old})
			node.material_override=null
			for s in node.mesh.get_surface_count():
				var id_material: ShaderMaterial=materials[classify(node,s)]
				if classify(node,s)=="sack" and saved[-1].override is ShaderMaterial:
					id_material=id_material.duplicate()
					id_material.set_shader_parameter("sack",true)
					id_material.set_shader_parameter("growth",saved[-1].override.get_shader_parameter("growth"))
				node.set_surface_override_material(s,id_material)
		elif node is MultiMeshInstance3D:
			saved.append({"node":node,"override":node.material_override})
			var id_material: ShaderMaterial=materials[classify(node,0)].duplicate()
			if node.multimesh.mesh.get_surface_count()>1:
				var leaves: Material=node.multimesh.mesh.surface_get_material(1)
				if leaves is ShaderMaterial and leaves.get_shader_parameter("use_atlas"):
					id_material.set_shader_parameter("cutout",true)
					id_material.set_shader_parameter("atlas",leaves.get_shader_parameter("leaf_atlas"))
			node.material_override=id_material
	for i in 8: await tree.process_frame
	await RenderingServer.frame_post_draw
	var im := tree.root.get_texture().get_image()
	im.save_png("res://artifacts/notes-6-"+label+"-material-ids.png")
	var file := FileAccess.open("res://artifacts/notes-6-material-legend.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(legend,"\t"));file.close()
	for entry in saved:
		var node: Node=entry.node
		if entry.has("visible"):node.visible=entry.visible
		else:
			node.material_override=entry.override
			if entry.has("surfaces"):
				for s in entry.surfaces.size():node.set_surface_override_material(s,entry.surfaces[s])
	camera.environment=environment;camera.attributes=attributes
	for i in 8:await tree.process_frame
	return legend
