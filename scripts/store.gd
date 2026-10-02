extends Node3D
const KEEPER := "Lambert"
const Layout=preload("res://scripts/store_layout.gd")
const Library=preload("res://scripts/asset_library.gd")
const Kit=preload("res://scripts/prop_kit.gd")
## Stage 6 yard dressing (no collision): [glb or goods name, position, yaw, scale].
const YARD := [
	["res://assets/props/barrel.glb",Vector3(3.25,0,-1.75),.3,1.0],
	["res://assets/props/barrel.glb",Vector3(3.3,0,-.95),1.9,.92],
	["res://assets/props/crate.glb",Vector3(3.35,0,-2.7),.1,1.0],
	["res://assets/props/crate.glb",Vector3(3.3,.346,-2.65),.25,.9],
	["res://assets/props/lantern.glb",Vector3(3.3,.88,-1.75),.6,1.0],
	["res://assets/props/tub.glb",Vector3(3.35,0,.05),.0,1.0],
	["res://assets/props/bucket.glb",Vector3(2.95,0,1.35),.9,1.0],
	["res://assets/props/bench.glb",Vector3(3.9,0,2.3),-.75,1.0],
	["flour_3",Vector3(-3.05,0,-1.55),.4,1.0],["flour_2",Vector3(-3.45,0,-1.85),1.1,1.0],
	["beans_3",Vector3(-3.1,0,-2.25),2.0,1.0],["coffee_3",Vector3(-3.55,0,-2.5),.7,1.0],
]
## Black oak canopies over the clearing for the terrain shader's duff (store frame).
var oaks: Array[Vector3]=[]
var counter: Node3D
var scale_model: Node3D
var shelves: Node3D
var board: Label3D
var slate: Label3D
var keeper: Node3D
var walker: CharacterBody3D
var camera_rig: Node3D
var busy := false
var focus_kind := ""
var focus_released := false
var pile_visual:=Node3D.new()
var poured_sack: Node3D
var beam: Node3D
var pour_elapsed := 0.0
var settling := false
var item_entries: Dictionary={}
var targets: Dictionary={}
var current_target := ""
var dust := GPUParticles3D.new()
var weights: Array[Node3D]=[]
var weight_rest: Array[Vector3]=[]
var auto_pour_limit := -1.0
func named(script: String,label: String) -> Node:
	var node: Node=load("res://scripts/"+script+".gd").new();node.name=label;add_child(node);return node
