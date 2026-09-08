extends Node3D
## Result overlay follows the physical pan socket; hidden while carried.

var flecks := MultiMeshInstance3D.new()
var nugget := MeshInstance3D.new()
var concentrate := MeshInstance3D.new()

func _ready() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.78, 0.28)
	gold.metallic = .72
	gold.roughness = .3
	gold.vertex_color_use_as_albedo = true
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.71, 0.19)
	gold.emission_energy_multiplier = .22
	var sphere := SphereMesh.new()
	sphere.radius = 0.004
	sphere.height = 0.008
	sphere.radial_segments = 8
	sphere.rings = 4
	flecks.multimesh = MultiMesh.new()
	flecks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	flecks.multimesh.use_colors = true
	flecks.multimesh.mesh = sphere
	flecks.material_override = gold
	add_child(flecks)
	var pea := SphereMesh.new()
	pea.radius = 0.012
	pea.height = 0.024
	pea.radial_segments = 12
	pea.rings = 6
	var arrays := pea.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var p := vertices[i]
		vertices[i] *= 1.0+.16*sin(p.x*610+p.y*290)+.09*cos(p.z*540-p.y*410)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var lump := ArrayMesh.new()
	lump.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	nugget.mesh = lump
	nugget.material_override = gold
	nugget.position = Vector3(0.04, 0.023, 0.14)
	add_child(nugget)
	var sand := CylinderMesh.new()
	sand.top_radius = .153
	sand.bottom_radius = .153
	sand.height = .001
	sand.radial_segments = 64
	concentrate.name = "DarkConcentrate"
	concentrate.mesh = sand
	concentrate.position.y = .0115
	var sand_material := ShaderMaterial.new()
	sand_material.shader = preload("res://shaders/pan_concentrate.gdshader")
	concentrate.material_override = sand_material
	add_child(concentrate)
	clear()

func clear() -> void:
	flecks.multimesh.instance_count = 0
	nugget.hide()
	concentrate.hide()

func show_result(tier: int, visual_seed: int) -> void:
	clear()
	concentrate.show()
	var rng := RandomNumberGenerator.new()
	rng.seed = visual_seed # Cosmetic randomness never consumes the yield RNG.
	var counts := [0, rng.randi_range(2, 3), rng.randi_range(12, 20), rng.randi_range(40, 60)]
	var count: int = counts[mini(tier, 3)]
	flecks.multimesh.instance_count = count
	for index in count:
		var angle := rng.randf_range(-1.05, 1.05)
		var radius := rng.randf_range(0.145, 0.163)
		if tier == 2:
			angle = lerpf(-1.05, 1.05, float(index) / maxf(count - 1, 1)) + rng.randf_range(-0.025, 0.025)
			radius = rng.randf_range(0.153, 0.16)
		if tier == 1:
			angle = rng.randf_range(-PI, PI)
			radius = rng.randf_range(0.05, 0.16)
		# Local +Z points back toward the miner: the low crease is this arc.
		var point := Vector3(sin(angle) * radius, 0.014, cos(angle) * radius)
		var scale := Vector3(rng.randf_range(1.1,1.9),rng.randf_range(.12,.25),rng.randf_range(.45,.85))
		# Flakes lie flat; a few thicker grains interrupt a good crescent.
		if tier>=3 and index%7==0: scale.y=.65
		var basis := Basis(Vector3.UP,angle+rng.randf_range(-.5,.5)).scaled_local(scale)
		flecks.multimesh.set_instance_transform(index, Transform3D(basis, point))
		flecks.multimesh.set_instance_color(index,Color(1,rng.randf_range(.8,1),rng.randf_range(.65,1)))
	nugget.rotation = Vector3(.15,rng.randf()*TAU,-.12)
	nugget.visible = tier == 4
