@tool
extends Node3D
## Deterministic blockout, also visible when the main scene is opened in the editor.

const Layout = preload("res://scripts/claim_layout.gd")

func _ready() -> void:
	_build_ground()
	_build_river()
	_build_boulders()
	_build_bedrock()

func _build_ground() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Strips follow the bend and waterline, avoiding sawtooth intersections.
	for x in range(-110, 110, 2):
		var left := _cross_section(x)
		var right := _cross_section(x + 2)
		for row in left.size() - 1:
			var a := Vector3(x, Layout.height_at(x, left[row]), left[row])
			var b := Vector3(x + 2, Layout.height_at(x + 2, right[row]), right[row])
			var c := Vector3(x, Layout.height_at(x, left[row + 1]), left[row + 1])
			var d := Vector3(x + 2, Layout.height_at(x + 2, right[row + 1]), right[row + 1])
			_triangle(surface, a, b, c)
			_triangle(surface, b, d, c)
	surface.generate_normals()
	var ground := MeshInstance3D.new()
	ground.name = "CanyonAndGravelBar"
	ground.mesh = surface.commit()
	var material := _material(Color.WHITE)
	material.vertex_color_use_as_albedo = true
	ground.material_override = material
	add_child(ground)
	ground.create_trimesh_collision()

func _cross_section(x: float) -> PackedFloat32Array:
	var section := PackedFloat32Array()
	for offset in [-72.0, -52.0, -44.0, -40.0, -36.0, -32.0, -28.0, -27.27619, -25.0, -20.0, -12.0, -5.0, -4.0, -3.0, -2.0, -0.666667, 0.0]:
		section.append(Layout.shore_z(x) + offset)
	for step in range(1, 20):
		section.append(Layout.shore_z(x) + Layout.width_at(x) * step / 19.0)
	for offset in [2.0, 4.0, 8.0, 12.0, 16.0, 20.0, 26.0, 36.0, 52.0, 72.0]:
		section.append(Layout.back_z(x) + offset)
	return section

func _triangle(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	if (b - a).cross(c - a).length_squared() < 0.000001:
		return
	var center := (a + b + c) / 3.0
	var color := Color(0.56, 0.53, 0.46)
	if center.z > Layout.back_z(center.x) + 0.4 or center.z < Layout.shore_z(center.x) - 27.0:
		color = Color(0.49, 0.51, 0.50)
	elif center.y < 0.1:
		color = Color(0.37, 0.39, 0.35)
	var variation := sin(center.x * 1.73 + center.z * 3.19) * 0.025
	surface.set_color(color.lightened(variation))
	for point in [a, b, c]:
		surface.add_vertex(point)

func _build_river() -> void:
	var river: Area3D = $River
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for x in range(-110, 110, 2):
		var a := Vector3(x, 0, Layout.shore_z(x) - 0.666667)
		var b := Vector3(x + 2, 0, Layout.shore_z(x + 2) - 0.666667)
		var c := Vector3(x, 0, Layout.shore_z(x) - 27.27619)
		var d := Vector3(x + 2, 0, Layout.shore_z(x + 2) - 27.27619)
		for point in [a, c, b, b, c, d]:
			surface.add_vertex(point)
		var volume := CollisionShape3D.new()
		var shape := ConvexPolygonShape3D.new()
		var points := PackedVector3Array([a, b, c, d])
		for point in [a, b, c, d]:
			points.append(point + Vector3(0, -6, 0))
		shape.points = points
		volume.shape = shape
		river.add_child(volume)
	surface.generate_normals()
	var water := MeshInstance3D.new()
	water.name = "WaterSurface"
	water.mesh = surface.commit()
	var material := _material(Color(0.20, 0.40, 0.39, 0.68))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.roughness = 0.35
	water.material_override = material
	water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	river.add_child(water)

func _build_boulders() -> void:
	var material := _material(Color(0.62, 0.63, 0.60))
	for index in Layout.BOULDERS.size():
		var data: Vector4 = Layout.BOULDERS[index]
		var rock := MeshInstance3D.new()
		rock.name = "Boulder%02d" % (index + 1)
		var mesh := SphereMesh.new()
		mesh.radius = 1.0
		mesh.height = 2.0
		mesh.radial_segments = 8
		mesh.rings = 3
		# Bake dimensions into the mesh so physics shapes have unit scale.
		var source := mesh.get_mesh_arrays()
		var vertices: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
		for i in vertices.size():
			vertices[i] *= Vector3(data.z, data.w, data.z * 0.78)
		source[Mesh.ARRAY_VERTEX] = vertices
		var baked := ArrayMesh.new()
		baked.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source)
		rock.mesh = baked
		rock.material_override = material
		rock.position = Vector3(data.x, Layout.height_at(data.x, data.y) + data.w * 0.35, data.y)
		rock.rotation.y = index * 1.71
		add_child(rock)
		rock.create_convex_collision(true, true)

func _build_bedrock() -> void:
	for index in Layout.BEDROCK.size():
		var data: Vector4 = Layout.BEDROCK[index]
		var slab := MeshInstance3D.new()
		slab.name = "Bedrock%02d" % (index + 1)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(data.z, 0.12, data.w)
		slab.mesh = mesh
		slab.material_override = _material(Color(0.13, 0.15, 0.15))
		slab.position = Vector3(data.x, Layout.height_at(data.x, data.y) - 0.025, data.y)
		# Match the shallow gravel slope so only 3.5 cm of the slab shows.
		var normal := Vector3(0.015 * data.x * 0.18, 1.0, -0.18).normalized()
		slab.quaternion = Quaternion(Vector3.UP, normal)
		add_child(slab)
		slab.create_trimesh_collision()

func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.95
	return material
