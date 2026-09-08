extends SceneTree
const Layout=preload("res://scripts/claim_layout.gd")
const Guard=preload("res://tests/composition_guard.gd")
var claim: Node3D
var camera: Camera3D
var walker: CharacterBody3D
var game: Node
var clock: Node
var school: Node
var results: Dictionary={}
var failures: Array[String]=[]

func patch_luma(image: Image,point: Vector2) -> float:
	var sum := 0.0
	for y in range(int(point.y)-8,int(point.y)+8):
		for x in range(int(point.x)-8,int(point.x)+8):
			if x<0 or y<0 or x>=image.get_width() or y>=image.get_height(): return -1
			var color := image.get_pixel(x,y);sum+=color.r*.2126+color.g*.7152+color.b*.0722
	return sum/256
func _initialize() -> void: run.call_deferred()
func frames(count: int) -> void:
	for i in count: await process_frame
func pose(hour: float) -> void:
	claim.get_node("Daylight").apply(hour)
	clock.elapsed=(hour-clock.DAWN)/(clock.DUSK-clock.DAWN)*clock.DAY_SECONDS if hour>=clock.DAWN and hour<=clock.DUSK else clock.DAY_SECONDS+fposmod(hour-clock.DUSK,24)/(24-clock.DUSK+clock.DAWN)*clock.NIGHT_SECONDS
func view(from: Vector3,to: Vector3,fov := 55.0) -> void:
	camera.position=from;camera.look_at(to);camera.fov=fov;camera.current=true
func save(label: String,subject: Vector3=Vector3.ZERO) -> void:
	await create_timer(.7).timeout
	await frames(40)
	await RenderingServer.frame_post_draw
	var guarded := Guard.check(self,label) if subject==Vector3.ZERO else Guard.check_subject(self,label,walker,subject)
	results[label]={"guard":guarded}
	root.get_texture().get_image().save_png("res://artifacts/milestone-9-"+label+".png")
	print("CAPTURE ",label," guard=",guarded)
	if label=="camp-dusk":
		var camp: Node3D=claim.get_node("Camp")
		var im := root.get_texture().get_image()
		var near := camp.position+Vector3(-1.8,0,-.5)
		var far := camp.position+Vector3(-8,0,-.5)
		near.y=Layout.height_at(near.x,near.z)+.01;far.y=Layout.height_at(far.x,far.z)+.01
		var a := 0.0
		for i in 8:
			var sample := camp.position+Vector3(cos(i*TAU/8)*1.5,0,sin(i*TAU/8)*1.5)
			sample.y=Layout.height_at(sample.x,sample.z)+.01
			a+=patch_luma(im,camera.unproject_position(sample))/8
		var b := patch_luma(im,camera.unproject_position(far))
		results[label].ground_ratio=a/maxf(.001,b) if a>=0 and b>=0 else 0
		var centre := camera.unproject_position(camp.position+Vector3(0,.4,0))
		var longest := 0
		var flame_pixels := 0
		for y in range(maxi(0,int(centre.y)-24),mini(im.get_height(),int(centre.y)+24)):
			var run := 0
			var previous := Color.TRANSPARENT
			for x in range(maxi(0,int(centre.x)-24),mini(im.get_width(),int(centre.x)+24)):
				var color := im.get_pixel(x,y)
				if color.r>color.b*1.4 and color.r>color.g*1.2 and color.r>.2:
					flame_pixels+=1;run=run+1 if color==previous else 1;longest=maxi(longest,run)
				else: run=0
				previous=color
		results[label].flame_longest_run=longest;results[label].flame_pixels=flame_pixels
	if label=="camp-night":
		var camp: Node3D=claim.get_node("Camp")
		var im := root.get_texture().get_image()
		var centre := camera.unproject_position(camp.position)
		var best := 0.0
		var best_point := Vector2.ZERO
		for y in range(2,im.get_height()-2,2):
			for x in range(2,im.get_width()-2,2):
				var color := im.get_pixel(x,y)
				var warmth := color.r*.2126+color.g*.7152+color.b*.0722 if color.r>color.b*1.4 and color.g>color.b*1.2 else 0.0
				if warmth>best: best=warmth;best_point=Vector2(x,y)
		results[label].warmest_distance=best_point.distance_to(centre)
	if label in ["trout-holding","landed","salmon-riffle"]:
		var subjects: Array=[]
		if label=="landed": subjects=[walker.get_node("Fisher").trophy]
		else:
			for fish in school.get_children():
				if fish.visible and not fish.retired and fish.species==("trout" if label=="trout-holding" else "salmon"): subjects.append(fish)
		results[label].merge(await preload("res://tests/fishing_probes.gd").coverage(self,claim,subjects,label))
		if label=="landed": await preload("res://tests/subject_coverage.gd").capture(self,claim,"m9-landed")
