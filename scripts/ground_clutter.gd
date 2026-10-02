extends Node3D
## Flood debris and litter (Stage 3): silver driftwood branches and logs along the
## spring high-water line, wood jammed against the bar boulders, bark and fallen
## twigs under the oaks, and two old stumps past the back of the bar. Visual only:
## no collision, and nothing in the panning strip, the camp or the camp's path to
## the river. Its own seeded generator; reads oak and camp positions, changes nothing.
const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
const ScanRocks = preload("res://scripts/scan_rocks.gd")
const SEED := 184851
const PIECES := ["driftwood_01", "driftwood_02", "driftwood_03", "driftwood_log", "stump_01", "bark_01", "bark_02"]
## The panning and cradle strip along the June shore stays clear.
const SHORE_LANE := 4.0
var placements: Dictionary = {}
var _camp := Vector3.ZERO
var _oaks: Array = []
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = SEED
	var claim := get_parent()
	var camp := claim.get_node_or_null("Camp")
	_camp = camp.position if camp else Vector3(0, 0, 13.8)
	var vegetation := claim.get_node_or_null("Vegetation")
	_oaks = vegetation.placements.get("black_oak", []) if vegetation else []
	for piece in PIECES: placements[piece] = []
	_wrack_line()
	_boulder_jams()
	_oak_litter()
	_stumps()
	for piece in PIECES: _instances(piece)

## Camp, its crew bunks and fire, the trail head and the camp's path to the river.
func clear_of_camp(p: Vector3, margin := 0.0) -> bool:
	var d := p - _camp
	if d.x > -6.0 - margin and d.x < 13.0 + margin and d.z > -5.0 - margin and d.z < 12.0 + margin: return false
	return not (absf(d.x) < 4.0 + margin and p.z < _camp.z)

func _legal(p: Vector3, margin := 0.3) -> bool:
	var inland := p.z - Layout.shore_z(p.x)
	if absf(p.x) > 40.0 or inland < SHORE_LANE or inland > Layout.width_at(p.x) - .4: return false
	for oak in _oaks:
		if Vector2(oak.origin.x - p.x, oak.origin.z - p.z).length() < 1.0 + margin: return false
	return clear_of_camp(p, margin)

func _clear_of_boulders(p: Vector3, extra: float) -> bool:
	for b in Layout.BOULDERS:
		if Vector2(p.x - b.x, p.z - b.y).length() < b.z + extra: return false
	return true

func _place(piece: String, p: Vector3, yaw: float, shade: float, scale_value := 1.0, sink := .03) -> void:
	p.y = Layout.height_at(p.x, p.z) - sink
	var normal := Vector3(Layout.height_at(p.x - .25, p.z) - Layout.height_at(p.x + .25, p.z), .5, Layout.height_at(p.x, p.z - .25) - Layout.height_at(p.x, p.z + .25)).normalized()
	if piece == "stump_01": normal = Vector3.UP  # trees grew plumb
	var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, yaw)
	placements[piece].append([Transform3D(basis.scaled(Vector3.ONE * scale_value), p), shade])

## Spring flood wrack: a wavering contour about 0.5 m above the June water, in
## clumps of two or three pieces with gaps, and a few whole logs.
func _wrack_line() -> void:
	var x := -36.0
	while x < 36.0:
		x += _rng.randf_range(3.0, 7.5)
		var inland := 11.5 + 2.0 * sin(x * .11) + 1.2 * sin(x * .31 + 1.0)
		var centre := Vector3(x, 0, Layout.shore_z(x) + inland)
		if not _legal(centre, 1.0) or not _clear_of_boulders(centre, 1.0): continue
		if _rng.randf() < .4:
			var yaw := _rng.randf_range(-.5, .5) + (PI if _rng.randf() < .5 else 0.0)
			var along := Vector3(cos(yaw), 0, -sin(yaw)) * 1.6
			if _legal(centre + along, .5) and _legal(centre - along, .5) and _clear_of_boulders(centre + along, .5) and _clear_of_boulders(centre - along, .5):
				_place("driftwood_log", centre, yaw + PI * .5, _rng.randf_range(.9, 1.1), 1.0, .06)
		for i in _rng.randi_range(1, 3):
			var p := centre + Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-.6, .6))
			if _legal(p, .3) and _clear_of_boulders(p, .4):
				_place("driftwood_0%d" % _rng.randi_range(1, 3), p, _rng.randf() * TAU, _rng.randf_range(.85, 1.15), _rng.randf_range(.8, 1.2))
		if _rng.randf() < .5:
			var p := centre + Vector3(_rng.randf_range(-1.5, 1.5), 0, _rng.randf_range(-.8, .8))
			if _legal(p, .2) and _clear_of_boulders(p, .2):
				_place("bark_0%d" % _rng.randi_range(1, 2), p, _rng.randf() * TAU, _rng.randf_range(.8, 1.05))

