extends Node3D
const Layout=preload("res://scripts/claim_layout.gd")
const Cooking=preload("res://scripts/cooking.gd")
const Kit=preload("res://scripts/prop_kit.gd")
## Stage 6 visuals for the nine camp props: [glb, transform, extra child meshes].
var looks := {
	# Wave C: eleven separate stones round an ash bed (blender/build_camp_kit.py fire_ring).
	"FireRing":["res://assets/camp/fire_ring.glb",Transform3D.IDENTITY,
		[["res://assets/camp/embers.glb",Transform3D(Basis.IDENTITY,Vector3(0,.095,0))]]],
	"LeanTo":["res://assets/camp/lean_to.glb"],
	"Bedroll":["res://assets/camp/bedroll.glb"],
	"Pot":["res://assets/camp/pot.glb"],
	"Skillet":["res://assets/camp/skillet.glb"],
	"Rack":["res://assets/camp/rack.glb"],
	"Crate":["res://assets/props/crate.glb",Transform3D(Basis.from_scale(Vector3(.8,1.25,1.1)),Vector3.ZERO),
		[["res://assets/camp/ledger.glb",Transform3D(Basis(Vector3.UP,.12),Vector3(.02,.433,-.01))]]],
	"Cache":["res://assets/camp/cache.glb"],
	"Driftwood":["res://assets/camp/firewood.glb"],
}
## Set dressing around the camp: [glb or goods.glb mesh name, position (camp frame, y above
## the ground), yaw, scale, tilt about x]. No collision: every piece sits beside a prop
## the walker and the crew already steer around, or under the lean-to (parented to it, so
## they go when a bought tent replaces it).
var dressing_items := [
	["res://assets/props/barrel.glb",Vector3(-4.05,0,2.55),.4,1.0,0.0],
	["res://assets/props/lantern.glb",Vector3(-4.0,.877,2.5),2.2,1.0,0.0],
	["res://assets/camp/chopping_block.glb",Vector3(-2.75,0,-.45),.3,1.0,0.0],
	["res://assets/props/axe.glb",Vector3(-2.75,.95,-.76),0.0,1.0,PI-.45],
	["res://assets/camp/woodpile.glb",Vector3(-4.5,0,1.6),PI/2+.05,1.0,0.0],
	["res://assets/props/stool.glb",Vector3(.78,0,.95),2.6,1.0,0.0],
	["res://assets/props/bucket.glb",Vector3(2.15,0,-.55),.7,1.0,0.0],
	["res://assets/props/pick.glb",Vector3(-4.35,0,3.5),1.7,1.0,.2],
	["res://assets/props/spade.glb",Vector3(-4.3,0,3.95),1.5,1.0,.24],
	["res://assets/miner/pan.glb",Vector3(-3.0,0,3.2),.2,1.0,1.25],
	["flour_3",Vector3(-2.6,0,4.25),.5,.95,0.0,"LeanTo"],
	["beans_1",Vector3(-.95,0,4.2),2.1,.9,0.0,"LeanTo"],
	["coffee_2",Vector3(-3.55,0,3.05),1.3,1.0,0.0],
	# Cook gear (coffee pot, Dutch oven, tin plates and cups) just outside the ring stones.
	["res://assets/camp/coffee.glb",Vector3(-1.05,0,.6),2.4,1.0,0.0],
]
var strips: MeshInstance3D
## The burning fire: flame ribbons, glowing coals and smoke, a child of the FireRing look.
var flames: Node3D
var props: Dictionary={}
var tent: Node3D
var oak := Vector3.ZERO
var fire_hours := 0.0
var ember_hours := 0.0
var smoking: Dictionary:
	get: return get_node("/root/GameState").inventory.get("rack",{})
	set(value): get_node("/root/GameState").inventory.rack=value