func run() -> void:
	root.content_scale_size=Vector2i(1920,1080);root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game=root.get_node("GameState")
	game.apply_scenario({"day":"20","hour":"18.5","weather":"clear","hooks":"20","bait.grasshopper":"10","firewood":"10"})
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	walker=claim.get_node("Walker");clock=claim.get_node("Daylight/Clock");school=claim.get_node("FishSchool")
	claim.get_node("Rain").set_process(false)
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes;camera.far=600
	pose(18.5);school.refresh()
	await create_timer(2.1).timeout
	await frames(150)
	walker.set_physics_process(false)
	var spot: Dictionary=preload("res://scripts/fishery.gd").spots()[1]
	var point := Vector3(spot.position.x,-.4,spot.position.y)
	for fish in school.get_children():
		fish.position=fish.home;fish.rotation.y=0;fish.set_process(false)
	# A bank-side telephoto view includes the waterline as well as the pool;
	# a tight downward view made water occupy the entire frame.
	var shore: float=Layout.shore_z(point.x)
	view(Vector3(point.x+.35,Layout.height_at(point.x,shore+12)+1.8,shore+12),Vector3(point.x+.35,0,shore-1.55),5.8)
	await save("trout-holding")
	for fish in school.get_children(): fish.set_process(true)
	var fisher: Node=walker.get_node("Fisher")
	walker.position=Vector3(point.x,Layout.height_at(point.x,Layout.shore_z(point.x)-1),Layout.shore_z(point.x)-1)
	fisher.reproducible=true;fisher.press()
	await frames(25)
	fisher.cast();fisher.target=Vector3(point.x,.02,point.z);fisher.set_physics_process(false);fisher._physics_process(.6)
	view(walker.position+Vector3(3,1.5,1.3),walker.position+Vector3(0,1,-2),55)
	await save("cast")
	fisher.drift();fisher.fish=school.nearest("trout",point)
	if is_instance_valid(fisher.fish):
		fisher.fish.approach=true;fisher.fish.approach_target=point
	view(walker.position+Vector3(1,1.8,1.5),point,45)
	fisher._physics_process(.01)
	await save("wait")
	fisher.change(fisher.State.BITE,"fish_wait");fisher.elapsed=.4;fisher.press()
	fisher.fight=preload("res://scripts/fight_model.gd").begin(1,4,0);fisher.weight=1
	fisher._physics_process(.01)
	view(walker.position+Vector3(3,1.5,-1),walker.position+Vector3(0,.5,-2),50)
	await save("fight")
	fisher.land();fisher._physics_process(2.01);fisher._physics_process(.01)
	claim.get_node("CameraRig/SpringArm3D/Camera3D").current=true
	for i in 45:
		fisher._physics_process(.01)
		await process_frame
	await save("landed",fisher.trophy.global_position)
	fisher.cancel()
	walker.position=Vector3(0,Layout.height_at(0,6),6)
	game.day=100;pose(6.5);school.refresh();await create_timer(2.1).timeout
	var riffle: Dictionary=preload("res://scripts/fishery.gd").spots()[6]
	view(Vector3(-34,2,Layout.shore_z(-34)+1),Vector3(riffle.position.x,-.5,riffle.position.y),36)
	await save("salmon-riffle")
	var camp: Node3D=claim.get_node("Camp")
	camp.fire_hours=4;camp.ember_hours=1
	pose(20.25)
	walker.position=camp.global_position+Vector3(1.5,.02,-.8)
	walker.get_node("Visual").rotation.y=-.3
	walker.get_node("Visual").play_activity("eat")
	view(camp.global_position+Vector3(8,4,-10),camp.global_position+Vector3(0,.9,.8),65)
	await save("camp-dusk")
	pose(23)
	view(Vector3(camp.position.x+36,2,Layout.shore_z(camp.position.x+36)+1),camp.global_position+Vector3(0,1,0),45)
	await save("camp-night")
	game.weather_override="rain"
	claim.get_node("Daylight").overcast=0;pose(17)
	var clear_sun: float=claim.get_node("Daylight").sun.light_energy
	claim.get_node("Daylight").overcast=.8
	claim.get_node("Rain").current=.8
	claim.get_node("Rain")._process(0)
	pose(17)
	view(Vector3(point.x,1.7,Layout.shore_z(point.x)+.5),point,30)
	claim.get_node("Rain")._process(0)
	await save("rain-pool")
	results["rain-pool"].sun_ratio=claim.get_node("Daylight").sun.light_energy/clear_sun
	results["rain-pool"].rain_alive=claim.get_node("Rain").particles.emitting
	# Preserve the original transmission probe's lighting pose too: at 17:00
	# its dry reference falls in a boulder shadow, invalidating the comparison.
	pose(19.25)
	view(Vector3(0,8,2),Vector3(0,0,-6),75)
	await save("rain-transmission")
	var im := root.get_texture().get_image()
	var water_probe=preload("res://tests/water_capture.gd")
	var shallow: Vector4=water_probe._patch(im,camera,Vector3(0,0,-8.777778),64)
	var dry: Vector4=water_probe._patch(im,camera,Vector3(-9,Layout.height_at(-9,-1),-1),64)
	var deep: Vector4=water_probe._patch(im,camera,Vector3(0,0,-10.666667))
	results["rain-transmission"].passed=shallow.y<=dry.y*1.25 and deep.y>=deep.x*1.3 and water_probe._luma(deep)<water_probe._luma(shallow)
	results["rain-transmission"].samples={"shallow":str(shallow),"dry":str(dry),"deep":str(deep)}
	game.day=40;game.event("A trout spoiled.");game.event("Rain. River up.");game.caught(preload("res://scripts/cooking.gd").fresh("trout",1.2,40))
	claim.get_node("Ledger").open_book()
	view(camp.global_position+Vector3(5,2.5,-6),camp.global_position+Vector3(0,.9,.8),55)
	await save("ledger")
	claim.get_node("Ledger").close_book()
	var sandbox: Node=claim.get_node("Sandbox")
	sandbox.opened=true;sandbox.refresh_fields();sandbox.panel.show()
	await save("sandbox")
	var file := FileAccess.open("res://artifacts/milestone-9-capture.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(results,"  "))
	sandbox.close_panel()
	claim.get_node("Soundscape").stop();walker.get_node("ActionAudio").stop();camp.fire_sound.stop();claim.get_node("Rain").sound.stop()
	await frames(15)
	for label in results:
		var r: Dictionary=results[label]
		if not r.guard: failures.append(label+" composition")
		if label=="trout-holding" and (r.coverage<.008 or r.largest_background_upper_bound>.70): failures.append(label+" coverage")
		if label=="landed" and r.coverage<.15: failures.append(label+" coverage")
		if label=="salmon-riffle" and r.visible_bodies<6: failures.append(label+" visible bodies")
		if label=="camp-dusk" and r.ground_ratio<1.6: failures.append(label+" ground lighting")
		if label=="camp-dusk" and (r.flame_pixels<3 or r.flame_longest_run>6): failures.append(label+" flame detail")
		if label=="camp-night" and r.warmest_distance>20: failures.append(label+" warmest point")
		if label=="rain-pool" and (r.sun_ratio>.55 or not r.rain_alive): failures.append(label+" weather")
		if label=="rain-transmission" and not r.passed: failures.append(label+" transmission")
	print("M9 RENDER PROBES: ","PASS" if failures.is_empty() else str(failures))
	quit(0 if failures.is_empty() else 1)
