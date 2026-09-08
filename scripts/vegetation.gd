@tool
extends Node3D
## Seeded placement samples the unchanged terrain. All positions are meters.
const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
const SPECIES := ["ponderosa", "incense_cedar", "douglas_fir", "black_oak"]
const BARK := [Color(.37,.16,.055), Color(.22,.09,.035), Color(.15,.105,.075), Color(.12,.105,.08)]
var placements: Dictionary = {}
var rng := RandomNumberGenerator.new()
var columns := PackedFloat32Array()
var sections: Array[PackedFloat32Array] = []

func _surface(x: float,z: float) -> Vector4:
	# The visual terrain is triangulated between analytical cross-sections.
	# Seat roots on those triangles, avoiding floating trunks between benches.
	var column := clampi(columns.bsearch(x)-1,0,columns.size()-2)
	var x0 := columns[column]
	var x1 := columns[column+1]
	var left := sections[column]
	var right := sections[column+1]
	for row in left.size()-1:
		if z<minf(left[row],right[row]) or z>maxf(left[row+1],right[row+1]): continue
		var a := Vector3(x0,Layout.height_at(x0,left[row]),left[row])
		var b := Vector3(x1,Layout.height_at(x1,right[row]),right[row])
		var c := Vector3(x0,Layout.height_at(x0,left[row+1]),left[row+1])
		var d := Vector3(x1,Layout.height_at(x1,right[row+1]),right[row+1])
		for triangle in [[a,b,c],[b,d,c]]:
			var hit = Geometry3D.ray_intersects_triangle(Vector3(x,1000,z),Vector3.DOWN,triangle[0],triangle[1],triangle[2])
			if hit!=null:
				var normal: Vector3 = (triangle[2]-triangle[0]).cross(triangle[1]-triangle[0]).normalized()
				return Vector4(normal.x,normal.y,normal.z,hit.y)
	return Vector4(0,1,0,Layout.height_at(x,z))

static func normal_at(x: float, z: float) -> Vector3:
	return Vector3(Layout.height_at(x-.25,z)-Layout.height_at(x+.25,z), .5, Layout.height_at(x,z-.25)-Layout.height_at(x,z+.25)).normalized()

static func clear_of_boulders(p: Vector3, extra := 0.0) -> bool:
	for b in Layout.BOULDERS:
		if Vector2(p.x-b.x,p.z-b.y).length() < b.z+extra: return false
	return true

