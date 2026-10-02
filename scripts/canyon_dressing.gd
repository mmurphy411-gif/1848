@tool
extends Node3D
## Stage 2 canyon dressing, seeded and seated on the render walls (greybox.gd's
## visual_surface: wall_point noise, bend and crests included):
##  * scanned cliff and outcrop pieces (assets/cliffs/cliff_*) faced onto the cliff bands,
##  * talus (assets/cliffs/talus_*) on the aprons, including a rock over each frozen
##    back-wall boulder collider that _build_cliff_boulders keeps,
##  * conifers continuing the wall forest just past the bend start (the existing
##    distant tree meshes), and a treeline of low-poly tiered spires on the bent
##    reach's slopes and crests, shaded by ridge_forest.gdshader.
## Render-only: nothing here collides. Instances are MultiMesh, chunked along the valley
## so frustum culling and the imported LODs work per chunk. Each system owns its RNG.
const Assets = preload("res://scripts/asset_library.gd")
const Canyon = preload("res://scripts/canyon.gd")
## Cliff pieces and their weights on the bands.
const CLIFFS := {"cliff_slate": 3.5, "cliff_face_01": 2.2, "cliff_jointed": 1.5, "cliff_face_02": 1.2}
const TALUS := ["talus_01", "talus_02", "talus_03", "talus_04"]
const CONIFERS := ["ponderosa", "incense_cedar", "douglas_fir"]
const BARK := [Color(.37,.16,.055), Color(.22,.09,.035), Color(.15,.105,.075)]
const CHUNK := 50.0
const BAND_SLOPE := 2.2
## Valley reach dressed with cliff pieces (far wall reaches into the outer bend) and talus.
const CLIFF_REACH := Vector2(330.0, 200.0)
const TALUS_REACH := 200.0
## Wall forest continues with tree meshes this far past the bend start, then spires.
const FOREST_SEAM := 80.0
## Gameplay cameras draw to 600 m; nothing is placed beyond this radius of the claim.
const TREE_RADIUS := 640.0
var ground: Node3D
## Mesh key -> Array of Transform3D.
var placements: Dictionary = {}
var pieces: Dictionary = {}

func build(greybox: Node3D, colliders: Array) -> void:
	ground = greybox
	for piece in CLIFFS.keys() + TALUS: pieces[piece] = _piece(piece)
	_cliffs()
	_talus(colliders)
	_seam_trees()
	_commit()
	_treeline()

