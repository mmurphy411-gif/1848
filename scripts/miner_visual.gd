extends Node3D
## Visual-only rig. The parent remains the original capsule-based controller.
const CLIPS := {"idle":4.0,"walk":1.0,"wade":1.2,"pan_enter":2.0,"pan_swirl":2.0,"pan_wash":1.5,"pan_lift":1.5,"pan_exit":1.0}
var miner: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var pan_playback: AnimationNodeStateMachinePlayback
var pan_attachment: BoneAttachment3D
var sack_attachment: BoneAttachment3D
var sack_visual: Node3D
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
	miner = preload("res://assets/miner/miner.glb").instantiate()
	miner.name = "Miner"
	miner.rotation.y = PI
	add_child(miner)
	skeleton = miner.find_children("*","Skeleton3D",true,false)[0]
	player = miner.find_children("*","AnimationPlayer",true,false)[0]
	# Blender's frame-one offset is cropped to the table's exact clip lengths.
	for name in CLIPS:
		var animation := player.get_animation(name)
		animation.length = CLIPS[name]
		animation.loop_mode = Animation.LOOP_LINEAR if name in ["idle","walk","wade","pan_swirl"] else Animation.LOOP_NONE
	for node in miner.find_children("*","MeshInstance3D",true,false):
		for s in node.mesh.get_surface_count():
			var label: String = ["Linen","Wool","Leather","Skin","Felt","Beard","Suspenders"][s]
			var m := ShaderMaterial.new()
			m.shader = preload("res://shaders/miner.gdshader")
			m.set_shader_parameter("body_albedo",preload("res://assets/miner/body_albedo.png"))
			m.set_shader_parameter("body_normal",preload("res://assets/miner/body_normal.png"))
			m.set_shader_parameter("wettable",label in ["Wool","Leather"])
			m.set_shader_parameter("worn_knees",label=="Wool")
			m.set_shader_parameter("textured",not label in ["Felt","Beard","Suspenders"])
			m.set_shader_parameter("tint",Color(.12,.09,.056) if label=="Felt" else Color(.085,.045,.018) if label=="Beard" else Color(.15,.10,.054))
			node.set_surface_override_material(s,m)
			wet_materials.append(m)
	pan_attachment = _attachment("PanSocket","pan_socket")
	var physical_pan: Node3D = preload("res://assets/miner/pan.glb").instantiate()
	pan_attachment.add_child(physical_pan)
	sack_attachment = _attachment("SackSocket","Hips")
	sack_visual = preload("res://assets/miner/sack.glb").instantiate()
	sack_attachment.add_child(sack_visual)
	sack_visual.position = Vector3(.195,.025,.015)
	get_node("/root/Sack").changed.connect(_sack_changed)
	_sack_changed(0)
	_build_tree()
	water_material = walker.get_parent().get_node("Greybox/River/WaterSurface").material_override
	for side in ["Left","Right"]: _splash(side)
	# Advance after controller and panner so result transforms/camera agree.
	process_physics_priority = 10

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
	for name in ["pan_enter","pan_swirl","pan_wash","pan_lift","pan_exit"]:
		var clip := AnimationNodeAnimation.new()
		clip.animation = name
		pan_machine.add_node(name,clip)
	root_machine.add_node("pan",pan_machine)
	for a in ["idle","walk","wade","pan"]:
		for b in ["idle","walk","wade","pan"]:
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

func play_pan(clip: String) -> void:
	active_pan = clip
	exit_elapsed = 0
	playback.start("pan",true)
	pan_playback.start(clip,true)
	tree.advance(0)

func _physics_process(delta: float) -> void:
	if not tree: return
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
		particles.global_position = Vector3(particles.get_parent().global_position.x,.015,particles.get_parent().global_position.z)
		particles.global_basis = Basis.IDENTITY
	if active_pan=="pan_exit":
		exit_elapsed+=delta
		if exit_elapsed>=1.0: active_pan=""
	if active_pan.is_empty():
		var next := "idle" if speed<.06 else "wade" if depth>.05 else "walk"
		if playback.get_current_node()!=next: playback.travel(next)
		locomotion_rate = 1.0 if next=="idle" else speed/(1.05 if next=="wade" else 2.4)
		tree.advance(delta*locomotion_rate)
	else:
		tree.advance(delta)
	_update_shin_foam(depth)
	$Pan.global_transform = pan_attachment.global_transform
	# The fabric poke hangs under gravity rather than rotating with pelvic bend.
	sack_visual.global_rotation = Vector3(0,rotation.y,0)

func _update_shin_foam(depth: float) -> void:
	# A depth-buffer intersection was enough for the capsule but loses most
	# of the narrow shin collar. Place a small surface ring at each real leg.
	var contacts := PackedVector4Array()
	for side in ["Left","Right"]:
		var knee := (skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(side+"LowerLeg"))).origin
		var ankle := (skeleton.global_transform*skeleton.get_bone_global_pose(skeleton.find_bone(side+"Foot"))).origin
		var shin := ankle.lerp(knee,clampf(-ankle.y/maxf(.01,knee.y-ankle.y),0,1))
		contacts.append(Vector4(shin.x,shin.z,0,1 if depth>.05 and is_visible_in_tree() else 0))
	water_material.set_shader_parameter("shin_contacts",contacts)

func _sack_changed(_ounces: float) -> void:
	var stage: int = get_node("/root/Sack").stage()
	sack_visual.scale = Vector3(.65+.12*stage,.85+.075*stage,.28+.20*stage)

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
