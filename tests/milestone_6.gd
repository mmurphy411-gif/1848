extends SceneTree
const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
var failures: Array[String] = []
func _initialize() -> void: _run.call_deferred()
func check(ok: bool,label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures.append(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
func place(w: CharacterBody3D,x: float,z: float) -> void:
	w.position=Vector3(x,Layout.height_at(x,z)+.01,z)
	w.velocity=Vector3.ZERO
func _run() -> void:
	for pair in [["miner",8000,20000],["pan",1,1499],["sack",1,799]]:
		var path: String="res://assets/miner/%s.glb" % pair[0]
		check(FileAccess.file_exists(path),path+" exists")
		var mesh:=Assets.mesh(path)
		var count:=0
		for s in mesh.get_surface_count():
			var arrays:=mesh.surface_get_arrays(s)
			count+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size()/3
			if pair[0]=="miner":
				check(arrays[Mesh.ARRAY_WEIGHTS]!=null and arrays[Mesh.ARRAY_WEIGHTS].size()<=arrays[Mesh.ARRAY_VERTEX].size()*4,"Skin has at most four influences per vertex")
		check(count>=pair[1] and count<=pair[2],"%s triangles %d" % [pair[0],count])
		if pair[0]=="miner":check(mesh.get_aabb().size.y>=1.72 and mesh.get_aabb().size.y<=1.85,"Miner height %.3f m" % mesh.get_aabb().size.y)
	for name in ["build_miner.py","build_miner_animation.py"]:check(FileAccess.file_exists("res://blender/"+name),name+" exists")
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	var w: CharacterBody3D=claim.get_node("Walker")
	var v: Node3D=w.get_node("Visual")
	var p: Node=w.get_node("Panner")
	var rig: Node3D=claim.get_node("CameraRig")
	await frames(5)
	check(not v.has_node("Capsule") and v.skeleton is Skeleton3D and v.tree is AnimationTree,"Visual has miner skeleton and AnimationTree, no capsule mesh")
	check(v.pan_attachment is BoneAttachment3D and v.pan_attachment.bone_name=="pan_socket" and v.sack_attachment.bone_name=="Hips","Physical pan and sack use bone attachments")
	for clip in v.CLIPS:
		check(v.player.has_animation(clip) and absf(v.player.get_animation(clip).length-v.CLIPS[clip])<v.CLIPS[clip]*.1,clip+" clip and duration")
	place(w,0,0);await frames(30)
	check(v.playback.get_current_node()=="idle","Idle AnimationTree state")
	var foot_error:=0.0
	for side in ["Left","Right"]:
		var foot: Vector3=(v.skeleton.global_transform*v.skeleton.get_bone_global_pose(v.skeleton.find_bone(side+"Foot"))).origin
		foot_error=maxf(foot_error,absf(foot.y-.10-Layout.height_at(foot.x,foot.z)))
	check(foot_error<.03,"Idle feet within 3 cm of ground: %.4f" % foot_error)
	rig.yaw=0;rig.rotation.y=0
	Input.action_press("move_forward");await frames(120)
	check(v.playback.get_current_node()=="walk","Dry forward movement selects walk")
	var full_rate: float=v.locomotion_rate
	Input.action_release("move_forward");await frames(25)
	place(w,0,-8.1);rig.yaw=PI*.5;rig.rotation.y=PI*.5;await frames(10)
	Input.action_press("move_forward");await frames(90)
	check(v.playback.get_current_node()=="wade","Knee-deep movement selects wade")
	check(v.splashes[0].emitting and v.splashes[1].emitting,"Moving in water emits foot splashes")
	var fast_rate: float=v.locomotion_rate
	Input.action_release("move_forward");await frames(5)
	check(v.locomotion_rate<fast_rate and full_rate>.9,"Playback rate follows actual velocity while decelerating")
	await frames(30)
	check(not v.splashes[0].emitting,"Standing in water does not splash")
	check(v.wet_line>.1,"Wet line rises while wading")
	var wet: float=v.wet_line
	place(w,0,0);await frames(120)
	check(v.wet_line<wet and v.wet_line>0 and not v.splashes[0].emitting,"Wet line persists and dries outside water; no dry splashes")
	var sizes: Array[float]=[]
	for ounces in [0,.25,1,3.5,8]:
		root.get_node("Sack").ounces=ounces;root.get_node("Sack").changed.emit(ounces)
		sizes.append(v.sack_visual.scale.x*v.sack_visual.scale.y*v.sack_visual.scale.z)
	check(sizes[0]<sizes[1] and sizes[1]<sizes[2] and sizes[2]<sizes[3] and sizes[3]<sizes[4],"Sack volume grows monotonically across five stages")
	place(w,0,-6.7);await frames(30)
	v.rotation.y=PI
	check(p.start_pan(),"Pan starts at actual waterline")
	await frames(6)
	check(absf(wrapf(v.rotation.y,-PI,PI))>.2,"Turn is unfinished at 0.1 seconds")
	await frames(17)
	check(absf(wrapf(v.rotation.y,-PI,PI))<.03,"Turn completes in 0.3 seconds")
	var visited: Array[String]=["pan_enter"]
	var cycles: Dictionary={}
	var last_index: int=p.segment_index
	while p.state==p.State.PANNING:
		await frames(1)
		if p.segment_index!=last_index:
			visited.append(p.segment);last_index=p.segment_index
		if p.segment=="pan_swirl":
			if not cycles.has(p.segment_index):cycles[p.segment_index]=[]
			cycles[p.segment_index].append(v.pan_attachment.global_position)
	check(visited==["pan_enter","pan_swirl","pan_swirl","pan_swirl","pan_wash","pan_lift"],"Ordered pan sequence: %s" % str(visited))
	check(p.PAN_DURATION>=8 and p.PAN_DURATION<=12 and p.state==p.State.SHOWING and p.elapsed<.1,"SHOWING starts at end of 11-second lift sequence")
	for cycle in cycles:
		var samples: Array=cycles[cycle];var mean:=Vector3.ZERO;var minimum:=INF
		for pos in samples:mean+=pos;minimum=minf(minimum,pos.y)
		mean/=samples.size();var variance:=Vector3.ZERO
		for pos in samples:variance+=(pos-mean)*(pos-mean)
		variance/=samples.size()
		check(minimum<0 and sqrt(variance.x)>.03 and sqrt(variance.z)>.03,"Swirl %d: min Y %.3f; X/Z std %.3f/%.3f" % [cycle,minimum,sqrt(variance.x),sqrt(variance.z)])
	await frames(40)
	var camera: Camera3D=rig.get_node("SpringArm3D/Camera3D")
	check(camera.global_position.distance_to(v.pan_attachment.global_position)<1,"SHOWING camera within 1 m of the physical pan")
	p._finish();await frames(2)
	check(v.active_pan=="pan_exit" and v.pan_playback.get_current_node()=="pan_exit","Exit clip on return to IDLE")
	await frames(65)
	check(v.playback.get_current_node()=="idle","Returns to idle after exit")
	print("MILESTONE 6: %s" % ("PASS" if failures.is_empty() else "FAIL (%d)" % failures.size()))
	quit(0 if failures.is_empty() else 1)
