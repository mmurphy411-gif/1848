extends Node3D
## Flood debris and litter (Stage 3): silver driftwood branches and logs along the
## spring high-water line, wood jammed against the bar boulders, bark and fallen
## twigs under the oaks, and two old stumps past the back of the bar. Wave C: denser
## and larger wrack (logs up to 5 m, branches to 2.5 m), big split snags on the
## high-water line, piled against the inland boulders and stranded at the bar ends.
## Visual only: no collision, and nothing (not even a log's far end) in the panning
## strip, the camp or the camp's path to the river. Its own seeded generators; reads
## oak and camp positions, changes nothing.
const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
const ScanRocks = preload("res://scripts/scan_rocks.gd")
const SEED := 184851
## Wave C flood debris has its own generator, so the Stage 3 litter draws stay put.
const SNAG_SEED := 184852
const PIECES := ["driftwood_01", "driftwood_02", "driftwood_03", "driftwood_log", "stump_01", "bark_01", "bark_02", "driftwood_snag"]
## Height of the snag scan (its bounding box), lifted back after rolling it over.
const SNAG_HEIGHT := 1.045
## Half-length of the long pieces at unit scale (metres), for keeping both ends legal.
const REACH := {"driftwood_log": 1.55, "driftwood_snag": 2.05, "driftwood_01": .65}
## The panning and cradle strip along the June shore stays clear.
const SHORE_LANE := 4.0
var placements: Dictionary = {}
var _camp := Vector3.ZERO
var _oaks: Array = []
var _rng := RandomNumberGenerator.new()
var _snags := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = SEED
	_snags.seed = SNAG_SEED
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
	_flood_debris()
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

## Both ends of a long piece (log and snag lie along their X axis, branches along Z) are
## legal and clear of the boulders.
func _ends_legal(piece: String, p: Vector3, yaw: float, size: float, margin: float) -> bool:
	var axis := Vector3(cos(yaw), 0, -sin(yaw)) if piece in ["driftwood_log", "driftwood_snag"] else Vector3(sin(yaw), 0, cos(yaw))
	var reach: float = REACH.get(piece, .5) * size
	for end in [p + axis * reach, p - axis * reach]:
		if not _legal(end, margin) or not _clear_of_boulders(end, .3): return false
	return _legal(p, margin)

func _clear_of_boulders(p: Vector3, extra: float) -> bool:
	for b in Layout.BOULDERS:
		if Vector2(p.x - b.x, p.z - b.y).length() < b.z + extra: return false
	return true

func _place(piece: String, p: Vector3, yaw: float, shade: float, scale_value := 1.0, sink := .03) -> void:
	p.y = Layout.height_at(p.x, p.z) - sink
	var normal := Vector3(Layout.height_at(p.x - .25, p.z) - Layout.height_at(p.x + .25, p.z), .5, Layout.height_at(p.x, p.z - .25) - Layout.height_at(p.x, p.z + .25)).normalized()
	if piece == "stump_01": normal = Vector3.UP  # trees grew plumb
	var basis := Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, yaw)
	if piece == "driftwood_snag":
		# The scan stands its trunk on a forked prop; rolled over, the trunk lies on the
		# ground and the prop limb sticks up, as a stranded snag's does.
		basis = basis * Basis(Vector3.RIGHT, PI)
		p += basis.y * -SNAG_HEIGHT * scale_value
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
			# Wave C: logs 1.1-1.6x (3.4-5 m), stranded along the flow (the log's own axis
			# is X); both ends stay legal.
			var size := _snags.randf_range(1.1, 1.6)
			if _ends_legal("driftwood_log", centre, yaw, size, .5):
				_place("driftwood_log", centre, yaw, _rng.randf_range(.9, 1.1), size, .06 * size)
		for i in _rng.randi_range(1, 3):
			var p := centre + Vector3(_rng.randf_range(-1.2, 1.2), 0, _rng.randf_range(-.6, .6))
			if _legal(p, .3) and _clear_of_boulders(p, .4):
				var piece := "driftwood_0%d" % _rng.randi_range(1, 3)
				var yaw := _rng.randf() * TAU
				var shade := _rng.randf_range(.85, 1.15)
				var size := _rng.randf_range(.8, 1.2) * _snags.randf_range(1.15, 1.9)
				if _ends_legal(piece, p, yaw, size, .3): _place(piece, p, yaw, shade, size)
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
			var piece := "driftwood_0%d" % _rng.randi_range(1, 3)
			var shade := _rng.randf_range(.85, 1.15)
			var size := _rng.randf_range(.8, 1.15) * _snags.randf_range(1.2, 1.7)
			_place(piece, p, yaw, shade, size, .05 * size)

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

## Wave C flood debris: split snags and log piles stranded on the spring high-water line
## and at the bar ends, and snags piled against the inland and lee faces of the boulders
## that stand back from the river. Own generator; legal ends, as for the logs.
func _flood_debris() -> void:
	for b: Vector4 in Layout.BOULDERS:
		for i in 2:
			var angle := _snags.randf_range(-PI * .35, PI * .35) if i == 0 else _snags.randf_range(PI * .3, PI * .7)
			var reach := b.z * _snags.randf_range(.95, 1.15)
			var p := Vector3(b.x + cos(angle) * reach, 0, b.y + sin(angle) * reach)
			var yaw := -angle + PI * .5 + _snags.randf_range(-.35, .35)
			var size := _snags.randf_range(.9, 1.3)
			var shade := _snags.randf_range(.85, 1.1)
			if _ends_legal("driftwood_snag", p, yaw, size, .2): _place("driftwood_snag", p, yaw, shade, size, .12)
	var made := 0
	var tries := 0
	while made < 9 and tries < 120:
		tries += 1
		var x := _snags.randf_range(-38.0, 38.0)
		var inland := _snags.randf_range(9.0, 15.0) + 1.5 * sin(x * .11)
		var p := Vector3(x, 0, Layout.shore_z(x) + inland)
		var yaw := _snags.randf_range(-.6, .6) + (PI if _snags.randf() < .5 else 0.0)
		var size := _snags.randf_range(.85, 1.35)
		var shade := _snags.randf_range(.85, 1.1)
		if not _ends_legal("driftwood_snag", p, yaw, size, .6): continue
		var clear := true
		for s in placements.driftwood_snag: clear = clear and s[0].origin.distance_to(p) > 7.0
		if not clear: continue
		_place("driftwood_snag", p, yaw, shade, size, .1)
		made += 1
		# A log or two jammed against it.
		for j in _snags.randi_range(0, 2):
			var q := p + Vector3(_snags.randf_range(-1.5, 1.5), 0, _snags.randf_range(-.9, .9))
			var log_yaw := yaw + _snags.randf_range(-.5, .5)
			var log_size := _snags.randf_range(.9, 1.4)
			if _ends_legal("driftwood_log", q, log_yaw, log_size, .4): _place("driftwood_log", q, log_yaw, _snags.randf_range(.85, 1.1), log_size, .08)

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
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if piece in ["driftwood_01", "driftwood_log", "stump_01", "driftwood_snag"] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 150.0 if piece in ["driftwood_log", "stump_01", "driftwood_snag"] else 70.0
	node.visibility_range_end_margin = 5
	node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(node)
	placements[piece] = items.map(func(item): return item[0])