var smoke_hours := 0.0
var cook_hours := 0.0
var cooking_fish: Dictionary={}
var light := OmniLight3D.new()
var flame := GPUParticles3D.new()
var smoke := GPUParticles3D.new()
var fire_sound := AudioStreamPlayer3D.new()
var last_hour := 4.75
var phase := 0.0
var skillet_rest := Transform3D.IDENTITY
var cooking_food: MeshInstance3D
var recipe := ""
var coffee_day := -1
var biscuit_day := -1
var pot_rest := Transform3D.IDENTITY
@onready var game: Node=get_node("/root/GameState")
@onready var clock: Node=get_parent().get_node("Daylight/Clock")
func _ready() -> void:
	var best := INF
	for transform in get_parent().get_node("Vegetation").placements.black_oak:
		var p: Vector3=transform.origin
		if p.z-Layout.shore_z(p.x)>=10 and absf(p.x)<best:
			best=absf(p.x);oak=p
	position=Vector3(oak.x,Layout.height_at(oak.x,oak.z-3),oak.z-3)
	# camp.glb holds the original prop meshes; they stay the collision source so shapes,
	# the open doorway and walk paths are unchanged. What you see is the Stage 6 kit.
	var asset := preload("res://assets/camp/camp.glb").instantiate()
	# A clear work area around the fire; the shelter opens riverward from inland.
	var offsets := {"FireRing":Vector3.ZERO,"LeanTo":Vector3(-1.8,0,3.4),"Bedroll":Vector3(-1.8,0,4.2),"Pot":Vector3(1.5,0,-.1),"Skillet":Vector3(.95,0,-1.05),"Rack":Vector3(2.6,0,1.2),"Crate":Vector3(-3.4,0,3.5),"Cache":Vector3(0,2.5,3),"Driftwood":Vector3(-2.2,0,.5)}
	for source in asset.find_children("*","MeshInstance3D",true,false):
		var key := str(source.name)
		if not offsets.has(key): continue
		var body := StaticBody3D.new();body.name=key;body.collision_layer=1;body.collision_mask=2
		add_child(body);body.position=offsets[key]
		var world := body.global_position
		body.position.y+=Layout.height_at(world.x,world.z)-global_position.y
		if key=="LeanTo": body.rotation.y=PI
		if key=="Skillet": body.rotation.y=PI/2
		var model := look(key)
		# The bedroll lies in the lean-to's shade; its own shadow only costs cascades.
		if key=="Bedroll": model.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		body.add_child(model)
		var collider := CollisionShape3D.new()
		# Preserve the shelter's open doorway instead of filling it with a hull.
		collider.shape=source.mesh.create_trimesh_shape() if key=="LeanTo" else source.mesh.create_convex_shape()
		collider.transform=source.transform
		body.add_child(collider);props[key]=body
	asset.free()
	strips=Kit.instance("res://assets/camp/fish_strips.glb");strips.visible=false;props.Rack.add_child(strips)
	# Built visible: the crew's supper fire (crew.gd) copies this look in its _ready, before
	# _process here hides the camp's own flames until it is lit.
	flames=build_flames();props.FireRing.get_child(0).add_child(flames)
	dress()
	skillet_rest=props.Skillet.transform
	pot_rest=props.Pot.transform
	cooking_food=MeshInstance3D.new();cooking_food.visible=false
	# FishSchool is later in the scene; resolve its mesh when cooking begins.
	cooking_food.scale=Vector3(.65,.35,.65);cooking_food.position=Vector3(0,.085,0)
	props.Skillet.add_child(cooking_food)
	process_physics_priority=20 # After the miner's hand pose.
	# The camp sits in an oak's litter on the terrain shader; a separate duff disc
	# drew a hard-edged circle against the cobble.
	light.position=Vector3(0,.55,0);light.light_color=Color(1,.48,.15);light.omni_range=9;light.shadow_enabled=true
	add_child(light)
	_particles(flame,60,Color(1,.36,.055),.45,.13,Vector3(0,.8,0))
	_particles(smoke,48,Color(.25,.26,.27,.25),7,.36,Vector3(.10,.40,.025))
	smoke.visibility_aabb=AABB(Vector3(-4,0,-4),Vector3(10,18,10))
	fire_sound.stream=preload("res://assets/audio/fire.wav").duplicate()
	fire_sound.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	fire_sound.stream.loop_end=roundi(fire_sound.stream.get_length()*fire_sound.stream.mix_rate)
	fire_sound.bus="Ambience";fire_sound.unit_size=4;fire_sound.volume_db=-22
	add_child(fire_sound)
	game.new_day.connect(day_end)
	last_hour=clock.hour_at(clock.elapsed)
	game.changed.connect(refresh_tent);refresh_tent()
## The visible mesh of a camp prop (child 0 of its body; the crew's fire copies FireRing's).
func look(key: String) -> MeshInstance3D:
	var spec: Array=looks[key]
	var model := Kit.instance(spec[0],spec[1] if spec.size()>1 else Transform3D.IDENTITY)
	model.name="Look"
	if key=="FireRing":
		# The ring stones carry their soot and tone in vertex colour.
		for i in model.mesh.get_surface_count():
			var stone := model.mesh.surface_get_material(i) as BaseMaterial3D
			if stone and not str(stone.resource_name).begins_with("kit_"):
				stone.vertex_color_use_as_albedo=true;stone.vertex_color_is_srgb=false
	if spec.size()>2:
		for extra in spec[2]:
			var part := Kit.instance(extra[0],model.transform.affine_inverse()*extra[1])
			part.visibility_range_end=60;part.visibility_range_end_margin=6;part.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;model.add_child(part)
	return model
