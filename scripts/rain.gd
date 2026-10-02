extends Node3D
var particles := GPUParticles3D.new()
var sound := AudioStreamPlayer.new()
var current := 0.0
## Stage 1 visuals: streaks that read against wall and sky, and the project-wide
## `rain_wetness` shader global (0 dry .. 1 soaked; declared in project.godot) that
## follows the rain in and dries off after it. The water shader reads it today.
var wetness := 0.0
var streak := StandardMaterial3D.new()
@onready var game: Node=get_node("/root/GameState")
@onready var daylight: Node3D=get_parent().get_node("Daylight")
func _ready() -> void:
	particles.amount=5000;particles.lifetime=1.2
	particles.visibility_aabb=AABB(Vector3(-12,-15,-12),Vector3(24,35,24))
	var process := ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(10,0,10)
	process.direction=Vector3(.12,-1,.03);process.spread=3
	process.initial_velocity_min=13;process.initial_velocity_max=17;process.gravity=Vector3(0,-1,0)
	var shader := ShaderMaterial.new();shader.shader=preload("res://shaders/rain_particles.gdshader")
	particles.process_material=shader
	# A long, thin streak trailing above each drop (its lower end is the drop, so
	# ground and canvas cut-offs still hold). Long enough to overlap its previous
	# frame's position, so temporal AA keeps it instead of averaging it away.
	var mesh := QuadMesh.new();mesh.size=Vector2(.016,.9);mesh.center_offset=Vector3(0,.45,0)
	var fade := Gradient.new()
	fade.offsets=PackedFloat32Array([0.0,.35,.65,1.0])
	fade.colors=PackedColorArray([Color(1,1,1,0),Color(1,1,1,1),Color(1,1,1,1),Color(1,1,1,0)])
	var along := GradientTexture2D.new();along.gradient=fade;along.width=4;along.height=64
	along.fill_from=Vector2(0,0);along.fill_to=Vector2(0,1)
	streak.albedo_texture=along;streak.albedo_color=Color(.72,.76,.8,.32)
	streak.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	streak.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;streak.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
	streak.disable_fog=true
	# Streaks passing the lens would smear across the frame; fade them in from 1.5 to 5 m.
	streak.distance_fade_mode=BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	streak.distance_fade_min_distance=1.5;streak.distance_fade_max_distance=5.0
	mesh.material=streak;particles.draw_pass_1=mesh;add_child(particles)
	sound.stream=preload("res://assets/audio/rain.wav").duplicate()
	sound.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	sound.stream.loop_end=roundi(sound.stream.get_length()*sound.stream.mix_rate)
	sound.bus="Ambience";sound.volume_db=-23;add_child(sound)
func _process(delta: float) -> void:
	var weather: String=game.weather()
	var target := preload("res://scripts/weather.gd").rain_intensity(game.day,game.seed) if weather=="rain" else .35 if weather=="hot" else 0.0
	if weather=="rain" and game.weather_override=="rain": target=.8
	current=move_toward(current,target,delta/30)
	daylight.overcast=current
	var camera := get_viewport().get_camera_3d()
	if camera:
		# Centre the 20 m rain box 6 m ahead of the lens, where it can be seen.
		var ahead: Vector3=-camera.global_basis.z;ahead.y=0
		particles.global_position=camera.global_position+ahead.normalized()*6.0+Vector3(0,9,0)
	particles.emitting=weather=="rain"
	particles.amount_ratio=maxf(.1,current)
	if weather=="rain" and get_parent().get_node("Soundscape").active:
		if not sound.playing: sound.play()
	else: sound.stop()
	_update_visuals(weather, delta)
func _update_visuals(weather: String, delta: float) -> void:
	# Soaks in with the rain; dries over a couple of minutes once it stops.
	wetness=clampf(current/.8,0,1) if weather=="rain" else move_toward(wetness,0.0,delta/150)
	RenderingServer.global_shader_parameter_set("rain_wetness",wetness)
	# Unshaded streaks follow the light so night rain does not glow.
	var light: float=clampf(smoothstep(-8.0,10.0,daylight.sun_elevation),.06,1.0)
	streak.albedo_color=Color(.72*light,.76*light,.8*light,.32)
func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("rain_wetness",0.0)
