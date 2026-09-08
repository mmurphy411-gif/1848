extends RefCounted
## A capture with an obstructed center is a failed composition, not a deliverable.
static var failed := false
static func check(tree: SceneTree, label: String) -> bool:
	var camera := tree.root.get_camera_3d()
	var rig := camera.get_parent().get_parent()
	if "focused" in rig and (rig.focused or rig.panning):
		var visual: Node3D = rig.target.get_node("Visual")
		return check_subject(tree,label,rig.target,visual.pan_attachment.global_position)
	return _ray(tree,label,2.0,[])

static func check_subject(tree: SceneTree, label: String, subject: CollisionObject3D, point: Vector3) -> bool:
	# A close-up intentionally places its subject inside 2 m. Test the sightline
	# to it, excluding its invisible controller capsule, without accepting any
	# intervening terrain or rock. Coverage gates separately test visible meshes.
	var camera := tree.root.get_camera_3d()
	return _ray(tree,label,minf(2.0,camera.global_position.distance_to(point)),[subject.get_rid()])

static func _ray(tree: SceneTree, label: String, distance_limit: float, exclusions: Array[RID]) -> bool:
	var camera := tree.root.get_camera_3d()
	var start := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start,start-camera.global_basis.z*distance_limit)
	query.exclude=exclusions
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var object: Node = hit.collider
		push_error("COMPOSITION GUARD: %s blocked within %.2f m by %s" % [label,distance_limit,object.get_path()])
		failed = true
		return false
	print("PASS: composition guard ",label)
	return true
