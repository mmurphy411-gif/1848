extends RefCounted
## A capture with an obstructed center is a failed composition, not a deliverable.
static var failed := false
static func check(tree: SceneTree, label: String) -> bool:
	var camera := tree.root.get_camera_3d()
	var start := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(start,start-camera.global_basis.z*2.0)
	var hit := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var object: Node = hit.collider
		push_error("COMPOSITION GUARD: %s blocked within 2 m by %s" % [label,object.get_path()])
		failed = true
		return false
	print("PASS: composition guard ",label)
	return true
