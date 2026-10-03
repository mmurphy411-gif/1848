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
## Wave C: wider than Stage 2's (55/85/105 m half-widths) and less varied in height, so
## their faces lie at 35-50 degrees and hold timber between the rock bands instead of
## being 60-degree rock cones.
const CRESTS := [Vector3(60, 85, 42), Vector3(190, 150, 100), Vector3(320, 190, 140)]
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

## Analytical distance from the wall foot of an analytical z (positive into the wall).
static func wall_distance(x: float, z: float, far: bool) -> float:
	return far_foot(x) - z if far else z - near_foot(x)

## Distance from a wall foot to the top of its last cliff band (the rim), matching
## claim_layout.gd::canyon_wall's apron, bands and benches.
static func rim(x: float, far: bool) -> float:
	var apron := 8.0 + 2.0 * sin(x * 0.055)
	var band := (7.0 if far else 5.0) + 2.0 * sin(x * 0.04)
	if far: band *= 1.0 - 0.55 * exp(-pow((x - 64.0) / 22.0, 2.0))
	return apron + band * (3.0 if far else 2.0) + (6.0 if far else 3.0)

## Far-wall profile above the rim: three crests with saddles, varied along the valley.
static func crest_profile(x: float, u: float) -> float:
	var crests: PackedVector2Array = relief_column(x, true).crests
	var height := 0.08 * u
	for k in CRESTS.size():
		var c: Vector3 = CRESTS[k]
		var q := (u - crests[k].x) / c.y
		if absf(q) >= 1.0: continue
		height = maxf(height, crests[k].y * (1.0 - q * q) * (1.0 - q * q))
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
	# Wave C: two octaves at longer wavelengths than Stage 2's three-octave noise; on the
	# 5 m render grid its finest octave stood up as 60-degree spikes.
	var n := relief_noise()
	var offset := 5.0 * n.get_noise_2d(x * 0.03, d * 0.035 + (0.0 if far else 50.0)) * smoothstep(apron, apron + 8.0, d)
	var u := d - rim(x, far)
	if u < 0.0 and d > apron:
		# Wave C: for stretches of the bent reach the bands and benches merge into one
		# cliff from the apron to the rim, so the walls round the bend are not the claim
		# reach's three terraces repeated.
		var merge := smoothstep(0.05, 0.35, n.get_noise_2d(x * 0.009, 2100.0 if far else 2300.0))
		if merge > 0.0:
			var foot := Layout.canyon_wall(x, apron, far)
			var top := Layout.canyon_wall(x, rim(x, far), far)
			var face := lerpf(foot, top, (d - apron) / (rim(x, far) - apron))
			offset += merge * (face - Layout.canyon_wall(x, d, far))
	if u > 0.0:
		offset += 7.0 * n.get_noise_2d(x * 0.018, u * 0.018 + 300.0) * smoothstep(0.0, 25.0, u)
		if far:
			var base := Layout.canyon_wall(x, rim(x, far), far)
			offset += base + crest_profile(x, u) - Layout.canyon_wall(x, d, far)
		offset += relief(x, u, far)[0]
	return t * offset

# ------------------------------------------------------------------ ridge relief (Wave C)
## The slopes above both rims of the bent reach carry draws (gullies running down the
## slope), cliff bands (steep risers between gentler benches) and tors (rock knobs, most
## on crests and spurs). The same functions give the ground cover that
## ridge_forest.gdshader paints and the treeline reads, so trees stand where the ground
## holds them: thick in the draws, open on spurs and crests, none on rock or scree.
## Distances above the rim (m) where the cliff bands run; each wanders by ±18 m.
const FAR_BANDS := [74.0, 128.0, 196.0, 262.0, 335.0]
const NEAR_BANDS := [70.0, 140.0, 215.0, 300.0]
## Tor cells: metres along the valley and up the slope.
const TOR_CELL := Vector2(70.0, 56.0)
static var _relief_noise: FastNoiseLite
static var _column_cache: Dictionary = {}

static func relief_noise() -> FastNoiseLite:
	if _relief_noise == null:
		_relief_noise = FastNoiseLite.new()
		_relief_noise.seed = 184825
		_relief_noise.frequency = 1.0
		_relief_noise.fractal_octaves = 2
	return _relief_noise

