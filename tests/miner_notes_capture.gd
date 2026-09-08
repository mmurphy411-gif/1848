extends "res://tests/miner_capture.gd"
const Notes = preload("res://tests/milestone_6_notes.gd")
const Coverage = preload("res://tests/subject_coverage.gd")
var review_subject := Vector3.ZERO
var subject_closeup := false
func capture_guard(label: String) -> bool:
	if subject_closeup and camera.current:return Guard.check_subject(self,label,walker,review_subject)
	return Guard.check(self,label)
func _run() -> void:
	capture_prefix="notes-6-"
	root.content_scale_size=Vector2i(1920,1080)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DirAccess.make_dir_recursive_absolute("res://artifacts")
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	walker=claim.get_node("Walker");visual=walker.get_node("Visual");panner=walker.get_node("Panner");rig=claim.get_node("CameraRig")
	player_camera=rig.get_node("SpringArm3D/Camera3D")
	camera=Camera3D.new();claim.add_child(camera)
	camera.attributes=claim.get_node("Daylight").camera_attributes;camera.far=600
	claim.get_node("Daylight").apply(19.25)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await frames(90)
	for group in claim.get_node("Vegetation").find_children("*","MultiMeshInstance3D",true,false):
		for s in group.multimesh.mesh.get_surface_count():
			var m: Material=group.multimesh.mesh.surface_get_material(s)
			if m is ShaderMaterial and m.shader.resource_path.get_file() in ["foliage.gdshader","bark.gdshader"]:m.set_shader_parameter("review_time",0.0)
	if "--sequences-only" in OS.get_cmdline_user_args():
		await record_sequences()
		print("NOTES 6 SEQUENCES: ","PASS" if not Guard.failed else "FAIL")
		quit(1 if Guard.failed else 0)
		return
	await start_review_pan()
	await frames(180)
	freeze(true)
	side_view()
	await save("pan-side-swirl")
	await Coverage.capture(self,claim,"pan-side-swirl")
	front_view(1.5)
	await save("pan-front-swirl")
	await Coverage.capture(self,claim,"pan-front-swirl")
	freeze(false)
	while panner.elapsed<8.75:await frames(1)
	freeze(true);front_view(1.5)
	await save("pan-front-wash")
	await Coverage.capture(self,claim,"pan-front-wash")
	freeze(false)
	while panner.state!=panner.State.SHOWING:await frames(1)
	player_camera.current=true
	await frames(42)
	freeze(true)
	await save("pan-showing")
	await Coverage.capture(self,claim,"pan-showing")
	front_view(.8)
	await save("hands")
	await Coverage.capture(self,claim,"hands")
	freeze(false)
	panner._reset();await frames(65)
	await place(0,1);visual.rotation.y=.35;rig.yaw=1.1;rig.pitch=-.18
	player_camera.current=true;await frames(45)
	freeze(true);await save("miner-standing")
	await oak_shadow_probe()
	await Coverage.capture(self,claim,"miner-standing")
	var hips: Vector3=Notes.joint(visual,"Hips").origin
	camera.fov=50
	view(hips-visual.global_basis.x*2,hips)
	review_subject=hips;subject_closeup=true
	await save("miner-side")
	await Coverage.capture(self,claim,"miner-side")
	root.get_node("Sack").ounces=3.5;root.get_node("Sack").changed.emit(3.5)
	camera.fov=35
	view(hips-visual.global_basis.x*.9+visual.global_basis.z*1.5+Vector3.UP*.2,visual.sack_visual.global_position+Vector3.DOWN*.1)
	review_subject=visual.sack_visual.global_position+Vector3.DOWN*.1
	await save("sack-stage-3")
	await Coverage.capture(self,claim,"sack-stage-3")
	freeze(false)
	walker.hide()
	subject_closeup=false
	var oak: Transform3D=claim.get_node("Vegetation").placements.black_oak[4]
	camera.fov=75;view(oak.origin+Vector3(2,1.8,-1),oak.origin+Vector3(0,9,0));await frames(30)
	await save("oak-under")
	freeze(true);await Coverage.capture(self,claim,"oak-under");freeze(false)
	camera.fov=65
	var start:=Vector3(-3,Layout.height_at(-3,-1)+1.2,-1)
	view(start,start+Vector3(0,-sin(deg_to_rad(35)),-cos(deg_to_rad(35)))*5)
	await frames(30);await save("gravel-close")
	freeze(true);await Coverage.capture(self,claim,"gravel-close")
	await gravel_mix_probe();freeze(false)
	camera.fov=60;view(Vector3(95,100,18),Vector3(-15,0,-3))
	await frames(30);await save("overview")
	walker.show()
	if not "--stills-only" in OS.get_cmdline_user_args():
		await record_sequences()
	print("NOTES 6 CAPTURE: ","PASS" if ok and not Guard.failed else "FAIL")
	quit(0 if ok and not Guard.failed else 1)

