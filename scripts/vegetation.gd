@tool
extends Node3D
## Seeded placement samples the unchanged terrain. All positions are meters.
const Layout = preload("res://scripts/claim_layout.gd")
const Assets = preload("res://scripts/asset_library.gd")
const SPECIES := ["ponderosa", "incense_cedar", "douglas_fir", "black_oak"]
## Brown-grey bark hints; the bark itself is scanned (Assets.plant, Stage 4).
const BARK := [Color(.42,.30,.22), Color(.40,.26,.19), Color(.33,.28,.24), Color(.36,.33,.29)]
## The `season` shader global is calendar progress: day / SEASON_DAYS (June 26 = 0,
## November 5, first snow = 1). Foliage shaders turn grass gold by August and oaks yellow
## by October from it; later stages may read it too.
const SEASON_DAYS := 132.0
## Understory (Stage 4): plant -> [visibility range m, chunk size m, shadows near the bar].
## Chunks are spatial MultiMeshes (one surface each); a range is measured to the chunk's
## centre, so it covers about range - 0.7 x chunk. Only chunks near the bar cast shadows.
const UNDERSTORY := {
	"grass_clump": [65.0, 48.0, false], "sedge_clump": [90.0, 64.0, false], "fern": [65.0, 48.0, false],
	"manzanita": [125.0, 64.0, true], "toyon": [125.0, 64.0, true], "deerbrush": [125.0, 64.0, true],
	"fir_sapling": [150.0, 90.0, true], "willow": [220.0, 120.0, true], "alder": [240.0, 150.0, true]}
const SHADOW_REACH := 60.0
var placements: Dictionary = {}
## Stage 4 understory and wall plants: name -> Array[Transform3D]. Kept apart from
## `placements`, whose Milestone 5 sets (trees, cobbles, oak-ring cover) carry rules tests.
var understory: Dictionary = {}
## Mesh variant of every tree placement (parallel to placements[species]).
var variants: Dictionary = {}
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
	# Mesh variants come from their own RNG, so tree and cobble positions keep rng's order.
	var variety := RandomNumberGenerator.new()
	variety.seed = 184811
	var full_forest := "--full-forest" in OS.get_cmdline_user_args()
	for i in SPECIES.size():
		var species: String = SPECIES[i]
		var kinds: int = Assets.TREE_VARIANTS[species]
		var near: Array = []
		var far: Array = []
		for v in kinds:
			near.append([]); far.append([])
		var picks := PackedInt32Array()
		var offset := variety.randi_range(0,kinds-1)
		for transform in placements[species]:
			# The ten bar oaks cycle through the meshes so every variant stands on the bar.
			var v := (picks.size()+offset)%kinds if i==3 else variety.randi_range(0,kinds-1)
			picks.append(v)
			var distant: bool = i<3 and Vector2(transform.origin.x,transform.origin.z).length()>60.0 and not full_forest
			(far[v] if distant else near[v]).append(transform)
		variants[species] = picks
		# Variants 2+ draw from `<species>_v<n>` and `<species>_v<n>_distant`.
		for v in range(1,kinds):
			if not near[v].is_empty(): _instances("%s_v%d" % [species,v+1],Assets.plant(species,BARK[i],true,false,v),near[v])
			if not far[v].is_empty(): _instances("%s_v%d_distant" % [species,v+1],Assets.plant(species,BARK[i],true,true,v),far[v])
		var near_trees: Array = near[0]
		var far_trees: Array = far[0]
		var rest: Array = far_trees.duplicate()
		for v in range(1,kinds): rest.append_array(near[v]+far[v])
		# `<species>` keeps the canonical full instance capacity for earlier placement tests;
		# visible_instance_count draws only the prefix of variant-1 near trees.
		var group := _instances(species,Assets.plant(species,BARK[i]),near_trees+rest)
		group.multimesh.visible_instance_count=near_trees.size()
		if not far_trees.is_empty():_instances(species+"_distant",Assets.plant(species,BARK[i],true,true),far_trees)
	# River cobbles: ten scans, 5-25 cm, a rock colour per instance (scripts/cobbles.gd).
	# It replays the legacy draws on rng, so the ground cover below is unchanged.
	preload("res://scripts/cobbles.gd").build(self,rng)
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
		# Stage 4: the oak-ring grass is drawn with the atlas grass clump; flowers keep their
		# procedural cards and go out of bloom over the season.
		var cover := Assets.understory("grass_clump") if i==0 else Assets.plant(names[i],tints[i],false)
		if i>0: cover.surface_get_material(0).set_shader_parameter("bloom_window",[Vector2(.12,.3),Vector2(.18,.4),Vector2(.5,.8)][i-1])
		# Cover in the camp's work area is allocated but not drawn (kept last, past the
		# visible prefix), so the fire ring and shelter stay clear.
		var camp := _camp_center()
		var shown: Array = transforms.filter(func(t): return not _in_camp(t.origin,camp))
		var hidden: Array = transforms.filter(func(t): return _in_camp(t.origin,camp))
		_instances(names[i],cover,shown+hidden,40).multimesh.visible_instance_count=shown.size()
	_build_understory(ground)
	_apply_season()
	if not Engine.is_editor_hint() and has_node("/root/GameState"):
		get_node("/root/GameState").changed.connect(_apply_season)
		get_node("/root/GameState").new_day.connect(_apply_season)

