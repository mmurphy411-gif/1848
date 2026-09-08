extends SceneTree
const Layout=preload("res://scripts/claim_layout.gd")
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var claim: Node3D=load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	var w: CharacterBody3D=claim.get_node("Walker")
	var p: Node=w.get_node("Panner")
	claim.get_node("Soundscape").start()
	claim.get_node("Daylight").apply(12)
	var recorder:=AudioEffectRecord.new()
	recorder.format=AudioStreamWAV.FORMAT_16_BITS
	var effect_index:=AudioServer.get_bus_effect_count(0)
	AudioServer.add_bus_effect(0,recorder)
	await create_timer(1).timeout
	recorder.set_recording_active(true)
	Input.action_press("move_right")
	await create_timer(2).timeout
	Input.action_release("move_right")
	w.position=Vector3(0,Layout.height_at(0,-8.5)+.01,-8.5)
	claim.get_node("CameraRig").yaw=PI*.5
	Input.action_press("move_forward")
	await create_timer(2).timeout
	Input.action_release("move_forward")
	w.position=Vector3(0,Layout.height_at(0,-6.7)+.01,-6.7)
	w.velocity=Vector3.ZERO
	await create_timer(.5).timeout
	p.start_pan()
	await create_timer(14.5).timeout
	recorder.set_recording_active(false)
	assert(recorder.get_recording().save_to_wav("res://artifacts/milestone-8-day-audio.wav")==OK)
	claim.get_node("Daylight").apply(0)
	await create_timer(6).timeout
	recorder.set_recording_active(true)
	claim.get_node("Soundscape").wildlife_timer=1.0
	await create_timer(8).timeout
	recorder.set_recording_active(false)
	assert(recorder.get_recording().save_to_wav("res://artifacts/milestone-8-night-audio.wav")==OK)
	AudioServer.remove_bus_effect(0,effect_index)
	claim.get_node("Soundscape").stop()
	w.get_node("ActionAudio").stop()
	await create_timer(.1).timeout
	print("AUDIO CAPTURE: PASS (19s actual day/action mix and 8s night mix)")
	quit()