func freeze(held: bool) -> void:
	walker.set_physics_process(not held)
	visual.set_physics_process(not held)
	panner.set_physics_process(not held)
	rig.set_process(not held)

func side_view() -> void:
	var hips: Vector3=Notes.joint(visual,"Hips").origin
	camera.fov=rad_to_deg(2*atan(36.0/(2*50.0)))
	view(hips-visual.global_basis.x*2,hips)
	review_subject=hips;subject_closeup=true

func front_view(distance: float) -> void:
	var pan: Vector3=visual.pan_attachment.global_position+Vector3.UP*.04
	var forward: Vector3=-visual.global_basis.z
	var quarter: Vector3=(forward-visual.global_basis.x*.65).normalized()
	camera.fov=40 if distance<1 else 45
	view(pan+(quarter*cos(PI/6)+Vector3.UP*sin(PI/6))*distance,pan)
	review_subject=pan;subject_closeup=true

func start_review_pan() -> void:
	panner._reset();await frames(65)
	await place(0,-6.7)
	visual.rotation.y=0;rig.yaw=.5;rig.pitch=-.2
	await frames(40)
	panner.start_pan();panner.result={"tier":3,"ounces":.4}

func record_sequences() -> void:
	for angle in ["player","side","front"]:
		if "--player-only" in OS.get_cmdline_user_args() and angle!="player":continue
		await start_review_pan()
		var folder: String="pan-sequence" if angle=="player" else "pan-sequence-"+angle
		DirAccess.make_dir_recursive_absolute("res://artifacts/"+folder)
		var manifest: Array=[]
		# Fixed review side view uses the measured crouched hip height for all
		# frames, so the character's movement remains visible in a stationary shot.
		var side_target: Vector3=walker.global_position+Vector3.UP*.52
		for i in 144:
			var target_time: float=(i+1)/12.0
			while (panner.elapsed if panner.state==panner.State.PANNING else 11.0+panner.elapsed)<target_time:await frames(1)
			freeze(true)
			if angle=="player":player_camera.current=true
			elif angle=="side":
				camera.fov=rad_to_deg(2*atan(36.0/(2*50.0)))
				view(side_target-visual.global_basis.x*2,side_target)
				review_subject=side_target;subject_closeup=true
			else:front_view(1.5)
			if angle!="front" or (panner.state==panner.State.PANNING and panner.segment in ["pan_swirl","pan_wash","pan_lift"]):
				await process_frame;await RenderingServer.frame_post_draw
				if capture_guard(folder+"-%03d" % i):root.get_texture().get_image().save_png("res://artifacts/"+folder+"/frame-%03d.png" % i)
				manifest.append({"frame":i,"time":panner.elapsed if panner.state==panner.State.PANNING else 11+panner.elapsed,"segment":panner.segment,"cycle":panner.segment_index,"state":panner.state})
			freeze(false)
		var file:=FileAccess.open("res://artifacts/"+folder+"/manifest.json",FileAccess.WRITE)
		file.store_string(JSON.stringify(manifest,"\t"));file.close()

func oak_shadow_probe() -> void:
	var oak: MultiMeshInstance3D=claim.get_node("Vegetation/black_oak")
	# Keep the trunk and limbs in the shadow pass; remove only leaf casting to
	# isolate the canopy contribution on the nearest boulder in this fixed view.
	var original: ArrayMesh=oak.multimesh.mesh
	var bark_only:=ArrayMesh.new()
	bark_only.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,original.surface_get_arrays(0))
	bark_only.surface_set_material(0,original.surface_get_material(0))
	var leaves:=ArrayMesh.new()
	leaves.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,original.surface_get_arrays(1))
	leaves.surface_set_material(0,original.surface_get_material(1))
	var visible_leaves:=MultiMeshInstance3D.new()
	visible_leaves.multimesh=oak.multimesh.duplicate()
	visible_leaves.multimesh.mesh=leaves
	visible_leaves.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	oak.add_child(visible_leaves)
	oak.multimesh.mesh=bark_only
	await frames(12)
	await save("standing-no-leaf-shadows")
	oak.multimesh.mesh=original
	visible_leaves.queue_free()
	await frames(12)

func gravel_mix_probe() -> void:
	var material: ShaderMaterial=claim.get_node("Greybox/CanyonAndGravelBar").get_active_material(0)
	var previous:=camera.environment
	var previous_attributes:=camera.attributes
	var neutral:=Environment.new();neutral.background_mode=Environment.BG_COLOR
	neutral.background_color=Color.BLACK;neutral.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	camera.environment=neutral;camera.attributes=CameraAttributesPractical.new()
	material.set_shader_parameter("review_mode",1)
	await frames(8)
	await save("gravel-mix-probe")
	material.set_shader_parameter("review_mode",0)
	camera.environment=previous;camera.attributes=previous_attributes
	await frames(8)