func _apply_season() -> void:
	var day := 0
	if not Engine.is_editor_hint() and has_node("/root/GameState"): day = get_node("/root/GameState").day
	RenderingServer.global_shader_parameter_set("season",clampf(day/SEASON_DAYS,0.0,1.0))

func _transform(p: Vector3, scale_value: float, tilt := 0.0) -> Transform3D:
	var basis := Basis(Vector3.UP,rng.randf()*TAU)
	if tilt>0: basis = Basis(Quaternion(Vector3.UP,Vector3.UP.lerp(normal_at(p.x,p.z),tilt).normalized()))*basis
	return Transform3D(basis.scaled(Vector3.ONE*scale_value),p)

func _instances(label: String, mesh: ArrayMesh, transforms: Array, distance_limit := 0.0) -> MultiMeshInstance3D:
	var group := MultiMeshInstance3D.new()
	group.name = label
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	var tree := label.get_slice("_v",0).trim_suffix("_distant") in SPECIES
	# Trees get a per-instance tone (custom data x) from their position, not from any RNG.
	multi.use_custom_data = tree
	multi.instance_count = transforms.size()
	for i in transforms.size():
		multi.set_instance_transform(i,transforms[i])
		if tree:
			var o: Vector3 = transforms[i].origin
			multi.set_instance_custom_data(i,Color(fposmod(sin(o.x*12.9898+o.z*78.233)*43758.547,1.0)*.4-.2,fposmod(sin(o.x*39.346+o.z*11.135)*24634.634,1.0)-.5,0,0))
	group.multimesh = multi
	group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if tree: group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
	if label in ["grass","lupine","poppy","yarrow"]: group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if label.begins_with("black_oak"): group.lod_bias=4.0
	group.gi_mode = GeometryInstance3D.GI_MODE_STATIC
	group.visibility_range_end = distance_limit
	group.visibility_range_end_margin = 5 if distance_limit>0 else 0
	group.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	add_child(group)
	return group

# ---------------------------------------------------------------- Stage 4 understory

## Camp centre as scripts/camp.gd derives it: 3 m riverward of the black oak nearest x = 0.
func _camp_center() -> Vector3:
	var best := INF
	var oak := Vector3.ZERO
	for transform in placements.black_oak:
		var p: Vector3 = transform.origin
		if p.z-Layout.shore_z(p.x)>=10 and absf(p.x)<best:
			best=absf(p.x);oak=p
	return Vector3(oak.x,0,oak.z-3)

## The fire, shelter, crate and the crew's bunk tents (crew.gd BUNK_SPOTS) stay clear.
static func _in_camp(p: Vector3, camp: Vector3) -> bool:
	var d := p-camp-Vector3(3.2,0,3.6)
	return pow(d.x/10.0,2)+pow(d.z/8.0,2)<1.0

func _add(sets: Dictionary, plant: String, random: RandomNumberGenerator, p: Vector3, normal: Vector3, scale_value: float, tilt: float, timing := 0.0) -> void:
	var basis := Basis(Vector3.UP,random.randf()*TAU)
	if tilt>0: basis = Basis(Quaternion(Vector3.UP,Vector3.UP.lerp(normal,tilt).normalized()))*basis
	sets[plant][0].append(Transform3D(basis.scaled(Vector3.ONE*scale_value),p))
	# Custom data: x tone, y season timing (negative stays green longer), z warm hue.
	sets[plant][1].append(Color(random.randf_range(-.12,.12),clampf(timing+random.randf_range(-.6,.6),-2.0,2.0),random.randf()*random.randf(),0))

var _visual_rows := {}
var _visual_vertices := {}

func _visual_row(ground: Node3D, column: int) -> PackedFloat32Array:
	if not _visual_rows.has(column):
		_visual_rows[column] = ground._visual_section(columns[column]) if ground.has_method("_visual_section") else sections[column]
	return _visual_rows[column]

