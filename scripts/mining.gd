extends Node3D
## Owns the live action and scene props; season records remain in GameState.
const Model = preload("res://scripts/mining_model.gd")
const Layout = preload("res://scripts/claim_layout.gd")
var selected_slab := -1
var source := Vector3.ZERO
var build_point := Vector3.ZERO
var action_elapsed := 0.0
var rocker := StaticBody3D.new()
var cradle: Node3D
var tool: Node3D
var tool_kind := ""
var gravel := Node3D.new()
var sound := AudioStreamPlayer3D.new()
var sound_tick := -1
var stance_from := Vector3.ZERO
var stance_to := Vector3.ZERO
@onready var game: Node = get_node("/root/GameState")
@onready var walker: CharacterBody3D = get_parent().get_node("Walker")
@onready var activities: Node = get_parent().get_node("Activities")
@onready var visual: Node3D = walker.get_node("Visual")

func _ready() -> void:
	rocker.name="Rocker";add_child(rocker)
	cradle=preload("res://assets/mining/rocker.glb").instantiate();rocker.add_child(cradle)
	for mesh in cradle.find_children("*","MeshInstance3D",true,false):
		for surface in mesh.mesh.get_surface_count():
			var original: Material=mesh.mesh.surface_get_material(surface)
			if original and ("pine" in original.resource_name or "edges" in original.resource_name):
				var material := ShaderMaterial.new();material.shader=preload("res://shaders/mining_wood.gdshader")
				mesh.set_surface_override_material(surface,material)
	cradle.add_child(gravel)
	for i in 15:
		var stone := MeshInstance3D.new();var pebble := SphereMesh.new();pebble.radius=.035;pebble.height=.05;pebble.radial_segments=6;pebble.rings=3
		stone.mesh=pebble;stone.material_override=preload("res://scripts/asset_library.gd").rock("gravel",.5)
		gravel.add_child(stone);stone.position=Vector3(-.16+(i%5)*.077,.45+.013*sin(i*2.2),-.15-(i/5)*.12)
		stone.scale=Vector3.ONE*(.75+.3*sin(i*1.7));stone.rotation.y=i*2.4
	gravel.hide()
	sound.bus="Foley";sound.unit_size=4;sound.volume_db=-20;add_child(sound)
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new();box.size=Vector3(.60,.60,1.4)
	collider.shape=box;collider.position.y=.3;rocker.add_child(collider)
	game.changed.connect(refresh)
	refresh()
	process_physics_priority=30

func refresh() -> void:
	if not is_inside_tree(): return
	rocker.visible=game.mining.rocker_built
	rocker.collision_layer=1 if rocker.visible else 0
	if rocker.visible:
		rocker.global_position=game.mining.rocker_position
		rocker.rotation.y=atan2(Layout.inland_normal(rocker.position.x).x,Layout.inland_normal(rocker.position.x).z)

func focus_site(kind: String) -> void:
	var p := Model.slab_point(0)+Vector3(0,0,.85) if kind=="crevice" else Vector3(0,0,walker.river.shore_z(0)+1.8)
	if kind=="rocker" and game.mining.rocker_built: p=rocker.to_global(Vector3(1.0,0,.05))
	p.y=Layout.height_at(p.x,p.z)+.04
	walker.global_position=p;walker.velocity=Vector3.ZERO
	visual.rotation.y=0;visual.turn_elapsed=.3
	walker.camera_rig.yaw=-.45;walker.camera_rig.pitch=-.4

func slab_nearby() -> int:
	for i in Layout.BEDROCK.size():
		var delta := Model.slab_point(i)-walker.global_position
		if Vector2(delta.x,delta.z).length()<1.35: return i
	return -1

func candidate() -> Vector3:
	var p := walker.global_position-visual.global_basis.z*1.2
	p.y=Layout.height_at(p.x,p.z)+.02
	return p

