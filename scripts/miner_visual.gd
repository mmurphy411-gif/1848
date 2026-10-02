extends Node3D
## Visual-only rig. The parent remains the original capsule-based controller.
const CLIPS := {"idle":4.0,"walk":1.0,"wade":1.2,"pan_enter":2.0,"pan_swirl":2.0,"pan_wash":1.5,"pan_lift":1.5,"pan_exit":1.0,"fish_idle":3.0,"cast":1.2,"fish_wait":4.0,"strike":.4,"fight":1.0,"land":2.0,"gather":2.0,"tend_fire":2.0,"cook":3.0,"eat":3.0,"lie_down":2.0}
const FISH_CLIPS := ["fish_idle","cast","fish_wait","strike","fight","land"]
const CAMP_CLIPS := ["gather","tend_fire","cook","eat","lie_down"]
const EXPEDITION_CLIPS := ["spear","rifle"]
const MINING_CLIPS := ["crevice","spoon","shovel","pick","rock"]
var activity_clip := ""
var activity_rate := 1.0
var handline_attachment: BoneAttachment3D
var right_hand: BoneAttachment3D
var handline: Node3D
var physical_pan: Node3D
var eating_pan: MeshInstance3D
var rod_visual: Node3D
var pack_visual: Node3D
var pack_stage := 0
var equipment: Dictionary = {}
var equipment_overrides: Dictionary = {}
var carry_grips: Dictionary = {}
var cast_elapsed := 0.0
const SWIRL_VARIANTS := ["pan_swirl", "pan_swirl_2", "pan_swirl_3"]
var miner: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var pan_playback: AnimationNodeStateMachinePlayback
var pan_attachment: BoneAttachment3D
var sack_attachment: BoneAttachment3D
var sack_visual: Node3D
var sack_material: ShaderMaterial
var sack_sway := 0.0
var sack_time := 0.0
var splashes: Array[GPUParticles3D] = []
var wet_materials: Array[ShaderMaterial] = []
var wet_line := 0.0
var wet_peak := 0.0
var drying_elapsed := 0.0
var locomotion_rate := 1.0
var active_pan := ""
var exit_elapsed := 0.0
var turn_elapsed := .3
var turn_start := 0.0
var turn_target := 0.0
var water_material: ShaderMaterial
@onready var walker: CharacterBody3D = get_parent()

