extends Node3D
var particles := GPUParticles3D.new()
## Drops alive at full rain (the box is 28 m square; see rain_particles.gdshader).
const AMOUNT := 20000
var sound := AudioStreamPlayer.new()
var current := 0.0
## Stage 1 visuals: streaks that read against wall and sky, and the project-wide
## `rain_wetness` shader global (0 dry .. 1 soaked; declared in project.godot) that
## follows the rain in and dries off after it. The water shader reads it today.
var wetness := 0.0
var streak := ShaderMaterial.new()
@onready var game: Node=get_node("/root/GameState")
@onready var daylight: Node3D=get_parent().get_node("Daylight")
func _ready() -> void:
	# Wave C: many short, thin, wind-slanted streaks in a deeper box ahead of the
	# lens, thinning out with distance (shaders/rain_streak.gdshader).
	particles.amount=AMOUNT;particles.lifetime=1.2;particles.emitting=false
	particles.visibility_aabb=AABB(Vector3(-16,-15,-16),Vector3(32,35,32))
	var shader := ShaderMaterial.new();shader.shader=preload("res://shaders/rain_particles.gdshader")
	particles.process_material=shader
	# The quad trails above each drop (its lower end is the drop, so ground and canvas
	# cut-offs still hold) and is long enough to overlap its previous frame's
	# position, so temporal AA keeps it instead of averaging it away.
	var mesh := QuadMesh.new();mesh.size=Vector2(.008,.55);mesh.center_offset=Vector3(0,.275,0)
	streak.shader=preload("res://shaders/rain_streak.gdshader")
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
		# Centre the 28 m rain box 7 m ahead of the lens, where it can be seen.
		var ahead: Vector3=-camera.global_basis.z;ahead.y=0
		particles.global_position=camera.global_position+ahead.normalized()*7.0+Vector3(0,9,0)
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
	streak.set_shader_parameter("tint",Color(.9*light,.93*light,.97*light,1.0))
func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("rain_wetness",0.0)
