@tool
extends Area3D
## Greybox water volume. Depth follows the actual bed rather than an arbitrary trigger.

const Layout = preload("res://scripts/claim_layout.gd")
const Model = preload("res://scripts/river_model.gd")

func water_level() -> float:
	var game := get_node_or_null("/root/GameState")
	return game.water_level() if game and not Engine.is_editor_hint() else 0.0

func shore_z(x: float) -> float: return Model.shore_z(x,water_level())

func work_edge(point: Vector3, limit: float) -> bool:
	return Model.work_edge(point,water_level(),limit) or _in_channel(point)

func depth_at(point: Vector3) -> float:
	return 0.0 if _in_channel(point) else Model.depth_at(point,water_level())

## 2.0: inside a standing wing dam the bed is dry and the channel can be panned.
func _in_channel(point: Vector3) -> bool:
	var game := get_node_or_null("/root/GameState")
	if game==null or Engine.is_editor_hint() or not "crew" in game: return false
	return preload("res://scripts/crew_model.gd").in_channel(game.crew,point.x,point.z)