func _ready() -> void:
	rng.seed = 184805
	var ground: Node3D = get_parent().get_node("Greybox")
	columns = ground._columns()
	for x in columns: sections.append(ground._cross_section(x))
	for species in SPECIES: placements[species] = []
	var count := 0
	for attempt in 40000:
		if count >= 600: break
		var x := rng.randf_range(-155,155)
		var far_bank := rng.randf() < .53
		var distance_from_foot := rng.randf_range(10,135)
		var shore := Layout.canyon_shore_z(x)
		var z := shore - 27.27619 - Layout.canyon_far_offset(x) - distance_from_foot if far_bank else shore+Layout.canyon_width_at(x)+distance_from_foot
		var p := Vector3(x,Layout.height_at(x,z),z)
		if normal_at(x,z).y < cos(deg_to_rad(40)) or absf(z-Layout.shore_z(x))<12: continue
		var surface := _surface(x,z)
		if surface.y<cos(deg_to_rad(40)): continue
		p.y=surface.w-.18
		if rng.randf() > exp(-p.y/125.0): continue
		var species := "ponderosa" if p.y>45 or (far_bank and rng.randf()<.55) else ("incense_cedar" if rng.randf()<.5 else "douglas_fir")
		placements[species].append(_transform(p, rng.randf_range(.8,1.2), .06))
		count += 1
	# Broad spacing leaves the playable shore, spawn and panning lanes open.
	for x in [-25.0,-13.0,0.0,13.0,25.0]:
		for fraction in [.60,.91]:
			var z: float = Layout.shore_z(x)+Layout.width_at(x)*fraction
			var p := Vector3(x,Layout.height_at(x,z),z)
			if z-Layout.shore_z(x)<12 or not clear_of_boulders(p,1.0): continue
			var transform := _transform(p,rng.randf_range(.85,1.1))
			placements.black_oak.append(transform)
			var body := StaticBody3D.new()
			body.name = "OakTrunk%02d" % placements.black_oak.size()
			body.position = p
			body.collision_layer = 1
			body.collision_mask = 2
			var collider := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = .60 * transform.basis.get_scale().x
			shape.height = 7.0
			collider.position.y = 3.5
			collider.shape = shape
			body.add_child(collider)
			add_child(body)
	var canopies := PackedVector4Array()
	for oak in placements.black_oak: canopies.append(Vector4(oak.origin.x,oak.origin.z,0,0))
	Assets.terrain().set_shader_parameter("oak_canopies",canopies)
	for i in SPECIES.size(): _instances(SPECIES[i], Assets.plant(SPECIES[i],BARK[i]),placements[SPECIES[i]])
	for i in 3:
		var key := "cobble_%02d" % (i+1)
		placements[key] = []
	for attempt in 12000:
		if placements.cobble_01.size()+placements.cobble_02.size()+placements.cobble_03.size()>=600: break
		var x := rng.randf_range(-38,38)
		var inland := 1.5+pow(rng.randf(),1.7)*(Layout.width_at(x)-1.5)
		var z := Layout.shore_z(x)+inland
		var p := Vector3(x,Layout.height_at(x,z),z)
		if not clear_of_boulders(p,.15): continue
		p.y -= .012
		placements["cobble_%02d" % (rng.randi_range(1,3))].append(_transform(p,rng.randf_range(.025,.075)))
	for i in 3:
		var key := "cobble_%02d" % (i+1)
		var mesh := Assets.mesh("res://assets/boulders/%s.glb" % key)
		mesh.surface_set_material(0,Assets.rock("granite",.7))
		_instances(key,mesh,placements[key],60)
	var names := ["grass","lupine","poppy","yarrow"]
	var tints := [Color(.15,.29,.055),Color(.19,.16,.55),Color(.9,.25,.018),Color(.85,.85,.73)]
	for i in names.size():
		var transforms: Array = []
		for attempt in 5000:
			if transforms.size()>=(240 if i==0 else 20): break
			var oak: Transform3D = placements.black_oak[rng.randi_range(0,placements.black_oak.size()-1)]
			var p := oak.origin+Vector3(rng.randf_range(-4,4),0,rng.randf_range(-4,4))
			if Vector2(p.x-oak.origin.x,p.z-oak.origin.z).length()>4: continue
			p.y = Layout.height_at(p.x,p.z)
			if p.z-Layout.shore_z(p.x)<12 or p.z>Layout.back_z(p.x)-.2 or normal_at(p.x,p.z).y<.71 or not clear_of_boulders(p,.3): continue
			transforms.append(_transform(p,rng.randf_range(.8,1.2)))
		placements[names[i]] = transforms
		_instances(names[i],Assets.plant(names[i],tints[i],false),transforms,40)

func _transform(p: Vector3, scale_value: float, tilt := 0.0) -> Transform3D:
	var basis := Basis(Vector3.UP,rng.randf()*TAU)
	if tilt>0: basis = Basis(Quaternion(Vector3.UP,Vector3.UP.lerp(normal_at(p.x,p.z),tilt).normalized()))*basis
	return Transform3D(basis.scaled(Vector3.ONE*scale_value),p)

func _instances(label: String, mesh: ArrayMesh, transforms: Array, distance_limit := 0.0) -> void:
	var group := MultiMeshInstance3D.new()
	group.name = label
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i in transforms.size(): multi.set_instance_transform(i,transforms[i])
	group.multimesh = multi
	group.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	group.visibility_range_end = distance_limit
	group.visibility_range_end_margin = 5 if distance_limit>0 else 0
	group.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(group)
