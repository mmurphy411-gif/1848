extends RefCounted
static func text_ink(tree: SceneTree,center: Vector3,size: Vector2) -> Dictionary:
	var camera:=tree.root.get_camera_3d()
	var a:=camera.unproject_position(center+Vector3(-size.x*.5,size.y*.5,0))
	var b:=camera.unproject_position(center+Vector3(size.x*.5,-size.y*.5,0))
	var rect:=Rect2(a,b-a).abs().grow(-12)
	var im:=tree.root.get_texture().get_image()
	var rows: Array[int]=[];var ink:=0;var text_luma:=0.0;var dark_luma:=0.0;var dark_count:=0
	for y in range(maxi(0,int(rect.position.y)),mini(im.get_height(),int(rect.end.y))):
		var count:=0
		for x in range(maxi(0,int(rect.position.x)),mini(im.get_width(),int(rect.end.x))):
			var c:=im.get_pixel(x,y)
			var l:=c.srgb_to_linear();var luminance:=l.r*.2126+l.g*.7152+l.b*.0722
			if c.r>.50 and c.g>.45 and c.r>c.b: count+=1;text_luma+=luminance;ink+=1
			elif c.r<.2 and c.g<.2: dark_luma+=luminance;dark_count+=1
		rows.append(count)
	var bands: Array[int]=[];var height:=0
	for count in rows:
		if count>=3: height+=1
		elif height>0:
			if height>=4: bands.append(height)
			height=0
	if height>=4: bands.append(height)
	var contrast: float=(text_luma/maxi(1,ink)+.05)/(dark_luma/maxi(1,dark_count)+.05)
	return {"ink_heights":bands,"minimum":bands.min() if not bands.is_empty() else 0,"contrast":contrast,"inside":Rect2(Vector2.ZERO,Vector2(im.get_size())).encloses(rect)}
static func coverage(tree: SceneTree,store: Node3D,portrait: bool) -> Dictionary:
	var camera:=tree.root.get_camera_3d();var old_environment:=camera.environment;var old_attributes:=camera.attributes
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK;env.tonemap_mode=Environment.TONE_MAPPER_LINEAR;camera.environment=env
	var attributes:=CameraAttributesPractical.new();attributes.exposure_multiplier=1;camera.attributes=attributes
	var shader:=Shader.new()
	shader.code="shader_type spatial; render_mode unshaded,fog_disabled,cull_disabled; uniform int kind=0; uniform vec3 left_hand;uniform vec3 right_hand;uniform vec3 face;uniform bool portrait=false;varying vec3 world;void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}void fragment(){bool hand=distance(world,left_hand)<.15||distance(world,right_hand)<.15;bool head=portrait&&distance(world,face)<.14;ALBEDO=kind==1?vec3(1.,0.,0.):kind==2?vec3(0.,0.,1.):kind==3&&(hand||head)?vec3(1.,0.,0.):vec3(0.); }"
	var saved: Array=[]
	for mesh in store.find_children("*","MeshInstance3D",true,false):
		var kind:=0;var actor: Node3D
		var path:=str(mesh.get_path())
		if "/StoreAsset/" in path and str(mesh.name).begins_with("Counter"): kind=2
		if not portrait and (str(mesh.name).begins_with("Scale") or str(mesh.name).begins_with("Pan") or str(mesh.name).begins_with("Beam") or store.poured_sack.is_ancestor_of(mesh)): kind=1
		if store.keeper.is_ancestor_of(mesh): actor=store.keeper
		elif not portrait and store.walker.is_ancestor_of(mesh): actor=store.walker
		var m:=ShaderMaterial.new();m.shader=shader;m.set_shader_parameter("kind",kind);m.set_shader_parameter("portrait",portrait)
		if actor:
			var skeleton: Skeleton3D=actor.find_children("*","Skeleton3D",true,false)[0]
			for pair in [["left_hand","LeftHand"],["right_hand","RightHand"],["face","Head"]]:
				var p: Vector3=(skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(pair[1]))).origin
				m.set_shader_parameter(pair[0],p+Vector3(0,.08,0) if pair[1]=="Head" else p)
			m.set_shader_parameter("kind",3)
		saved.append([mesh,mesh.material_override]);mesh.material_override=m
	for i in 3: await tree.process_frame
	await RenderingServer.frame_post_draw
	var im:=tree.root.get_texture().get_image();var subject:=0;var counter:=0
	for y in range(0,im.get_height(),2):
		for x in range(0,im.get_width(),2):
			var color:=im.get_pixel(x,y)
			if color.r>.8 and color.b<.2: subject+=1
			if color.b>.8 and color.r<.2: counter+=1
	for pair in saved: pair[0].material_override=pair[1]
	camera.environment=old_environment;camera.attributes=old_attributes
	return {"subject":subject*4.0/(im.get_width()*im.get_height()),"counter":counter*4.0/(im.get_width()*im.get_height())}