## Mesh, size and facing of a scan. Cliff scans are open shells: their area-weighted
## normals sum to the face direction, and `front` is how far the face stands in front
## of the centroid. Closed rocks (talus) sum to nearly zero.
func _piece(piece: String) -> Dictionary:
	var mesh := Assets.mesh("res://assets/cliffs/%s.glb" % piece)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normal_sum := Vector3.ZERO
	var centroid := Vector3.ZERO
	var area := 0.0
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var cross := (vertices[indices[i + 2]] - a).cross(vertices[indices[i + 1]] - a)
		normal_sum += cross
		centroid += (a + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0 * cross.length()
		area += cross.length()
	centroid /= maxf(area, 0.0001)
	var face := normal_sum.normalized() if normal_sum.length() > 0.05 * area else Vector3.UP
	var front := 0.0
	var front_area := 0.0
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var cross := (vertices[indices[i + 2]] - a).cross(vertices[indices[i + 1]] - a)
		if cross.normalized().dot(face) < 0.3: continue
		front += ((a + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0 - centroid).dot(face) * cross.length()
		front_area += cross.length()
	if not mesh.has_meta("cliff_kit"):
		var source := mesh.surface_get_material(0) as BaseMaterial3D
		var material := ShaderMaterial.new()
		material.shader = preload("res://shaders/cliff_kit.gdshader")
		if source:
			material.set_shader_parameter("albedo_map", source.albedo_texture)
			material.set_shader_parameter("normal_map", source.normal_texture)
			material.set_shader_parameter("orm_map", source.roughness_texture)
		material.set_shader_parameter("detail_map", load("res://assets/cliffs/cliff_detail.png"))
		if piece.begins_with("talus"): material.set_shader_parameter("iron_amount", 0.3)
		mesh.surface_set_material(0, material)
		mesh.set_meta("cliff_kit", true)
	return {"mesh": mesh, "size": mesh.get_aabb().size, "face": face, "centroid": centroid, "front": front / maxf(front_area, 0.0001)}

## Instances group by piece, wall and 50 m of valley: per-chunk culling and LOD.
func _key(piece: String, x: float, far: bool) -> String:
	return "%s|%d|%s" % [piece, floori(x / CHUNK), "far" if far else "near"]

func _add(key: String, transform: Transform3D) -> void:
	if not placements.has(key): placements[key] = []
	placements[key].append(transform)

## Render-space point and surface of an analytical wall point at distance d from a foot.
func _wall(x: float, d: float, far: bool) -> Dictionary:
	var z := Canyon.far_foot(x) - d if far else Canyon.near_foot(x) + d
	var zv := Canyon.remap_z(x, z)
	var surface: Vector4 = ground.visual_surface(x, zv)
	return {"point": Vector3(x, surface.w, zv), "normal": Vector3(surface.x, surface.y, surface.z)}

func _cliffs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 184821
	var names: Array = CLIFFS.keys()
	var total := 0.0
	for piece in names: total += CLIFFS[piece]
	for far in [true, false]:
		var reach: float = CLIFF_REACH.x if far else CLIFF_REACH.y
		for band_index in (3 if far else 2):
			var x := -reach + rng.randf() * 8.0
			while x < reach:
				var pick := rng.randf() * total
				var piece: String = names[-1]
				for candidate in names:
					pick -= CLIFFS[candidate]
					if pick <= 0.0:
						piece = candidate
						break
				var info: Dictionary = pieces[piece]
				var size: Vector3 = info.size
				var apron := 8.0 + 2.0 * sin(x * 0.055)
				var band := (7.0 if far else 5.0) + 2.0 * sin(x * 0.04)
				if far: band *= 1.0 - 0.55 * exp(-pow((x - 64.0) / 22.0, 2.0))
				var slant := band * sqrt(1.0 + BAND_SLOPE * BAND_SLOPE)
				var scale := minf(slant * rng.randf_range(0.75, 1.1) / size.y, 24.0 / size.x)
				var stretch := rng.randf_range(0.85, 1.15)
				var width := size.x * scale * stretch
				var start := apron + band_index * (band + 3.0)
				var mid := _wall(x, start + band * rng.randf_range(0.4, 0.55), far)
				var outward := Vector3(mid.normal.x, 0.0, mid.normal.z)
				if outward.length() < 0.2: outward = Vector3(0, 0, 1 if far else -1)
				outward = outward.normalized()
				# Face the scan onto the band (66 degrees), rolled so its strata dip.
				var band_normal := (outward * BAND_SLOPE + Vector3.UP).normalized()
				var basis := Basis(band_normal, rng.randf_range(-0.3, 0.3)) * Basis(Quaternion(info.face, band_normal))
				basis = basis * Basis.from_scale(Vector3(scale * stretch, scale, scale))
				var proud := rng.randf_range(0.2, 0.9) - float(info.front) * scale
				var origin: Vector3 = mid.point + band_normal * proud - basis * Vector3(info.centroid)
				var keep := rng.randf() > (0.2 if absf(x) <= Canyon.BEND_START + 10.0 else 0.5)
				if keep and (far or absf(x) <= Canyon.BEND_START + 10.0):
					_add(_key(piece, x, far), Transform3D(basis, origin))
				x += width * rng.randf_range(0.55, 0.85)

## Basis turning a rock's open side (if any) into the slope, spun about the slope.
func _seated(info: Dictionary, normal: Vector3, spin: float, scale: float) -> Basis:
	var face: Vector3 = info.face
	var align := Basis(Quaternion(face, normal))
	return (Basis(normal, spin) * align).scaled(Vector3.ONE * scale)

func _talus(colliders: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 184822
	# The frozen back-wall colliders keep a rock where they stand.
	for blob in colliders:
		var position: Vector3 = blob.position
		var size: float = blob.size
		var piece: String = TALUS[rng.randi_range(0, TALUS.size() - 1)]
		var info: Dictionary = pieces[piece]
		var extent: Vector3 = info.size
		var surface: Vector4 = ground.visual_surface(position.x, position.z)
		var normal := Vector3(surface.x, surface.y, surface.z).lerp(Vector3.UP, 0.5).normalized()
		# Cover the old blob: its footprint and the dome that stood above the slope.
		var footprint := size * 1.9 / maxf(extent.x, extent.z)
		var scale := clampf(0.65 * size * float(blob.stretch) / (0.7 * extent.y), footprint, footprint * 1.2)
		var basis := _seated(info, normal, rng.randf() * TAU, scale)
		var origin: Vector3 = Vector3(position.x, surface.w, position.z) - normal * extent.y * scale * 0.3
		_add(_key(piece, position.x, false), Transform3D(basis, origin))
	for far in [true, false]:
		var x := -TALUS_REACH
		while x < TALUS_REACH:
			x += rng.randf_range(1.2, 3.6)
			var cluster := Canyon.noise().get_noise_2d(x * 0.04, 60.0 if far else 90.0)
			if rng.randf() > 0.6 + 0.5 * cluster: continue
			var piece: String = TALUS[rng.randi_range(0, TALUS.size() - 1)]
			var info: Dictionary = pieces[piece]
			var extent: Vector3 = info.size
			var scale := rng.randf_range(0.45, 1.5) * (1.0 + 0.5 * maxf(cluster, 0.0))
			var reach := maxf(extent.x, extent.z) * 0.5 * scale
			var apron := 8.0 + 2.0 * sin(x * 0.055)
			# Behind the bar the talus keeps off the playable gravel.
			var lowest := reach + 0.4 if not far and absf(x) < 48.0 else 0.2
			var d := lowest + pow(rng.randf(), 1.4) * maxf(apron + 2.0 - lowest, 0.5)
			var spot := _wall(x, d, far)
			var normal: Vector3 = spot.normal.lerp(Vector3.UP, 0.35).normalized()
			var basis := _seated(info, normal, rng.randf() * TAU, scale)
			var origin: Vector3 = spot.point - normal * extent.y * scale * rng.randf_range(0.2, 0.4)
			_add(_key(piece, x, far), Transform3D(basis, origin))

## Wall forest just past the bend start, with the same tree meshes and density rule
## as the claim reach's wall forest, so the seam at |x| = 160 m does not show.
func _seam_trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 184823
	for side in [-1.0, 1.0]:
		var placed := 0
		for attempt in 3000:
			if placed >= 80: break
			var s := rng.randf() * FOREST_SEAM
			var x: float = side * (Canyon.BEND_START + 2.0 + s)
			var far := rng.randf() < 0.53
			var spot := _wall(x, rng.randf_range(10.0, 135.0), far)
			var p: Vector3 = spot.point
			if spot.normal.y < cos(deg_to_rad(40)) or rng.randf() > exp(-p.y / 125.0): continue
			if s > FOREST_SEAM * 0.5 and rng.randf() < (s - FOREST_SEAM * 0.5) / (FOREST_SEAM * 0.5): continue
			var species := "ponderosa" if p.y > 45 or (far and rng.randf() < .55) else ("incense_cedar" if rng.randf() < .5 else "douglas_fir")
			var basis := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.8, 1.2))
			_add("tree:%s|%d" % [species, int(side)], Transform3D(basis, p - Vector3.UP * 0.18))
			placed += 1

## Tiered spires (three stacked five-sided cones, 15 triangles) on the bent reach: a
## fringe along each far-wall crest so the skylines carry tree tips, and a looser
## scatter over both walls. One mesh per end; ridge_forest.gdshader shades it.
func _treeline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 184824
	for side in [-1.0, 1.0]:
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		var vertices := PackedVector3Array()
		var normals := PackedVector3Array()
		var colors := PackedColorArray()
		var count := 0
		for attempt in 20000:
			if count >= 2000: break
			var s := FOREST_SEAM * 0.6 + rng.randf() * 420.0
			var x: float = side * (Canyon.BEND_START + s)
			var far := rng.randf() < 0.72
			var rim := Canyon.rim(x, far)
			var crest_row := far and rng.randf() < 0.55
			var u := rng.randf_range(-rim + 10.0, 420.0)
			if crest_row:
				var k := rng.randi_range(0, Canyon.CRESTS.size() - 1)
				u = Canyon.CRESTS[k].x + 18.0 * Canyon.noise().get_noise_2d(x * 0.009, 40.0 + k * 31.0) + rng.randfn(0.0, 9.0)
			# Fade in past the seam trees.
			if s < FOREST_SEAM and rng.randf() > (s - FOREST_SEAM * 0.6) / (FOREST_SEAM * 0.4): continue
			var z := Canyon.far_foot(x) - rim - u if far else Canyon.near_foot(x) + rim + u
			if Vector2(x, Canyon.remap_z(x, z)).length() > TREE_RADIUS: continue
			var spot := _wall(x, rim + u, far)
			# Thin where the slope steepens; none on cliffs.
			if spot.normal.y < 0.55 or rng.randf() > smoothstep(0.55, 0.8, spot.normal.y) + (0.5 if crest_row else 0.0): continue
			_spire(vertices, normals, colors, spot.point, rng)
			count += 1
		arrays[Mesh.ARRAY_VERTEX] = vertices
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_COLOR] = colors
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var line := MeshInstance3D.new()
		line.name = "RidgeTreeline%s" % ("Downstream" if side > 0 else "Upstream")
		line.mesh = mesh
		line.material_override = ground.ridge_forest()
		line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		add_child(line)

