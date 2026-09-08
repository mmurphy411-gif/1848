extends Node3D
const Layout=preload("res://scripts/claim_layout.gd")
const Cooking=preload("res://scripts/cooking.gd")
var props: Dictionary={}
var oak := Vector3.ZERO
var fire_hours := 0.0
var ember_hours := 0.0
var smoking: Dictionary={}
var smoke_hours := 0.0
var cook_hours := 0.0
var cooking_fish: Dictionary={}
var light := OmniLight3D.new()
var flame := GPUParticles3D.new()
var smoke := GPUParticles3D.new()
var fire_sound := AudioStreamPlayer3D.new()
var last_hour := 4.75
var phase := 0.0
@onready var game: Node=get_node("/root/GameState")
@onready var clock: Node=get_parent().get_node("Daylight/Clock")
func _ready() -> void:
	var best := INF
	for transform in get_parent().get_node("Vegetation").placements.black_oak:
		var p: Vector3=transform.origin
		if p.z-Layout.shore_z(p.x)>=10 and absf(p.x)<best:
			best=absf(p.x);oak=p
	position=Vector3(oak.x,Layout.height_at(oak.x,oak.z-3),oak.z-3)
	var asset := preload("res://assets/camp/camp.glb").instantiate()
	var offsets := {"FireRing":Vector3.ZERO,"LeanTo":Vector3(0,0,1.3),"Bedroll":Vector3(0,0,1.9),"Pot":Vector3(-.6,0,0),"Skillet":Vector3(1,0,-.1),"Rack":Vector3(1.7,0,.8),"Crate":Vector3(-1.1,0,1.5),"Cache":Vector3(0,2.5,3),"Driftwood":Vector3(-1.5,0,-.4)}
	for source in asset.find_children("*","MeshInstance3D",true,false):
		var key := str(source.name)
		if not offsets.has(key): continue
		var body := StaticBody3D.new();body.name=key;body.collision_layer=1;body.collision_mask=2
		add_child(body);body.position=offsets[key]
		var world := body.global_position
		body.position.y+=Layout.height_at(world.x,world.z)-global_position.y
		var model := MeshInstance3D.new();model.mesh=source.mesh;model.transform=source.transform
		body.add_child(model)
		if key=="FireRing": model.material_override=preload("res://scripts/asset_library.gd").rock("granite",.6)
		var collider := CollisionShape3D.new();collider.shape=model.mesh.create_convex_shape();collider.transform=model.transform
		body.add_child(collider);props[key]=body
	asset.free()
	var duff := MeshInstance3D.new()
	var surface := SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 64:
		for p in [Vector3.ZERO,Vector3(cos((i+1)*TAU/64)*2.5,0,sin((i+1)*TAU/64)*2.5),Vector3(cos(i*TAU/64)*2.5,0,sin(i*TAU/64)*2.5)]:
			p.y=Layout.height_at(global_position.x+p.x,global_position.z+p.z)-global_position.y+.008
			surface.set_uv(Vector2(p.x,p.z));surface.add_vertex(p)
	surface.generate_normals();duff.mesh=surface.commit()
	duff.material_override=preload("res://scripts/asset_library.gd").rock("duff",2)
	add_child(duff)
	light.position=Vector3(0,.55,0);light.light_color=Color(1,.48,.15);light.omni_range=9;light.shadow_enabled=true
	add_child(light)
	_particles(flame,60,Color(1,.36,.055),.45,.13,Vector3(0,.8,0))
	_particles(smoke,24,Color(.25,.26,.27,.25),3,.30,Vector3(.22,.65,.06))
	fire_sound.stream=preload("res://assets/audio/fire.wav").duplicate()
	fire_sound.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	fire_sound.stream.loop_end=roundi(fire_sound.stream.get_length()*fire_sound.stream.mix_rate)
	fire_sound.bus="Ambience";fire_sound.unit_size=4;fire_sound.volume_db=-22
	add_child(fire_sound)
	game.new_day.connect(day_end)
	last_hour=clock.hour_at(clock.elapsed)
func _particles(p: GPUParticles3D,count: int,color: Color,life: float,size: float,gravity: Vector3) -> void:
	p.amount=count;p.lifetime=life;p.position=Vector3(0,.1,0);p.visibility_aabb=AABB(Vector3(-3,0,-3),Vector3(6,7,6))
	var material := ParticleProcessMaterial.new()
	material.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;material.emission_sphere_radius=.18
	material.direction=Vector3.UP;material.spread=20;material.initial_velocity_min=.25;material.initial_velocity_max=.8;material.gravity=gravity
	material.scale_min=.35;material.scale_max=1.2;material.color=color
	p.process_material=material
	var mesh := SphereMesh.new();mesh.radius=size;mesh.height=size*1.6;mesh.radial_segments=6;mesh.rings=3
	var m := StandardMaterial3D.new();m.vertex_color_use_as_albedo=true;m.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;m.emission_enabled=true;m.emission=color;m.emission_energy_multiplier=2 if p==flame else 0
	mesh.material=m
	if p==flame:
		var fire_material := ShaderMaterial.new();fire_material.shader=preload("res://shaders/fire.gdshader")
		mesh.material=fire_material
	p.draw_pass_1=mesh;p.emitting=false;add_child(p)
