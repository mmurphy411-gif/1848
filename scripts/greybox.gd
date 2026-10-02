@tool
extends Node3D
## Unchanged procedural terrain and physics layout, with milestone 5 surfaces.

const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
const ScanRocks = preload("res://scripts/scan_rocks.gd")
const Canyon = preload("res://scripts/canyon.gd")
const MATERIAL_COUNT := 5
var river_level := INF

func _ready() -> void:
	_build_ground()
	_build_river()
	_build_boulders()
	_build_bedrock()
	_build_cliff_boulders()
	if not Engine.is_editor_hint(): get_node("/root/GameState").changed.connect(_sync_river)
	_sync_river()

func _sync_river() -> void:
	if not is_inside_tree(): return
	var level: float = $River.water_level()
	if is_equal_approx(level,river_level): return
	river_level=level
	$River.position.y=level
	_build_river(level)
	Assets.set_water_level(level)
	ScanRocks.set_water_level(level)

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
	# Preserve the original collision triangles; only the wall's render mesh
	# gains outcrops. The playable apron and analytical height function stay put.
	# Beyond |x| = Canyon.BEND_START the render mesh also bends and gains ridge
	# crests (scripts/canyon.gd); triangles are classified on unbent positions.
	# That bent reach is a separate mesh that casts no shadow and stays out of GI:
	# its ridges stand across the low morning, evening and moon light, which must
	# keep reaching the bar as it did when the valley ran out straight.
	var visual_sets: Array = []
	for set_index in 2:
		var visual_surfaces: Array[SurfaceTool] = []
		for i in MATERIAL_COUNT + 1:
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surface.set_material(Assets.terrain() if i < MATERIAL_COUNT else ridge_forest())
			visual_surfaces.append(surface)
		visual_sets.append(visual_surfaces)
	visual_columns.clear()
	visual_x = PackedFloat32Array()
	visual_z.clear()
	var analytic_columns: Array[PackedVector3Array] = []
	for x in columns:
		var points := _visual_column(x)
		analytic_columns.append(points[0])
		visual_columns.append(points[1])
	for column in columns.size()-1:
		var left: PackedVector3Array = analytic_columns[column]
		var right: PackedVector3Array = analytic_columns[column+1]
		var left_visual := visual_columns[column]
		var right_visual := visual_columns[column+1]
		var visual_surfaces: Array[SurfaceTool] = visual_sets[1 if absf(columns[column] + columns[column+1]) * 0.5 > Canyon.BEND_START else 0]
		for row in left.size()-1:
			_visual_triangle(visual_surfaces,[left[row],right[row],left[row+1]],[left_visual[row],right_visual[row],left_visual[row+1]])
			_visual_triangle(visual_surfaces,[right[row],right[row+1],left[row+1]],[right_visual[row],right_visual[row+1],left_visual[row+1]])
	ground.mesh = _commit_surfaces(visual_sets[0])
	var reach := MeshInstance3D.new()
	reach.name = "CanyonReach"
	reach.mesh = _commit_surfaces(visual_sets[1])
	reach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	reach.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	add_child(reach)

## Surfaces in material order; trailing empty ones are left out.
func _commit_surfaces(surfaces: Array[SurfaceTool]) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var last := surfaces.size() - 1
	while last > 0 and not surfaces[last].has_meta("used"): last -= 1
	for i in last + 1:
		surfaces[i].index()
		surfaces[i].generate_normals()
		surfaces[i].commit(mesh)
	return mesh

## Rows beyond the top cliff band. The claim reach keeps the original COARSE rows (the
## extra rows are interpolated on it); the bent reach samples its crests on all of them.
const COARSE := [4.0,8.0,16.0,32.0,64.0,100.0,150.0,250.0,400.0,720.0]
const FINE := [4.0,8.0,16.0,24.0,32.0,44.0,56.0,64.0,80.0,90.0,100.0,115.0,130.0,150.0,170.0,190.0,210.0,230.0,250.0,270.0,290.0,310.0,330.0,350.0,370.0,400.0,450.0,520.0,600.0,720.0]
## Render points per column, the same rows for every column (strip triangulation).
var visual_columns: Array[PackedVector3Array] = []
var visual_x := PackedFloat32Array()
var visual_z: Array[PackedFloat32Array] = []