func _ready() -> void:
	get_tree().auto_accept_quit=false
	get_tree().root.close_requested.connect(request_quit)
	var game: Node=get_node("/root/GameState")
	game.scene="store"
	var daylight: Node3D=load("res://scripts/daylight.gd").new();daylight.name="Daylight"
	daylight.camera_attributes=CameraAttributesPractical.new()
	for id in ["Sun","Moon"]:
		var light:=DirectionalLight3D.new();light.name=id;daylight.add_child(light)
	var clock: Node=load("res://scripts/day_clock.gd").new();clock.name="Clock";daylight.add_child(clock)
	var world:=WorldEnvironment.new();world.name="WorldEnvironment";daylight.add_child(world)
	for id in ["RiverMist","ClearRimAir"]:
		var fog:=FogVolume.new();fog.name=id;daylight.add_child(fog);fog.size=Vector3(60,10,60)
	add_child(daylight)
	daylight.get_node("Clock").start(game.start_hour);daylight.apply(game.start_hour)
	daylight.time_changed.connect(store_light)
	store_light(game.start_hour,1)
	daylight.get_node("RiverMist").hide()
	build_ground()
	var asset: Node3D=load("res://assets/store/store.glb").instantiate();asset.name="StoreAsset";add_child(asset)
	Kit.dress_tree(asset)
	for mesh in asset.find_children("*","MeshInstance3D",true,false):
		# The Milestone 10 walls and counter, kept exactly, are the collision; hidden.
		if "proxy" in str(mesh.name): mesh.visible=false;mesh.create_trimesh_collision();continue
		if str(mesh.name).begins_with("Beam"): beam=mesh
		if str(mesh.name).begins_with("Weight"): weights.append(mesh);weight_rest.append(mesh.position)
	var barrel:=Kit.instance("res://assets/props/barrel.glb");barrel.name="Fish barrel";add_child(barrel);barrel.position=Vector3(Layout.BARREL.x,0,Layout.BARREL.z);barrel.rotation.y=.6
	dress_yard()
	var sound: Node=named("soundscape","Soundscape");sound.store_bed=true;sound.start()
	named("store_rain","Rain")
	counter=named("counter","Counter")
	scale_model=named("beam_scale","Scale");scale_model.counter=counter
	shelves=named("shelves","Shelves");shelves.counter=counter
	board=named("price_board","Board");board.position=Layout.BOARD+Vector3(0,0,.035)
	slate=named("slate","Slate");slate.position=Layout.SLATE+Vector3(0,0,.035);slate.counter=counter
	keeper=named("shopkeeper","Lambert");keeper.position=Vector3(.15,0,-.7)
	targets={"scale":Layout.SCALE,"slate":Layout.SLATE,"pile":Layout.PILE,"barrel":Layout.BARREL,"board":Layout.BOARD,"home":Layout.TRAIL[0]}
	for good in counter.Stock.catalogue(): item_entries[good.item]=good;targets[good.item]=Layout.item_position(good.item)
	label(KEEPER.to_upper()+"\nFRENCH CAMP",Vector3(0,2.97,1.09),.0017)
	for good in counter.Stock.catalogue():
		if not good.for_sale: label("%s $%.2f" % [good.item.capitalize(),counter.Prices.price(good.item,game.day,game.seed)],Layout.item_position(good.item)+Vector3(0,.45,.05),.0009)
	build_outfitting(game)
	walker=load("res://scripts/store_walker.gd").new();walker.name="Walker"
	walker.collision_layer=2;walker.collision_mask=1;walker.floor_snap_length=.35
	var collider:=CollisionShape3D.new();var shape:=CapsuleShape3D.new();shape.radius=.25;shape.height=1.7;collider.shape=shape;collider.position.y=.85;walker.add_child(collider)
	var visual: Node3D=load("res://scripts/miner_visual.gd").new();visual.name="Visual";walker.add_child(visual)
	var pan:=Node3D.new();pan.name="Pan";visual.add_child(pan)
	camera_rig=load("res://scripts/store_camera.gd").new();camera_rig.name="CameraRig";camera_rig.target=walker
	walker.camera_rig=camera_rig;walker.river=walker
	add_child(walker);walker.position=Layout.TRAIL[0]+Vector3(0,.1,0)
	add_child(camera_rig);camera_rig.camera.attributes=daylight.camera_attributes
	named("ledger","Ledger");named("sandbox","Sandbox");named("hud","HUD")
	add_child(pile_visual)
	poured_sack=load("res://assets/miner/sack.glb").instantiate();add_child(poured_sack);poured_sack.hide()
	dust.amount=42;dust.lifetime=.45;dust.emitting=false;dust.position=Vector3(-1.35,1.43,.14)
	var dust_process:=ParticleProcessMaterial.new();dust_process.direction=Vector3.DOWN;dust_process.spread=4;dust_process.initial_velocity_min=.35;dust_process.initial_velocity_max=.5;dust_process.gravity=Vector3(0,-2,0)
	dust_process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;dust_process.emission_sphere_radius=.009;dust.process_material=dust_process
	var grain:=SphereMesh.new();grain.radius=.004;grain.height=.008;grain.radial_segments=4;grain.rings=2
	var gold:=StandardMaterial3D.new();gold.albedo_color=Color(.88,.60,.17);gold.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;grain.material=gold;dust.draw_pass_1=grain;add_child(dust)
	counter.changed.connect(refresh);refresh()
	if game.start_hour==13 and get_node("/root/Trip").departure_hour==7: pass
func label(text: String,point: Vector3,pixel: float) -> void:
	var node:=Label3D.new();node.text=text;node.font_size=48;node.pixel_size=pixel;node.outline_size=0;node.modulate=Color(.17,.13,.08);add_child(node);node.position=point
