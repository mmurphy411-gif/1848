extends RefCounted
## Visible miner and cradle pixels in the actual frozen review camera.
static func measure(tree: SceneTree, claim: Node3D) -> Dictionary:
	var camera:=tree.root.get_camera_3d()
	var old_environment:=camera.environment;var old_attributes:=camera.attributes
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;camera.environment=env
	var exposure:=CameraAttributesPractical.new();exposure.exposure_multiplier=1;camera.attributes=exposure
	var shader:=Shader.new();shader.code="shader_type spatial; render_mode unshaded,fog_disabled,cull_disabled; uniform vec3 code; void fragment(){ALBEDO=code;}"
	var saved: Array=[]
	for node in claim.find_children("*","GeometryInstance3D",true,false):
		if node is GPUParticles3D or node is FogVolume:
			saved.append({"node":node,"visible":node.visible});node.hide();continue
		if not (node is MeshInstance3D or node is MultiMeshInstance3D): continue
		if node is MeshInstance3D and node.mesh==null: continue
		var entry: Dictionary={"node":node,"material":node.material_override,"surfaces":[]}
		var material:=ShaderMaterial.new();material.shader=shader
		var path:=str(node.get_path())
		material.set_shader_parameter("code",Vector3(1,0,0) if "/Walker/Visual/" in path else Vector3(0,0,1) if "/Mining/Rocker/" in path else Vector3.ZERO)
		if node is MeshInstance3D:
			for i in node.mesh.get_surface_count():
				entry.surfaces.append(node.get_surface_override_material(i));node.set_surface_override_material(i,material)
		node.material_override=material;saved.append(entry)
	for i in 4: await tree.process_frame
	await RenderingServer.frame_post_draw
	var im:=tree.root.get_texture().get_image();var miner:=0;var cradle:=0
	for y in range(0,im.get_height(),2):
		for x in range(0,im.get_width(),2):
			var c:=im.get_pixel(x,y)
			if c.r>.8 and c.b<.1: miner+=1
			if c.b>.8 and c.r<.1: cradle+=1
	for entry in saved:
		if entry.has("visible"): entry.node.visible=entry.visible
		else:
			entry.node.material_override=entry.material
			for i in entry.surfaces.size(): entry.node.set_surface_override_material(i,entry.surfaces[i])
	camera.environment=old_environment;camera.attributes=old_attributes
	return {"miner":miner*4.0/(im.get_width()*im.get_height()),"cradle":cradle*4.0/(im.get_width()*im.get_height())}