func target() -> String:
	var slab := slab_nearby()
	if slab>=0 and Model.exposed(slab,game.water_level()): return "crevice"
	if game.mining.rocker_built and walker.global_position.distance_to(rocker.global_position)<2.0: return "rocker"
	if game.inventory.get("rocker",false) and not game.mining.rocker_built and Model.rocker_site(candidate(),game.water_level()): return "build"
	return ""

func prompt() -> String:
	match target():
		"crevice":
			if not game.inventory.get("crowbar",false): return "Crevice · crowbar and horn spoon needed"
			return "Crevice worked out" if game.mining.taken[slab_nearby()]>=Model.reserve(slab_nearby(),game.seed)-.00001 else "Work crevice"
		"build": return "Build rocker"
		"rocker":
			if not Model.rocker_site(rocker.global_position,game.water_level()): return "Move rocker · water has shifted"
			return "Load and rock gravel" if game.inventory.get("shovel",false) else "Rocker · shovel needed"
	return ""

func interact() -> bool:
	var kind := target()
	if kind=="": return false
	if kind=="crevice":
		selected_slab=slab_nearby()
		if not game.inventory.get("crowbar",false) or game.mining.taken[selected_slab]>=Model.reserve(selected_slab,game.seed)-.00001: return true
		source=Model.slab_point(selected_slab)
		_begin("crevice","crevice",Model.CREVICE_SECONDS)
	elif kind=="build":
		build_point=candidate();source=build_point
		_begin("build_rocker","shovel",6.0)
	elif kind=="rocker":
		if not Model.rocker_site(rocker.global_position,game.water_level()):
			game.mining.rocker_built=false;game.event("Moved the cradle out of the old water.");return true
		if not game.inventory.get("shovel",false): return true
		var stance := rocker.to_global(Vector3(1.0,0,.05))
		stance.y=Layout.height_at(stance.x,stance.z)+.025
		if not _can_stand(stance):
			get_parent().get_node("HUD").notify("Walk around to the handle");return true
		source=walker.global_position
		_begin("rocker","pick" if game.inventory.get("pick",false) else "shovel",Model.load_seconds(game.inventory)+Model.ROCK_SECONDS)
		stance_to=stance
		visual.turn_to(rocker.global_rotation.y+PI/2)
	return true

