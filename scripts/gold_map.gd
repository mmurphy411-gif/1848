extends RefCounted
## Deterministic placer field. Geometry and pocket locations share ClaimLayout.

const Layout = preload("res://scripts/claim_layout.gd")

static func density_at(x: float, z: float) -> float:
	var inland := z - Layout.shore_z(x)
	if absf(x) >= Layout.HALF_LENGTH or z > Layout.back_z(x) or inland < -7.0:
		return 0.0 # Access depth is now checked by the worker, not the geology.
	# Coarse gravel settles first at the upstream head; fine inland sand is lean.
	var shore_strength := 1.0 - smoothstep(3.0, 12.0, inland)
	var upstream := lerpf(1.0, 0.25, clampf((x + 40.0) / 80.0, 0.0, 1.0))
	var base := lerpf(0.015, 0.03 + 0.12 * upstream, shore_strength)
	var point := Vector2(x, z)
	for rock in Layout.BOULDERS:
		if absf(rock.y - Layout.shore_z(rock.x)) <= 6.0:
			# Scour at the upstream face slightly depletes the lean base.
			base *= 1.0 - 0.45 * _bump(point, Vector2(rock.x - 2.0, rock.y), Vector2(1.0, 3.5))
	# The first boulder's lee is also the coarse head deposit: one richest pocket.
	var density := maxf(base, 0.98 * _bump(point, Layout.boulder_lee(Layout.BOULDERS[0]), Vector2(2.2, 3.5)))
	for rock in Layout.BOULDERS:
		if absf(rock.y - Layout.shore_z(rock.x)) <= 6.0:
			# Settling in the lee, 2 m downstream, on the water side of the rock.
			var downstream := clampf((rock.x + 27.0) / 50.0, 0.0, 1.0)
			# Less coarse material remains downstream: a smaller, leaner deposit.
			var strength := lerpf(0.82, 0.75, downstream)
			var spread := Vector2(1.7, lerpf(3.5, 2.6, downstream))
			density = maxf(density, strength * _bump(point, Layout.boulder_lee(rock), spread))
	for slab in Layout.BEDROCK:
		# Tight cracks trap heavy gold at each downstream bedrock edge. These
		# reinforce two lees, giving four distinct rich areas rather than seven.
		var edge := Vector2(slab.x + slab.z * 0.5, slab.y)
		density = maxf(density, 0.9 * _bump(point, edge, Vector2(1.5, 1.5)))
	return clampf(lerpf(base, density, shore_strength), 0.0, 1.0)

static func peak_points() -> Array[Vector2]:
	var peaks: Array[Vector2] = [Layout.boulder_lee(Layout.BOULDERS[0])]
	for rock in Layout.BOULDERS:
		if absf(rock.y - Layout.shore_z(rock.x)) <= 6.0:
			_append_unique(peaks, Layout.boulder_lee(rock))
	for slab in Layout.BEDROCK:
		_append_unique(peaks, Vector2(slab.x + slab.z * 0.5, slab.y))
	return peaks

static func _append_unique(points: Array[Vector2], point: Vector2) -> void:
	for existing in points:
		if existing.distance_to(point) < 0.01:
			return
	points.append(point)

static func _bump(point: Vector2, center: Vector2, spread: Vector2) -> float:
	return exp(-0.5 * ((point - center) / spread).length_squared())
