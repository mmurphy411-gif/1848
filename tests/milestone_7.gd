extends SceneTree
var failures: Array[String] = []
func _initialize() -> void: run.call_deferred()
func check(ok: bool, label: String) -> void:
	print("PASS: " if ok else "FAIL: ",label)
	if not ok: failures.append(label)
func run() -> void:
	var claim: Node3D = load("res://scenes/claim.tscn").instantiate()
	root.add_child(claim)
	await process_frame
	var light: Node3D = claim.get_node("Daylight")
	var clock: Node = light.clock
	check(is_equal_approx(clock.hour_at(0),4.75) and is_equal_approx(clock.hour_at(1200),20.5),"Dawn to dusk takes exactly twenty real minutes")
	check(is_equal_approx(clock.hour_at(1380),4.75),"Three-minute night wraps to dawn")
	clock.set_process(false)
	clock.start(4.75)
	clock.advance(1380*4+123)
	var large_step: float = clock.elapsed
	clock.start(4.75)
	for i in 738: clock.advance(7.646341463414634)
	check(absf(clock.elapsed-large_step)<.001,"Clock handles large deltas, multiple wraps and frame-rate independence")
	clock.start(23.99)
	clock.advance(1)
	check(clock.hour_at(clock.elapsed)<1,"Clock crosses midnight without reversing")
	light.apply(19.25)
	var golden: Color = light.sun.light_color
	var golden_fog: float = light.mist.material.density
	clock.advance(60)
	check(not clock.running and light.sun.light_color==golden,"Explicit light poses freeze the clock")
	light.apply(12)
	check(light.sun.light_color.b>golden.b and light.mist.material.density<golden_fog,"Noon is cooler with thinner mist than golden hour")
	light.apply(0)
	check(light.sun.light_energy==0 and light.moon.light_energy>.2,"Moon lights the scene while the sun is below the horizon")
	check(light.sky_material.night_sky!=null and light.environment.volumetric_fog_density>.004,"Stars and thicker river fog at night")
	var night: Image = light.sky_material.night_sky.get_image()
	check(night.get_width()==4096 and light.stars.visibility==1.0,"Fine star panorama fades fully in at night")
	light.apply(12)
	check(light.stars.visibility==0.0,"Stars disappear fully in daylight")
	light.apply(0)
	var sound: Node3D = claim.get_node("Soundscape")
	sound.start()
	sound.set_process(false)
	for i in 360: sound._process(1.0/60)
	check(sound.day_mix<.01 and sound.crickets[0].volume_db>-40 and sound.birds.volume_db<-70,"Night fades birds out and crickets in")
	light.apply(12)
	for i in 360: sound._process(1.0/60)
	check(sound.day_mix>.99 and sound.crickets[0].volume_db<-70,"Day fades nocturnal ambience out")
	check(sound.loops.size()==9 and sound.get_child_count()==11,"Ambience has bounded spatial sources")
	for voice in sound.loops:
		check(voice.stream.loop_mode==AudioStreamWAV.LOOP_FORWARD and voice.stream.loop_end>0,"Loop range configured: "+str(voice.name))
	current_scene = claim
	claim._start_play()
	check(clock.running and sound.active,"Launching the main scene starts the live clock and sound")
	print("MILESTONE 7: ","PASS" if failures.is_empty() else "FAIL")
	quit(0 if failures.is_empty() else 1)