## Flame ribbons (fire.gdshader, mode 1), coals glowing through their ash and a thin
## column of smoke; the particle licks stay on the camp's and crew's own emitters.
static func build_flames() -> Node3D:
	var parts: Dictionary=Kit.named("res://assets/camp/flames.glb")
	var root:=Node3D.new();root.name="Flames"
	var tongues:=MeshInstance3D.new();tongues.name="Tongues";tongues.mesh=parts.Tongues
	var fire:=ShaderMaterial.new();fire.shader=preload("res://shaders/fire.gdshader");fire.set_shader_parameter("mode",1)
	tongues.material_override=fire;tongues.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;tongues.position.y=.04
	root.add_child(tongues)
	var coals:=MeshInstance3D.new();coals.name="Coals";coals.mesh=parts.Coals
	var glow:=ShaderMaterial.new();glow.shader=fire.shader;glow.set_shader_parameter("mode",2)
	coals.material_override=glow;coals.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(coals)
	var smoke_puffs:=GPUParticles3D.new();smoke_puffs.name="Smoke"
	smoke_puffs.amount=14;smoke_puffs.lifetime=5.0;smoke_puffs.position.y=.5
	smoke_puffs.visibility_aabb=AABB(Vector3(-2.5,-.5,-2.5),Vector3(5,7,5));smoke_puffs.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;process.emission_sphere_radius=.1
	process.direction=Vector3.UP;process.spread=10;process.initial_velocity_min=.3;process.initial_velocity_max=.45;process.gravity=Vector3(.06,.1,.02)
	process.damping_min=.04;process.damping_max=.08;process.scale_min=.55;process.scale_max=.85
	process.angle_min=-180;process.angle_max=180
	var grow:=Curve.new();grow.add_point(Vector2(0,.3));grow.add_point(Vector2(1,1.0))
	var grow_texture:=CurveTexture.new();grow_texture.curve=grow;process.scale_curve=grow_texture
	var ramp:=Gradient.new();ramp.set_color(0,Color(.45,.43,.41,0));ramp.set_color(1,Color(.55,.55,.55,0))
	ramp.add_point(.12,Color(.38,.36,.34,.32));ramp.add_point(.55,Color(.5,.5,.5,.16))
	var ramp_texture:=GradientTexture1D.new();ramp_texture.gradient=ramp;process.color_ramp=ramp_texture
	smoke_puffs.process_material=process
	var quad:=QuadMesh.new();quad.size=Vector2(.9,.9)
	var puff:=StandardMaterial3D.new();puff.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;puff.billboard_keep_scale=true
	puff.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;puff.vertex_color_use_as_albedo=true;puff.roughness=1.0;puff.disable_receive_shadows=true
	var disc:=GradientTexture2D.new();disc.width=64;disc.height=64;disc.fill=GradientTexture2D.FILL_RADIAL
	disc.fill_from=Vector2(.5,.5);disc.fill_to=Vector2(.5,0)
	var soft:=Gradient.new();soft.set_color(0,Color(1,1,1,1));soft.set_color(1,Color(1,1,1,0));soft.add_point(.45,Color(1,1,1,.55));disc.gradient=soft
	puff.albedo_texture=disc;quad.material=puff;smoke_puffs.draw_pass_1=quad
	root.add_child(smoke_puffs)
	return root
## A canvas tent (bought, or a crew bunk tent): assets/expedition/tent.glb keeps its meshes
## as the collision, hidden; assets/camp/tent.glb (sagging canvas, stakes, guy lines) is seen.
static func tent_instance() -> Node3D:
	var tent: Node3D=load("res://assets/expedition/tent.glb").instantiate()
	for model in tent.find_children("*","MeshInstance3D",true,false):
		model.create_trimesh_collision();model.visible=false
	var look:=Kit.instance("res://assets/camp/tent.glb");look.name="Canvas";tent.add_child(look)
	return tent
