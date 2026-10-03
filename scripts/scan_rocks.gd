@tool
extends RefCounted
## Normalised CC0 rock scans (tools/art/intake_rocks.py): shared scan_rock
## materials, mesh baking for unit-scale physics, and the margin rocks that sit
## outside the playable bar. Boulder GLBs have a unit horizontal half-extent and
## their natural height; the bar boulders are fitted to Layout.BOULDERS here.
const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
const SHADER = preload("res://shaders/scan_rock.gdshader")
const BOULDER_PATH := "res://assets/boulders/boulder_%02d.glb"
## Per bar boulder (Layout.BOULDERS index): yaw offset from flow alignment,
## lichen amount, rust staining. boulder_02 is the white quartz boulder.
const BAR_LOOK := [
	[3.2, .55, .10], [.30, .10, .0], [.15, .45, .12], [-.30, .35, .30],
	[.25, .50, .25], [-.10, .40, .45], [.40, .60, .08],
]
## Granite character per boulder file (scan_rock.gdshader): crystal grain and quartz
## veins. boulder_02 is quartz (faint grain, no veins), boulder_11 dark slate (none).
const GRAIN := {1: [1.0, .6], 2: [.35, 0.0], 3: [1.0, .8], 4: [1.0, .5], 5: [1.0, .7], 6: [.8, .3],
	7: [1.0, .6], 8: [1.0, .5], 9: [1.0, .4], 10: [.8, .4], 11: [0.0, 0.0], 12: [1.0, .3], 13: [1.0, .5]}
## The narrow side of an elongated scan is stretched to at least this share of the
## footprint radius, and heights stretch at most this much from natural. Wave C: the
## river-rounded scans keep close to their own proportions (the old .78 and 1.35 turned
## a fractured block into a sheer-sided, flat-topped "quarry block").
const ROUNDNESS := .62
const STRETCH := Vector2(.85, 1.12)
## Visible height target as a share of the layout's vertical radius (the domes stood 1.35).
const HEIGHT := 1.1
const MARGIN_SEED := 184830
## Far-bank margin rocks: x along the reach and the scan for each (every margin scan
## shows across the river from the bar).
const FAR_BANK_X := [-36.0, -27.0, -19.0, -11.0, -3.0, 5.0, 13.0, 22.0, 32.0]
const FAR_BANK_MESH := [10, 12, 9, 13, 8, 12, 10, 11, 9]
const GIRTH_BINS := 20
static var _materials: Dictionary = {}
## Per bar boulder after fitting: visible height, old dome height, vertical stretch, buried share.
static var fits: Dictionary = {}
static var water := 0.0
## Ground outline of each fitted bar boulder for the terrain shader's contact shading and
## sand drifts: centre x, z, mean radius, top height; and the outline's Fourier terms
## (cos, sin, cos 2a, sin 2a) of radius against angle.
static var outline_at := PackedVector4Array()
static var outline_shape := PackedVector4Array()

## One ShaderMaterial per scan file, built from the GLB's own baked maps.
static func material(path: String, lichen := .45, stain := .0) -> ShaderMaterial:
	var key := "%s:%.2f:%.2f" % [path, lichen, stain]
	if _materials.has(key): return _materials[key]
	var source := Assets.mesh(path).surface_get_material(0) as BaseMaterial3D
	var result := ShaderMaterial.new()
	result.shader = SHADER
	result.set_shader_parameter("albedo_map", source.albedo_texture)
	result.set_shader_parameter("normal_map", source.normal_texture)
	result.set_shader_parameter("orm_map", source.roughness_texture)
	result.set_shader_parameter("lichen", lichen)
	result.set_shader_parameter("stain", stain)
	result.set_shader_parameter("water_level", water)
	var number := int(path.get_file().get_basename().get_slice("_", 1)) if path.get_file().begins_with("boulder_") else 0
	if GRAIN.has(number):
		result.set_shader_parameter("granite", GRAIN[number][0])
		result.set_shader_parameter("veins", GRAIN[number][1])
	_materials[key] = result
	return result

