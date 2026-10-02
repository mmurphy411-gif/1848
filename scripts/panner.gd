extends Node

const Layout = preload("res://scripts/claim_layout.gd")
const GoldMap = preload("res://scripts/gold_map.gd")
const PanResult = preload("res://scripts/pan_result.gd")
const SWIRL_CYCLES := 3
const PAN_DURATION := 2.0 + SWIRL_CYCLES * 2.0 + 1.5 + 1.5
const SEGMENTS := ["pan_enter", "pan_swirl", "pan_swirl", "pan_swirl", "pan_wash", "pan_lift"]
const LENGTHS := [2.0, 2.0, 2.0, 2.0, 1.5, 1.5]
var segment := ""
var segment_index := -1
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
var speed_scale := 1.0
const ConditionModel=preload("res://scripts/condition_model.gd")
const Crew=preload("res://scripts/crew_model.gd")
var sample_point := Vector3.ZERO

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
	if get_node("/root/GameState").season_ended: return false
	var fisher := walker.get_node_or_null("Fisher")
	if fisher and fisher.state!=0: return false
	var activities := walker.get_parent().get_node_or_null("Activities")
	if activities and (activities.busy or activities.ui_open()): return false
	var point := walker.global_position
	return state == State.IDLE and walker.river.work_edge(point,walker.wade_limit())

func start_pan() -> bool:
	if not can_pan():
		return false
	state = State.PANNING
	elapsed = 0.0
	# Worked ground pans leaner; an untouched bar matches the geological map exactly.
	var crew: Dictionary = get_node("/root/GameState").crew
	sampled_density = Crew.channel_worked_density(crew, walker.position.x, walker.position.z) if Crew.in_channel(crew, walker.position.x, walker.position.z) else Crew.worked_density(crew.worked, walker.position.x, walker.position.z)
	result = PanResult.roll(sampled_density, rng)
	var condition: float=get_node("/root/GameState").condition
	speed_scale=ConditionModel.speed(condition)
	var demoted := ConditionModel.demote(result.tier,condition,rng.randf() if condition<40 else 1.0)
	if demoted!=result.tier:
		result.tier=demoted
		var yields := [Vector2.ZERO,PanResult.SPECKS,PanResult.COLOR,PanResult.GOOD]
		result.ounces=rng.randf_range(yields[demoted].x,yields[demoted].y)
	sample_point = walker.global_position
	walker.velocity.x = 0.0
	walker.velocity.z = 0.0
	var direction := -Layout.inland_normal(walker.position.x)
	walker.get_node("Visual").turn_to(atan2(-direction.x, -direction.z))
	segment_index = 0
	segment = SEGMENTS[0]
	walker.get_node("Visual").play_pan(segment)
	walker.camera_rig.begin_panning()
	pan.clear()
	pan.show()
	return true

func _physics_process(delta: float) -> void:
	if state == State.IDLE:
		return
	elapsed += delta*(speed_scale if state==State.PANNING else 1.0)
	if state == State.PANNING:
		var end := 0.0
		for i in LENGTHS.size():
			end += LENGTHS[i]
			if elapsed < end:
				if segment_index != i:
					segment_index = i
					segment = SEGMENTS[i]
					walker.get_node("Visual").play_pan(segment, i-1 if segment=="pan_swirl" else 0)
				break
		if not walker.river.work_edge(walker.global_position,walker.wade_limit()):
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
	var game: Node = get_node("/root/GameState")
	if Crew.in_channel(game.crew, sample_point.x, sample_point.z):
		Crew.take_channel(game.crew, sample_point.x, sample_point.z, result.ounces)
	else:
		Crew.take(game.crew.worked, sample_point.x, sample_point.z, result.ounces)
		Crew.record_prospect(game.crew, sample_point, result.ounces, game.day)
	_reset()

func _reset() -> void:
	if state != State.IDLE: walker.get_node("Visual").play_pan("pan_exit")
	segment = ""
	segment_index = -1
	state = State.IDLE
	elapsed = 0.0
	result = {}
	pan.hide()
	walker.camera_rig.release_focus()
