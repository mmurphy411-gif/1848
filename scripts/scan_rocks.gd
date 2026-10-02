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
	[.35, .55, .10], [-.20, .10, .0], [.15, .45, .12], [-.30, .35, .35],
	[.25, .50, .30], [-.10, .40, .45], [.40, .60, .08],
]
## The narrow side of an elongated scan is stretched to at least this share of
## the footprint radius, and heights stretch at most this much from natural.
const ROUNDNESS := .78
const STRETCH := Vector2(.85, 1.35)
const MARGIN_SEED := 184830
const GIRTH_BINS := 20
static var _materials: Dictionary = {}
## Per bar boulder after fitting: visible height, old dome height, vertical stretch, buried share.
static var fits: Dictionary = {}
static var water := 0.0

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
	_materials[key] = result
	return result

## The river's live elevation, mirrored from the terrain's water_level uniform.
static func set_water_level(level: float) -> void:
	water = level
	for key in _materials: _materials[key].set_shader_parameter("water_level", level)

## Copy surface 0 through an affine transform: vertices, normals and tangents.
static func baked(mesh: ArrayMesh, transform: Transform3D) -> ArrayMesh:
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
	var target := data.w * 1.35
	var bury := (ground - lowest) + maxf(.25, target * .12)
	var natural := box.size.y * k
	var stretch := clampf(maxf(target + bury, target / (1.0 - footing)) / natural, STRETCH.x, STRETCH.y)
	var sy := k * stretch
	bury = maxf(bury, footing * natural * stretch)
	var visible := natural * stretch - bury
	fits[index] = Vector4(visible, target, stretch, footing)
	var scale := Basis.from_scale(Vector3(sx, sy, sz))
	var offset := Vector3(0, visible - (box.end.y - center.y) * sy, 0) - scale * center
	return baked(mesh, Transform3D(scale * rotation, offset))

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
	for i in 9:
		var x := rng.randf_range(-75.0, 75.0)
		var foot := Layout.canyon_shore_z(x) - 27.27619 - Layout.canyon_far_offset(x)
		spots.append(Vector4(x, foot - rng.randf_range(-.3, 2.2), rng.randf_range(1.0, 2.4), 1))
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
		var file: int = meshes[i % meshes.size()]
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
		batches[file].append([Transform3D(basis, Vector3(s.x, ground + sink, s.y)), tint])
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
		multi.mesh = Assets.mesh(BOULDER_PATH % file)
		multi.instance_count = items.size()
		for j in items.size():
			multi.set_instance_transform(j, items[j][0])
			multi.set_instance_color(j, items[j][1])
		node.multimesh = multi
		node.material_override = material(BOULDER_PATH % file, .5, .15 if file == 11 else .0)
		node.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		group.add_child(node)
	return group