func dress() -> void:
	var dressing := Node3D.new();dressing.name="Dressing";add_child(dressing)
	var goods: Dictionary=Kit.named("res://assets/store/goods.glb")
	for item in dressing_items:
		var node := MeshInstance3D.new()
		node.mesh=Kit.mesh(item[0]) if item[0].begins_with("res://") else goods[item[0]]
		# Goods under the lean-to are parented to it, so they hide when a bought tent replaces it.
		(props[item[5]] if item.size()>5 else dressing).add_child(node)
		var p: Vector3=global_position+item[1]
		node.global_transform=Transform3D(Basis.from_euler(Vector3(item[4],item[2],0)).scaled(Vector3.ONE*item[3]),Vector3(p.x,Layout.height_at(p.x,p.z)+item[1].y,p.z))
		# Small dressing drops out beyond 60 m (the overview is the tight frame-time view).
		node.visibility_range_end=60;node.visibility_range_end_margin=6;node.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		# Hand tools and cookware are too small to need their own shadow (three cascades each).
		if item[0].get_file() in ["coffee.glb","axe.glb","pan.glb","pick.glb","spade.glb","lantern.glb"]: node.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
func refresh_tent() -> void:
	var owned: bool=game.inventory.get("tent",false)
	props.LeanTo.visible=not owned;props.LeanTo.collision_layer=0 if owned else 1
	if owned and not is_instance_valid(tent):
		tent=tent_instance();add_child(tent)
		tent.position=props.LeanTo.position;tent.rotation.y=PI
	if is_instance_valid(tent):
		tent.visible=owned
		for body in tent.find_children("*","StaticBody3D",true,false): body.collision_layer=1 if owned else 0
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
	for key in ["FireRing","Skillet","Pot","Rack","Cache","Bedroll","Crate"]:
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
func work_position() -> Vector3:
	var point := global_position+Vector3(.14,0,-1.0)
	point.y=Layout.height_at(point.x,point.z)+.02
	return point
func wake_position() -> Vector3:
	var point: Vector3=props.LeanTo.global_position+Vector3(0,0,-.65)
	point.y=Layout.height_at(point.x,point.z)+.02
	return point
func restore_skillet() -> void:
	props.Pot.transform=pot_rest;props.Pot.collision_layer=1
	props.Skillet.transform=skillet_rest
	props.Skillet.show()
	props.Skillet.collision_layer=1
	cooking_food.hide()
func _physics_process(_delta: float) -> void:
	if biscuit_day>=0 and get_parent().get_node("Walker").global_position.distance_to(global_position)>3.5: biscuit_day=-1
	var activities: Node=get_parent().get_node("Activities")
	if not activities.busy or activities.action!="cook": return
	if recipe in ["beans","coffee"]:
		props.Pot.global_position=global_position+Vector3(0,.05,0);props.Pot.collision_layer=0
		return
	var hand: Node3D=get_parent().get_node("Walker/Visual").right_hand
	# The authored handle extends along +X; turn it riverward toward the grip.
	props.Skillet.global_basis=Basis(Vector3.UP,PI/2)
	props.Skillet.global_position=hand.global_position-props.Skillet.global_basis*Vector3(.42,.045,0)
func fry() -> bool:
	var i := fresh_index()
	if i<0 or fire_hours<Cooking.RECIPES.fried.hours or not cooking_fish.is_empty(): return false
	cooking_fish=game.inventory.fish.pop_at(i);cook_hours=Cooking.RECIPES.fried.hours
	props.Skillet.collision_layer=0
	cooking_food.mesh=get_parent().get_node("FishSchool").sources.get(cooking_fish.species)
	if cooking_food.mesh==null:
		var meat:=BoxMesh.new();meat.size=Vector3(.24,.06,.18)
		var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.25,.10,.06);mat.roughness=.9;meat.material=mat;cooking_food.mesh=meat
	cooking_food.show()
	game.changed.emit();return true
func hang() -> bool:
	var i := fresh_index()
	if i<0 or not burning() or not smoking.is_empty() or game.inventory.goods.salt<.1: return false
	var first: Dictionary=game.inventory.fish[i]
	if first.species in ["salmon","venison","bear meat"]:
		var batch: Array=[];var mass:=0.0
		for f in game.inventory.fish:
			if f.species==first.species and f.state=="fresh" and not f.get("cooked",false) and mass+f.weight_lb<=20:
				batch.append(f);mass+=f.weight_lb
		var salt:=maxf(.1,mass*.02)
		if game.inventory.goods.salt<salt: return false
		game.inventory.goods.salt-=salt
		for f in batch: game.inventory.fish.erase(f)
		smoking=Cooking.fresh(first.species,mass,game.day);smoking.batch=true
	else:
		game.inventory.goods.salt=maxf(0,game.inventory.goods.salt-.1)
		smoking=game.inventory.fish.pop_at(i)
	smoke_hours=0;game.event("Hung food on the rack.");return true