func _can_stand(point: Vector3) -> bool:
	var lift := Vector3.UP*.25
	if walker.test_move(walker.global_transform,lift): return false
	var raised := walker.global_transform;raised.origin+=lift
	var travel := point-walker.global_position;travel.y=0
	if walker.test_move(raised,travel): return false
	var query := PhysicsShapeQueryParameters3D.new()
	var shape: CollisionShape3D=walker.get_node("CollisionShape3D")
	query.shape=shape.shape;query.transform=walker.global_transform*shape.transform
	query.transform.origin+=point-walker.global_position;query.collision_mask=1
	query.exclude=[walker.get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _begin(kind: String, clip: String, seconds: float) -> void:
	action_elapsed=0;sound_tick=-1
	stance_from=walker.global_position;stance_to=stance_from
	walker.velocity=Vector3.ZERO
	var delta := (rocker.global_position if kind=="rocker" else source)-walker.global_position
	visual.turn_to(atan2(-delta.x,-delta.z))
	activities.start(kind,clip,seconds)
	_show_tool("crowbar" if kind=="crevice" else "pick" if clip=="pick" else "shovel")

func _show_tool(name: String) -> void:
	tool_kind=name
	if is_instance_valid(tool): tool.queue_free();tool=null
	if name=="": return
	tool=load("res://assets/mining/"+name+".glb").instantiate()
	visual.right_hand.add_child(tool)
	# Local +Y of the baked asset follows the hand's grip; hand pose supplies reach.
	tool.position=Vector3(0,-.60,0)
	if name=="spoon": tool.position=Vector3(0,-.12,0)

func _physics_process(delta: float) -> void:
	if not activities.busy or not activities.action in ["crevice","rocker","build_rocker"]: return
	var kind: String=activities.action
	if (kind=="crevice" and not Model.exposed(selected_slab,game.water_level())) or (kind=="rocker" and not Model.rocker_site(rocker.global_position,game.water_level())) or walker.river.depth_at(walker.global_position)>walker.wade_limit():
		cancel();return
	action_elapsed+=delta
	walker.global_position=stance_from.lerp(stance_to,smoothstep(0,.35,action_elapsed))
	walker.velocity=Vector3.ZERO
	if kind=="crevice" and action_elapsed>Model.CREVICE_SECONDS*.6 and visual.activity_clip!="spoon":
		visual.play_activity("spoon");_show_tool("spoon")
	if kind=="rocker":
		var load_time := Model.load_seconds(game.inventory)
		if action_elapsed>=load_time:
			if visual.activity_clip!="rock": visual.play_activity("rock");_show_tool("")
			cradle.rotation.z=sin((action_elapsed-load_time)*PI*1.3)*.10
		elif action_elapsed>=load_time*.45 and visual.activity_clip=="pick":
			visual.play_activity("shovel");_show_tool("shovel")
		gravel.visible=action_elapsed>load_time*.5
	_pose_tool()
	var tick := int(action_elapsed/2)
	if tick!=sound_tick and get_parent().get_node("Soundscape").active:
		sound_tick=tick;sound.global_position=walker.global_position
		sound.stream=load("res://assets/audio/%s_%d.wav" % ["wash" if visual.activity_clip=="rock" else "scoop",tick%3]);sound.play()

func _pose_tool() -> void:
	if not is_instance_valid(tool): return
	var hand: Vector3=visual.mining_grip("Right")
	var upper: Vector3=visual.mining_grip("Left")
	var shaft_axis := (upper-hand).normalized()
	var shaft_basis := Basis(Quaternion(Vector3.UP,shaft_axis))
	if tool_kind=="crowbar":
		tool.global_basis=shaft_basis
		var reach: float=(hand.y-Layout.height_at(hand.x,hand.z)-.035)/maxf(.3,shaft_axis.y)
		tool.global_position=hand-shaft_axis*reach
	elif tool_kind=="spoon":
		tool.global_basis=Basis(Vector3.RIGHT,PI)
		tool.global_position=hand
	elif tool_kind=="pick":
		tool.global_basis=shaft_basis*Basis(Vector3.RIGHT,PI)
		tool.global_position=hand+shaft_axis*.25
	elif tool_kind=="shovel":
		tool.global_basis=shaft_basis
		tool.global_position=hand-shaft_axis*.65

func complete(kind: String) -> void:
	if kind=="crevice" and Model.exposed(selected_slab,game.water_level()):
		var ounces := Model.crevice(selected_slab,game.seed,game.mining.taken[selected_slab],game.mining.crevice_actions[selected_slab])
		game.mining.taken[selected_slab]+=ounces;game.mining.crevice_actions[selected_slab]+=1
		_award(ounces,"Cleaned a bedrock crevice")
	elif kind=="build_rocker" and Model.rocker_site(build_point,game.water_level()):
		game.mining.rocker_position=build_point;game.mining.rocker_built=true
		game.event("Set the cradle beside running water.")
	elif kind=="rocker" and Model.rocker_site(rocker.global_position,game.water_level()):
		var Crew=preload("res://scripts/crew_model.gd")
		var ounces: float = Model.rocker_yield(source,game.seed,game.mining.rocker_actions)*Crew.remaining(game.crew.worked,source.x,source.z)
		Crew.take(game.crew.worked,source.x,source.z,ounces)
		game.mining.rocker_actions+=1;_award(ounces,"Washed a cradle load")
	_cleanup()

func _award(ounces: float, label: String) -> void:
	get_node("/root/Sack").add(ounces)
	game.event("%s: %.3f oz." % [label,ounces])
	get_parent().get_node("HUD").notify("%.3f oz" % ounces,3)

func _cleanup() -> void:
	if is_instance_valid(tool): tool.queue_free();tool=null
	cradle.rotation.z=0
	gravel.hide();sound.stop()

func cancel() -> void:
	_cleanup();activities.busy=false;activities.action="";visual.stop_activity()
	get_parent().get_node("HUD").notify("Work stopped")