## The river's live elevation, mirrored from the terrain's water_level uniform.
static func set_water_level(level: float) -> void:
	water = level
	for key in _materials: _materials[key].set_shader_parameter("water_level", level)

## Copy surface 0 through an affine transform: vertices, normals and tangents. With
## `origin` (the node's world position) UV2 carries the world ground height under each
## vertex and a flag, for the shader's contact shading.
static func baked(mesh: ArrayMesh, transform: Transform3D, origin := Vector3(NAN, 0, 0)) -> ArrayMesh:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = arrays[Mesh.ARRAY_TANGENT] if arrays[Mesh.ARRAY_TANGENT] != null else PackedFloat32Array()
	var normal_basis := transform.basis.inverse().transposed()
	for i in vertices.size():
		vertices[i] = transform * vertices[i]
		normals[i] = (normal_basis * normals[i]).normalized()
		if tangents.size() == vertices.size() * 4:
			var t := transform.basis * Vector3(tangents[i*4], tangents[i*4+1], tangents[i*4+2])
			t = (t - normals[i] * normals[i].dot(t)).normalized()
			tangents[i*4] = t.x; tangents[i*4+1] = t.y; tangents[i*4+2] = t.z
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	if not is_nan(origin.x):
		var ground := PackedVector2Array()
		ground.resize(vertices.size())
		for i in vertices.size():
			ground[i] = Vector2(Layout.height_at(origin.x + vertices[i].x, origin.z + vertices[i].z), 1.0)
		arrays[Mesh.ARRAY_TEX_UV2] = ground
	if tangents.size() == vertices.size() * 4: arrays[Mesh.ARRAY_TANGENT] = tangents
	var result := ArrayMesh.new()
	result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return result

static func _bounds(mesh: ArrayMesh, basis: Basis) -> AABB:
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var box := AABB(basis * vertices[0], Vector3.ZERO)
	for v in vertices: box = box.expand(basis * v)
	return box

## Fit a scan to a Layout.BOULDERS footprint: the larger horizontal half-extent is
## exactly the radius, the long axis runs with the flow (X), and the top stands
## 1.35 vertical radii above the centre ground, as the old domes did, buried
## deeper than the lowest ground under the footprint. Local origin = ground at centre.
static func fit_bar_boulder(index: int) -> ArrayMesh:
	var data: Vector4 = Layout.BOULDERS[index]
	var mesh := Assets.mesh(BOULDER_PATH % (index + 1))
	var raw := _bounds(mesh, Basis.IDENTITY)
	var yaw: float = (PI * .5 if raw.size.z > raw.size.x else 0.0) + BAR_LOOK[index][0]
	var rotation := Basis(Vector3.UP, yaw)
	var box := _bounds(mesh, rotation)
	var half := Vector2(box.size.x, box.size.z) * .5
	var k := data.z / maxf(half.x, half.y)
	var sx := maxf(k, ROUNDNESS * data.z / half.x)
	var sz := maxf(k, ROUNDNESS * data.z / half.y)
	var ground := Layout.height_at(data.x, data.y)
	var lowest := ground
	for step in 16:
		var angle := step * TAU / 16
		for reach in [.55, .9]:
			lowest = minf(lowest, Layout.height_at(data.x + cos(angle) * data.z * reach, data.y + sin(angle) * data.z * reach))
	var center := box.get_center()
	# Bury at least to where the rock first reaches 92 % of its widest girth, so no
	# boulder stands on a narrow, undercut foot.
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var girth := PackedFloat32Array()
	girth.resize(GIRTH_BINS)
	for v in vertices:
		var p := rotation * v - center
		var bin := clampi(int((p.y + box.size.y * .5) / box.size.y * GIRTH_BINS), 0, GIRTH_BINS - 1)
		girth[bin] = maxf(girth[bin], Vector2(p.x * sx, p.z * sz).length())
	var widest := 0.0
	for g in girth: widest = maxf(widest, g)
	var foot := 0
	while foot < GIRTH_BINS - 1 and girth[foot] < widest * .92: foot += 1
	var footing := minf(float(foot) / GIRTH_BINS, .3)
	var target := data.w * HEIGHT
	var bury := (ground - lowest) + maxf(.25, target * .12)
	var natural := box.size.y * k
	var stretch := clampf(maxf(target + bury, target / (1.0 - footing)) / natural, STRETCH.x, STRETCH.y)
	var sy := k * stretch
	bury = maxf(bury, footing * natural * stretch)
	var visible := natural * stretch - bury
	fits[index] = Vector4(visible, target, stretch, footing)
	var scale := Basis.from_scale(Vector3(sx, sy, sz))
	var offset := Vector3(0, visible - (box.end.y - center.y) * sy, 0) - scale * center
	var origin := Vector3(data.x, ground, data.y)
	var result := baked(mesh, Transform3D(scale * rotation, offset), origin)
	_record_outline(index, result, origin, visible)
	return result