## [analytical points after wall_point(), render points] for one column.
func _visual_column(x: float) -> Array[PackedVector3Array]:
	var rows := _visual_section(x)
	var analytic := PackedVector3Array()
	var rendered := PackedVector3Array()
	analytic.resize(rows.size())
	rendered.resize(rows.size())
	# Both row lists ascend in z and share every coarse row exactly.
	var bent := Canyon.reach(x) > 0.0
	var coarse_rows := PackedFloat32Array() if bent else _visual_section(x, false)
	var coarse_points := PackedVector3Array()
	for z in coarse_rows: coarse_points.append(wall_point(Vector3(x, Layout.height_at(x, z), z)))
	var j := 0
	for i in rows.size():
		var z: float = rows[i]
		var p: Vector3
		if bent:
			p = wall_point(Vector3(x, Layout.height_at(x, z), z))
		else:
			while j < coarse_rows.size() - 2 and coarse_rows[j + 1] <= z: j += 1
			var a: float = coarse_rows[j]
			var b: float = coarse_rows[j + 1]
			p = coarse_points[j] if z <= a else (coarse_points[j + 1] if z >= b else coarse_points[j].lerp(coarse_points[j + 1], (z - a) / (b - a)))
		analytic[i] = p
		rendered[i] = Canyon.visual_point(x, z, p)
	return [analytic, rendered]

func _visual_triangle(surfaces: Array[SurfaceTool], analytic: Array, rendered: Array) -> void:
	var a: Vector3 = rendered[0]
	var b: Vector3 = rendered[1]
	var c: Vector3 = rendered[2]
	if (b - a).cross(c - a).length_squared() < 0.000001:
		return
	var center: Vector3 = (analytic[0] + analytic[1] + analytic[2]) / 3.0
	var kind := _kind(center)
	if kind == 3 and Canyon.reach(center.x) > 25.0:
		kind = MATERIAL_COUNT
	var surface := surfaces[kind]
	surface.set_meta("used", true)
	surface.set_color(Color(float(mini(kind, 3)) / 4.0, 0, 0, 1))
	for point in [a, b, c]:
		surface.add_vertex(point)

## Forested ridges of the bent reach, shaded as canopy rather than rock.
static func ridge_forest() -> ShaderMaterial:
	if Assets.materials.has("ridge_forest"): return Assets.materials.ridge_forest
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/ridge_forest.gdshader")
	Assets.materials.ridge_forest = result
	return result

## Render-surface height and normal at a render-space (x, z): Vector4(normal, y).
## Seats cliff pieces, talus and ridge trees on the visual walls (wall_point noise,
## bend and crests included). Falls back to the analytical height off the mesh.
func visual_surface(x: float, z: float) -> Vector4:
	if visual_x.is_empty():
		visual_x = _columns()
		for points in visual_columns:
			var zs := PackedFloat32Array()
			for p in points: zs.append(p.z)
			visual_z.append(zs)
	var column := clampi(visual_x.bsearch(x) - 1, 0, visual_x.size() - 2)
	var left := visual_columns[column]
	var right := visual_columns[column + 1]
	# Rows ascend in z (wall_point noise can fold a few), so search a window first.
	var a := visual_z[column].bsearch(z)
	var b := visual_z[column + 1].bsearch(z)
	var rows := left.size() - 1
	for window in [Vector2i(maxi(mini(a, b) - 5, 0), mini(maxi(a, b) + 5, rows)), Vector2i(0, rows)]:
		for row in range(window.x, window.y):
			if z < minf(minf(left[row].z, right[row].z), minf(left[row + 1].z, right[row + 1].z)) - 3.0: continue
			if z > maxf(maxf(left[row].z, right[row].z), maxf(left[row + 1].z, right[row + 1].z)) + 3.0: continue
			for triangle in [[left[row], right[row], left[row + 1]], [right[row], right[row + 1], left[row + 1]]]:
				var hit = Geometry3D.ray_intersects_triangle(Vector3(x, 2000, z), Vector3.DOWN, triangle[0], triangle[1], triangle[2])
				if hit != null:
					var normal: Vector3 = (triangle[2] - triangle[0]).cross(triangle[1] - triangle[0]).normalized()
					if normal.y < 0.0: normal = -normal
					return Vector4(normal.x, normal.y, normal.z, hit.y)
	return Vector4(0, 1, 0, Layout.height_at(x, z))

