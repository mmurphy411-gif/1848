extends SceneTree
const Layout = preload("res://scripts/claim_layout.gd")
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("%s: %s" % ["PASS" if ok else "FAIL",label])
	if not ok: failures.append(label)
func frames(n: int) -> void:
	for i in n: await physics_frame
static func joint(v: Node3D, name: String) -> Transform3D:
	return v.skeleton.global_transform * v.skeleton.get_bone_global_pose(v.skeleton.find_bone(name))
func pitch_between(a: Vector3, b: Vector3) -> float:
	return rad_to_deg((b-a).normalized().angle_to(Vector3.UP))
func run() -> void:
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	var w: CharacterBody3D = claim.get_node("Walker")
	var v: Node3D = w.get_node("Visual")
	var p: Node = w.get_node("Panner")
	var rig: Node3D = claim.get_node("CameraRig")
	var camera: Camera3D = rig.get_node("SpringArm3D/Camera3D")
	w.position = Vector3(0,Layout.height_at(0,-6.7)+.01,-6.7)
	await frames(30)
	v.rotation.y = 0
	check(p.start_pan(),"Pan starts at the review waterline")
	await frames(48)
	var hips := joint(v,"Hips").origin
	var distance := camera.global_position.distance_to(hips)
	var aim := rad_to_deg((-camera.global_basis.z).angle_to(v.pan_attachment.global_position-camera.global_position))
	check(distance>=1.8 and distance<=2.6 and aim<=25,"Panning camera after 0.8 s: %.3f m, %.2f degrees" % [distance,aim])
	var yaw: float = rig.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(500,250)
	rig._unhandled_input(motion)
	check(is_equal_approx(yaw,rig.yaw),"Mouse cannot orbit the held panning camera")
	Input.action_press("look_right");await frames(4);Input.action_release("look_right")
	check(is_equal_approx(yaw,rig.yaw),"Stick cannot orbit the held panning camera")
	var obstruction:=StaticBody3D.new()
	var collider:=CollisionShape3D.new()
	var sphere:=SphereShape3D.new();sphere.radius=.45;collider.shape=sphere
	obstruction.add_child(collider);claim.add_child(obstruction)
	obstruction.global_position=camera.global_position
	await frames(3)
	check(rig.side_sign<0,"Blocked left panning camera mirrors to the right")
	obstruction.queue_free();await frames(2)
	var feet: Array[Vector3] = [joint(v,"LeftFoot").origin,joint(v,"RightFoot").origin]
	var paths: Dictionary = {}
	var shoulders: Dictionary = {}
	var rim_min := INF
	var rim_max := -INF
	var min_highest := INF
	var fingertip_error := 0.0
	var foot_error := 0.0
	var measured := false
	while p.state==p.State.PANNING:
		await frames(1)
		for i in 2:
			foot_error=maxf(foot_error,feet[i].distance_to(joint(v,"LeftFoot" if i==0 else "RightFoot").origin))
		if p.segment!="pan_swirl": continue
		if not paths.has(p.segment_index):
			paths[p.segment_index]=[]
			shoulders[p.segment_index]=[]
		paths[p.segment_index].append(v.pan_attachment.global_position)
		shoulders[p.segment_index].append(joint(v,"LeftUpperArm").origin)
		var low := INF
		var high := -INF
		for i in 64:
			var a := TAU*i/64.0
			var point: Vector3 = v.pan_attachment.global_transform*Vector3(sin(a)*.2,.08,cos(a)*.2)
			low=minf(low,point.y);high=maxf(high,point.y)
		rim_min=minf(rim_min,low);rim_max=maxf(rim_max,low);min_highest=minf(min_highest,high)
		for side in ["Left","Right"]:
			for finger in ["Thumb","Index","Middle","Ring","Little"]:
				var tip := joint(v,side+finger+"Distal")
				# Bone +Y follows its segment in the imported Godot skeleton.
				var rest_length: float = sqrt(.0381*.0381+.003*.003)
				var point: Vector3 = v.pan_attachment.global_transform.affine_inverse()*(tip*Vector3(0,rest_length,0))
				var radial := Vector2(point.x,point.z).length()
				var error := Vector2(radial-.1975,point.y-.08).length()
				fingertip_error=maxf(fingertip_error,error)
		if not measured and p.segment_index==1 and p.elapsed>=3.0:
			measured=true
			hips=joint(v,"Hips").origin
			var hip_height := hips.y-w.global_position.y
			var torso := pitch_between(hips,joint(v,"Neck").origin)
			var head_pitch := rad_to_deg(joint(v,"Head").basis.y.normalized().angle_to(Vector3.UP))
			var knee_sep := absf((joint(v,"LeftLowerLeg").origin-joint(v,"RightLowerLeg").origin).dot(v.global_basis.x))
			check(hip_height>=.48 and hip_height<=.60,"Hip height above boot soles %.4f m" % hip_height)
			check(torso>=30 and torso<=45,"Torso pitch %.3f degrees" % torso)
			check(knee_sep>=.40,"Knee separation %.4f m" % knee_sep)
			check(absf(head_pitch-torso-20)<2,"Head pitch %.3f degrees (torso + 20)" % head_pitch)
	check(rim_min>=-.061 and rim_max<=-.019 and min_highest>0,"Lowest rim %.4f to %.4f m; minimum highest rim %.4f m" % [rim_min,rim_max,min_highest])
	check(fingertip_error<=.03,"Maximum fingertip distance from rim %.4f m" % fingertip_error)
	check(foot_error<.01,"Feet remain planted: maximum travel %.4f m" % foot_error)
	for side in ["Left","Right"]:
		var count := 0
		for finger in ["Thumb","Index","Middle","Ring","Little"]:
			var index: int = v.skeleton.find_bone(side+finger+"Proximal")
			if index>=0 and not v.skeleton.get_bone_children(index).is_empty(): count+=1
		check(count==5,side+" hand has five articulated fingers")
	for cycle in paths:
		var mean := Vector3.ZERO
		for point in paths[cycle]: mean+=point
		mean/=paths[cycle].size()
		var variance := Vector3.ZERO
		for point in paths[cycle]: variance+=(point-mean)*(point-mean)
		variance/=paths[cycle].size()
		check(sqrt(variance.x)>.06 and sqrt(variance.z)>.06,"Swirl %d X/Z std %.4f/%.4f m" % [cycle,sqrt(variance.x),sqrt(variance.z)])
		var travel := 0.0
		for point in shoulders[cycle]:travel=maxf(travel,point.distance_to(shoulders[cycle][0]))
		check(travel>=.03,"Swirl %d shoulder travel %.4f m" % [cycle,travel])
	var squared := 0.0
	for i in mini(paths[1].size(),paths[2].size()): squared+=paths[1][i].distance_squared_to(paths[2][i])
	var rms := sqrt(squared/mini(paths[1].size(),paths[2].size()))
	check(rms>.01,"Cycle 2 differs from cycle 1: %.4f m RMS" % rms)
	var forest: Node3D=claim.get_node("Vegetation")
	var rendered := 0
	var placements := 0
	for species in ["ponderosa","incense_cedar","douglas_fir"]:
		placements+=forest.placements[species].size()
		# Stage 4 mesh variants: `<species>` (whose visible prefix is variant 1) and
		# `<species>_v<n>` near groups, `<species>_distant` and `<species>_v<n>_distant` far ones.
		var near_groups: Array=[forest.get_node(species)]
		var far_groups: Array=[forest.get_node(species+"_distant")]
		for n in range(2,9):
			if forest.has_node("%s_v%d" % [species,n]): near_groups.append(forest.get_node("%s_v%d" % [species,n]))
			if forest.has_node("%s_v%d_distant" % [species,n]): far_groups.append(forest.get_node("%s_v%d_distant" % [species,n]))
		rendered+=near_groups[0].multimesh.visible_instance_count
		for near in near_groups.slice(1): rendered+=near.multimesh.instance_count
		var far_count:=0
		var legal := true
		for far in far_groups:
			rendered+=far.multimesh.instance_count
			far_count+=far.multimesh.instance_count
			var triangles:=0
			for s in far.multimesh.mesh.get_surface_count():
				triangles+=far.multimesh.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size()/3
			check(triangles<600,"%s distant mesh %d triangles" % [far.name,triangles])
			if DisplayServer.get_name()!="headless":
				for i in far.multimesh.instance_count:
					var position: Vector3=far.multimesh.get_instance_transform(i).origin
					legal=legal and Vector2(position.x,position.z).length()>60
		if DisplayServer.get_name()=="headless":
			# The dummy renderer returns identity for MultiMesh transform readback.
			# Check allocation here; the graphical run checks actual GPU instances.
			var expected := 0
			for transform in forest.placements[species]:
				if Vector2(transform.origin.x,transform.origin.z).length()>60:expected+=1
			legal=far_count==expected
			check(legal,species+" distant allocation matches the >60 m placement partition")
		else:
			check(legal,species+" distant variants only beyond 60 m")
	check(placements==600 and rendered==600,"Exactly 600 conifers placed and rendered (%d/%d)" % [placements,rendered])
	print("MILESTONE 6 NOTES: ","PASS" if failures.is_empty() else "FAIL (%d)" % failures.size())
	claim.queue_free()
	await frames(2)
	quit(0 if failures.is_empty() else 1)
