extends Node3D
## Scene instances stay posed for tools; launching this as the main scene starts play.
func _ready() -> void:
	_start_play.call_deferred()

func _start_play() -> void:
	if get_tree().current_scene == self:
		$Daylight/Clock.start()
		$Soundscape.start()
