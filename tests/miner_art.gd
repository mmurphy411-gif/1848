extends SceneTree
## Contact checks use the animated fingers and the visible prop's dimensions.
var failures := 0
func _initialize() -> void: run.call_deferred()
func frames(n: int) -> void:
	for i in n: await physics_frame
func check(ok: bool,label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures+=1
func run() -> void:
	root.get_node("GameState").apply_scenario({"day":"75","crowbar":"1","shovel":"1","pick":"1","rocker":"1"})
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	var m: Node3D=claim.get_node("Mining")
	var v: Node3D=claim.get_node("Walker/Visual")
	m.focus_site("crevice");await frames(20);m.interact();await frames(30)
	var worst := 0.0
	for i in 120:
		await frames(1)
		for side in ["Left","Right"]:
			# Every fingertip should turn back toward its knuckle around the
			# real iron shaft, with a hand-sized radius (not an open rake pose).
			for finger in ["Index","Middle","Ring","Little"]:
				var index: int=v.skeleton.find_bone(side+finger+"Distal")
				var distal: Transform3D=v.skeleton.global_transform*v.skeleton.get_bone_global_pose(index)
				var tip := distal*Vector3(0,.0382,0)
				var on_shaft := Geometry3D.get_closest_point_to_segment(tip,m.tool.global_position,m.tool.to_global(Vector3(0,1.05,0)))
				worst=maxf(worst,tip.distance_to(on_shaft))
	check(worst<.060,"Crevice fingertips stay within 6 cm of shaft through full stroke: %.4f m" % worst)
	m.cancel();m.focus_site("rocker");await frames(20);m.interact();await frames(370)
	m.focus_site("rocker");await frames(20);m.interact();await frames(510)
	check(v.activity_clip=="rock","Live rocker action reaches rocking clip")
	worst=0
	for i in 190:
		await frames(1)
		var a: Vector3=m.cradle.to_global(Vector3(.55,.85,-.165))
		var b: Vector3=m.cradle.to_global(Vector3(.55,.85,.065))
		for side in ["Left","Right"]:
			var grip: Vector3=v.mining_grip(side)
			var nearest := Geometry3D.get_closest_point_to_segment(grip,a,b)
			worst=maxf(worst,grip.distance_to(nearest))
	check(worst<.045,"Both palms follow the crossbar within 4.5 cm over one cycle: %.4f m" % worst)
	m.cancel()
	check(v.pack_visual.visible and not v.pack_visual is MeshInstance3D,"Loaded inventory uses authored pack scene")
	print("MINER ART: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