func _spire(vertices: PackedVector3Array, normals: PackedVector3Array, colors: PackedColorArray, base: Vector3, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(14.0, 27.0)
	var radius := height * rng.randf_range(0.16, 0.24)
	var tint := rng.randf()
	var turn := rng.randf() * TAU
	base.y -= 0.6
	# COLOR: r = per-tree tint, g = 1 marks a spire, b = height within the tier.
	var tip := Color(tint, 1.0, 1.0)
	var skirt := Color(tint, 1.0, 0.0)
	for tier in 3:
		var bottom := height * (0.18 + 0.24 * tier)
		var top := height * (0.55 + 0.225 * tier)
		var r := radius * (1.0 - 0.27 * tier)
		var apex := base + Vector3(0, top, 0)
		for i in 5:
			var a0 := turn + TAU * i / 5.0
			var a1 := turn + TAU * (i + 1) / 5.0
			vertices.append_array([apex, base + Vector3(cos(a0) * r, bottom, sin(a0) * r), base + Vector3(cos(a1) * r, bottom, sin(a1) * r)])
			normals.append_array([Vector3.UP, Vector3(cos(a0), 0.75, sin(a0)).normalized(), Vector3(cos(a1), 0.75, sin(a1)).normalized()])
			colors.append_array([tip, skirt, skirt])

func _commit() -> void:
	var keys := placements.keys()
	keys.sort()
	for key in keys:
		var label: String = key
		var piece := label.get_slice("|", 0)
		var group := MultiMeshInstance3D.new()
		group.name = label.replace("|", "_").replace(":", "_")
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		var tree := piece.begins_with("tree:")
		if tree:
			var species := piece.get_slice(":", 1)
			multi.mesh = Assets.plant(species, BARK[CONIFERS.find(species)], true, true)
		else:
			multi.mesh = pieces[piece].mesh
		var transforms: Array = placements[key]
		multi.instance_count = transforms.size()
		for i in transforms.size(): multi.set_instance_transform(i, transforms[i])
		group.multimesh = multi
		# The far wall faces away from the sun all day, so only near-wall rock by the
		# claim casts shadows; GI sees the rock by the claim. The overview has about
		# a millisecond of frame budget to spare.
		var centre := absf((float(label.get_slice("|", 1).to_int()) + 0.5) * CHUNK)
		var near_wall := label.get_slice("|", 2) == "near"
		var shadow_reach := 75.0 if piece.begins_with("cliff") else 25.0
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not tree and near_wall and centre <= shadow_reach else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.gi_mode = GeometryInstance3D.GI_MODE_STATIC if not tree and centre <= 75.0 else GeometryInstance3D.GI_MODE_DISABLED
		# Scans carry baked normal maps, so their imported LODs can switch early;
		# talus is a speck beyond the claim reach and drops out there.
		if not tree: group.lod_bias = 0.45
		if piece.begins_with("talus"):
			group.visibility_range_end = 170.0
			group.visibility_range_end_margin = 15.0
		add_child(group)