func _ready() -> void:
	# A dedicated loop keeps the skillet at the coals throughout the recipe.
	miner = preload("res://assets/miner/intrepid/miner.glb").instantiate()
	miner.name = "Miner"
	miner.rotation.y = PI
	add_child(miner)
	skeleton = miner.find_children("*","Skeleton3D",true,false)[0]
	player = miner.find_children("*","AnimationPlayer",true,false)[0]
	var store_clips: Node3D=load("res://assets/store/miner_clips.glb").instantiate()
	var clips: AnimationPlayer=store_clips.find_children("*","AnimationPlayer",true,false)[0]
	for clip in ["pour","take"]:
		player.get_animation_library("").add_animation(clip,clips.get_animation(clip).duplicate())
	player.get_animation("pour").loop_mode=Animation.LOOP_LINEAR
	store_clips.free()
	var mining_clips: Node3D=load("res://assets/mining/miner_clips.glb").instantiate()
	var mining_player: AnimationPlayer=mining_clips.find_children("*","AnimationPlayer",true,false)[0]
	for clip in MINING_CLIPS:
		var animation := mining_player.get_animation(clip).duplicate() as Animation
		animation.loop_mode=Animation.LOOP_LINEAR
		player.get_animation_library("").add_animation(clip,animation)
	mining_clips.free()
	var expedition_clips: Node3D=load("res://assets/expedition/miner_clips.glb").instantiate()
	var expedition_player: AnimationPlayer=expedition_clips.find_children("*","AnimationPlayer",true,false)[0]
	for clip in EXPEDITION_CLIPS:
		var animation:=expedition_player.get_animation(clip).duplicate() as Animation
		animation.loop_mode=Animation.LOOP_LINEAR
		player.get_animation_library("").add_animation(clip,animation)
	expedition_clips.free()
	# Blender's frame-one offset is cropped to the table's exact clip lengths.
	for name in CLIPS:
		var animation := player.get_animation(name)
		animation.length = CLIPS[name]
		animation.loop_mode = Animation.LOOP_LINEAR if name in ["idle","walk","wade","pan_swirl","fish_idle","fish_wait","fight","cook"] else Animation.LOOP_NONE
	for name in SWIRL_VARIANTS.slice(1):
		player.get_animation(name).length = 2.0
		player.get_animation(name).loop_mode = Animation.LOOP_LINEAR
	_setup_intrepid_materials()
	var grip_data: Dictionary = preload("res://assets/miner/intrepid/grips.gd").ROTATIONS
	for bone in grip_data:
		var q: Array = grip_data[bone]
		# Blender stores a delta from rest; Godot expects the complete local bone rotation.
		var rest_rotation := skeleton.get_bone_rest(skeleton.find_bone(bone)).basis.get_rotation_quaternion()
		carry_grips[bone] = rest_rotation * Quaternion(q[1], q[2], q[3], q[0])
	pan_attachment = _attachment("PanSocket","pan_socket")
	physical_pan = preload("res://assets/miner/pan.glb").instantiate()
	pan_attachment.add_child(physical_pan)
	handline_attachment=_attachment("HandlineSocket","LeftHand")
	right_hand=_attachment("FishSocket","RightHand")
	handline=preload("res://assets/miner/handline.glb").instantiate()
	handline_attachment.add_child(handline)
	handline.hide()
	rod_visual=load("res://assets/miner/rod.glb").instantiate();handline_attachment.add_child(rod_visual);rod_visual.hide()
	rod_visual.rotation.x=PI
	# Skinned pack includes its fitted harness; it must not be scaled away from the shoulders.
	pack_visual = Node3D.new();pack_visual.name = "TravelPack";miner.add_child(pack_visual)
	var pack_mesh: MeshInstance3D = equipment.wear_pack
	pack_mesh.reparent(pack_visual, true);pack_mesh.skeleton = pack_mesh.get_path_to(skeleton)
	equipment.wear_pack = pack_visual
	sack_attachment = _attachment("SackSocket","Hips")
	sack_visual = preload("res://assets/miner/sack.glb").instantiate()
	sack_attachment.add_child(sack_visual)
	sack_visual.position = Vector3(.24,.025,-.14)
	sack_material = ShaderMaterial.new()
	sack_material.shader = preload("res://shaders/sack.gdshader")
	for mesh in sack_visual.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = sack_material
	get_node("/root/Sack").changed.connect(_sack_changed)
	_sack_changed(get_node("/root/Sack").ounces)
	_build_tree()
	var water:=walker.get_parent().get_node_or_null("Greybox/River/WaterSurface")
	if water: water_material=water.material_override
	for side in ["Left","Right"]: _splash(side)
	# Advance after controller and panner so result transforms/camera agree.
	process_physics_priority = 10
	_update_equipment()

func _setup_intrepid_materials() -> void:
	var keys := {"Pack":"wear_pack", "Satchel":"wear_satchel", "Canteen":"wear_canteen", "Pickaxe":"carry_pickaxe", "TravelPan":"carry_pan"}
	for node: MeshInstance3D in miner.find_children("*", "MeshInstance3D", true, false):
		node.lod_bias = 1.0
		# Expanded bounds prevent crouches and high-reaching activity poses from being culled.
		node.extra_cull_margin = 1.25
		for surface in node.mesh.get_surface_count():
			var source := node.mesh.surface_get_material(surface) as StandardMaterial3D
			assert(source != null and source.resource_name.begins_with("Intrepid_"))
			var part := source.resource_name.trim_prefix("Intrepid_")
			var material := ShaderMaterial.new()
			material.shader = preload("res://shaders/intrepid_miner.gdshader")
			material.set_shader_parameter("albedo_atlas", source.albedo_texture)
			material.set_shader_parameter("normal_atlas", source.normal_texture)
			material.set_shader_parameter("surface_atlas", source.roughness_texture)
			material.set_shader_parameter("hair_cutout", part == "Hair")
			material.set_shader_parameter("wettable", part in ["Body", "Pack", "Satchel"])
			node.set_surface_override_material(surface, material)
			wet_materials.append(material)
			if keys.has(part):equipment[keys[part]] = node

