extends SceneTree
const Layout=preload("res://scripts/claim_layout.gd")
const Guard=preload("res://tests/composition_guard.gd")
const Lighting=preload("res://tests/lighting_capture.gd")
const Water=preload("res://tests/water_capture.gd")
var claim: Node3D
var walker: CharacterBody3D
var visual: Node3D
var panner: Node
var rig: Node3D
var camera: Camera3D
var player_camera: Camera3D
var ok:=true
var capture_prefix := "milestone-6-"
func _initialize() -> void:_run.call_deferred()
func frames(n: int) -> void:
	for i in n:await physics_frame
func view(from: Vector3,target: Vector3) -> void:
	camera.global_position=from;camera.look_at(target);camera.current=true
func place(x: float,z: float) -> void:
	walker.position=Vector3(x,Layout.height_at(x,z)+.01,z);walker.velocity=Vector3.ZERO
	await frames(30)
func save(label: String) -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	var im:=root.get_texture().get_image()
	assert(im.get_size()==Vector2i(1920,1080))
	if capture_guard(capture_prefix+label):
		im.save_png("res://artifacts/"+capture_prefix+label+".png")
		print("Saved ",capture_prefix,label)
	return im
func capture_guard(label: String) -> bool:
	if label.ends_with("sack-stage-3") and camera.current:
		return Guard.check_subject(self,label,walker,visual.sack_visual.global_position+Vector3.DOWN*.1)
	return Guard.check(self,label)
func _run() -> void:
	root.content_scale_size=Vector2i(1920,1080)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	walker=claim.get_node("Walker");visual=walker.get_node("Visual");panner=walker.get_node("Panner");rig=claim.get_node("CameraRig")
	player_camera=rig.get_node("SpringArm3D/Camera3D")
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes;camera.far=600;camera.fov=55
	claim.get_node("Daylight").apply(19.25)
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await frames(90)
	await place(0,-6.7);visual.rotation.y=0;rig.yaw=.5;rig.pitch=-.2
	panner.start_pan();panner.result={"tier":3,"ounces":.4}
	await frames(150)
	view(walker.position+Vector3(2.2,1.05,-.6),walker.position+Vector3(0,.45,-.3))
	await save("pan-swirl")
	print("PROBE pan center below water: ",visual.pan_attachment.global_position)
	ok=visual.pan_attachment.global_position.y<0 and ok
	while panner.state!=panner.State.SHOWING:await frames(1)
	player_camera.current=true;await frames(40);await save("pan-lift")
	if "--pan-only" in OS.get_cmdline_user_args():quit(0 if ok and not Guard.failed else 1);return
	panner._reset();await frames(65)
	await place(0,1);visual.rotation.y=.35;rig.yaw=1.1;rig.pitch=-.18;await frames(45)
	var standing:=await save("miner-standing")
	ok=await shadow_probe(standing) and ok
	root.get_node("Sack").ounces=3.5;root.get_node("Sack").changed.emit(3.5)
	var hips: Vector3 = (visual.skeleton.global_transform*visual.skeleton.get_bone_global_pose(visual.skeleton.find_bone("Hips"))).origin
	camera.fov=35
	view(hips-visual.global_basis.x*.9+visual.global_basis.z*1.5+Vector3.UP*.2,visual.sack_visual.global_position+Vector3.DOWN*.1)
	await save("sack-stage-3")
	camera.fov=55
	rig.yaw=0;rig.rotation.y=0;Input.action_press("move_forward");await frames(24)
	view(walker.position+Vector3(3.3,1.35,.1),walker.position+Vector3(0,.9,0));await save("miner-walk")
	Input.action_release("move_forward");await frames(30)
	await place(0,-8.7);rig.yaw=PI*.5;rig.rotation.y=PI*.5;Input.action_press("move_forward");await frames(40)
	view(walker.position+Vector3(2.0,1.3,2.3),walker.position+Vector3(0,.7,0));await save("miner-wade")
	Input.action_release("move_forward");await frames(30)
	player_camera.current=true
	await Lighting._place(self,walker,rig,Vector2(-20,Layout.shore_z(-20)+8),-1.1475,-.08);await save("downstream")
	ok=await Lighting._sample(self,"milestone 6 downstream") and ok
	await Lighting._place(self,walker,rig,Vector2(20,Layout.shore_z(20)+8),1.4,-.08);await save("upstream")
	walker.hide()
	var oak: Transform3D=claim.get_node("Vegetation").placements.black_oak[4]
	camera.fov=75;view(oak.origin+Vector3(2,1.8,-1),Vector3(oak.origin.x-5,18,-16));await frames(30);await save("oak-under")
	camera.fov=65;var start:=Vector3(-3,Layout.height_at(-3,-1)+1.2,-1)
	view(start,start+Vector3(0,-sin(deg_to_rad(35)),-cos(deg_to_rad(35)))*5);await frames(30)
	var gravel:=await save("gravel-close")
	var patch:=Water._patch(gravel,camera,Vector3(-3,Layout.height_at(-3,-2.2),-2.2),64)
	ok=Water._check(patch.w>.05,"M6 gravel variation %.3f" % patch.w) and ok
	if "--stills-only" in OS.get_cmdline_user_args():
		print("MINER CAPTURE: ","PASS" if ok and not Guard.failed else "FAIL")
		quit(0 if ok and not Guard.failed else 1)
		return
	walker.show();player_camera.current=true
	await place(0,-6.7);visual.rotation.y=0;rig.yaw=.5;rig.pitch=-.2;await frames(40)
	panner.start_pan();panner.result={"tier":3,"ounces":.4}
	DirAccess.make_dir_recursive_absolute("res://artifacts/pan-sequence")
	for i in 144:
		await frames(5);await process_frame;await RenderingServer.frame_post_draw
		if Guard.check(self,"pan-sequence-%03d" % i):root.get_texture().get_image().save_png("res://artifacts/pan-sequence/frame-%03d.png" % i)
	print("MINER CAPTURE: ","PASS" if ok and not Guard.failed else "FAIL")
	quit(0 if ok and not Guard.failed else 1)

