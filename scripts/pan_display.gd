extends Node3D
## Result overlay follows the physical pan socket; hidden while carried.

var flecks := MultiMeshInstance3D.new()
var nugget := MeshInstance3D.new()

func _ready() -> void:
	var gold := StandardMaterial3D.new()
	gold.albedo_color = Color(1.0, 0.65, 0.12)
	gold.emission_enabled = true
	gold.emission = Color(1.0, 0.53, 0.06)
	gold.emission_energy_multiplier = 1.4
	var sphere := SphereMesh.new()
	sphere.radius = 0.004
	sphere.height = 0.008
	sphere.radial_segments = 8
	sphere.rings = 4
	flecks.multimesh = MultiMesh.new()
	flecks.multimesh.transform_format = MultiMesh.TRANSFORM_3D
	flecks.multimesh.mesh = sphere
	flecks.material_override = gold
	add_child(flecks)
	var pea := SphereMesh.new()
	pea.radius = 0.012
	pea.height = 0.024
	nugget.mesh = pea
	nugget.material_override = gold
	nugget.position = Vector3(0.04, 0.023, 0.14)
	add_child(nugget)
	clear()

func clear() -> void:
	flecks.multimesh.instance_count = 0
	nugget.hide()

func show_result(tier: int, visual_seed: int) -> void:
	clear()
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
		flecks.multimesh.set_instance_transform(index, Transform3D(Basis.IDENTITY, point))
	nugget.visible = tier == 4