## Override any of the five loadout items; clearing an override restores inventory/activity behavior.
func set_equipment(item: String, enabled: bool) -> void:
	assert(item in equipment, "Unknown equipment: " + item)
	equipment_overrides[item] = enabled
	_update_equipment()

func clear_equipment_override(item: String) -> void:
	equipment_overrides.erase(item)
	_update_equipment()

func _update_equipment() -> void:
	var inventory: Dictionary = get_node("/root/GameState").inventory
	# A lone miner carries his provisions; an outfit's pantry stays at camp (2.0).
	var Pack := preload("res://scripts/pack.gd")
	var pounds := Pack.weight(inventory) if get_node("/root/GameState").crew.hands.is_empty() else Pack.field_weight(inventory)
	pack_stage = 0 if pounds <= 5 else 1 if pounds < 15 else 2 if pounds < 30 else 3
	var defaults := {"wear_pack":pack_stage > 0, "wear_satchel":true, "wear_canteen":true, "carry_pickaxe":inventory.get("pick", false), "carry_pan":true}
	if activity_clip in ["lie_down", "cook", "eat", "tend_fire"]:
		for item in ["wear_pack", "wear_satchel", "wear_canteen"]:defaults[item] = false
	var hands_free := activity_clip.is_empty() and active_pan.is_empty()
	for item in equipment:
		equipment[item].visible = equipment_overrides.get(item, defaults[item]) and (hands_free or not item.begins_with("carry_"))
	# The working pan uses the established two-handed socket and result geometry during panning.
	physical_pan.visible = not active_pan.is_empty() and activity_clip.is_empty()

func _apply_carry_grips() -> void:
	if not activity_clip.is_empty() or not active_pan.is_empty():return
	for bone in carry_grips:
		var item := "carry_pan" if String(bone).begins_with("Left") else "carry_pickaxe"
		if equipment[item].visible:
			skeleton.set_bone_pose_rotation(skeleton.find_bone(bone), carry_grips[bone])

func _attachment(label: String,bone: String) -> BoneAttachment3D:
	var attachment := BoneAttachment3D.new()
	attachment.name = label
	skeleton.add_child(attachment)
	attachment.bone_name = bone
	return attachment

