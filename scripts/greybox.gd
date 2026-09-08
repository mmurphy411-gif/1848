@tool
extends Node3D
## Unchanged procedural terrain and physics layout, with milestone 5 surfaces.

const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
const MATERIAL_COUNT := 5

func _ready() -> void:
	_build_ground()
	_build_river()
	_build_boulders()
	_build_bedrock()

func _build_ground() -> void:
	var surfaces: Array[SurfaceTool] = []
	for index in MATERIAL_COUNT:
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(Assets.terrain())
		surfaces.append(surface)
	# Strips follow the bend and waterline, avoiding sawtooth intersections.
	var columns := _columns()
	for column in columns.size() - 1:
		var x: float = columns[column]
		var next_x: float = columns[column + 1]
		var left := _cross_section(x)
		var right := _cross_section(next_x)
		for row in left.size() - 1:
			var a := Vector3(x, Layout.height_at(x, left[row]), left[row])
			var b := Vector3(next_x, Layout.height_at(next_x, right[row]), right[row])
			var c := Vector3(x, Layout.height_at(x, left[row + 1]), left[row + 1])
			var d := Vector3(next_x, Layout.height_at(next_x, right[row + 1]), right[row + 1])
			_triangle(surfaces, a, b, c)
			_triangle(surfaces, b, d, c)
	var ground := MeshInstance3D.new()
	ground.name = "CanyonAndGravelBar"
	var mesh := ArrayMesh.new()
	for surface in surfaces:
		surface.index()
		surface.generate_normals()
		surface.commit(mesh)
	ground.mesh = mesh
	ground.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	add_child(ground)
	ground.create_trimesh_collision()

func _cross_section(x: float) -> PackedFloat32Array:
	var section := PackedFloat32Array()
	for offset in [-720.0, -600.0, -450.0, -300.0, -200.0, -140.0, -110.0, -90.0, -80.0, -72.0, -64.0, -56.0, -52.0, -48.0, -44.0, -40.0, -36.0, -32.0, -28.0, -27.27619, -25.0, -20.0, -12.0, -5.0, -4.0, -3.0, -2.333333, -2.0, -0.666667, 0.0]:
		section.append(Layout.canyon_shore_z(x) + offset - Layout.canyon_far_offset(x) * smoothstep(5.0, 25.0, -offset))
	# Exact material boundaries keep sand and wet gravel from zigzagging
	# across alternating triangles, including where the bar tapers away.
	var width := Layout.canyon_width_at(x)
	section.append(Layout.canyon_shore_z(x) + minf(1.5, width))
	section.append(Layout.canyon_shore_z(x) + minf(3.0, width))
	for step in range(1, 18):
		section.append(Layout.canyon_shore_z(x) + minf(3.0, width) + maxf(width - 3.0, 0) * step / 17.0)
	for offset in [2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0, 16.0, 18.0, 20.0, 24.0, 28.0, 34.0, 40.0, 52.0, 64.0, 80.0, 110.0, 140.0, 200.0, 300.0, 450.0, 600.0, 720.0]:
		section.append(Layout.canyon_shore_z(x) + Layout.canyon_width_at(x) + offset)
	return section

func _columns() -> PackedFloat32Array:
	var columns := PackedFloat32Array()
	for x in range(-710, -110, 20):
		columns.append(x)
	for x in range(-110, 111, 2):
		columns.append(x)
	for x in range(130, 711, 20):
		columns.append(x)
	return columns

func _triangle(surfaces: Array[SurfaceTool], a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).length_squared() < 0.000001:
		return
	var center := (a + b + c) / 3.0
	var inland := center.z - Layout.canyon_shore_z(center.x)
	var kind := 0
	if inland > Layout.canyon_width_at(center.x) + 0.1 or inland < -27.0 - Layout.canyon_far_offset(center.x):
		kind = 3
	elif center.y < -0.3:
		kind = 4
	elif inland < 1.5:
		kind = 2
	elif inland < 3.0:
		kind = 1
	var surface := surfaces[kind]
	var color := Color(float(kind) / 4.0, 0, 0, 1)
	surface.set_color(color)
	for point in [a, b, c]:
		surface.add_vertex(point)

