extends "res://tests/miner_capture.gd"
const Coverage = preload("res://tests/subject_coverage.gd")
func _run() -> void:
	capture_prefix="milestone-8-"
	root.content_scale_size=Vector2i(1920,1080)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	claim=load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	walker=claim.get_node("Walker")
	visual=walker.get_node("Visual")
	panner=walker.get_node("Panner")
	rig=claim.get_node("CameraRig")
	player_camera=rig.get_node("SpringArm3D/Camera3D")
	camera=player_camera
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	claim.get_node("Daylight").apply(19.25)
	await frames(90)
	await place(0,-6.7)
	panner.start_pan()
	while panner.state!=panner.State.SHOWING: await frames(1)
	await frames(45)
	panner.set_physics_process(false)
	visual.set_physics_process(false)
	walker.set_physics_process(false)
	rig.set_process(false)
	for tier in 5:
		panner.pan.show_result(tier,42)
		await save("pan-tier-%d" % tier)
		await Coverage.capture(self,claim,"m8-pan-tier-%d" % tier)
	claim.get_node("Daylight").apply(0)
	await frames(90)
	panner.pan.show_result(3,42)
	await save("pan-night")
	await Coverage.capture(self,claim,"m8-pan-night")
	claim.get_node("Daylight").apply(19.25)
	panner._reset()
	visual.set_physics_process(true)
	walker.set_physics_process(true)
	rig.set_process(true)
	await place(0,1)
	visual.rotation.y=.35
	await frames(90)
	visual.set_physics_process(false)
	walker.set_physics_process(false)
	camera=Camera3D.new()
	claim.add_child(camera)
	camera.attributes=claim.get_node("Daylight").camera_attributes
	camera.far=600
	camera.fov=35
	var hips: Vector3=(visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("Hips"))).origin
	view(hips-visual.global_basis.x*.9+visual.global_basis.z*1.5+Vector3.UP*.2,visual.sack_visual.global_position+Vector3.DOWN*.1)
	for stage in 5:
		var sack: Node=root.get_node("Sack")
		sack.ounces=sack.THRESHOLDS[stage]
		sack.changed.emit(sack.ounces)
		await save("sack-stage-%d" % stage)
		await Coverage.capture(self,claim,"m8-sack-stage-%d" % stage)
	walker.hide()
	var oak: Transform3D=claim.get_node("Vegetation").placements.black_oak[4]
	camera.fov=75
	view(oak.origin+Vector3(2,1.8,-1),oak.origin+Vector3(0,9,0))
	for time in [0.0,4.0]:
		for node in claim.get_node("Vegetation").find_children("*","GeometryInstance3D",true,false):
			var mesh: Mesh=node.multimesh.mesh if node is MultiMeshInstance3D else node.mesh
			for surface in mesh.get_surface_count():
				var material: Material=mesh.surface_get_material(surface)
				if material is ShaderMaterial: material.set_shader_parameter("review_time",time)
		await frames(30)
		await save("oak-wind-%d" % int(time))
		await Coverage.capture(self,claim,"m8-oak-wind-%d" % int(time))
	print("POLISH CAPTURE: ","FAIL" if Guard.failed else "PASS")
	quit(1 if Guard.failed else 0)
func capture_guard(label: String) -> bool:
	if "sack-stage" in label:
		return Guard.check_subject(self,label,walker,visual.sack_visual.global_position+Vector3.DOWN*.1)
	return Guard.check(self,label)
