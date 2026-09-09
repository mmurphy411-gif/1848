extends CharacterBody3D
## Deliberate walking, grounded on the riverbed, with no run, jump, or swim.

const Boundary = preload("res://scripts/claim_boundary.gd")
const WALK_SPEED := 2.4
const WADE_SPEED := 1.05
const ACCELERATION := 7.0
const GRAVITY := 18.0

@export var camera_rig: Node3D
@export var river: Area3D
@onready var visual: Node3D = $Visual
@onready var panner: Node = $Panner
var water_depth := 0.0

func _physics_process(delta: float) -> void:
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var fisher := get_node_or_null("Fisher")
	var activities := get_parent().get_node_or_null("Activities")
	if activities and activities.holds_at_fire():
		velocity=Vector3.ZERO
		return
	if panner.state != panner.State.IDLE or (fisher and fisher.state>1) or (activities and (activities.busy or activities.ui_open())):
		axes = Vector2.ZERO # Current and gravity remain active during the pan.
	var direction := Basis(Vector3.UP, camera_rig.rotation.y) * Vector3(axes.x, 0, axes.y)
	water_depth = river.depth_at(global_position)
	var wade: float=preload("res://scripts/condition_model.gd").wade_speed(get_node("/root/GameState").condition)
	var speed := lerpf(WALK_SPEED, wade, smoothstep(0.0, 0.45, water_depth))
	var motion := Boundary.guide_motion(global_position, direction * speed, water_depth)
	velocity.x = move_toward(velocity.x, motion.x, ACCELERATION * delta)
	velocity.z = move_toward(velocity.z, motion.z, ACCELERATION * delta)
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()
	if direction.length_squared() > 0.01:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-direction.x, -direction.z), 1.0 - exp(-8.0 * delta))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
