extends Node3D
var particles := GPUParticles3D.new()
var sound := AudioStreamPlayer.new()
var current := 0.0
@onready var game: Node=get_node("/root/GameState")
@onready var daylight: Node3D=get_parent().get_node("Daylight")
func _ready() -> void:
	particles.amount=1200;particles.lifetime=1.2
	particles.visibility_aabb=AABB(Vector3(-12,-15,-12),Vector3(24,35,24))
	var process := ParticleProcessMaterial.new()
	process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_BOX;process.emission_box_extents=Vector3(10,0,10)
	process.direction=Vector3(.12,-1,.03);process.spread=3
	process.initial_velocity_min=13;process.initial_velocity_max=17;process.gravity=Vector3(0,-1,0)
	var shader := ShaderMaterial.new();shader.shader=preload("res://shaders/rain_particles.gdshader")
	particles.process_material=shader
	var mesh := QuadMesh.new();mesh.size=Vector2(.008,.22)
	var material := StandardMaterial3D.new();material.albedo_color=Color(.68,.75,.8,.3);material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.billboard_mode=BaseMaterial3D.BILLBOARD_FIXED_Y
	mesh.material=material;particles.draw_pass_1=mesh;add_child(particles)
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
	if camera: particles.global_position=camera.global_position+Vector3(0,9,0)
	particles.emitting=weather=="rain"
	particles.amount_ratio=maxf(.1,current)
	if weather=="rain" and get_parent().get_node("Soundscape").active:
		if not sound.playing: sound.play()
	else: sound.stop()
