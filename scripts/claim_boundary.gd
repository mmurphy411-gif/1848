extends RefCounted
## Smoothly redirects attempted escape while preserving travel along the boundary.
## There is no position clamp, teleport, damage, or invisible collision wall.

const Layout = preload("res://scripts/claim_layout.gd")

static func guide_motion(position: Vector3, desired: Vector3, depth: float) -> Vector3:
	var motion := desired
	var water_weight := smoothstep(0.32, 0.62, depth)
	var inland := Layout.inland_normal(position.x)
	motion = _redirect(motion, inland, water_weight)
	# Return current at knee depth, including when the player lets go of movement.
	motion += inland * water_weight * 1.25
	motion += Vector3(1.0, 0.0, 0.015 * position.x).normalized() * water_weight * 0.18
	var end_weight := smoothstep(33.0, 40.5, absf(position.x))
	var toward_center := Vector3(-signf(position.x), 0.0, 0.0)
	motion = _redirect(motion, toward_center, end_weight)
	motion += toward_center * end_weight * 1.25
	# The same taper that forms the canyon closes the bar at each end.
	var back_distance := Layout.back_z(position.x) - position.z
	var back_weight := 1.0 - smoothstep(0.6, 3.6, back_distance)
	var back_derivative := -0.0280839 * position.x
	var toward_bar := Vector3(back_derivative, 0.0, -1.0).normalized()
	motion = _redirect(motion, toward_bar, back_weight)
	motion += toward_bar * back_weight * 0.9
	return motion

static func _redirect(motion: Vector3, inward: Vector3, weight: float) -> Vector3:
	var outward_speed := minf(motion.dot(inward), 0.0)
	return motion - inward * outward_speed * weight
