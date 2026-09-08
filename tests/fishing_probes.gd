extends RefCounted
static func coverage(tree: SceneTree,claim: Node3D,subjects: Array,label: String) -> Dictionary:
	var saved: Array=[]
	var white := StandardMaterial3D.new()
	white.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;white.albedo_color=Color.WHITE
	white.disable_fog=true;white.cull_mode=BaseMaterial3D.CULL_DISABLED
	var black := white.duplicate();black.albedo_color=Color.BLACK
	var camera := tree.root.get_camera_3d()
	var old_environment := camera.environment
	var old_attributes := camera.attributes
	var environment := Environment.new();environment.background_mode=Environment.BG_COLOR;environment.background_color=Color.BLACK
	var exposure := CameraAttributesPractical.new();exposure.exposure_multiplier=1
	camera.environment=environment;camera.attributes=exposure
	for node in claim.find_children("*","GeometryInstance3D",true,false):
		saved.append({"node":node,"material":node.material_override,"visible":node.visible})
		if node is GPUParticles3D or node is FogVolume: node.hide()
		elif node.name=="WaterSurface": node.hide() # Fish silhouette through transparent water.
		else: node.material_override=white if node in subjects else black
	claim.get_node("HUD").hide()
	for i in 6: await tree.process_frame
	await RenderingServer.frame_post_draw
	var image := tree.root.get_texture().get_image()
	image.save_png("res://artifacts/milestone-9-"+label+"-ids.png")
	var white_count := 0
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x,y).r>.8: white_count+=1
	var coverage := float(white_count)/(image.get_width()*image.get_height())
	var water_fraction := 0.0
	var visible_bodies := 0
	if label=="salmon-riffle":
		var shader := Shader.new();shader.code="shader_type spatial; render_mode unshaded,fog_disabled,cull_disabled; uniform vec3 code; void fragment(){ALBEDO=code;}"
		for i in subjects.size():
			var material := ShaderMaterial.new();material.shader=shader
			var code := Color8(32+(i%4)*64,32+((i/4)%4)*64,96).srgb_to_linear()
			material.set_shader_parameter("code",Vector3(code.r,code.g,code.b));subjects[i].material_override=material
		for i in 6: await tree.process_frame
		await RenderingServer.frame_post_draw
		var identities := tree.root.get_texture().get_image()
		identities.save_png("res://artifacts/milestone-9-salmon-bodies-ids.png")
		var pixels: Dictionary={}
		for y in identities.get_height():
			for x in identities.get_width():
				var rgb := identities.get_pixel(x,y)
				if absf(rgb.b*255-96)>5: continue
				var r := roundi((rgb.r*255-32)/64)
				var g := roundi((rgb.g*255-32)/64)
				if absf(rgb.r*255-(32+r*64))>5 or absf(rgb.g*255-(32+g*64))>5: continue
				var index := r+4*g
				pixels[index]=pixels.get(index,0)+1
		for count in pixels.values():
			if count>=120: visible_bodies+=1
	if label=="trout-holding":
		var water: MeshInstance3D=claim.get_node("Greybox/River/WaterSurface")
		var water_id := white.duplicate();water_id.albedo_color=Color(1,0,0)
		water.material_override=water_id;water.show()
		for i in 6: await tree.process_frame
		await RenderingServer.frame_post_draw
		var identity := tree.root.get_texture().get_image()
		identity.save_png("res://artifacts/milestone-9-trout-background-ids.png")
		var count := 0
		for y in identity.get_height():
			for x in identity.get_width():
				var color := identity.get_pixel(x,y)
				if color.r>.8 and color.g<.1: count+=1
		water_fraction=float(count)/(identity.get_width()*identity.get_height())
	for entry in saved: entry.node.material_override=entry.material;entry.node.visible=entry.visible
	claim.get_node("HUD").show()
	camera.environment=old_environment;camera.attributes=old_attributes
	print("SUBJECT ",label," coverage=",coverage)
	if label=="trout-holding": return {"coverage":coverage,"largest_background_upper_bound":maxf(water_fraction,1-water_fraction)}
	if label=="salmon-riffle": return {"coverage":coverage,"visible_bodies":visible_bodies}
	return {"coverage":coverage}