## Crest centre of crest k (distance above the far rim) at x.
static func crest_centre(x: float, k: int) -> float:
	return CRESTS[k].x + 18.0 * noise().get_noise_2d(x * 0.009, 40.0 + k * 31.0)

## Tors whose footprint reaches column x on one wall: Vector4(x, u, radius, height).
## Seeded per cell, so every column sees the same tors.
static func tors_near(x: float, far: bool) -> Array:
	var out: Array = []
	var reach_x := 18.0
	var rng := RandomNumberGenerator.new()
	for cx in range(floori((x - reach_x) / TOR_CELL.x), floori((x + reach_x) / TOR_CELL.x) + 1):
		for cu in 8:
			rng.seed = hash(Vector3i(cx, cu, 184826 if far else 184827))
			var tx := (cx + 0.15 + 0.7 * rng.randf()) * TOR_CELL.x
			var tu := (cu + 0.1 + 0.8 * rng.randf()) * TOR_CELL.y
			var radius := rng.randf_range(6.0, 12.0)
			var height := rng.randf_range(2.5, 5.0)
			var chance := 0.22
			if far:
				# Crests are where rock breaks the skyline.
				for k in CRESTS.size():
					var c: Vector3 = CRESTS[k]
					if absf(tu - crest_centre(tx, k)) < c.y * 0.3: chance = 0.62
			if rng.randf() > chance or absf(x - tx) > radius: continue
			if far:
				# A crest tor sits on the crest line.
				for k in CRESTS.size():
					var centre := crest_centre(tx, k)
					if absf(tu - centre) < CRESTS[k].y * 0.3: tu = centre + rng.randf_range(-6.0, 6.0)
			out.append(Vector4(tx, tu, radius, height))
	return out

## Everything about one wall column that depends only on x: bands, tors and (far wall)
## crest centres and tops. Cached per metre of valley: the claim load builds ~50,000
## render vertices and the treeline tests ~30,000 spots on these walls.
static func relief_column(x: float, far: bool) -> Dictionary:
	x = roundf(x)
	var key := Vector2(x, 1.0 if far else 0.0)
	if _column_cache.has(key): return _column_cache[key]
	var n := relief_noise()
	var side := 0.0 if far else 500.0
	var bands: Array = []
	var list: Array = FAR_BANDS if far else NEAR_BANDS
	for k in list.size():
		# Bands run for a few hundred metres, then die out into the slope.
		var mask := smoothstep(-0.15, 0.2, n.get_noise_2d(x * 0.0065, side + 40.0 + k * 23.0))
		if mask <= 0.0: continue
		var at: float = list[k] + 18.0 * n.get_noise_2d(x * 0.005, side + 60.0 + k * 23.0)
		var height := mask * (8.0 + 11.0 * (0.5 + 0.5 * n.get_noise_2d(x * 0.021, side + 80.0 + k * 23.0)))
		bands.append(Vector2(at, height))
	var crests := PackedVector2Array()
	if far:
		for k in CRESTS.size():
			var top: float = CRESTS[k].z * (1.0 + 0.3 * noise().get_noise_2d(x * 0.011, 7.0 + k * 17.0))
			crests.append(Vector2(crest_centre(x, k), top))
	var column := {"bands": bands, "tors": tors_near(x, far), "crests": crests}
	_column_cache[key] = column
	return column

## Render-only relief above a rim and its ground cover: [height offset (m),
## Color(forest, draw, rock, scree)]. Forest is before slope; the shader and the
## treeline take steep ground out themselves.
static func relief(x: float, u: float, far: bool) -> Array:
	if u <= 0.0: return [0.0, Color(0.45, 0.0, 0.0, 0.0)]
	# greybox.gd asks twice per vertex (height, then cover); answer the repeat from memory.
	var key := Vector3(x, u, 1.0 if far else 0.0)
	if key == _last_key: return _last_relief
	_last_key = key
	_last_relief = _relief(x, u, far)
	return _last_relief

static var _last_key := Vector3.INF
static var _last_relief: Array = []

