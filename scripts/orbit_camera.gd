extends Node3D
## Smoothed orbit with a sphere-tested boom that retracts against terrain and rocks.

@export var target: Node3D
@export var mouse_sensitivity := 0.0022
@export var stick_speed := 1.5
@onready var arm: SpringArm3D = $SpringArm3D

var yaw := -0.65
var pitch := -0.22

func _ready() -> void:
	rotation = Vector3(pitch, yaw, 0)
	global_position = target.global_position + Vector3(0, 1.45, 0)
	arm.add_excluded_object(target.get_rid())
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			get_tree().quit()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -0.85, 0.32)

func _process(delta: float) -> void:
	var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	yaw -= stick.x * stick_speed * delta
	pitch = clampf(pitch - stick.y * stick_speed * delta, -0.85, 0.32)
	var blend := 1.0 - exp(-12.0 * delta)
	rotation.y = lerp_angle(rotation.y, yaw, blend)
	rotation.x = lerpf(rotation.x, pitch, blend)
	global_position = global_position.lerp(target.global_position + Vector3(0, 1.45, 0), blend)
