extends RefCounted
static func measure(tree: SceneTree,claim: Node3D) -> Dictionary:
	var camera:=tree.root.get_camera_3d();var old_environment:=camera.environment;var old_attributes:=camera.attributes
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK
	camera.environment=env;camera.attributes=CameraAttributesPractical.new()
	var shader:=Shader.new()
	shader.code="shader_type spatial;render_mode unshaded,fog_disabled,cull_disabled;uniform int kind=0;varying vec3 p;void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}void fragment(){float shore=-6.+.0075*p.x*p.x;float back=shore+38.*max(0.,1.-pow(p.x/42.,2.));bool bar=abs(p.x)<42.&&p.z>=shore&&p.z<back;ALBEDO=kind==2?vec3(1.,0.,0.):kind==1&&bar?vec3(1.,0.,0.):vec3(0.);}"
	var saved: Array=[]
	for mesh in claim.find_children("*","GeometryInstance3D",true,false):
		# Leave vegetation's real alpha cutouts and wind intact; opaque cards
		# would falsely hide the bar in a silhouette override.
		if mesh.name not in ["WaterSurface","CanyonAndGravelBar"]: continue
		var material:=ShaderMaterial.new();material.shader=shader
		material.set_shader_parameter("kind",2 if mesh.name=="WaterSurface" else 1 if mesh.name=="CanyonAndGravelBar" else 0)
		saved.append([mesh,mesh.material_override]);mesh.material_override=material
	for i in 3: await tree.process_frame
	await RenderingServer.frame_post_draw
	var im:=tree.root.get_texture().get_image();var count:=0
	for y in range(0,im.get_height(),2):
		for x in range(0,im.get_width(),2):
			var c:=im.get_pixel(x,y)
			if c.r>.8 and c.g<.2: count+=1
	for pair in saved: pair[0].material_override=pair[1]
	camera.environment=old_environment;camera.attributes=old_attributes
	return {"bar_and_river":count*4.0/(im.get_width()*im.get_height()),"minimum":.3}