## The rock's outline where it meets the ground, as a radius-against-angle curve
## r(a) = r0 + c1 cos a + s1 sin a + c2 cos 2a + s2 sin 2a about the layout centre, handed
## to the terrain shader (Assets.terrain(): boulder_at, boulder_shape).
static func _record_outline(index: int, mesh: ArrayMesh, origin: Vector3, top: float) -> void:
	const BINS := 24
	var reach := PackedFloat32Array()
	reach.resize(BINS)
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	for v in vertices:
		var above := origin.y + v.y - Layout.height_at(origin.x + v.x, origin.z + v.z)
		if above < -.15 or above > .3: continue
		var bin := posmod(int(floor((atan2(v.z, v.x) + PI) / TAU * BINS)), BINS)
		reach[bin] = maxf(reach[bin], Vector2(v.x, v.z).length())
	# Empty bins (sparse vertices) borrow from their nearest filled neighbours.
	for pass_index in BINS:
		var filled := true
		for i in BINS:
			if reach[i] > 0.0: continue
			filled = false
			reach[i] = maxf(reach[(i + 1) % BINS], reach[(i + BINS - 1) % BINS]) * .98
		if filled: break
	var terms := PackedFloat32Array([0, 0, 0, 0, 0])
	for i in BINS:
		var a := (i + .5) / BINS * TAU - PI
		terms[0] += reach[i] / BINS
		terms[1] += reach[i] * cos(a) * 2.0 / BINS
		terms[2] += reach[i] * sin(a) * 2.0 / BINS
		terms[3] += reach[i] * cos(2.0 * a) * 2.0 / BINS
		terms[4] += reach[i] * sin(2.0 * a) * 2.0 / BINS
	var count := Layout.BOULDERS.size()
	if outline_at.size() != count:
		outline_at.resize(count); outline_shape.resize(count)
	outline_at[index] = Vector4(origin.x, origin.z, terms[0], origin.y + top)
	outline_shape[index] = Vector4(terms[1], terms[2], terms[3], terms[4])
	Assets.terrain().set_shader_parameter("boulder_at", outline_at)
	Assets.terrain().set_shader_parameter("boulder_shape", outline_shape)

