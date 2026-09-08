@tool
extends RefCounted
## Shared meters-space geometry: X follows the river downstream; +Z is inland.
## The surface, river depth and boundary all sample this same layout.

const WATER_LEVEL := 0.0
const HALF_LENGTH := 42.0
const BAR_WIDTH := 38.0
const RIVER_WIDTH := 25.0
## X/Z center, horizontal radius, vertical radius. Downstream is always +X.
const BOULDERS := [
	Vector4(-27, 2.5, 3.4, 2.8), Vector4(-14, -4.3, 2.7, 2.0),
	Vector4(7, -5.0, 3.6, 3.0), Vector4(23, 0.5, 2.8, 2.5),
	Vector4(-8, 22, 4.2, 3.2), Vector4(20, 17, 3.5, 3.8),
	Vector4(-31, 13, 2.4, 2.1),
]
## X/Z center, X/Z slab size. Downstream edges reinforce two boulder lees.
const BEDROCK := [Vector4(-13.5, -6.806, 3.0, 1.2), Vector4(7.5, -8.208, 3.0, 1.2)]

static func boulder_lee(boulder: Vector4) -> Vector2:
	var x := boulder.x + 2.0
	return Vector2(x, minf(boulder.y - boulder.z * 0.78 - 0.4, shore_z(x) + 0.5))

static func shore_z(x: float) -> float:
	return -6.0 + 0.0075 * x * x

static func width_at(x: float) -> float:
	return BAR_WIDTH * maxf(0.0, 1.0 - pow(x / HALF_LENGTH, 2.0))

static func back_z(x: float) -> float:
	return shore_z(x) + width_at(x)

static func inland_normal(x: float) -> Vector3:
	return Vector3(-0.015 * x, 0.0, 1.0).normalized()

static func height_at(x: float, z: float) -> float:
	var inland := z - shore_z(x)
	var width := width_at(x)
	if inland > width:
		# A continuous, unclimbable canyon slope, not a vertical collision fence.
		var rise := inland - width
		var ridge := 24.0 + 4.0 * sin(x * 0.065) + 2.0 * cos(x * 0.18)
		return 0.12 + width * 0.035 + minf(rise * 1.65, ridge) + maxf(rise - 22.0, 0.0) * 0.06
	if inland >= 0.0:
		return 0.12 + inland * 0.035
	if inland > -5.0:
		return 0.12 + inland * 0.18
	if inland > -RIVER_WIDTH:
		return -0.78 - minf((-inland - 5.0) * 0.42, 4.0)
	# Far canyon bank rises out of deep water.
	var far_ridge := 33.0 + 7.0 * sin(x * 0.055 + 0.8) + 3.0 * cos(x * 0.14)
	return -4.78 + minf((-inland - RIVER_WIDTH) * 2.1, far_ridge)