func burning() -> bool: return fire_hours>0
func light_fire() -> bool:
	var needed := 1 if burning() else 3
	if game.inventory.firewood<needed: return false
	game.inventory.firewood-=needed
	fire_hours=minf(4,fire_hours+1) if burning() else 2.0
	ember_hours=1
	game.event("Tended the fire.");return true
func target(walker: Node3D) -> String:
	var nearest := 1.5
	var result := ""
	for key in ["FireRing","Skillet","Rack","Cache","Bedroll","Crate"]:
		if not props.has(key): continue
		var delta: Vector3=props[key].global_position-walker.global_position
		delta.y=0
		if delta.length()<nearest and (-walker.get_node("Visual").global_basis.z).dot(delta.normalized())>-.1:
			nearest=delta.length();result=key
	return result
func fresh_index() -> int:
	for i in game.inventory.fish.size():
		if game.inventory.fish[i].state=="fresh" and not game.inventory.fish[i].get("cooked",false): return i
	return -1
func fry() -> bool:
	var i := fresh_index()
	if i<0 or fire_hours<Cooking.RECIPES.fried.hours or not cooking_fish.is_empty(): return false
	cooking_fish=game.inventory.fish.pop_at(i);cook_hours=Cooking.RECIPES.fried.hours
	game.changed.emit();return true
func hang() -> bool:
	var i := fresh_index()
	if i<0 or not burning() or not smoking.is_empty(): return false
	smoking=game.inventory.fish.pop_at(i);smoke_hours=0;game.event("Hung a fish on the rack.");return true
func eat_stored() -> bool:
	for i in game.inventory.fish.size():
		var f: Dictionary=game.inventory.fish[i]
		if f.state=="smoked" or f.get("cooked",false):
			game.inventory.fish.remove_at(i);game.eat(f.state=="smoked");return true
	return false
func swap_cache() -> void:
	if not game.inventory.fish.is_empty():
		game.inventory.cache.append_array(game.inventory.fish);game.inventory.fish=[]
	else:
		game.inventory.fish=game.inventory.cache;game.inventory.cache=[]
	game.event("Checked the hanging cache.")
func day_end() -> void:
	if not cooking_fish.is_empty():
		game.event("The unfinished meal spoiled.")
		cooking_fish={}
		get_parent().get_node("Activities").finish_cooking()
	if not smoking.is_empty(): game.event("The unfinished fish on the rack spoiled.")
	smoking={};smoke_hours=0
	fire_hours=0;ember_hours=0
	last_hour=clock.DAWN
func advance(hours: float) -> void:
	var lit := minf(hours,fire_hours)
	if not smoking.is_empty():
		smoke_hours+=lit
		if smoke_hours>=4:
			smoking.state="smoked";game.inventory.fish.append(smoking);smoking={};game.event("A fish finished smoking.")
	if not cooking_fish.is_empty():
		cook_hours-=lit
		if cook_hours<=0:
			if Cooking.portions(cooking_fish.weight_lb)==2:
				cooking_fish.cooked=true;cooking_fish.day=game.day;game.inventory.fish.append(cooking_fish)
			game.eat();cooking_fish={}
			get_parent().get_node("Activities").finish_cooking()
	fire_hours=maxf(0,fire_hours-hours)
	if hours>lit: ember_hours=maxf(0,ember_hours-(hours-lit))
func _process(delta: float) -> void:
	phase+=delta
	var hour: float=clock.hour_at(clock.elapsed)
	if clock.running:
		var change := fposmod(hour-last_hour,24)
		if change<1: advance(change)
	last_hour=hour
	flame.emitting=burning();smoke.emitting=burning() or ember_hours>0
	light.visible=burning() or ember_hours>0
	light.light_energy=(6.0 if burning() else .3)*(.9+.07*sin(phase*9)+.03*sin(phase*17))
	if get_parent().get_node("Soundscape").active and burning():
		if not fire_sound.playing: fire_sound.play()
	elif fire_sound.playing: fire_sound.stop()
	if props.has("Driftwood"): props.Driftwood.scale=Vector3.ONE*(.35+.30*mini(2,game.inventory.firewood/3))