func _build_tree() -> void:
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	var root_machine := AnimationNodeStateMachine.new()
	for name in ["idle","walk","wade"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = name
		root_machine.add_node(name,clip)
	var pan_machine := AnimationNodeStateMachine.new()
	for name in ["pan_enter","pan_swirl","pan_swirl_2","pan_swirl_3","pan_wash","pan_lift","pan_exit"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = name
		pan_machine.add_node(name,clip)
	root_machine.add_node("pan",pan_machine)
	for group in ["fishing","camp"]:
		var machine := AnimationNodeStateMachine.new()
		for name in FISH_CLIPS if group=="fishing" else CAMP_CLIPS:
			var clip := AnimationNodeAnimation.new()
			clip.animation=name
			machine.add_node(name,clip)
		root_machine.add_node(group,machine)
	for name in ["pour","take"]+MINING_CLIPS+EXPEDITION_CLIPS:
		var clip:=AnimationNodeAnimation.new();clip.animation=name
		var machine: AnimationNodeStateMachine=root_machine.get_node("camp");machine.add_node(name,clip)
	for a in ["idle","walk","wade","pan","fishing","camp"]:
		for b in ["idle","walk","wade","pan","fishing","camp"]:
			if a==b: continue
			var transition := AnimationNodeStateMachineTransition.new()
			transition.xfade_time = .15
			root_machine.add_transition(a,b,transition)
	tree.tree_root = root_machine
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.active = true
	playback = tree.get("parameters/playback")
	pan_playback = tree.get("parameters/pan/playback")
	playback.start("idle")
	tree.advance(0)

func turn_to(yaw: float) -> void:
	turn_start = rotation.y
	turn_target = yaw
	turn_elapsed = 0

func play_pan(clip: String, cycle := 0) -> void:
	active_pan = clip
	exit_elapsed = 0
	playback.start("pan",true)
	pan_playback.start(SWIRL_VARIANTS[clampi(cycle,0,2)] if clip=="pan_swirl" else clip,true)
	tree.advance(0)
	_update_equipment()

func _physics_process(delta: float) -> void:
	if not tree: return
	var inventory: Dictionary=get_node("/root/GameState").inventory
	_update_equipment()
	rod_visual.visible=inventory.get("rod",false) and activity_clip in FISH_CLIPS
	if rod_visual.visible: handline.hide()
	if turn_elapsed<.3:
		turn_elapsed = minf(.3,turn_elapsed+delta)
		rotation.y = lerp_angle(turn_start,turn_target,smoothstep(0,.3,turn_elapsed))
	var speed := Vector2(walker.velocity.x,walker.velocity.z).length()
	var depth: float = walker.river.depth_at(walker.global_position)
	if depth>=wet_line and depth>0:
		wet_line=depth
		wet_peak=depth
		drying_elapsed=0
	else:
		drying_elapsed=minf(60,drying_elapsed+delta)
		wet_line=maxf(depth,wet_peak*(1.0-drying_elapsed/60.0))
	for material in wet_materials:
		material.set_shader_parameter("wet_line",wet_line)
		material.set_shader_parameter("feet_y",walker.global_position.y)
	for particles in splashes:
		particles.emitting=depth>.05 and speed>.3
		particles.global_position = Vector3(particles.get_parent().global_position.x,get_node("/root/GameState").water_level()+.015,particles.get_parent().global_position.z)
		particles.global_basis = Basis.IDENTITY
	if active_pan=="pan_exit":
		exit_elapsed+=delta
		if exit_elapsed>=1.0: active_pan=""
	if not activity_clip.is_empty():
		tree.advance(delta*activity_rate)
	elif active_pan.is_empty():
		var next := "idle" if speed<.06 else "wade" if depth>.05 else "walk"
		if playback.get_current_node()!=next: playback.travel(next)
		locomotion_rate = 1.0 if next=="idle" else speed/(1.05 if next=="wade" else 2.4)
		tree.advance(delta*locomotion_rate)
	else:
		tree.advance(delta*walker.panner.speed_scale)
	_apply_carry_grips()
	if rod_visual.visible and activity_clip=="cast":
		cast_elapsed+=delta
		var forearm:=skeleton.find_bone("LeftLowerArm")
		var flick:=deg_to_rad(40)*sin(PI*clampf(cast_elapsed/1.2,0,1))
		skeleton.set_bone_pose_rotation(forearm,skeleton.get_bone_pose_rotation(forearm)*Quaternion(Vector3.RIGHT,flick))
	_update_shin_foam(depth)
	$Pan.global_transform = pan_attachment.global_transform
	if is_instance_valid(eating_pan) and eating_pan.visible: eating_pan.global_rotation=Vector3.ZERO
	# The fabric poke hangs under gravity rather than rotating with pelvic bend.
	sack_time += delta*locomotion_rate
	sack_sway = move_toward(sack_sway,minf(speed/2.4,1.0),delta*3.0)
	sack_visual.global_rotation = Vector3(0,rotation.y,sin(sack_time*TAU*2)*.055*sack_sway)

func _update_shin_foam(depth: float) -> void:
	if water_material==null: return
	# A depth-buffer intersection was enough for the capsule but loses most
	# of the narrow shin collar. Place a small surface ring at each real leg.
	var contacts := PackedVector4Array()
	for side in ["Left","Right"]:
		var knee := (skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(side+"LowerLeg"))).origin
		var ankle := (skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(side+"Foot"))).origin
		var shin := ankle.lerp(knee,clampf((get_node("/root/GameState").water_level()-ankle.y)/maxf(.01,knee.y-ankle.y),0,1))
		contacts.append(Vector4(shin.x,shin.z,0,1 if depth>.05 and is_visible_in_tree() else 0))
	water_material.set_shader_parameter("shin_contacts",contacts)

