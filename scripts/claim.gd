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
		$Daylight/Clock.start()
		$Soundscape.start()

func request_quit() -> void:
	if quitting: return
	quitting = true
	$Soundscape.stop()
	$Walker/ActionAudio.stop()
	# Let the audio thread release stopped loop playbacks before engine teardown.
	await get_tree().create_timer(.1,true,false,true).timeout
	get_tree().quit()
