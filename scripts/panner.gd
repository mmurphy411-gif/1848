extends Node

const Layout = preload("res://scripts/claim_layout.gd")
const GoldMap = preload("res://scripts/gold_map.gd")
const PanResult = preload("res://scripts/pan_result.gd")
const PAN_DURATION := 6.0
const SHOW_DURATION := 3.0
enum State { IDLE, PANNING, SHOWING }

@export var reproducible := false
@onready var walker: CharacterBody3D = get_parent()
@onready var pan: Node3D = walker.get_node("Visual/Pan")
var state := State.IDLE
var elapsed := 0.0
var sampled_density := 0.0
var result: Dictionary = {}
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = hash(walker.position)
	if not reproducible:
		rng.seed ^= Time.get_ticks_usec() ^ int(Time.get_unix_time_from_system())
	pan.hide()

func _input(event: InputEvent) -> void:
	if state == State.SHOWING and event.is_action_pressed("ui_cancel"):
		_finish()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("pan") and not event.is_echo():
		if event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			return # The first uncaptured click only recaptures the mouse.
		start_pan()
		get_viewport().set_input_as_handled()

func can_pan() -> bool:
	var point := walker.global_position
	var inland := point.z - Layout.shore_z(point.x)
	var depth: float = walker.river.depth_at(point)
	var shallows := depth > 0.0 and depth <= 0.45
	var dry_edge := depth == 0.0 and inland >= -0.7 and inland <= 1.5
	return state == State.IDLE and absf(point.x) < 40.0 and point.z <= Layout.back_z(point.x) and (shallows or dry_edge)

func start_pan() -> bool:
	if not can_pan():
		return false
	state = State.PANNING
	elapsed = 0.0
	sampled_density = GoldMap.density_at(walker.position.x, walker.position.z)
	result = PanResult.roll(sampled_density, rng)
	walker.velocity.x = 0.0
	walker.velocity.z = 0.0
	var direction := -Layout.inland_normal(walker.position.x)
	walker.get_node("Visual").rotation.y = atan2(-direction.x, -direction.z)
	pan.clear()
	pan.show()
	return true

func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	elapsed += delta
	if state == State.PANNING:
		if walker.river.depth_at(walker.global_position) > 0.45:
			_reset() # Cancel without awarding the held result.
		elif elapsed >= PAN_DURATION:
			state = State.SHOWING
			elapsed = 0.0
			pan.show_result(result.tier, hash(result))
	if state == State.SHOWING:
		walker.camera_rig.focus(pan.global_transform)
		if elapsed >= SHOW_DURATION:
			_finish()

func _finish() -> void:
	if state != State.SHOWING:
		return
	get_node("/root/Sack").add(result.ounces)
	_reset()

func _reset() -> void:
	state = State.IDLE
	elapsed = 0.0
	result = {}
	pan.hide()
	walker.camera_rig.release_focus()
