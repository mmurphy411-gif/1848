extends Node3D
## A bounded spatial ambience bed and sparse wildlife; no music or gameplay RNG.
const Layout = preload("res://scripts/claim_layout.gd")
var active := false
var day_mix := 1.0
var target_day_mix := 1.0
var wildlife_timer := 4.0
var rng := RandomNumberGenerator.new()
var birds: AudioStreamPlayer3D
var owl: AudioStreamPlayer3D
var crickets: Array[AudioStreamPlayer3D] = []
var loops: Array[AudioStreamPlayer3D] = []
var winds: Array[AudioStreamPlayer3D] = []
var wind_time := 0.0

func _ready() -> void:
	rng.seed = 184807
	get_node("../Daylight").time_changed.connect(_time_changed)
	for x in [-34.0,0.0,34.0]:
		loops.append(_voice("river",Vector3(x,0,Layout.shore_z(x)-10),-19,30,true))
	for x in [-28.0,25.0]:
		loops.append(_voice("rapids",Vector3(x,0,Layout.shore_z(x)-4),-19,9,true))
		var wind := _voice("wind",Vector3(x,13,Layout.back_z(x)+3),-25,35,true)
		winds.append(wind)
		loops.append(wind)
		var cricket := _voice("crickets",Vector3(x,1,Layout.back_z(x)-2),-80,20,true)
		crickets.append(cricket)
		loops.append(cricket)
	birds = _voice("bird_0",Vector3.ZERO,-25,30)
	owl = _voice("owl_0",Vector3.ZERO,-26,40)

func _voice(clip: String, point: Vector3, db: float, range_m: float, loop := false) -> AudioStreamPlayer3D:
	var voice := AudioStreamPlayer3D.new()
	voice.name = clip.capitalize()+str(get_child_count())
	voice.stream = load("res://assets/audio/"+clip+".wav").duplicate()
	if loop:
		voice.stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		voice.stream.loop_begin = 0
		voice.stream.loop_end = roundi(voice.stream.get_length()*voice.stream.mix_rate)
	voice.volume_db = db
	voice.bus = "Ambience"
	voice.unit_size = range_m
	voice.max_distance = 180
	voice.attenuation_filter_cutoff_hz = 9000
	voice.position = point
	add_child(voice)
	return voice

func start() -> void:
	if active: return
	active = true
	for voice in loops: voice.play(rng.randf()*voice.stream.get_length())

func stop() -> void:
	active = false
	for voice in get_children():
		if voice is AudioStreamPlayer3D: voice.stop()

func _time_changed(_hour: float, light: float) -> void:
	target_day_mix = smoothstep(.05,.8,light)

func _process(delta: float) -> void:
	if not active: return
	wind_time += delta
	var gust := .72+.28*sin(wind_time*.19)*sin(wind_time*.071+1.0)
	for wind in winds: wind.volume_db=-25.0+linear_to_db(gust)
	day_mix = move_toward(day_mix,target_day_mix,delta*.2)
	for cricket in crickets:
		cricket.volume_db = linear_to_db(maxf(.0001,(1-day_mix)*db_to_linear(-32.0)))
	birds.volume_db = linear_to_db(maxf(.0001,day_mix*db_to_linear(-25.0)))
	owl.volume_db = linear_to_db(maxf(.0001,(1-day_mix)*db_to_linear(-26.0)))
	wildlife_timer -= delta
	if wildlife_timer <= 0:
		var voice := birds if day_mix>.5 else owl
		var kind := "bird" if voice==birds else "owl"
		voice.stream = load("res://assets/audio/%s_%d.wav" % [kind,rng.randi_range(0,2)])
		var x := rng.randf_range(-35,35)
		voice.position = Vector3(x,rng.randf_range(9,17),Layout.back_z(x)+rng.randf_range(1,7))
		voice.pitch_scale = rng.randf_range(.96,1.04)
		voice.play()
		wildlife_timer = rng.randf_range(9,22) if voice==birds else rng.randf_range(26,48)