func _visual_vertex(ground: Node3D, column: int, row: int) -> Vector3:
	var key := column*4096+row
	if not _visual_vertices.has(key):
		var x := columns[column]
		var z: float = _visual_row(ground,column)[row]
		var v := Vector3(x,Layout.height_at(x,z),z)
		_visual_vertices[key] = ground.wall_point(v) if ground.has_method("wall_point") else v
	return _visual_vertices[key]

static func _barycentric(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> Vector3:
	var v0 := b-a
	var v1 := c-a
	var v2 := p-a
	var den := v0.x*v1.y-v1.x*v0.y
	if absf(den)<1e-9: return Vector3(-1,-1,-1)
	var v := (v2.x*v1.y-v1.x*v2.y)/den
	var w := (v0.x*v2.y-v2.x*v0.y)/den
	return Vector3(1.0-v-w,v,w)

## A point on the canyon's render mesh, which greybox.gd triangulates from _columns(),
## _visual_section() and wall_point(): `d` metres from the wall foot (negative: toward the
## river) at x. Returns [point, face normal], or [] outside the grid. Plants seated here sit
## exactly on the visible ledges and benches rather than on the smoother collision wall.
func _wall(ground: Node3D, x: float, d: float, far: bool) -> Array:
	var foot := Layout.canyon_shore_z(x)-27.27619-Layout.canyon_far_offset(x) if far else Layout.canyon_shore_z(x)+Layout.canyon_width_at(x)
	var z := foot-d if far else foot+d
	var c := clampi(columns.bsearch(x)-1,0,columns.size()-2)
	var x0 := columns[c]
	var x1 := columns[c+1]
	var left := _visual_row(ground,c)
	var right := _visual_row(ground,c+1)
	if left.size()!=right.size(): return []
	var fx := (x-x0)/(x1-x0)
	var q := Vector2(x,z)
	for r in left.size()-1:
		if z<lerpf(left[r],right[r],fx) or z>lerpf(left[r+1],right[r+1],fx): continue
		var flat := [Vector2(x0,left[r]),Vector2(x1,right[r]),Vector2(x0,left[r+1]),Vector2(x1,right[r+1])]
		for ids in [[0,1,2],[1,3,2]]:
			var w := _barycentric(q,flat[ids[0]],flat[ids[1]],flat[ids[2]])
			if w.x<-.001 or w.y<-.001 or w.z<-.001: continue
			var corner := [_visual_vertex(ground,c,r),_visual_vertex(ground,c+1,r),_visual_vertex(ground,c,r+1),_visual_vertex(ground,c+1,r+1)]
			var a: Vector3 = corner[ids[0]]
			var b: Vector3 = corner[ids[1]]
			var cc: Vector3 = corner[ids[2]]
			var n := (cc-a).cross(b-a).normalized()
			return [a*w.x+b*w.y+cc*w.z, n if n.y>=0 else -n]
	return []

## Seeded understory with its own RNG: grass across the upper bar (denser under oaks and at
## the wall foot), ferns in oak shade, chaparral shrubs, saplings and tufts on the talus,
## ledges, benches and rims of both walls, willow, alder and sedge at the far bank and past
## the ends of the bar. No collision; shrubs stay off the playable bar and out of camp.
func _build_understory(ground: Node3D) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 184821
	var sets := {}
	for plant in UNDERSTORY: sets[plant] = [[],[]]
	var camp := _camp_center()
	var oaks: Array = []
	for t in placements.black_oak: oaks.append(t.origin)
	# Upper bar grass in patches: shade and the wall foot thicken it, shade keeps it green longer.
	var made := 0
	for attempt in 14000:
		if made>=650: break
		var x := random.randf_range(-40,40)
		var width := Layout.width_at(x)
		if width<13.0: continue
		var inland := random.randf_range(12.0,width-.3)
		var z := Layout.shore_z(x)+inland
		var shade := 0.0
		for o in oaks: shade = maxf(shade,exp(-(pow(o.x-x,2)+pow(o.z-z,2))/30.0))
		if random.randf()>.12+.6*shade+.55*smoothstep(width-9.0,width,inland): continue
		for tuft in random.randi_range(3,9):
			var a := random.randf()*TAU
			var r := sqrt(random.randf())*1.8
			var q := Vector3(x+cos(a)*r,0,z+sin(a)*r)
			if q.z-Layout.shore_z(q.x)<12 or q.z>Layout.back_z(q.x)-.3: continue
			if normal_at(q.x,q.z).y<.71 or not clear_of_boulders(q,.4) or _in_camp(q,camp): continue
			q.y = _surface(q.x,q.z).w-.03
			_add(sets,"grass_clump",random,q,normal_at(q.x,q.z),random.randf_range(.7,1.4)*(1.15-r*.2),.7,-shade*1.6)
			made += 1
	# Ferns in the deeper oak shade toward the back of the bar.
	made = 0
	for attempt in 3000:
		if made>=70: break
		var o: Vector3 = oaks[random.randi_range(0,oaks.size()-1)]
		var a := random.randf()*TAU
		var r := random.randf_range(1.2,4.5)
		var x := o.x+cos(a)*r
		var z := o.z+sin(a)*r
		var p := Vector3(x,0,z)
		if z-Layout.shore_z(x)<16 or z>Layout.back_z(x)-.3 or normal_at(x,z).y<.71 or not clear_of_boulders(p,.4) or _in_camp(p,camp): continue
		p.y = _surface(x,z).w-.02
		_add(sets,"fern",random,p,normal_at(x,z),random.randf_range(.7,1.15),.6)
		made += 1
	# Both canyon walls, seated on the render mesh: foot strip and talus apron, then ledges,
	# benches and rim. Chaparral low, saplings mostly on benches and the rim.
	var oaks_on_walls: Array = []
	for far in [false,true]:
		var shrubs := 0
		var tufts := 0
		var live_oaks := 0
		for attempt in 16000:
			if shrubs>=340 and tufts>=360 and live_oaks>=30: break
			var x := random.randf_range(-125,125)
			# Layout.canyon_wall's profile: talus apron, cliff bands split by benches, rim.
			var apron := 8.0+2.0*sin(x*.055)
			var band := (7.0 if far else 5.0)+2.0*sin(x*.04)
			if far: band *= 1.0-.55*exp(-pow((x-64.0)/22.0,2.0))
			var bands := 3 if far else 2
			var rim := apron+bands*band+(bands-1)*3.0
			var zone := random.randf()
			var d := 0.0
			if zone<.3: d = random.randf_range(-.8,apron)
			elif zone<.62:
				var k := random.randi_range(0,bands-1)
				var top := apron+(k+1)*band+k*3.0
				d = random.randf_range(top-1.2,top+(3.3 if k<bands-1 else 2.0))
			elif zone<.72: d = random.randf_range(apron,rim)
			else: d = random.randf_range(rim,rim+60.0)
			var hit := _wall(ground,x,d,far)
			if hit.is_empty(): continue
			var p: Vector3 = hit[0]
			var n: Vector3 = hit[1]
			if p.y<.3 or not clear_of_boulders(p,.6): continue
			# Benches and the upper apron hold the larger plants.
			var big := 1.0 if zone<.3 and d<apron*.5 else 1.45
			if live_oaks<30 and n.y>.74 and d>2.0 and d<rim+20.0 and random.randf()<.12:
				var spaced := true
				for o in oaks_on_walls: spaced = spaced and o.distance_to(p)>7.0
				if spaced:
					oaks_on_walls.append(p)
					live_oaks += 1
					continue
			if shrubs<340 and n.y>.62 and random.randf()<.5:
				var roll := random.randf()
				var plant := ""
				if d>apron+2.0 and roll<.24 and n.y>.75: plant = "fir_sapling"
				elif roll<.55: plant = "manzanita"
				elif roll<.78: plant = "toyon"
				else: plant = "deerbrush"
				var size := random.randf_range(.75,1.35)*big*(random.randf_range(1.0,1.9) if plant=="fir_sapling" else 1.0)
				_add(sets,plant,random,p-Vector3(0,.1,0),n,size,.3)
				shrubs += 1
			elif tufts<360 and n.y>.5:
				_add(sets,"grass_clump",random,p-Vector3(0,.03,0),n,random.randf_range(.8,1.6),.8)
				tufts += 1
				if d<12.0 and n.y>.72 and random.randf()<.18:
					_add(sets,"fern",random,p-Vector3(0,.02,0),n,random.randf_range(.7,1.1),.6,-.8)
	# Riparian: willow and alder thickets at the far wall's foot, sedge at the water.
	made = 0
	var sedges := 0
	for attempt in 6000:
		if made>=150 and sedges>=200: break
		var x := random.randf_range(-150,150)
		# Thickets come in runs along the bank.
		if sin(x*.11)+sin(x*.037+1.3)<-.4: continue
		var hit := _wall(ground,x,random.randf_range(.1,3.4),true)
		if hit.is_empty(): continue
		var p: Vector3 = hit[0]
		if p.y<.25: continue
		if made<150 and random.randf()<.45:
			var roll := random.randf()
			_add(sets,"alder" if roll<.22 else "willow",random,p-Vector3(0,.12,0),hit[1],random.randf_range(.65,1.3),.15)
			made += 1
		elif sedges<200:
			_add(sets,"sedge_clump",random,p-Vector3(0,.03,0),hit[1],random.randf_range(.8,1.4),.5,-1.5)
			sedges += 1
	# Past the ends of the bar (|x| > 46, outside the walkable claim): the near bank's strip.
	made = 0
	sedges = 0
	for attempt in 4000:
		if made>=70 and sedges>=110: break
		var x := random.randf_range(46,150)*(1 if random.randf()<.5 else -1)
		var width := Layout.canyon_width_at(x)
		var hit := _wall(ground,x,random.randf_range(-width+1.0,2.5),false)
		if hit.is_empty(): continue
		var p: Vector3 = hit[0]
		if p.y<.2: continue
		if made<70 and random.randf()<.4:
			_add(sets,"willow",random,p-Vector3(0,.12,0),hit[1],random.randf_range(.65,1.25),.15)
			made += 1
		elif sedges<110:
			_add(sets,"sedge_clump",random,p-Vector3(0,.03,0),hit[1],random.randf_range(.8,1.4),.5,-1.5)
			sedges += 1
	var parent := Node3D.new()
	parent.name = "Understory"
	add_child(parent)
	_live_oaks(parent,random,oaks_on_walls)
	for plant in UNDERSTORY:
		understory[plant] = sets[plant][0]
		if not sets[plant][0].is_empty(): _chunked(parent,plant,sets[plant][0],sets[plant][1])


## Canyon live oaks on the talus, benches and rim of both walls: the black oaks' distant
## meshes at 40-70 % size (they stand 30 m and more from the bar), darker and evergreen
## (custom-data season timing far below the autumn window). Shadows only near the bar.
func _live_oaks(parent: Node3D, random: RandomNumberGenerator, points: Array) -> void:
	var kinds: int = Assets.TREE_VARIANTS.black_oak
	var groups := {}
	understory["live_oak"] = []
	for p in points:
		var v := random.randi_range(0,kinds-1)
		var shadow: bool = Vector2(p.x,p.z).length()<SHADOW_REACH
		var key := "live_oak_v%d%s" % [v+1,"_shadow" if shadow else ""]
		if not groups.has(key): groups[key] = [v,shadow,[],[]]
		var basis := Basis(Vector3.UP,random.randf()*TAU).scaled(Vector3.ONE*random.randf_range(.4,.7))
		var t := Transform3D(basis,p-Vector3(0,.25,0))
		groups[key][2].append(t)
		groups[key][3].append(Color(random.randf_range(-.24,-.12),-9.0,0,0))
		understory.live_oak.append(t)
	var keys := groups.keys()
	keys.sort()
	for key in keys:
		var g: Array = groups[key]
		var group := MultiMeshInstance3D.new()
		group.name = key
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = Assets.plant("black_oak",BARK[3],true,true,g[0])
		multi.instance_count = g[2].size()
		for j in g[2].size():
			multi.set_instance_transform(j,g[2][j])
			multi.set_instance_custom_data(j,g[3][j])
		group.multimesh = multi
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if g[1] else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		parent.add_child(group)

## MultiMeshes per spatial cell, so frustum culling and visibility ranges work per chunk.
func _chunked(parent: Node3D, plant: String, transforms: Array, customs: Array) -> void:
	var spec: Array = UNDERSTORY[plant]
	var size: float = spec[1]
	var cells := {}
	for k in transforms.size():
		var o: Vector3 = transforms[k].origin
		var key := Vector2i(floori(o.x/size),floori(o.z/size))
		if not cells.has(key): cells[key] = []
		cells[key].append(k)
	var mesh := Assets.understory(plant)
	var keys := cells.keys()
	keys.sort()
	for key in keys:
		var group := MultiMeshInstance3D.new()
		group.name = "%s_%d_%d" % [plant,key.x,key.y]
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.use_custom_data = true
		multi.mesh = mesh
		multi.instance_count = cells[key].size()
		for j in cells[key].size():
			multi.set_instance_transform(j,transforms[cells[key][j]])
			multi.set_instance_custom_data(j,customs[cells[key][j]])
		group.multimesh = multi
		var center := Vector2((key.x+.5)*size,(key.y+.5)*size)
		var near_bar: bool = center.distance_to(Vector2(0,15))<SHADOW_REACH+size*.5
		group.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if spec[2] and near_bar else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		group.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
		group.visibility_range_end = spec[0]
		group.visibility_range_end_margin = spec[0]*.12
		group.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		parent.add_child(group)
