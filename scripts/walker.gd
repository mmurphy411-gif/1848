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
var water_depth := 0.0

func _physics_process(delta: float) -> void:
	var axes := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction := Basis(Vector3.UP, camera_rig.rotation.y) * Vector3(axes.x, 0, axes.y)
	water_depth = river.depth_at(global_position)
	var speed := lerpf(WALK_SPEED, WADE_SPEED, smoothstep(0.0, 0.45, water_depth))
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
