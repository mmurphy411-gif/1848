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

static func canyon_shore_z(x: float) -> float:
	# Outside the playable bend the valley continues along X, rather than
	# extending the shore parabola into a closed bowl. Claim geometry is unchanged.
	return shore_z(clampf(x, -HALF_LENGTH, HALF_LENGTH))

static func canyon_width_at(x: float) -> float:
	return width_at(x) + maxf(absf(x) - HALF_LENGTH, 0.0) * 0.2

static func canyon_far_offset(x: float) -> float:
	return maxf(absf(x) - HALF_LENGTH, 0.0) * 0.45

static func canyon_wall(x: float, distance: float, far_bank: bool) -> float:
	# 44-degree talus, then 66-degree cliff bands separated by 15-degree benches.
	var apron := 8.0 + 2.0 * sin(x * 0.055)
	var remaining := maxf(distance, 0.0)
	var height := minf(remaining, apron) * 0.97
	remaining = maxf(remaining - apron, 0.0)
	var band_width := (7.0 if far_bank else 5.0) + 2.0 * sin(x * 0.04)
	if far_bank:
		# A distinct downstream saddle breaks the taller far rim.
		band_width *= 1.0 - 0.55 * exp(-pow((x - 64.0) / 22.0, 2.0))
	var bands := 3 if far_bank else 2
	for index in bands:
		height += minf(remaining, band_width) * 2.2
		remaining = maxf(remaining - band_width, 0.0)
		if index < bands - 1:
			height += minf(remaining, 3.0) * 0.27
			remaining = maxf(remaining - 3.0, 0.0)
	# The rim never levels off. Extended terrain disappears into distance haze.
	return height + remaining * 0.34

static func height_at(x: float, z: float) -> float:
	var inland := z - canyon_shore_z(x)
	var width := canyon_width_at(x)
	var far_offset := canyon_far_offset(x)
	if inland > width:
		return 0.12 + width * 0.035 + canyon_wall(x, inland - width, false)
	if inland >= 0.0:
		return 0.12 + inland * 0.035
	if inland > -5.0:
		return 0.12 + inland * 0.18
	if inland > -RIVER_WIDTH - far_offset:
		return -0.78 - minf((-inland - 5.0) * 0.42, 4.0)
	if inland > -27.27619 - far_offset:
		return -4.78 + (-inland - RIVER_WIDTH - far_offset) * 2.1
	return canyon_wall(x, -inland - 27.27619 - far_offset, true)