## Branches caught against the boulders, tucked into the ring between the rock's
## face and its layout footprint, on the inland and lee sides.
func _boulder_jams() -> void:
	for b: Vector4 in Layout.BOULDERS:
		for i in _rng.randi_range(2, 4):
			var angle := _rng.randf_range(-PI * .55, PI * .55) if _rng.randf() < .6 else _rng.randf_range(PI * .35, PI * .65)
			var reach := b.z * _rng.randf_range(.82, 1.08)
			var p := Vector3(b.x + cos(angle) * reach, 0, b.y + sin(angle) * reach)
			if not _legal(p, .2): continue
			var yaw := -angle + PI * .5 + _rng.randf_range(-.4, .4)
			_place("driftwood_0%d" % _rng.randi_range(1, 3), p, yaw, _rng.randf_range(.85, 1.15), _rng.randf_range(.8, 1.15), .05)

## Bark flakes and fallen twigs in the duff under each oak.
func _oak_litter() -> void:
	for oak in _oaks:
		for i in _rng.randi_range(4, 7):
			var angle := _rng.randf() * TAU
			var p: Vector3 = oak.origin + Vector3(cos(angle), 0, sin(angle)) * _rng.randf_range(1.0, 4.2)
			if not _legal(p, .1) or not _clear_of_boulders(p, .2): continue
			var piece := "bark_0%d" % _rng.randi_range(1, 2) if _rng.randf() < .62 else "driftwood_03"
			_place(piece, p, _rng.randf() * TAU, _rng.randf_range(.75, 1.0), _rng.randf_range(.7, 1.1) if piece == "driftwood_03" else _rng.randf_range(.9, 1.4), .02)

## Two old stumps just past the back of the bar, where the walker is turned back.
func _stumps() -> void:
	var made := 0
	var tries := 0
	while made < 2 and tries < 100:
		tries += 1
		var x := _rng.randf_range(-30.0, 30.0)
		var p := Vector3(x, 0, Layout.back_z(x) + _rng.randf_range(.4, 1.6))
		if not clear_of_camp(p, 4.0) or not _clear_of_boulders(p, 2.0): continue
		var clear := true
		for oak in _oaks: clear = clear and Vector2(oak.origin.x - p.x, oak.origin.z - p.z).length() > 2.5
		for s in placements.stump_01: clear = clear and s[0].origin.distance_to(p) > 15.0
		if not clear: continue
		_place("stump_01", p, _rng.randf() * TAU, _rng.randf_range(.9, 1.1), _rng.randf_range(.85, 1.05), .12)
		made += 1

func _instances(piece: String) -> void:
	var path := "res://assets/clutter/%s.glb" % piece
	var items: Array = placements[piece]
	var node := MultiMeshInstance3D.new()
	node.name = piece.to_pascal_case()
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = true
	multi.mesh = Assets.mesh(path)
	multi.instance_count = items.size()
	for i in items.size():
		multi.set_instance_transform(i, items[i][0])
		var shade: float = items[i][1]
		multi.set_instance_color(i, Color(shade, shade, shade))
	node.multimesh = multi
	node.material_override = ScanRocks.material(path, .12 if piece.begins_with("drift") else 0.0, 0.0)
	node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	# Shadows only where they read: logs, the stump and the largest branch.
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if piece in ["driftwood_01", "driftwood_log", "stump_01"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 150.0 if piece in ["driftwood_log", "stump_01"] else 70.0
	node.visibility_range_end_margin = 5
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(node)
	placements[piece] = items.map(func(item): return item[0])
