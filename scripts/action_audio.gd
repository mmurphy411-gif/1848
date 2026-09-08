extends Node3D
## Foley follows traveled distance and the existing panning timeline.
var step_distance := 0.0
var last_position := Vector3.ZERO
var last_segment := ""
var scooped := false
var steps_played := 0
var last_step_kind := ""
var rng := RandomNumberGenerator.new()
var step: AudioStreamPlayer3D
var pan: AudioStreamPlayer3D
var swirl: AudioStreamPlayer3D
var clips: Dictionary = {}
@onready var walker: CharacterBody3D = get_parent()
@onready var panner: Node = walker.get_node("Panner")
@onready var ambience: Node3D = walker.get_parent().get_node("Soundscape")

func _ready() -> void:
	rng.seed = 184808
	last_position = walker.global_position
	for kind in ["gravel","step_water","scoop","wash"]:
		clips[kind] = []
		for variant in 3: clips[kind].append(load("res://assets/audio/%s_%d.wav" % [kind,variant]))
	step = _voice(-15)
	pan = _voice(-13)
	swirl = _voice(-20)
	swirl.stream = preload("res://assets/audio/swirl.wav").duplicate()
	swirl.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	swirl.stream.loop_end = roundi(swirl.stream.get_length()*swirl.stream.mix_rate)
	process_physics_priority = 20

func _voice(db: float) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.volume_db = db
	voice.unit_size = 5
	voice.max_distance = 28
	voice.bus = "Foley"
	add_child(voice)
	return voice

func _play(voice: AudioStreamPlayer3D, kind: String) -> void:
	voice.stream = clips[kind][rng.randi_range(0,2)]
	voice.pitch_scale = rng.randf_range(.94,1.06)
	voice.play()

func stop() -> void:
	set_physics_process(false)
	for voice in [step,pan,swirl]: voice.stop()

func twitch() -> void:
	step.stream=preload("res://assets/audio/line_twitch.wav")
	step.play()

func _physics_process(delta: float) -> void:
	var traveled := Vector2(walker.global_position.x-last_position.x,walker.global_position.z-last_position.z).length()
	last_position = walker.global_position
	if not ambience.active: return
	var moving := Vector2(walker.velocity.x,walker.velocity.z).length()>.2
	if panner.state==panner.State.IDLE and walker.is_on_floor() and moving and traveled<1:
		step_distance += traveled
		var wet: bool = walker.river.depth_at(walker.global_position)>.05
		var stride := .63 if wet else 1.2
		if step_distance>=stride:
			step_distance = fmod(step_distance,stride)
			last_step_kind = "step_water" if wet else "gravel"
			_play(step,last_step_kind)
			steps_played += 1
	else: step_distance=0
	pan.global_position = walker.get_node("Visual").pan_attachment.global_position
	swirl.global_position = pan.global_position
	if panner.segment!=last_segment:
		last_segment = panner.segment
		scooped = false
		if last_segment=="pan_wash": _play(pan,"wash")
		if last_segment=="pan_enter": _play(pan,"gravel")
	if last_segment=="pan_enter" and panner.elapsed>=.85 and not scooped:
		_play(pan,"scoop")
		scooped = true
	var wet_swirl: bool = panner.state==panner.State.PANNING and last_segment=="pan_swirl"
	if wet_swirl and not swirl.playing: swirl.play()
	swirl.volume_db = move_toward(swirl.volume_db,-20.0 if wet_swirl else -80.0,delta*90)
	if not wet_swirl and swirl.volume_db<=-79: swirl.stop()
	if panner.state!=panner.State.PANNING:
		pan.stop()
		last_segment=""