func _build_river() -> void:
	var river: Area3D = $River
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := _columns()
	for column in columns.size() - 1:
		var x: float = columns[column]
		var next_x: float = columns[column + 1]
		var a := Vector3(x, 0, Layout.canyon_shore_z(x) - 0.666667)
		var b := Vector3(next_x, 0, Layout.canyon_shore_z(next_x) - 0.666667)
		var c := Vector3(x, 0, Layout.canyon_shore_z(x) - 27.27619 - Layout.canyon_far_offset(x))
		var d := Vector3(next_x, 0, Layout.canyon_shore_z(next_x) - 27.27619 - Layout.canyon_far_offset(next_x))
		var steps := ceili(maxf(a.distance_to(c), b.distance_to(d)))
		for row in steps:
			var t0 := float(row) / steps
			var t1 := float(row + 1) / steps
			for point in [a.lerp(c, t0), a.lerp(c, t1), b.lerp(d, t0), b.lerp(d, t0), a.lerp(c, t1), b.lerp(d, t1)]:
				var across := inverse_lerp(Layout.canyon_shore_z(point.x) - 0.666667, Layout.canyon_shore_z(point.x) - 27.27619 - Layout.canyon_far_offset(point.x), point.z)
				var flow := Vector2(1, 0.015 * clampf(point.x, -42, 42)).normalized()
				var speed := 0.2 + 0.8 * sin(PI * clampf(across, 0, 1))
				surface.set_color(Color(flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, speed, clampf(-Layout.height_at(point.x, point.z) / 5.0, 0, 1)))
				surface.add_vertex(point)
		var volume := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array([a, b, c, d])
		for point in [a, b, c, d]:
			points.append(point + Vector3(0, -6, 0))
		shape.points = points
		volume.shape = shape
		river.add_child(volume)
	surface.index()
	surface.generate_normals()
	var water := MeshInstance3D.new()
	water.name = "WaterSurface"
	# Exclude the screen-reading water from its own reflection capture.
	water.layers = 8
	water.mesh = surface.commit()
	water.set_script(preload("res://scripts/water_surface.gd"))
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	river.add_child(water)
	var probe := ReflectionProbe.new()
	probe.name = "RiverReflection"
	probe.position = Vector3(0, 4, -12)
	probe.size = Vector3(110, 24, 50)
	probe.origin_offset = Vector3(0, 2, 0)
	probe.update_mode = ReflectionProbe.UPDATE_ONCE
	probe.interior = false
	probe.box_projection = true
	probe.cull_mask = 1
	probe.max_distance = 250
	add_child(probe)

func _build_boulders() -> void:
	var material := Assets.rock()
	for index in Layout.BOULDERS.size():
		var data: Vector4 = Layout.BOULDERS[index]
		var rock := MeshInstance3D.new()
		rock.name = "Boulder%02d" % (index + 1)
		var mesh := Assets.mesh("res://assets/boulders/boulder_%02d.glb" % (index + 1))
		# Bake dimensions into the mesh so physics shapes have unit scale.
		var source := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
		var basis := Basis(Vector3.UP, index * 1.71).scaled(Vector3(data.z, data.w, data.z))
		var radius := 0.0
		for i in vertices.size():
			vertices[i] = basis * vertices[i]
			normals[i] = (basis.inverse().transposed() * normals[i]).normalized()
			radius = maxf(radius, maxf(absf(vertices[i].x), absf(vertices[i].z)))
		for i in vertices.size():
			vertices[i].x *= data.z / radius
			vertices[i].z *= data.z / radius
			normals[i] = (normals[i] / Vector3(data.z / radius, 1, data.z / radius)).normalized()
		source[Mesh.ARRAY_VERTEX] = vertices
		source[Mesh.ARRAY_NORMAL] = normals
		var baked := ArrayMesh.new()
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source)
		rock.mesh = baked
		rock.material_override = material
		rock.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		rock.position = Vector3(data.x, Layout.height_at(data.x, data.y) + data.w * 0.35, data.y)
		add_child(rock)
		rock.create_convex_collision(true, true)

func _build_bedrock() -> void:
	for index in Layout.BEDROCK.size():
		var data: Vector4 = Layout.BEDROCK[index]
		var slab := MeshInstance3D.new()
		slab.name = "Bedrock%02d" % (index + 1)
		var source := Assets.mesh("res://assets/bedrock/ledge_%02d.glb" % (index + 1)).surface_get_arrays(0)
		var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		for i in vertices.size(): vertices[i] *= Vector3(data.z, 1, data.w)
		source[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source)
		slab.mesh = mesh
		slab.material_override = Assets.rock("bedrock", 2.0)
		slab.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		slab.position = Vector3(data.x, Layout.height_at(data.x, data.y) - 0.025, data.y)
		# Match the shallow gravel slope so only 3.5 cm of the slab shows.
		var normal := Vector3(0.015 * data.x * 0.18, 1.0, -0.18).normalized()
		slab.quaternion = Quaternion(Vector3.UP, normal)
		add_child(slab)
		slab.create_trimesh_collision()
