extends Node3D
## Smoothed orbit with a sphere-tested boom that retracts against terrain and rocks.

@export var target: Node3D
@export var mouse_sensitivity := 0.0022
@export var stick_speed := 1.5
@onready var arm: SpringArm3D = $SpringArm3D

var yaw := -0.65
var pitch := -0.22
const FOCUS_DURATION := 0.4
var focused := false
var _focus_transform := Transform3D.IDENTITY
var _focus_blend := 0.0
var _orbit_position := Vector3.ZERO
var _orbit_rotation := Vector3.ZERO
var _spring_length := 4.6
var _shoulder := Vector3.ZERO
var _spring_margin := 0.18

func _ready() -> void:
	rotation = Vector3(pitch, yaw, 0)
	global_position = target.global_position + Vector3(0, 1.45, 0)
	_orbit_position = global_position
	_orbit_rotation = rotation
	_spring_length = arm.spring_length
	_shoulder = arm.position
	_spring_margin = arm.margin
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
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not focused and _focus_blend == 0.0:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -0.85, 0.32)

func _process(delta: float) -> void:
	if not focused and _focus_blend == 0.0:
		var stick := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		yaw -= stick.x * stick_speed * delta
		pitch = clampf(pitch - stick.y * stick_speed * delta, -0.85, 0.32)
	var blend := 1.0 - exp(-12.0 * delta)
	_orbit_rotation.y = lerp_angle(_orbit_rotation.y, yaw, blend)
	_orbit_rotation.x = lerpf(_orbit_rotation.x, pitch, blend)
	_orbit_position = _orbit_position.lerp(target.global_position + Vector3(0, 1.45, 0), blend)
	_focus_blend = move_toward(_focus_blend, 1.0 if focused else 0.0, delta / FOCUS_DURATION)
	var weight := smoothstep(0.0, 1.0, _focus_blend)
	var orbit := Transform3D(Basis.from_euler(_orbit_rotation), _orbit_position)
	global_transform = orbit.interpolate_with(_focus_transform, weight)
	arm.position = _shoulder.lerp(Vector3.ZERO, weight)
	arm.spring_length = lerpf(_spring_length, 0.0, weight)
	arm.margin = lerpf(_spring_margin, 0.0, weight)

func focus(pan_transform: Transform3D) -> void:
	focused = true
	# Look across the raised pan from beside the shoulder. The socket's bone
	# basis is not a camera frame; using it can aim through the miner's capsule.
	var forward := Vector3(pan_transform.origin.x-target.global_position.x,0,pan_transform.origin.z-target.global_position.z).normalized()
	var right := forward.cross(Vector3.UP)
	var camera_point := pan_transform.origin + right*.50 + Vector3.UP*.30 - forward*.15
	_focus_transform = Transform3D(Basis.IDENTITY, camera_point).looking_at(pan_transform.origin, Vector3.UP)

func release_focus() -> void:
	focused = false