## Hook for the river's WaterSurface vertices only (never its collision volumes):
## the same narrowing and bend as the canyon floor beyond |x| = Canyon.BEND_START.
static func visual_bend(p: Vector3) -> Vector3:
	return Canyon.visual_point(p.x, p.z, p)

func _visual_section(x: float, fine := true) -> PackedFloat32Array:
	var result := PackedFloat32Array()
	var shore := Layout.canyon_shore_z(x)
	var back := shore+Layout.canyon_width_at(x)
	var far_shore := shore-27.27619-Layout.canyon_far_offset(x)
	for far in [true,false]:
		var distances: Array[float] = [0,2,3,4,5]
		var apron := 8.0+2.0*sin(x*.055)
		var band := (7.0 if far else 5.0)+2.0*sin(x*.04)
		if far: band*=1.0-.55*exp(-pow((x-64.0)/22.0,2.0))
		distances.append(apron)
		var edge := apron
		for i in (3 if far else 2):
			for f in [.25,.5,.75,.98,1.0]: distances.append(edge+band*f)
			edge+=band
			if i<(2 if far else 1):
				for f in [.08,1.0,2.8,3.0]: distances.append(edge+f)
				edge+=3.0
		for d in (FINE if fine else COARSE): distances.append(edge+d)
		if far:
			distances.reverse()
			for d in distances: result.append(far_shore-d)
			var original := _cross_section(x)
			for i in range(19,49): result.append(original[i])
		else:
			for d in distances: result.append(back+d)
	return result

static var _wall_noise: FastNoiseLite

static func wall_point(p: Vector3) -> Vector3:
	var shore := Layout.canyon_shore_z(p.x)
	var far := p.z < shore - 27.27619 - Layout.canyon_far_offset(p.x)
	var distance_from_foot := shore - 27.27619 - Layout.canyon_far_offset(p.x) - p.z if far else p.z - shore - Layout.canyon_width_at(p.x)
	if distance_from_foot <= 3: return p
	if _wall_noise == null:
		_wall_noise = FastNoiseLite.new()
		_wall_noise.seed = 184806
		_wall_noise.frequency = .16
		_wall_noise.fractal_octaves = 3
	var n := _wall_noise
	var normal := Vector3(Layout.height_at(p.x-.25,p.z)-Layout.height_at(p.x+.25,p.z),.5,Layout.height_at(p.x,p.z-.25)-Layout.height_at(p.x,p.z+.25)).normalized()
	var apron := 8.0 + 2.0*sin(p.x*.055)
	var band := (7.0 if far else 5.0)+2.0*sin(p.x*.04)
	if far: band *= 1.0-.55*exp(-pow((p.x-64.0)/22.0,2.0))
	var phase := fposmod(maxf(0,distance_from_foot-apron),band+3.0)
	var ledge := smoothstep(band-.7,band,phase)*(1.0-smoothstep(band,band+.25,phase))
	var amplitude := lerpf(.5,2.5,smoothstep(apron,apron+band,distance_from_foot))
	var displacement := clampf(n.get_noise_3d(p.x,p.y*.7,p.z)*1.4+ledge,-1,1)*amplitude
	return p+normal*displacement*smoothstep(3.0,6.0,distance_from_foot)

