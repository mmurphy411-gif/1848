extends Node3D
## Presentation of the immutable season result; the session remains inspectable via F4.
var snow:=GPUParticles3D.new()
var shown:=false
var book_delay:=0.0
@onready var game: Node=get_node("/root/GameState")
@onready var claim: Node3D=get_parent()
func _ready() -> void:
	game.season_finished.connect(begin)
	game.changed.connect(reset_if_rewound)
	snow.amount=420;snow.lifetime=12;snow.preprocess=4;snow.emitting=false
	snow.visibility_aabb=AABB(Vector3(-15,-3,-15),Vector3(30,18,30))
	var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(12,3,12)
	process.direction=Vector3.DOWN;process.spread=15;process.initial_velocity_min=.4;process.initial_velocity_max=.8;process.gravity=Vector3(.10,-.05,.025);process.scale_min=.4;process.scale_max=1
	snow.process_material=process
	var flake:=QuadMesh.new();flake.size=Vector2(.025,.025)
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.84,.88,.9);mat.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;mat.billboard_mode=BaseMaterial3D.BILLBOARD_ENABLED;flake.material=mat
	snow.draw_pass_1=flake;add_child(snow)
func reset_if_rewound() -> void:
	if not game.season_ended and shown:
		shown=false;book_delay=0;snow.emitting=false
		preload("res://scripts/asset_library.gd").terrain().set_shader_parameter("snow_amount",0)
func begin() -> void:
	if shown: return
	shown=true;book_delay=4
	claim.get_node("Daylight/Clock").running=false
	if get_node("/root/Trip").shop!=null: get_node("/root/Trip").home(true)
	claim.get_node("Walker/Fisher").cancel();claim.get_node("Walker/Panner")._reset()
	claim.get_node("Expedition").cancel()
	var activities: Node=claim.get_node("Activities")
	activities.busy=false;activities.action="";activities.fade.color.a=0;activities.cooking_menu=false
	var walker: Node3D=claim.get_node("Walker")
	walker.position=claim.get_node("Camp").work_position()+Vector3(0,0,-1);walker.velocity=Vector3.ZERO
	claim.get_node("Daylight").apply(8)
	claim.get_node("HUD").notify("First snow · November 5, 1848",4)
	snow.global_position=walker.global_position+Vector3.UP*6;snow.emitting=true
	preload("res://scripts/asset_library.gd").terrain().set_shader_parameter("snow_amount",.65)
func _process(delta: float) -> void:
	if game.day>=132 and not game.season_ended: game.finish_season()
	if game.season_ended:
		if not shown: begin()
		claim.get_node("Daylight/Clock").running=false
		if book_delay>0:
			book_delay-=delta
			if book_delay<=0: claim.get_node("Ledger").open_book()
	elif shown:
		shown=false;book_delay=0;snow.emitting=false
		preload("res://scripts/asset_library.gd").terrain().set_shader_parameter("snow_amount",0)
func _unhandled_input(event: InputEvent) -> void:
	if game.season_ended and event.is_action_pressed("interact"):
		claim.get_node("Ledger").open_book();get_viewport().set_input_as_handled()