## Partly buried mid-size scans outside the playable bar: both bar ends, the
## far-bank waterline under the cliff, and the back edge of the bar (these can be
## reached, so they collide). Returns the group node.
static func build_margin(parent: Node3D, oaks: Array) -> Node3D:
	var group := Node3D.new()
	group.name = "MarginRocks"
	parent.add_child(group)
	var rng := RandomNumberGenerator.new()
	rng.seed = MARGIN_SEED
	var meshes := [8, 9, 10, 11, 12, 13]
	var spots: Array[Vector4] = []  # x, z, half-extent, zone (0 ends, 1 far bank, 2 back edge)
	for side in [-1.0, 1.0]:
		for i in 5:
			var x: float = side * rng.randf_range(43.0, 85.0)
			var shore := Layout.canyon_shore_z(x)
			spots.append(Vector4(x, shore + rng.randf_range(-1.5, Layout.canyon_width_at(x) + 3.0), rng.randf_range(1.2, 2.8), 0))
	# The far bank drops 2.1 m per metre into the pool; keep these on the wall's foot.
	# Wave C: spread along the reach the bar looks across (the across-river, far-wall,
	# wildlife and crew views), one of each margin scan in view, instead of anywhere in
	# |x| < 75 where they fell out of every tour view.
	for i in 9:
		var x: float = FAR_BANK_X[i] + rng.randf_range(-2.5, 2.5)
		var foot := Layout.canyon_shore_z(x) - 27.27619 - Layout.canyon_far_offset(x)
		spots.append(Vector4(x, foot - rng.randf_range(-.3, 1.4), rng.randf_range(1.6, 2.6), 1))
	var tries := 0
	while spots.size() < 10 + 9 + 6 and tries < 200:
		tries += 1
		var x := rng.randf_range(-36.0, 36.0)
		if absf(x) < 7.0: continue
		var z := Layout.back_z(x) + rng.randf_range(-.2, 1.4)
		var clear := true
		for oak in oaks: clear = clear and Vector2(oak.origin.x - x, oak.origin.z - z).length() > 3.5
		for b in Layout.BOULDERS: clear = clear and Vector2(b.x - x, b.y - z).length() > b.z + 2.5
		for s in spots: clear = clear and Vector2(s.x - x, s.y - z).length() > 5.0
		if clear: spots.append(Vector4(x, z, rng.randf_range(.8, 1.6), 2))
	# All margin rocks share one MultiMesh per scan (few draw calls, shadows kept);
	# the back-edge rocks also get a baked unit-scale convex body.
	var batches: Dictionary = {}
	for i in spots.size():
		var s: Vector4 = spots[i]
		var file: int = meshes[i % meshes.size()] if s.w != 1 else FAR_BANK_MESH[i - 10]
		var path := BOULDER_PATH % file
		var mesh := Assets.mesh(path)
		var box := _bounds(mesh, Basis.IDENTITY)
		var size := s.z
		var squash := rng.randf_range(.8, 1.15)
		var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(size, size * squash, size))
		var ground := Layout.height_at(s.x, s.y)
		var lowest := ground
		for step in 8:
			var angle := step * TAU / 8
			lowest = minf(lowest, Layout.height_at(s.x + cos(angle) * size * .8, s.y + sin(angle) * size * .8))
		# Bury 25-45 % of the height; on slopes the base sits between centre and lowest ground.
		var height := box.size.y * size * squash
		var sink := (lowest - ground) * (.35 if s.w == 1 else .6) - height * rng.randf_range(.25, .45) - box.position.y * size * squash
		var look := rng.randf_range(.92, 1.08)
		var tint := Color(look, look * rng.randf_range(.97, 1.0), look * rng.randf_range(.93, 1.0), rng.randf_range(.6, 1.2))
		if not batches.has(file): batches[file] = []
		# Ground plane under the rock (height at its centre and slope) for contact shading.
		var slope := Vector2(Layout.height_at(s.x + .5, s.y) - Layout.height_at(s.x - .5, s.y), Layout.height_at(s.x, s.y + .5) - Layout.height_at(s.x, s.y - .5))
		batches[file].append([Transform3D(basis, Vector3(s.x, ground + sink, s.y)), tint, Color(ground, slope.x, slope.y, 1.0)])
		if s.w == 2:
			# Reachable: a unit-scale convex body baked from the same placement.
			var body := StaticBody3D.new()
			body.name = "MarginRock%02d" % (i + 1)
			body.position = Vector3(s.x, ground, s.y)
			var shape := CollisionShape3D.new()
			shape.shape = baked(mesh, Transform3D(basis, Vector3(0, sink, 0))).create_convex_shape(true, true)
			body.add_child(shape)
			group.add_child(body)
	for file in batches:
		var items: Array = batches[file]
		var node := MultiMeshInstance3D.new()
		node.name = "Scan%02d" % file
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_colors = true
		multi.use_custom_data = true
		multi.mesh = Assets.mesh(BOULDER_PATH % file)
		multi.instance_count = items.size()
		for j in items.size():
			multi.set_instance_transform(j, items[j][0])
			multi.set_instance_color(j, items[j][1])
			multi.set_instance_custom_data(j, items[j][2])
		node.multimesh = multi
		node.material_override = material(BOULDER_PATH % file, .5, .15 if file == 11 else .0)
		node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		group.add_child(node)
	return group
