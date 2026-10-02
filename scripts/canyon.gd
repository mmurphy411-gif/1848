@tool
extends RefCounted
## World edge (visual upgrade Stage 2). Beyond |x| = BEND_START the render-only canyon
## narrows, bends inland (+Z) both ways around the bar's spur, and its outer walls rise
## into three ridge crests, so every view down the valley ends on a forested ridge
## instead of a flat horizon. Gameplay never reaches it: collision, river depth, the
## claim and vegetation all keep using the unbent analytical layout in claim_layout.gd.
## Only render geometry passes through visual_point(): the canyon's visual mesh, the
## WaterSurface vertices (greybox.gd::visual_bend) and the dressing seated on them.
const Layout = preload("res://scripts/claim_layout.gd")
## Inside this |x| the visual canyon is the analytical one (vegetation seats on it).
const BEND_START := 160.0
## The canyon axis turns from +X to this dz/dx (about 56 degrees) over BEND_LENGTH.
const BEND_SLOPE := 1.5
const BEND_LENGTH := 180.0
## The over-wide analytical floor narrows to these widths over SQUEEZE_LENGTH.
const SQUEEZE_LENGTH := 140.0
const NEAR_FLAT := 10.0
const RIVER_SPAN := 42.0
## Crest shaping fades in over this reach beyond BEND_START.
const SHAPE_LENGTH := 110.0
const FAR_BANK := 27.27619
## Far-wall crests above the cliff rim: distance from the rim, half-width, height (m).
const CRESTS := [Vector3(55, 55, 42), Vector3(170, 85, 100), Vector3(295, 105, 160)]
static var _noise: FastNoiseLite

static func noise() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 184820
		_noise.frequency = 1.0
		_noise.fractal_octaves = 3
	return _noise

## Metres beyond the bend start (0 inside the claim reach).
static func reach(x: float) -> float:
	return maxf(absf(x) - BEND_START, 0.0)

## Inland shift of the canyon axis at x: the integral of a smoothstep-ramped heading.
static func bend(x: float) -> float:
	var s := reach(x)
	if s <= 0.0: return 0.0
	if s < BEND_LENGTH:
		var t := s / BEND_LENGTH
		return BEND_SLOPE * BEND_LENGTH * (t * t * t - 0.5 * t * t * t * t)
	return BEND_SLOPE * (s - BEND_LENGTH * 0.5)

static func near_foot(x: float) -> float:
	return Layout.canyon_shore_z(x) + Layout.canyon_width_at(x)

static func far_foot(x: float) -> float:
	return Layout.canyon_shore_z(x) - FAR_BANK - Layout.canyon_far_offset(x)

## Visual z of an analytical z: the floor narrows, the walls slide in, the axis bends.
## Monotonic in z for every x, so the canyon strip never folds.
static func remap_z(x: float, z: float) -> float:
	var s := reach(x)
	if s <= 0.0: return z
	var g := smoothstep(0.0, SQUEEZE_LENGTH, s)
	var shore := Layout.canyon_shore_z(x)
	var near := near_foot(x)
	var far := far_foot(x)
	var near_width := lerpf(near - shore, NEAR_FLAT, g)
	var far_width := lerpf(shore - far, RIVER_SPAN, g)
	var mapped := z
	if z >= near: mapped = z - near + shore + near_width
	elif z <= far: mapped = z - far + shore - far_width
	elif z >= shore: mapped = shore + (z - shore) * near_width / (near - shore)
	else: mapped = shore - (shore - z) * far_width / (shore - far)
	return mapped + bend(x)

## Distance from a wall foot to the top of its last cliff band (the rim), matching
## claim_layout.gd::canyon_wall's apron, bands and benches.
static func rim(x: float, far: bool) -> float:
	var apron := 8.0 + 2.0 * sin(x * 0.055)
	var band := (7.0 if far else 5.0) + 2.0 * sin(x * 0.04)
	if far: band *= 1.0 - 0.55 * exp(-pow((x - 64.0) / 22.0, 2.0))
	return apron + band * (3.0 if far else 2.0) + (6.0 if far else 3.0)

## Far-wall profile above the rim: three crests with saddles, varied along the valley.
static func crest_profile(x: float, u: float) -> float:
	var n := noise()
	var height := 0.08 * u
	for k in CRESTS.size():
		var c: Vector3 = CRESTS[k]
		var centre := c.x + 18.0 * n.get_noise_2d(x * 0.009, 40.0 + k * 31.0)
		var q := (u - centre) / c.y
		if absf(q) >= 1.0: continue
		var top := c.z * (1.0 + 0.45 * n.get_noise_2d(x * 0.011, 7.0 + k * 17.0))
		height = maxf(height, top * (1.0 - q * q) * (1.0 - q * q))
	return height

## Render-only height change of an analytical wall point at (x, z).
static func shaped_offset(x: float, z: float) -> float:
	var s := reach(x)
	if s <= 0.0: return 0.0
	var far := z < far_foot(x)
	var d := far_foot(x) - z if far else z - near_foot(x)
	if d <= 0.0: return 0.0
	var t := smoothstep(0.0, SHAPE_LENGTH, s)
	var apron := 8.0 + 2.0 * sin(x * 0.055)
	# Bands wander up and down the wall, and spurs and gullies break the slopes,
	# so the distant walls are not regular terraces and smooth sweeps.
	var n := noise()
	var offset := 7.0 * n.get_noise_2d(x * 0.045, d * 0.05 + (0.0 if far else 50.0)) * smoothstep(apron, apron + 8.0, d)
	var u := d - rim(x, far)
	if u > 0.0:
		offset += 9.0 * n.get_noise_2d(x * 0.035, u * 0.03) * smoothstep(0.0, 25.0, u)
		if far:
			var base := Layout.canyon_wall(x, rim(x, far), far)
			offset += base + crest_profile(x, u) - Layout.canyon_wall(x, d, far)
	return t * offset

## Render position of an analytical point. `p` is the analytical point after
## greybox.gd::wall_point() noise; (x, z) are its undisplaced coordinates.
static func visual_point(x: float, z: float, p: Vector3) -> Vector3:
	if reach(x) <= 0.0: return p
	p.y += shaped_offset(x, z)
	p.z += remap_z(x, z) - z
	return p