## 2.0: crates out front for the claims that hire, with a hand-lettered sign.
func build_outfitting(game: Node) -> void:
	for item in ["pan","whiskey"]:
		var crate:=Kit.instance("res://assets/props/crate.glb");crate.scale=Vector3(.73,1.03,1.1)
		add_child(crate);crate.position=Layout.item_position(item)-Vector3(0,.36,0);crate.rotation.y=.05 if item=="pan" else -.08
	var sign:=Label3D.new();sign.font=preload("res://assets/fonts/PatrickHand-Regular.ttf");sign.font_size=48;sign.pixel_size=.0016
	sign.modulate=Color(.17,.13,.08);sign.outline_size=0;sign.shaded=true
	sign.text="OUTFITTING\n"
	var names:={"pan":"Tin pan","bunk":"Bunk tent, sleeps four","strongbox":"Iron strongbox","whiskey":"Whiskey, the bottle","timber":"Dam timber, by mule"}
	for item in counter.Stock.OUTFIT: sign.text+="%s  $%.2f\n" % [names[item],counter.Prices.price(item,game.day,game.seed)]
	add_child(sign);sign.position=Vector3(-4.75,1.25,2.32);sign.rotation.y=.35
	var post:=MeshInstance3D.new();var pole:=BoxMesh.new();pole.size=Vector3(.08,1.6,.08);post.mesh=pole;pole.material=Kit.materials().kit_wood
	add_child(post);post.position=Vector3(-4.75,.75,2.27);post.rotation.y=.35
	var board:=MeshInstance3D.new();var plank:=BoxMesh.new();plank.size=Vector3(.95,.62,.03);board.mesh=plank
	plank.material=Kit.materials().kit_paper
	add_child(board);board.position=Vector3(-4.75,1.22,2.29);board.rotation.y=.35
