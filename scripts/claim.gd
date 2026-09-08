extends Node3D
var quitting := false
## Scene instances stay posed for tools; launching this as the main scene starts play.
func _ready() -> void:
	_start_play.call_deferred()

func _start_play() -> void:
	if get_tree().current_scene == self:
		get_tree().auto_accept_quit = false
		if not get_tree().root.close_requested.is_connected(request_quit):
			get_tree().root.close_requested.connect(request_quit)
		var state := get_node("/root/GameState")
		if not $Daylight/Clock.day_ended.is_connected(state.end_day):
			$Daylight/Clock.day_ended.connect(state.end_day)
			$Daylight/Clock.advanced.connect(state.check_midday)
		$Daylight/Clock.start(state.start_hour)
		$Soundscape.start()
		if state.day>=81 and state.day<=127 and state.start_hour>=5 and state.start_hour<=8:
			var layout=preload("res://scripts/claim_layout.gd")
			var z: float=layout.shore_z(-34)-.8
			$Walker.position=Vector3(-34,layout.height_at(-34,z)+.05,z)
			$CameraRig.yaw=.25;$CameraRig.pitch=-.38

func request_quit() -> void:
	if quitting: return
	quitting = true
	$Soundscape.stop()
	$Walker/ActionAudio.stop()
	if has_node("Camp"): $Camp.fire_sound.stop()
	if has_node("Rain"): $Rain.sound.stop()
	# Let the audio thread release stopped loop playbacks before engine teardown.
	await get_tree().create_timer(.1,true,false,true).timeout
	get_tree().quit()
