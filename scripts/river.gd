@tool
extends Area3D
## Greybox water volume. Depth follows the actual bed rather than an arbitrary trigger.

const Layout = preload("res://scripts/claim_layout.gd")

func depth_at(point: Vector3) -> float:
	var across := point.z - Layout.shore_z(point.x)
	if absf(point.x) > 110.0 or across > 0.0 or across < -28.0:
		return 0.0
	return maxf(Layout.WATER_LEVEL - Layout.height_at(point.x, point.z), 0.0)