static func _relief(x: float, u: float, far: bool) -> Array:
	var n := relief_noise()
	var side := 0.0 if far else 500.0
	var column := relief_column(x, far)
	# Draws: where a slow noise along the valley crosses zero, meandering with height.
	var v := n.get_noise_2d(x * 0.0075, side + 7.0 + u * 0.0045)
	var draw := pow(1.0 - minf(absf(v) * 3.2, 1.0), 2.0) * smoothstep(0.0, 18.0, u)
	var spur := smoothstep(0.22, 0.5, absf(v))
	var offset := -draw * (7.0 + 9.0 * smoothstep(30.0, 160.0, u))
	var rock := 0.0
	var scree := 0.0
	for band: Vector2 in column.bands:
		# A riser of band.y metres over 7 m, the slope eased above and below it.
		var step := smoothstep(band.x - 3.5, band.x + 3.5, u)
		var ramp := clampf((u - band.x + 26.0) / 52.0, 0.0, 1.0)
		var h := band.y * (1.0 - 0.6 * draw)
		offset += h * (step - ramp)
		var strength := smoothstep(5.0, 14.0, h)
		rock = maxf(rock, strength * (1.0 - smoothstep(4.5, 8.0, absf(u - band.x - 1.0))))
		# Scree fans below the riser, wider where the band is tall.
		var fan := smoothstep(band.x - 12.0 - h * 1.4, band.x - 6.0, u) * (1.0 - smoothstep(band.x - 5.0, band.x - 3.0, u))
		if fan > 0.0: scree = maxf(scree, strength * fan * smoothstep(-0.2, 0.3, n.get_noise_2d(x * 0.05, side + band.x)))
	for tor: Vector4 in column.tors:
		var r := Vector2(x - tor.x, u - tor.y).length() / tor.z
		if r >= 1.6: continue
		# A low knob; canyon_dressing.gd stands a rock piece on it.
		offset += tor.w * smoothstep(1.0, 0.3, r)
		rock = maxf(rock, 1.0 - smoothstep(0.85, 1.1, r))
		if u < tor.y: scree = maxf(scree, (1.0 - smoothstep(1.0, 1.6, r)) * 0.8)
	# Crests and spurs are open; draws hold the thickest timber.
	var crest := 0.0
	if far:
		var crests: PackedVector2Array = column.crests
		for k in CRESTS.size():
			crest = maxf(crest, 1.0 - smoothstep(0.06, 0.26, absf(u - crests[k].x) / CRESTS[k].y))
	var stands := n.get_noise_2d(x * 0.011, u * 0.013 + side + 900.0)
	var gaps := n.get_noise_2d(x * 0.045, u * 0.05 + side + 1300.0)
	var forest := 0.62 + 0.8 * stands + 0.3 * gaps + 0.45 * draw - 0.42 * crest - 0.18 * spur - (0.0 if far else 0.12)
	forest *= (1.0 - rock) * (1.0 - 0.85 * scree)
	return [offset, Color(clampf(forest, 0.0, 1.0), draw, rock, scree)]

## Ground cover at a render-space point of the bent reach (for the treeline):
## Color(forest, draw, rock, scree), or forest 0 off the slopes above the rims.
static func cover_at(x: float, d: float, far: bool) -> Color:
	return relief(x, d - rim(x, far), far)[1]

## Render position of an analytical point. `p` is the analytical point after
## greybox.gd::wall_point() noise; (x, z) are its undisplaced coordinates.
static func visual_point(x: float, z: float, p: Vector3) -> Vector3:
	if reach(x) <= 0.0: return p
	p.y += shaped_offset(x, z)
	p.z += remap_z(x, z) - z
	p.z += rib(x, z)
	return p

## Wave C: buttresses and gullies on the bent reach's cliff bands, so they are not three
## regular terraces running round the bend: the band faces stand out or fall back by up
## to 5 m (toward or away from the river) in runs 15-40 m long. Render-only, from the
## apron to just above the rim.
static func rib(x: float, z: float) -> float:
	var s := reach(x)
	var far := z < far_foot(x)
	var d := wall_distance(x, z, far)
	if s <= 0.0 or d <= 2.0: return 0.0
	var top := rim(x, far)
	# Ramped over 14 m so the shift never folds the strip (its slope in d stays below 0.6).
	var w := smoothstep(2.0, 16.0, d) * (1.0 - smoothstep(top, top + 14.0, d)) * smoothstep(0.0, 50.0, s)
	if w <= 0.0: return 0.0
	var n := relief_noise()
	var v := n.get_noise_2d(x * 0.05, d * 0.012 + (0.0 if far else 700.0) + 1500.0)
	return (1.0 if far else -1.0) * w * 5.5 * clampf(v * 1.6, -1.0, 1.0)