## Stage 6: the clearing is drawn by the claim's terrain shader (its own material
## instance: no river wetness, oak duff under the clearing's black oaks), ringed by the
## talus boulders and a mixed forest of near and distant trees on their own seed.
func build_ground() -> void:
	var rng:=RandomNumberGenerator.new();rng.seed=184810
	var trees:=RandomNumberGenerator.new();trees.seed=184813
	var forest:={"black_oak":[],"incense_cedar":[],"douglas_fir":[],"ponderosa":[]}
	var far:={"incense_cedar":[],"douglas_fir":[],"ponderosa":[]}
	for i in 12:
		var angle:=PI*1.06+i*PI*.88/11+trees.randf_range(-.08,.08);var radius:=trees.randf_range(14.5,19.5)
		var p:=Vector3(cos(angle)*radius,0,sin(angle)*radius+1);oaks.append(p)
		forest.black_oak.append(Transform3D(Basis(Vector3.UP,trees.randf()*TAU).scaled(Vector3.ONE*trees.randf_range(.55,.85)),p))
	for i in 32:
		var angle:=trees.randf()*TAU;var radius:=trees.randf_range(19,27)
		# Behind and beside the stall the stand is denser; the trail side stays open.
		if sin(angle)>.55 and trees.randf()<.6: angle=-angle
		var species: String=["incense_cedar","douglas_fir","ponderosa"][i%3]
		var size:=trees.randf_range(.28,.62) if radius<24 else trees.randf_range(.45,.8)
		forest[species].append(Transform3D(Basis(Vector3.UP,trees.randf()*TAU).scaled(Vector3.ONE*size),Vector3(cos(angle)*radius,hill_height(angle,radius),sin(angle)*radius+1)))
	for i in 70:
		var angle:=trees.randf()*TAU;var radius:=trees.randf_range(27,52)
		var species: String=["incense_cedar","douglas_fir","ponderosa"][i%3]
		far[species].append(Transform3D(Basis(Vector3.UP,trees.randf()*TAU).scaled(Vector3.ONE*trees.randf_range(.6,1.1)),Vector3(cos(angle)*radius,hill_height(angle,radius),sin(angle)*radius+1)))
	var bark:={"ponderosa":Color(.37,.16,.055),"incense_cedar":Color(.22,.09,.035),"douglas_fir":Color(.15,.105,.075),"black_oak":Color(.12,.105,.08)}
	for species in forest: _trees(Library.plant(species,bark[species]),forest[species])
	for species in far: _trees(Library.plant(species,bark[species],true,true),far[species],false)
	var ground:=Library.terrain().duplicate() as ShaderMaterial
	ground.set_shader_parameter("water_level",-100.0)
	# Away from the river the bar's gravel layer is forest litter and its sand patches
	# are trampled bare earth: same shader, the clearing's own texture sets.
	for suffix in ["albedo","normal","orm"]:
		var litter=ground.get_shader_parameter("duff_"+suffix)
		if litter: ground.set_shader_parameter("gravel_"+suffix,litter)
	var canopies:=PackedVector4Array()
	for p in oaks: canopies.append(Vector4(p.x,p.z,0,0))
	ground.set_shader_parameter("oak_canopies",canopies)
	var mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(100,100);plane.subdivide_width=24;plane.subdivide_depth=24;mesh.mesh=plane;mesh.material_override=ground;add_child(mesh);mesh.create_trimesh_collision()
	for i in 32:
		var angle:=i*TAU/32+rng.randf_range(-.07,.07);var radius:=rng.randf_range(16.8,20.5)
		var rock:=MeshInstance3D.new();rock.mesh=Library.mesh("res://assets/boulders/boulder_%02d.glb" % (1+i%8))
		rock.material_override=Library.rock("talus",1);add_child(rock);rock.position=Vector3(cos(angle)*radius,.2,sin(angle)*radius+1);rock.scale=Vector3.ONE*rng.randf_range(1,2.3);rock.rotation.y=angle
	# The surrounding hill on the terrain shader's slope rules (vertex colour = wall).
	var hill:=SurfaceTool.new();hill.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		for corners in [[Vector2(i,1),Vector2(i+1,0),Vector2(i,0)],[Vector2(i,1),Vector2(i+1,1),Vector2(i+1,0)]]:
			for corner in corners:
				var angle: float=corner.x*TAU/96;var radius:=lerpf(17,55,corner.y)
				var point:=Vector3(cos(angle)*radius,corner.y*(11+3*sin(angle*3)+1.5*cos(angle*7)),sin(angle)*radius+1)
				hill.set_color(Color(.75,0,0));hill.set_uv(Vector2(point.x,point.z));hill.add_vertex(point)
	hill.generate_normals();var slope:=MeshInstance3D.new();slope.mesh=hill.commit();slope.material_override=ground;add_child(slope)
	# The trail home, worn to bare sand with a ragged edge (seeded).
	var worn:=ground.duplicate() as ShaderMaterial
	for suffix in ["albedo","normal","orm"]:
		var bare=worn.get_shader_parameter("sand_"+suffix)
		if bare: worn.set_shader_parameter("gravel_"+suffix,bare)
	worn.set_shader_parameter("oak_canopies",PackedVector4Array())
	var edge:=FastNoiseLite.new();edge.seed=184814;edge.frequency=.55
	var path:=SurfaceTool.new();path.begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var points: Array[Vector3]=[]
	for i in range(1,Layout.TRAIL.size()):
		var a: Vector3=Layout.TRAIL[i-1];var b: Vector3=Layout.TRAIL[i]
		var steps:=maxi(1,ceili(a.distance_to(b)/.45))
		for s in steps: points.append(a.lerp(b,float(s)/steps))
	points.append(Layout.TRAIL[-1])
	for i in points.size():
		var p: Vector3=points[i]
		var along: Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(i-1,0)]).normalized()
		var side:=Vector3(-along.z,0,along.x)
		var taper:=minf(1.0,float(points.size()-1-i)/3.0+.35)
		for k in [1,-1]: # strip winding faces up
			var q: Vector3=p+side*k*(.42+.13*edge.get_noise_2d(i*.45,k*7.0))*taper
			path.set_normal(Vector3.UP);path.set_uv(Vector2(q.x,q.z));path.add_vertex(Vector3(q.x,.008,q.z))
	var trail:=MeshInstance3D.new();trail.mesh=path.commit();trail.material_override=worn;trail.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(trail)
## Height of the surrounding hill (below) at a polar position about (0, 1), sunk 0.4 m.
static func hill_height(angle: float,radius: float) -> float:
	return clampf((radius-17)/38,0,1)*(11+3*sin(angle*3)+1.5*cos(angle*7))-.4
