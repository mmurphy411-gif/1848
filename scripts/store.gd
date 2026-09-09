extends Node3D
const KEEPER := "Lambert"
const Layout=preload("res://scripts/store_layout.gd")
const Library=preload("res://scripts/asset_library.gd")
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
	for mesh in asset.find_children("*","MeshInstance3D",true,false):
		if str(mesh.name).begins_with("Canvas"):
			var fabric:=ShaderMaterial.new();fabric.shader=load("res://shaders/store_canvas.gdshader");fabric.set_shader_parameter("atlas",load("res://assets/store/store_atlas.png"));mesh.material_override=fabric
		if str(mesh.name).begins_with("Beam"): beam=mesh
		if str(mesh.name).begins_with("Weight"): weights.append(mesh);weight_rest.append(mesh.position)
		if str(mesh.name).begins_with("Counter") or "log" in str(mesh.name): mesh.create_trimesh_collision()
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
func build_ground() -> void:
	var mesh:=MeshInstance3D.new();var plane:=PlaneMesh.new();plane.size=Vector2(100,100);mesh.mesh=plane;mesh.material_override=Library.rock("duff",2);add_child(mesh);mesh.create_trimesh_collision()
	var rng:=RandomNumberGenerator.new();rng.seed=184810
	for i in 32:
		var angle:=i*TAU/32+rng.randf_range(-.07,.07);var radius:=rng.randf_range(16.8,20.5)
		var rock:=MeshInstance3D.new();rock.mesh=Library.mesh("res://assets/boulders/boulder_%02d.glb" % (1+i%8))
		rock.material_override=Library.rock("talus",1);add_child(rock);rock.position=Vector3(cos(angle)*radius,.2,sin(angle)*radius+1);rock.scale=Vector3.ONE*rng.randf_range(1,2.3);rock.rotation.y=angle
	for i in 32:
		var angle:=rng.randf()*TAU;var radius:=rng.randf_range(20,34);var tree:=MeshInstance3D.new();tree.mesh=Library.plant("ponderosa",Color(.37,.16,.055));add_child(tree);tree.position=Vector3(cos(angle)*radius,0,sin(angle)*radius+1);tree.scale=Vector3.ONE*rng.randf_range(.55,1.2);tree.rotation.y=rng.randf()*TAU
	var hill:=SurfaceTool.new();hill.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		for corners in [[Vector2(i,1),Vector2(i+1,0),Vector2(i,0)],[Vector2(i,1),Vector2(i+1,1),Vector2(i+1,0)]]:
			for corner in corners:
				var angle: float=corner.x*TAU/96;var radius:=lerpf(17,55,corner.y)
				var point:=Vector3(cos(angle)*radius,corner.y*(11+3*sin(angle*3)+1.5*cos(angle*7)),sin(angle)*radius+1)
				hill.set_uv(Vector2(point.x,point.z));hill.add_vertex(point)
	hill.generate_normals();var slope:=MeshInstance3D.new();slope.mesh=hill.commit();slope.material_override=Library.rock("talus",3);add_child(slope)
	for i in range(1,Layout.TRAIL.size()):
		var a: Vector3=Layout.TRAIL[i-1];var b: Vector3=Layout.TRAIL[i];var strip:=MeshInstance3D.new();var p:=PlaneMesh.new();p.size=Vector2(1.2,a.distance_to(b)+.2);strip.mesh=p;strip.material_override=Library.rock("sand",1);add_child(strip);strip.position=(a+b)*.5+Vector3(0,.012,0);strip.rotation.y=atan2(b.x-a.x,b.z-a.z)
func refresh() -> void:
	shelves.refresh();slate.refresh()
	for node in pile_visual.get_children(): pile_visual.remove_child(node);node.queue_free()
	for i in counter.pile.size():
		var prop: Node3D=shelves.object(counter.pile[i]);pile_visual.add_child(prop);prop.position=Layout.PILE+Vector3((i%3)*.36-.35,(i/3)*.1,0)
	for i in counter.fish_offer.size():
		var fish:=MeshInstance3D.new();fish.mesh=Library.mesh("res://assets/fish/fish.glb") if ResourceLoader.exists("res://assets/fish/fish.glb") else CapsuleMesh.new();pile_visual.add_child(fish);fish.position=Layout.BARREL+Vector3(i*.1-.2,0,0);fish.scale=Vector3(.2,.2,.2)
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
		"slate": return "Settle" if not counter.pile.is_empty() or not counter.fish_offer.is_empty() else "Slate"
		"board": return "Prices"
		"pile": return "Return last item"
		"barrel": return "Take fish back" if not counter.fish_offer.is_empty() else "Sell smoked fish"
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
			var needed: float=maxf(0,counter.total()-counter.game.dollars-counter.fish_credit())/(counter.visit.gold_price*.92)
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