func _sack_changed(_ounces: float) -> void:
	if not is_inside_tree(): return
	var stage: int = get_node("/root/Sack").stage()
	sack_visual.scale = Vector3(.65+.12*stage,.85+.075*stage,.28+.20*stage)
	sack_material.set_shader_parameter("growth",sack_visual.scale)

func play_activity(clip: String) -> void:
	activity_clip=clip
	cast_elapsed=0
	activity_rate=1.0
	var group := "fishing" if clip in FISH_CLIPS else "camp"
	playback.start(group,true)
	var machine: AnimationNodeStateMachinePlayback=tree.get("parameters/%s/playback" % group)
	machine.start(clip,true)
	physical_pan.hide()
	handline.visible=group=="fishing"
	if clip=="eat" and eating_pan==null:
		var prop: MeshInstance3D=walker.get_parent().get_node("Camp").props.Skillet.get_child(0)
		eating_pan=MeshInstance3D.new();eating_pan.mesh=prop.mesh
		handline_attachment.add_child(eating_pan)
		eating_pan.position=Vector3(0,.015,0)
	if eating_pan: eating_pan.visible=clip=="eat"
	tree.advance(0)
	_update_equipment()

func fishing_origin() -> Vector3:
	return rod_visual.to_global(Vector3(.09,1.8,0)) if rod_visual.visible else handline_attachment.global_position

func mining_grip(side: String) -> Vector3:
	# Center of the curled middle finger, rather than the wrist attachment.
	var knuckle := skeleton.get_bone_global_pose(skeleton.find_bone(side+"MiddleProximal")).origin
	var distal := skeleton.get_bone_global_pose(skeleton.find_bone(side+"MiddleDistal"))
	var tip := distal*Vector3(0,.0382,0)
	return skeleton.to_global((knuckle+tip)*.5)

func stop_activity() -> void:
	activity_clip=""
	active_pan=""
	handline.hide()
	physical_pan.show()
	if eating_pan: eating_pan.hide()
	playback.start("idle",true)
	_update_equipment()

func _splash(side: String) -> void:
	var foot := _attachment(side+"SplashSocket",side+"Foot")
	var particles := GPUParticles3D.new()
	particles.name = side+"Splash"
	particles.amount = 8
	particles.lifetime = .32
	particles.local_coords = false
	particles.emitting = false
	particles.visibility_aabb = AABB(Vector3(-1,-1,-1),Vector3(2,2,2))
	var material := ParticleProcessMaterial.new()
	material.direction = Vector3(0,1,0)
	material.spread = 45
	material.initial_velocity_min = .7
	material.initial_velocity_max = 1.25
	material.gravity = Vector3(0,-9.8,0)
	material.scale_min = .6
	material.scale_max = 1.2
	particles.process_material = material
	var drop := SphereMesh.new()
	drop.radius=.009
	drop.height=.027
	drop.radial_segments=6
	drop.rings=2
	var white := ShaderMaterial.new()
	white.shader=preload("res://shaders/splash.gdshader")
	drop.material=white
	particles.draw_pass_1=drop
	foot.add_child(particles)
	splashes.append(particles)