func _trees(mesh: Mesh,transforms: Array,shadows := true) -> void:
	if transforms.is_empty(): return
	var group:=MultiMeshInstance3D.new();var multi:=MultiMesh.new();multi.transform_format=MultiMesh.TRANSFORM_3D;multi.mesh=mesh
	multi.instance_count=transforms.size()
	for i in transforms.size(): multi.set_instance_transform(i,transforms[i])
	group.multimesh=multi;group.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF;add_child(group)
## Barrels, crates, sacks and a bench around the stall; set dressing only.
func dress_yard() -> void:
	var goods:=Kit.named("res://assets/store/goods.glb")
	for item in YARD:
		var node:=MeshInstance3D.new()
		node.mesh=Kit.mesh(item[0]) if item[0].begins_with("res://") else goods[item[0]]
		add_child(node);node.position=item[1];node.rotation.y=item[2];node.scale=Vector3.ONE*item[3]
func refresh() -> void:
	shelves.refresh();slate.refresh()
	for node in pile_visual.get_children(): pile_visual.remove_child(node);node.queue_free()
	for i in counter.pile.size():
		var prop: Node3D=shelves.pile_object(counter.pile[i]);pile_visual.add_child(prop);prop.position=Layout.PILE+Vector3((i%3)*.36-.35,(i/3)*.1,0)
	for i in counter.fish_offer.size():
		var fish:=MeshInstance3D.new();fish.mesh=Library.mesh("res://assets/fish/fish.glb") if ResourceLoader.exists("res://assets/fish/fish.glb") else CapsuleMesh.new();pile_visual.add_child(fish);fish.position=Layout.BARREL+Vector3(i*.1-.2,0,0);fish.scale=Vector3(.2,.2,.2)
	for i in mini(3,counter.hide_offer.size()):
		var hide: Node3D=load("res://assets/expedition/hide.glb").instantiate();pile_visual.add_child(hide)
		hide.position=Layout.BARREL+Vector3(0,.03*i+.04,0);hide.scale=Vector3.ONE*.65
func target() -> String:
	var camera: Camera3D=camera_rig.camera
	var result:="";var best:=.82
	for id in targets:
		if id=="pile" and counter.pile.is_empty(): continue
		if id=="home" and (-camera.global_basis.z).dot((Layout.TRAIL[0]-Layout.TRAIL[1]).normalized())<.35: continue
		var point: Vector3=targets[id]
		var bin_front: float=point.z+(.6 if item_entries.has(id) else 0.0)
		var horizontal:=Vector2(point.x-walker.position.x,bin_front-walker.position.z).length()
		# Shelf reach is measured from the front of its bin; rear meshes are decoration.
		var reach:=2.0 if item_entries.has(id) else 1.5
		if horizontal>reach: continue
		var score:=(-camera.global_basis.z).dot((point-camera.global_position).normalized())
		if score>best: best=score;result=id
	return result
func prompt() -> String:
	var id:=target()
	match id:
		"scale": return "Weigh out · hold" if get_node("/root/Sack").ounces>0 else "Sack empty"
		"slate": return "Settle" if not counter.pile.is_empty() or (not counter.fish_offer.is_empty() or not counter.hide_offer.is_empty()) else "Slate"
		"board": return "Prices"
		"pile": return "Return last item"
		"barrel": return "Take offered food and hides back" if (not counter.fish_offer.is_empty() or not counter.hide_offer.is_empty()) else "Sell smoked food and hides"
		"home": return "Home · by dusk"
		"": return ""
	var game: Node=get_node("/root/GameState")
	return "%s · $%.2f %s" % [id.capitalize(),counter.Prices.price(id,game.day,game.seed),counter.Stock.entry(id).unit]
func _unhandled_input(event: InputEvent) -> void:
	if get_node("Sandbox").opened or settling: return
	if event.is_action_pressed("ui_cancel"):
		finish_pour();camera_rig.release_focus();focus_released=true;get_viewport().set_input_as_handled();return
	if event.is_action_released("interact"):
		finish_pour();return
	if event.is_action_pressed("interact") and not event.is_echo():
		interact(target());get_viewport().set_input_as_handled()