func _build_cliff_boulders() -> void:
	var group := Node3D.new()
	group.name = "CliffBoulders"
	add_child(group)
	var random := RandomNumberGenerator.new()
	random.seed = 184806
	# Stage 2: the 40 boulder-mesh blobs are no longer drawn; scanned talus from
	# assets/cliffs/ (canyon_dressing.gd) replaces them. Collision is frozen, so the
	# draw sequence is replayed and the 10 back-wall blobs keep their colliders: the
	# same transforms, and the convex hulls their Stage 0 boulder meshes produced
	# (create_convex_shape(true, true)), stored in blob_colliders.tres so they no
	# longer depend on assets/boulders/, which Stage 3 replaced.
	var hulls: Dictionary = load("res://assets/cliffs/blob_colliders.tres").get_meta("hulls")
	var colliders: Array = []
	for i in 40:
		var x := random.randf_range(-100,100)
		var far := i % 2 == 0
		var z := Layout.canyon_shore_z(x)-27.27619-Layout.canyon_far_offset(x)-random.randf_range(3,8) if far else Layout.canyon_shore_z(x)+Layout.canyon_width_at(x)+random.randf_range(3,8)
		if absf(z-Layout.canyon_shore_z(x))<12: continue
		var size := random.randf_range(2,5)
		var stretch := random.randf_range(.8,1.3)
		var yaw := random.randf()*TAU
		if absf(z-Layout.back_z(x))>=20: continue
		var rock := Node3D.new()
		rock.name = "CliffRock%02d" % i
		rock.scale = Vector3(size,size*stretch,size)
		rock.rotation.y = yaw
		rock.position = Vector3(x,Layout.height_at(x,z)-size*.35,z)
		group.add_child(rock)
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		shape.shape = ConvexPolygonShape3D.new()
		shape.shape.points = hulls[i]
		body.add_child(shape, true)
		rock.add_child(body, true)
		colliders.append({"position": rock.position, "size": size, "stretch": stretch})
	var dressing := Node3D.new()
	dressing.name = "CanyonDressing"
	dressing.set_script(preload("res://scripts/canyon_dressing.gd"))
	add_child(dressing)
	dressing.build(self, colliders)

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
	var kind := _kind((a + b + c) / 3.0)
	var surface := surfaces[kind]
	var color := Color(float(kind) / 4.0, 0, 0, 1)
	surface.set_color(color)
	for point in [a, b, c]:
		surface.add_vertex(point)

func _kind(center: Vector3) -> int:
	var inland := center.z - Layout.canyon_shore_z(center.x)
	if inland > Layout.canyon_width_at(center.x) + 0.1 or inland < -27.0 - Layout.canyon_far_offset(center.x):
		return 3
	if center.y < -0.3:
		return 4
	if inland < 1.5:
		return 2
	if inland < 3.0:
		return 1
	return 0

func _build_river(level := 0.0) -> void:
	var river: Area3D = $River
	for child in river.get_children():
		if child is CollisionShape3D:
			river.remove_child(child);child.queue_free()
	var model = preload("res://scripts/river_model.gd")
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var broken := _broken_water_field(level)
	var columns := _columns()
	for column in columns.size() - 1:
		var x: float = columns[column]
		var next_x: float = columns[column + 1]
		var a := Vector3(x, 0, model.shore_z(x,level))
		var b := Vector3(next_x, 0, model.shore_z(next_x,level))
		var c := Vector3(x, 0, model.far_z(x,level))
		var d := Vector3(next_x, 0, model.far_z(next_x,level))
		var steps := ceili(maxf(a.distance_to(c), b.distance_to(d)))
		for row in steps:
			var t0 := float(row) / steps
			var t1 := float(row + 1) / steps
			for point in [a.lerp(c, t0), a.lerp(c, t1), b.lerp(d, t0), b.lerp(d, t0), a.lerp(c, t1), b.lerp(d, t1)]:
				var across := inverse_lerp(model.shore_z(point.x,level),model.far_z(point.x,level),point.z)
				var flow := Vector2(1, 0.015 * clampf(point.x, -42, 42)).normalized()
				var speed := 0.2 + 0.8 * sin(PI * clampf(across, 0, 1))
				surface.set_color(Color(flow.x * 0.5 + 0.5, flow.y * 0.5 + 0.5, speed, clampf((level-Layout.height_at(point.x, point.z)) / 5.0, 0, 1)))
				surface.set_uv(broken.call(point, across))
				surface.add_vertex(visual_bend(point)) # S2-canyon hook: render-only bend beyond |x| = 160
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
	var existing := river.get_node_or_null("WaterSurface")
	if existing:
		existing.mesh=surface.commit()
		return
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