func eat_stored() -> bool:
	for i in game.inventory.fish.size():
		var f: Dictionary=game.inventory.fish[i]
		if f.state=="smoked" or f.get("cooked",false):
			game.inventory.fish.remove_at(i);game.eat(f.state=="smoked");return true
	return false
func has_stored() -> bool:
	return game.inventory.fish.any(func(f):return f.state=="smoked" or f.get("cooked",false))
func cut_bait() -> bool:
	if not game.inventory.knife or game.inventory.goods.pork<.25: return false
	game.inventory.goods.pork-=.25;game.inventory.bait.pork+=4;game.event("Cut pork for bait.");return true
func start_recipe(kind: String) -> bool:
	if recipe!="" or not cooking_fish.is_empty(): return false
	if not Cooking.can_cook(kind,game.inventory.goods,fire_hours,clock.hour_at(clock.elapsed),coffee_day==game.day): return false
	for item in Cooking.RECIPES[kind].needs: game.inventory.goods[item]-=Cooking.RECIPES[kind].needs[item]
	recipe=kind;cook_hours=Cooking.RECIPES[kind].hours;game.changed.emit();return true
func finish_recipe() -> void:
	if recipe=="coffee":
		game.condition=minf(100,game.condition+5);coffee_day=game.day;game.event("Coffee.")
	else:
		var carried: int=Cooking.RECIPES[recipe].portions-1
		if recipe=="biscuits" and biscuit_day==game.day: carried=1
		else: game.condition=minf(100,game.condition+20);game.inventory.meals_today+=1
		if recipe=="biscuits": biscuit_day=game.day
		for i in carried: game.inventory.fish.append({"species":recipe,"weight_lb":.5,"state":"fresh","cooked":true,"day":game.day,"keeps_until":game.day+2})
		game.event("Cooked "+recipe+".")
	recipe="";get_parent().get_node("Activities").finish_cooking()
func swap_cache() -> void:
	if not game.inventory.fish.is_empty():
		game.inventory.cache.append_array(game.inventory.fish);game.inventory.fish=[]
	else:
		game.inventory.fish=game.inventory.cache;game.inventory.cache=[]
	game.event("Checked the hanging cache.")
func day_end() -> void:
	if recipe!="":
		game.event("The unfinished meal spoiled.")
		get_parent().get_node("Activities").busy=false;get_parent().get_node("Activities").action=""
		get_parent().get_node("Walker/Visual").stop_activity();restore_skillet()
	recipe=""
	if not cooking_fish.is_empty():
		game.event("The unfinished meal spoiled.")
		cooking_fish={}
		restore_skillet()
		get_parent().get_node("Activities").finish_cooking()
	if not smoking.is_empty(): game.event("The unfinished fish on the rack spoiled.")
	smoking={};smoke_hours=0
	fire_hours=0;ember_hours=0
	last_hour=clock.DAWN
func advance(hours: float) -> void:
	var lit := minf(hours,fire_hours)
	if recipe!="":
		cook_hours-=lit
		if cook_hours<=.000001: finish_recipe()
	if not smoking.is_empty():
		smoke_hours+=lit
		if smoke_hours>=4:
			if smoking.get("batch",false):
				for f in preload("res://scripts/expedition_model.gd").food(smoking.species,smoking.weight_lb,game.day):
					f.state="smoked";game.inventory.fish.append(f)
			else:
				smoking.state="smoked";game.inventory.fish.append(smoking)
			smoking={};game.event("Food finished smoking.")
	if not cooking_fish.is_empty():
		cook_hours-=lit
		if cook_hours<=0:
			if Cooking.portions(cooking_fish.weight_lb)==2:
				cooking_fish.cooked=true;cooking_fish.day=game.day;game.inventory.fish.append(cooking_fish)
			game.eat();cooking_fish={}
			restore_skillet()
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
	flame.emitting=burning();smoke.emitting=not burning() and ember_hours>0
	if flames: flames.visible=burning()
	light.visible=burning() or ember_hours>0
	light.light_energy=(6.0 if burning() else .3)*(.9+.07*sin(phase*9)+.03*sin(phase*17))
	if get_parent().get_node("Soundscape").active and burning():
		if not fire_sound.playing: fire_sound.play()
	elif fire_sound.playing: fire_sound.stop()
	if props.has("Driftwood"): props.Driftwood.scale=Vector3.ONE*(.35+.30*mini(2,game.inventory.firewood/3))
	if strips: strips.visible=not smoking.is_empty()