func interact(id: String) -> void:
	if busy: return
	match id:
		"scale":
			if get_node("/root/Sack").ounces<=0: return
			busy=true;scale_model.begin();keeper.position=Layout.KEEPER_SCALE;keeper.play("weigh")
			walker.position=Vector3(-1.35,0,.7);walker.get_node("Visual").rotation.y=0;walker.get_node("Visual").play_activity("pour")
			camera_rig.focus(Vector3(-2.25,2.35,-.7),Vector3(-1.05,1.35,.15),42)
			poured_sack.show();dust.emitting=true;pour_elapsed=0
		"pile": counter.return_last();keeper.play("shelve")
		"barrel": counter.toggle_fish()
		"slate":
			# Show the required dust crossing the scale before the atomic exchange.
			var needed: float=maxf(0,counter.total()-counter.game.dollars-counter.trade_credit())/(counter.visit.gold_price*.92)
			if needed>.000001 and needed<=counter.sack.ounces and not counter.pile.is_empty():
				interact("scale");settling=true;auto_pour_limit=needed
				return
			if counter.settle():
				busy=true;settling=true;keeper.position=Layout.KEEPER_SLATE;keeper.settle()
				create_tween().tween_interval(3).finished.connect(func():settling=false;busy=false;slate.text="";keeper.position=Vector3(.15,0,-.7))
			else: keeper.play("shelve")
		"home": get_node("/root/Trip").home()
		"board","": pass
		_:
			var message: String=counter.select(id)
			if message!="": get_node("HUD").notify(message)
			else:
				busy=true;walker.get_node("Visual").play_activity("take")
				var prop: Node3D=pile_visual.get_child(counter.pile.size()-1)
				var end:=prop.position;prop.position=Layout.item_position(id)
				var take:=create_tween();take.tween_property(prop,"position",end,1.5).set_trans(Tween.TRANS_SINE)
				take.tween_callback(func():walker.get_node("Visual").stop_activity();busy=false)
func finish_pour() -> void:
	if not scale_model.pouring: return
	scale_model.release();busy=false;poured_sack.hide();dust.emitting=false;keeper.play("keep_idle");walker.get_node("Visual").stop_activity();camera_rig.release_focus();focus_released=true
	keeper.position=Vector3(.15,0,-.7)
	if beam: beam.rotation.z=0
func _physics_process(delta: float) -> void:
	if scale_model==null: return
	if scale_model.pouring:
		var step:=minf(delta,maxf(0,auto_pour_limit-scale_model.poured)/scale_model.RATE) if auto_pour_limit>=0 else delta
		scale_model.advance(step);pour_elapsed+=step
		if beam: beam.rotation.z=scale_model.angle
		for i in weights.size():
			weights[i].position=weight_rest[i]+(Vector3(-.05-i*.05,.15,.28) if scale_model.weights>i else Vector3.ZERO)
		poured_sack.position=Vector3(-1.35,1.39,.17);poured_sack.scale=Vector3.ONE*1.4;poured_sack.rotation=Vector3(.5,0,PI*.7)
		slate.text="%.2f oz\n$%.2f" % [scale_model.poured*.92,scale_model.poured*.92*counter.visit.gold_price]
		if pour_elapsed>=3: keeper.play("weigh");pour_elapsed=0
		if auto_pour_limit>=0 and scale_model.poured>=auto_pour_limit-.0000001:
			auto_pour_limit=-1;finish_pour();settling=false;interact.call_deferred("slate");return
		if get_node("/root/Sack").ounces<=0: finish_pour()
		return
	if busy: return
	var id:=target()
	if Vector2(walker.position.x,walker.position.z).distance_to(Vector2(0,0))>3.8: focus_released=false;camera_rig.release_focus()
	if not focus_released and id in ["board","slate"]:
		if id=="board": camera_rig.focus(Vector3(-3.25,1.78,4.8),Layout.BOARD,32)
		else: camera_rig.focus(Vector3(1.2,1.48,3.1),Layout.SLATE,20)
func request_quit() -> void:
	get_node("Soundscape").stop();get_node("Rain").sound.stop();get_tree().quit()
func store_light(_hour: float,_strength: float) -> void:
	var environment: Environment=get_node("Daylight").environment
	environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color=Color(.66,.72,.79);environment.ambient_light_energy=1.5
	environment.ambient_light_sky_contribution=0
	environment.sdfgi_energy=1.4;environment.ssao_intensity=.5