## Visual-only broken water, baked per vertex into the water mesh UV: x is riffle
## strength, y the shear-line wake trailing a bar boulder or bedrock lip that stands
## in the current at this level. Riffles sit beyond the claim, under the downstream
## saddle and above the bar; the bed and every depth stay as Layout defines them.
## Returns a cached lookup (point, across 0 near .. 1 far bank) -> Vector2.
func _broken_water_field(level: float) -> Callable:
	var model = preload("res://scripts/river_model.gd")
	var noise := FastNoiseLite.new()
	noise.seed = 184811
	noise.frequency = 0.07
	noise.fractal_octaves = 2
	# x, z, footprint radius, strength; only obstacles reaching into the current.
	var obstacles: Array[Vector4] = []
	for b in Layout.BOULDERS:
		if b.y - b.z < model.shore_z(b.x, level) - 0.3:
			obstacles.append(Vector4(b.x, b.y, b.z, 1.0))
	for slab in Layout.BEDROCK:
		var top: float = Layout.height_at(slab.x, slab.y) + 0.01
		if top < level and level - top < 0.6 and slab.y < model.shore_z(slab.x, level):
			obstacles.append(Vector4(slab.x, slab.y, slab.z * 0.5, 0.45))
	var cache := {}
	return func(point: Vector3, across: float) -> Vector2:
		var key := Vector2(point.x, point.z)
		if cache.has(key): return cache[key]
		var riffle := 0.0
		# Two riffles, skewed across the channel and broken up along their crests.
		for zone in [Vector3(66.0, 9.0, 0.11), Vector3(-55.0, 8.0, -0.09)]:
			var centre: float = zone.x + 6.0 * sin(point.z * zone.z) + (point.z + 15.0) * 0.25
			var band := 1.0 - smoothstep(zone.y * 0.4, zone.y, absf(point.x - centre))
			if band <= 0.0: continue
			var lanes := smoothstep(0.04, 0.3, across) * (1.0 - smoothstep(0.86, 0.99, across))
			riffle = maxf(riffle, band * lanes * clampf(0.55 + 0.9 * noise.get_noise_2d(point.x, point.z * 1.7), 0.0, 1.0))
		var wake := 0.0
		for o in obstacles:
			var downstream := point.x - o.x
			if downstream < -o.z or downstream > o.z * 9.0: continue
			var lateral := absf(point.z - o.y)
			# Shear lines leave the rock's flanks and spread slowly downstream.
			var edge := o.z * 0.82 + maxf(downstream, 0.0) * 0.08
			var width := 0.45 + maxf(downstream, 0.0) * 0.06
			var line := exp(-pow((lateral - edge) / width, 2.0))
			var fade := exp(-maxf(downstream - o.z * 0.5, 0.0) / (o.z * 2.6))
			wake = maxf(wake, o.w * line * fade * smoothstep(-o.z, -o.z * 0.4, downstream))
		var value := Vector2(snappedf(riffle, 0.001), snappedf(clampf(wake, 0.0, 1.0), 0.001))
		cache[key] = value
		return value

func _build_boulders() -> void:
	# Normalised granite and quartz scans (tools/art/intake_rocks.py). Dimensions are
	# baked into each mesh so physics shapes have unit scale; the footprint radius is
	# exact and the base is buried below the lowest ground under it.
	for index in Layout.BOULDERS.size():
		var data: Vector4 = Layout.BOULDERS[index]
		var look: Array = ScanRocks.BAR_LOOK[index]
		var rock := MeshInstance3D.new()
		rock.name = "Boulder%02d" % (index + 1)
		rock.mesh = ScanRocks.fit_bar_boulder(index)
		rock.material_override = ScanRocks.material(ScanRocks.BOULDER_PATH % (index + 1), look[1], look[2])
		rock.gi_mode = GeometryInstance3D.GI_MODE_STATIC
		rock.position = Vector3(data.x, Layout.height_at(data.x, data.y), data.y)
		add_child(rock)
		rock.create_convex_collision(true, true)
	var vegetation := get_parent().get_node_or_null("Vegetation") if get_parent() else null
	ScanRocks.build_margin(self, vegetation.placements.get("black_oak", []) if vegetation else [])

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