func shadow_probe(shadowed: Image) -> bool:
	# Compare the same frozen view with body shadows disabled. Points follow
	# light rays from the torso to the unchanged collision surface, not hand-
	# picked dark pixels. Every point in the central torso strip must darken.
	visual.set_physics_process(false)
	rig.set_process(false)
	var meshes: Array=visual.miner.find_children("*","MeshInstance3D",true,false)
	for mesh in meshes:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	await frames(8);await process_frame;await RenderingServer.frame_post_draw
	var baseline:=root.get_texture().get_image()
	if Guard.check(self,"standing-shadow-baseline"):baseline.save_png("res://artifacts/milestone-6-standing-shadow-baseline.png")
	var sun: DirectionalLight3D=claim.get_node("Daylight/Sun")
	var passes:=0
	for height in [1.07,1.13,1.19,1.25,1.31]:
		var source:=walker.global_position+Vector3(0,height,0)
		var query:=PhysicsRayQueryParameters3D.create(source,source-sun.global_basis.z*40,1)
		var hit:=walker.get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():continue
		var pixel:=Vector2i(player_camera.unproject_position(hit.position))
		var bounds:=Rect2i(pixel-Vector2i(2,2),Vector2i(5,5))
		if not Rect2i(Vector2i.ZERO,baseline.get_size()).encloses(bounds):
			print("Torso shadow outside view: ",pixel)
			continue
		var lit:=Water._stats(baseline,bounds)
		var dark:=Water._stats(shadowed,bounds)
		var difference: float=(lit.x+lit.y+lit.z-dark.x-dark.y-dark.z)/3
		print("Torso shadow %.2fm: light difference %.4f" % [height,difference])
		if difference>.015:passes+=1
	for mesh in meshes:mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	visual.set_physics_process(true);rig.set_process(true)
	return Water._check(passes==5,"Contiguous torso shadow: %d/5 ray-projected samples" % passes)
