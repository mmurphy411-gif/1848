@tool
extends RefCounted
## River cobbles on the bar: ten normalised scans (tools/art/intake_rocks.py), a
## 5-25 cm size range with the coarse stones near the channel, and a rock type per
## instance (granite, tan, rust-stained, dark slate and greenstone, white quartz)
## carried by the MultiMesh colour on a neutral grey scan. Called from the cobble
## block of vegetation.gd; placements land in `vegetation.placements` as cobble_NN.
const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
const ScanRocks = preload("res://scripts/scan_rocks.gd")
const MESHES := 10
const SEED := 184841
const LEGACY := 600
const EXTRA := 220
## Linear albedo multipliers on the grey scans (mean about 0.35), with weights. Wave C:
## fewer and greyer white stones, browner tan and rust, more dark slate and greenstone
## (the bar read as orange-and-white garden gravel).
const KINDS := [
	[Color(.70, .69, .66), .30],  # granite
	[Color(.74, .66, .54), .18],  # tan
	[Color(.68, .49, .35), .12],  # iron-stained
	[Color(.32, .34, .35), .20],  # slate
	[Color(.40, .46, .41), .13],  # greenstone
	[Color(.88, .87, .84), .07],  # white quartz
]
## Meshes that read best for a type (index 1-based); others draw from all ten.
const QUARTZ_MESHES := [9, 6, 7]
const SLATE_MESHES := [8, 10, 3, 2]

static func build(vegetation: Node3D, rng: RandomNumberGenerator) -> void:
	var positions: Array[Vector3] = []
	# The legacy scatter keeps its positions and its exact draws from the shared rng:
	# the ground cover after this block draws from the same generator.
	for attempt in 12000:
		if positions.size() >= LEGACY: break
		var x := rng.randf_range(-38, 38)
		var inland := 1.5 + pow(rng.randf(), 1.7) * (Layout.width_at(x) - 1.5)
		var z := Layout.shore_z(x) + inland
		var p := Vector3(x, Layout.height_at(x, z), z)
		if not vegetation.clear_of_boulders(p, .15): continue
		rng.randi_range(1, 3); rng.randf_range(.04, .075); rng.randf()
		positions.append(p)
	var own := RandomNumberGenerator.new()
	own.seed = SEED
	# Coarse stones collect against the boulders and along the channel edge.
	var tries := 0
	while positions.size() < LEGACY + EXTRA and tries < 20000:
		tries += 1
		var p: Vector3
		if own.randf() < .55:
			var b: Vector4 = Layout.BOULDERS[own.randi_range(0, Layout.BOULDERS.size() - 1)]
			var angle := own.randf() * TAU
			var reach := b.z + .05 + pow(own.randf(), 1.6) * 2.2
			p = Vector3(b.x + cos(angle) * reach, 0, b.y + sin(angle) * reach)
		else:
			var x := own.randf_range(-36, 36)
			p = Vector3(x, 0, Layout.shore_z(x) + own.randf_range(1.55, 4.0))
		var inland := p.z - Layout.shore_z(p.x)
		if absf(p.x) > 38 or inland < 1.55 or inland > Layout.width_at(p.x) - .3: continue
		if not vegetation.clear_of_boulders(p, .03): continue
		p.y = Layout.height_at(p.x, p.z)
		positions.append(p)
	var groups: Array = []
	var colours: Array = []
	for i in MESHES:
		groups.append([]); colours.append([])
	var total := 0.0
	for kind in KINDS: total += kind[1]
	var boxes: Array[AABB] = []
	for i in MESHES: boxes.append(Assets.mesh(_path(i)).get_aabb())
	for p in positions:
		var pick := own.randf() * total
		var kind := 0
		while kind < KINDS.size() - 1 and pick > KINDS[kind][1]:
			pick -= KINDS[kind][1]; kind += 1
		var mesh := own.randi_range(0, MESHES - 1)
		if kind == 5 and own.randf() < .7: mesh = QUARTZ_MESHES[own.randi_range(0, 2)] - 1
		if kind == 3 and own.randf() < .5: mesh = SLATE_MESHES[own.randi_range(0, 3)] - 1
		# Half-extent 2.5-12.5 cm, mostly small; bigger toward the channel.
		var inland := p.z - Layout.shore_z(p.x)
		var coarse := 1.0 - smoothstep(2.0, 14.0, inland)
		var size := .025 + .10 * pow(own.randf(), lerpf(2.6, 1.3, coarse))
		var lean := own.randf() * TAU
		var tilt := Basis(Vector3(cos(lean), 0, sin(lean)), own.randf_range(0, .18))
		var basis := tilt * Basis(Vector3.UP, own.randf() * TAU)
		var box: AABB = boxes[mesh]
		# Bed the stone: 25-45 % of its height below the gravel surface.
		var height := box.size.y * size
		var origin := p + Vector3(0, -box.position.y * size - height * own.randf_range(.25, .45), 0)
		groups[mesh].append(Transform3D(basis.scaled(Vector3.ONE * size), origin))
		var shade := own.randf_range(.86, 1.1)
		var c: Color = KINDS[kind][0]
		colours[mesh].append(Color(c.r * shade, c.g * shade, c.b * shade))
	for i in MESHES:
		var key := "cobble_%02d" % (i + 1)
		vegetation.placements[key] = groups[i]
		var node := MultiMeshInstance3D.new()
		node.name = key
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.mesh = Assets.mesh(_path(i))
		multi.instance_count = groups[i].size()
		for j in groups[i].size():
			multi.set_instance_transform(j, groups[i][j])
			multi.set_instance_color(j, colours[i][j])
		node.multimesh = multi
		node.material_override = ScanRocks.material(_path(i), 0.0, 0.0)
		node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		# Bedded stones need no shadow pass: ten meshes would cost up to six draws each.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 60
		node.visibility_range_end_margin = 5
		node.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		vegetation.add_child(node)

static func _path(index: int) -> String:
	return "res://assets/boulders/cobble_%02d.glb" % (index + 1)
