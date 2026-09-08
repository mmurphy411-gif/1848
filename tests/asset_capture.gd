extends RefCounted
const Layout = preload("res://scripts/claim_layout.gd")
const Lighting = preload("res://tests/lighting_capture.gd")
const Water = preload("res://tests/water_capture.gd")
const Guard = preload("res://tests/composition_guard.gd")

static func run(tree: SceneTree, claim: Node3D) -> bool:
	var walker: CharacterBody3D = claim.get_node("Walker")
	var rig: Node3D = claim.get_node("CameraRig")
	var player: Camera3D = rig.get_node("SpringArm3D/Camera3D")
	var daylight: Node3D = claim.get_node("Daylight")
	claim.get_node("DensityDebug").hide()
	walker.get_node("Panner")._reset()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	daylight.apply(19.25)
	var camera := Camera3D.new()
	claim.add_child(camera)
	camera.attributes = daylight.camera_attributes
	camera.far = 600
	camera.fov = 65
	walker.hide()
	# Review priority: gravel first, then the conifer silhouettes.
	var start := Vector3(-3,Layout.height_at(-3,-1)+1.2,-1)
	Water._view(camera,start,start+Vector3(0,-sin(deg_to_rad(35)),-cos(deg_to_rad(35)))*5)
	var gravel := await _save(tree,"gravel-close")
	var patch := Water._patch(gravel,camera,Vector3(-3,Layout.height_at(-3,-2.2),-2.2),64)
	var ok := Water._check(patch.w>.05,"Gravel 64x64 luminance deviation %.3f > .05" % patch.w)
	var water_material: ShaderMaterial = claim.get_node("Greybox/River/WaterSurface").material_override
	var breakup: Image = water_material.get_shader_parameter("foam_noise").get_image()
	var covered := 0
	for y in breakup.get_height():
		for x in breakup.get_width():
			if breakup.get_pixel(x,y).r>.56: covered+=1
	var coverage := float(covered)/(breakup.get_width()*breakup.get_height())
	ok = Water._check(coverage>=.30 and coverage<=.50,"Foam breakup coverage %.1f%% in contact band (30–50%%)" % (coverage*100)) and ok
	Water._view(camera,Vector3(-34,2,4),Vector3(-45,32,61))
	var treeline := await _save(tree,"treeline")
	# Fixed patches are selected from the actual visible canopy, not the sky.
	var canopy := Water._stats(treeline,Rect2i(1010,240,64,64))
	var granite := Water._stats(treeline,Rect2i(1090,380,64,64))
	ok = Water._check(canopy.y>=canopy.x*1.2,"Canopy RGB %s, G/R %.3f >= 1.2" % [canopy,canopy.y/maxf(canopy.x,.001)]) and ok
	ok = Water._check(granite.y<granite.x*1.2,"Adjacent granite RGB %s G/R %.3f < 1.2" % [granite,granite.y/maxf(granite.x,.001)]) and ok
	if "--priority-only" in OS.get_cmdline_user_args():
		camera.queue_free()
		return ok
	walker.show()
	player.current = true
	await Lighting._place(tree,walker,rig,Vector2(-20,Layout.shore_z(-20)+8),-1.1475,-.08)
	await _save(tree,"downstream")
	ok = await _sample(tree,"downstream") and ok
	await Lighting._place(tree,walker,rig,Vector2(20,Layout.shore_z(20)+8),1.4,-.08)
	await _save(tree,"upstream")
	walker.hide()
	var b := Layout.BOULDERS[1]
	Water._view(camera,Vector3(b.x+5.7,1.5,b.y+.6),Vector3(b.x,1,b.y))
	var boulder := await _save(tree,"boulder-close")
	patch = Water._patch(boulder,camera,Vector3(b.x+2.1,1,b.y),64)
	ok = Water._check(patch.w>.04,"Granite 64x64 luminance deviation %.3f > .04" % patch.w) and ok
	var oak: Transform3D = claim.get_node("Vegetation").placements.black_oak[4]
	camera.fov = 75
	Water._view(camera,oak.origin+Vector3(2,1.8,-1),Vector3(oak.origin.x-5,18,-16))
	await _save(tree,"oak")
	camera.fov = 60
	Water._view(camera,Vector3(95,100,18),Vector3(-15,0,-3))
	await _save(tree,"overview")
	ok = await _sample(tree,"overview") and ok
	daylight.apply(12.0)
	walker.show()
	player.current = true
	await Lighting._place(tree,walker,rig,Vector2(-20,Layout.shore_z(-20)+8),-1.1475,-.08)
	await _save(tree,"noon")
	daylight.apply(19.25)
	walker.hide()
	camera.fov = 65
	Water._view(camera,Vector3(-10,1.1,-1),Vector3(-8,0,-10))
	await Water._save(tree,"water-shore")
	walker.show()
	player.current = true
	camera.queue_free()
	print("ASSET CAPTURE: ","PASS" if ok and not Guard.failed else "FAIL")
	return ok and not Guard.failed

static func _save(tree: SceneTree,label: String) -> Image:
	await Water._settle(tree)
	var picture := tree.root.get_texture().get_image()
	assert(picture.get_size()==Vector2i(1920,1080))
	if Guard.check(tree,"milestone-5-"+label):
		assert(picture.save_png("res://artifacts/milestone-5-%s.png" % label)==OK)
		print("Saved milestone-5-%s.png" % label)
	return picture

static func _sample(tree: SceneTree,label: String) -> bool:
	var times: Array[float] = []
	var previous := Time.get_ticks_usec()
	for i in 600:
		await tree.process_frame
		var now := Time.get_ticks_usec()
		times.append(float(now-previous)/1000)
		previous = now
	times.sort()
	return Water._check(times[570]<5.5,"MILESTONE 5 %s: median %.2f ms, p95 %.2f ms < 5.5" % [label,times[300],times[570]])
