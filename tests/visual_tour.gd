extends SceneTree
## Standard visual tour (VISUAL_UPGRADE_PLAN.md, Stage 0): fixed-scenario stills that
## every art stage is judged on, before and after. Renders; do not run headless.
##
##   ./.tools/Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1600x900 \
##       --fixed-fps 60 --script tests/visual_tour.gd -- label=baseline
##   ... -- label=stage1_try only=downstream_10h,rain_downstream_10h
##   settle=<frames> overrides the 180 frames each view settles before capture.
##
## Writes artifacts/visual-tour/<label>/<view>.png (1600x900) and views.json (merged by
## view name, so an only= run updates its entries and keeps the rest). Exits 1 if a
## requested view could not be captured or a view overran its frame slot.
##
## Conventions: X runs downstream, +Z is inland. Camera-rig yaw 0 looks across the
## river (-Z), yaw PI looks inland, negative yaw turns downstream. Paired views (the
## downstream_* series, across_river_10h/_d100, under_oak_10h/_d100) share a camera.
##
## Determinism: --fixed-fps 60 makes every frame step, animation and shader TIME
## identical between runs; wildlife and fish are posed and frozen, GPU particles use a
## fixed seed, the crew fire flicker (wall-clock driven) is pinned, and nothing waits on
## real time. Each view owns a fixed slot of frames from the start of the tour, so a
## view is captured on the same frame (same water, wind and idle phase) whether the run
## is full or only= a subset; skipped slots pass with 3D rendering off. Rain is set to
## its full scenario strength directly: in play it ramps over ~24 s, and the posed
## Daylight only reads Rain's overcast when apply() runs.
const Layout = preload("res://scripts/claim_layout.gd")
const River = preload("res://scripts/river_model.gd")
const Crew = preload("res://scripts/crew_model.gd")
const Gold = preload("res://scripts/gold_map.gd")
const SIZE := Vector2i(1600, 900)
const SETTLE := 180
## Frames a view may spend on setup (scene open, rig travel, crew walk) before settling.
const SETUP := 180
var settle_frames := SETTLE
var slot_frames := SETTLE + SETUP
var tour_start := 0
var current_slot := -1
var overruns: Array[String] = []
const SEED := "1848"
## Every view in capture order: name -> section. The order here is the manifest order.
const VIEWS := [
	["store","store"],
	["downstream_10h","day10"],["upstream_10h","day10"],["across_river_10h","day10"],
	["far_wall_10h","day10"],["near_wall_10h","day10"],["camp_10h","day10"],
	["shoreline_close_10h","day10"],["gravel_close_10h","day10"],["under_oak_10h","day10"],
	["overview_10h","day10"],["valley_low_10h","day10"],["fish_underwater_10h","day10"],
	["downstream_06h","day10"],["downstream_13h","day10"],["downstream_1925","day10"],
	["downstream_00h","day10"],
	["rain_downstream_10h","rain"],
	["across_river_d100","day100"],["under_oak_d100","day100"],
	["wildlife_deer","wildlife"],["wildlife_deer_close","wildlife"],["wildlife_bear","wildlife"],
	["wildlife_jay","wildlife"],["wildlife_quail","wildlife"],["wildlife_squirrel","wildlife"],
	["crew_work_10h","crew"],["crew_supper_1936","crew"],
	["crew_lineup","crew"],
	# Stage 6 close-ups (appended): camp props at 4 m and the store's goods.
	["camp_close_10h","props"],["store_shelves","props"],
]
## Rig poses shared by paired views: x, metres inland of the June shore, yaw, pitch.
const DOWNSTREAM := [-20.0, 8.0, -1.1475, -.08]
const UPSTREAM := [20.0, 8.0, 1.4, -.08]
const ACROSS := [0.0, 2.0, 0.0, -.10]
const FAR_WALL := [0.0, 2.0, 0.0, .35]
const NEAR_WALL := [0.0, 6.0, PI, .30]

var game: Node
var out_dir := ""
var label := "latest"
var only: PackedStringArray = []
var claim: Node3D
var store: Node3D
var walker: CharacterBody3D
var rig: Node3D
var light: Node3D
var clock: Node
var camera: Camera3D
var scenario: Dictionary = {}
var light_hour := 10.0
var clock_hour := 10.0
var entries: Dictionary = {}
var missing: Array[String] = []
var captured := 0

func _initialize() -> void: run.call_deferred()

func frames(n: int) -> void:
	for i in n: await process_frame

func wanted(view: String) -> bool:
	return only.is_empty() or view in only

func view_index(view: String) -> int:
	for i in VIEWS.size():
		if VIEWS[i][0] == view: return i
	return -1

## Wait, with 3D rendering off, for the first frame of a view's slot.
func at_slot(index: int) -> void:
	if index == current_slot: return
	current_slot = index
	var target := tour_start + index * slot_frames
	if Engine.get_process_frames() > target:
		overruns.append(VIEWS[index - 1][0])
		push_error("visual_tour: %s overran its %d-frame slot; later views will not repeat" % [VIEWS[index - 1][0], slot_frames])
	root.disable_3d = true
	while Engine.get_process_frames() < target: await process_frame
	root.disable_3d = false

## Enter a view's slot; true when the view is to be captured in this run. Skipped
## views cost nothing here: the next wanted view's slot absorbs their frames.
func begin(view: String) -> bool:
	if not wanted(view): return false
	await at_slot(view_index(view))
	await fresh_gi()
	return true

## SDFGI keeps probe history in the viewport's buffers across views and scenes, so each
## view would otherwise inherit light from whatever was rendered before it. Restart it.
func fresh_gi() -> void:
	var environment: Environment = (store.get_node("Daylight") if store else light).environment
	environment.sdfgi_enabled = false
	await frames(2)
	environment.sdfgi_enabled = true

func section_wanted(section: String) -> bool:
	for view in VIEWS:
		if view[1] == section and wanted(view[0]): return true
	return false

# ------------------------------------------------------------------ capture

func shot(view: String, description: String, extra := 0) -> void:
	var settle := settle_frames + extra
	for layer in root.find_children("*", "CanvasLayer", true, false): layer.visible = false
	# Re-render the river reflection probe once GI has settled, then settle again.
	await frames(settle / 2)
	(store.get_node("Daylight") if store else light)._refresh_reflection()
	await frames(settle - settle / 2)
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	if image.get_size() != SIZE: push_warning("%s rendered at %s, expected %s" % [view, image.get_size(), SIZE])
	image.save_png(out_dir.path_join(view + ".png"))
	var active := root.get_camera_3d()
	var forward := -active.global_basis.z
	entries[view] = {"name": view, "file": view + ".png", "scene": "store" if store else "claim",
		"day": game.day, "hour": light_hour, "clock_hour": clock_hour, "weather": game.weather(),
		"water_level": snappedf(game.water_level(), .001), "camera": description,
		"eye": _vec(active.global_position), "forward": _vec(forward), "fov": active.fov}
	captured += 1
	print("CAPTURE %s (%d frames)" % [view, settle])

func _vec(v: Vector3) -> Array: return [snappedf(v.x, .001), snappedf(v.y, .001), snappedf(v.z, .001)]

## Gameplay camera: the miner placed `inland` metres from the June shore, rig posed.
func place(pose: Array) -> String:
	var x: float = pose[0]
	var z := Layout.shore_z(x) + float(pose[1])
	walker.visible = true
	walker.position = Vector3(x, Layout.height_at(x, z) + .05, z)
	walker.velocity = Vector3.ZERO
	rig.yaw = pose[2]; rig.pitch = pose[3]
	# Snap the orbit smoothing so the camera path never depends on the previous view.
	rig._orbit_position = walker.global_position + Vector3(0, 1.45, 0)
	rig._orbit_rotation = Vector3(pose[3], pose[2], 0)
	walker.get_node("Visual").rotation.y = pose[2]
	rig.get_node("SpringArm3D/Camera3D").current = true
	for i in 90: await physics_frame
	return "gameplay rig, miner at x=%.1f, %.1f m inland, yaw %.3f, pitch %.2f" % [x, pose[1], pose[2], pose[3]]

## Free camera; the miner is hidden unless the view needs him.
func view(eye: Vector3, target: Vector3, fov: float, keep_walker := false) -> void:
	walker.visible = keep_walker
	camera.position = eye
	camera.look_at(target, Vector3.UP)
	camera.fov = fov
	camera.current = true

# ------------------------------------------------------------------ scene state

func clock_seconds(hour: float) -> float:
	var h := fposmod(hour, 24.0)
	if h >= clock.DAWN and h <= clock.DUSK: return (h - clock.DAWN) / (clock.DUSK - clock.DAWN) * clock.DAY_SECONDS
	return clock.DAY_SECONDS + fposmod(h - clock.DUSK, 24.0) / (24.0 - clock.DUSK + clock.DAWN) * clock.NIGHT_SECONDS

## Light and clock posed separately (wildlife windows follow the clock), the clock
## stopped, then animals and fish repopulated for that hour and frozen in place.
func pose_time(hour: float, population_hour := -1.0) -> void:
	light_hour = hour
	clock_hour = hour if population_hour < 0 else population_hour
	var rain: Node = claim.get_node("Rain")
	rain.current = .8 if game.weather() == "rain" else 0.0
	light.overcast = rain.current
	light.apply(hour)
	clock.elapsed = clock_seconds(clock_hour)
	clock.running = false
	var wildlife: Node = claim.get_node("Wildlife")
	wildlife.set_process(false)
	wildlife.refresh(true)
	for actor in wildlife.actors: freeze_actor(actor)
	var school: Node = claim.get_node("FishSchool")
	school.refresh()
	for fish in school.get_children():
		if fish.retired:
			school.remove_child(fish); fish.queue_free(); continue
		fish.fade = 1.0
		fish.material.set_shader_parameter("visibility", 1.0)
		fish.position = fish.home; fish.rotation.y = 0
		fish.set_process(false)

func freeze_actor(actor: Node3D) -> void:
	actor.review_pose = true
	actor.set_physics_process(false)
	for i in 40: actor.animate(1.0 / 60)

func fixed_particles(scene: Node) -> void:
	for particles in scene.find_children("*", "GPUParticles3D", true, false):
		if "use_fixed_seed" in particles:
			particles.use_fixed_seed = true; particles.seed = 1848
		particles.restart()

func open_claim(args: Dictionary, hour: float, population_hour := -1.0) -> void:
	scenario = args.duplicate(); scenario.seed = SEED
	game.apply_scenario(scenario)
	claim = load("res://scenes/claim.tscn").instantiate(); root.add_child(claim)
	walker = claim.get_node("Walker"); rig = claim.get_node("CameraRig")
	light = claim.get_node("Daylight"); clock = light.get_node("Clock")
	# The rig captures the mouse in _ready; stray input must not turn the camera.
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	rig.set_process_unhandled_input(false)
	claim.get_node("DensityDebug").hide()
	camera = Camera3D.new(); claim.add_child(camera)
	camera.far = 900; camera.attributes = light.camera_attributes
	await frames(10)
	pose_time(hour, population_hour)
	fixed_particles(claim)

func close_claim() -> void:
	claim.get_node("Soundscape").stop()
	claim.get_node("Camp").fire_sound.stop()
	claim.get_node("Rain").sound.stop()
	claim.queue_free(); claim = null
	await frames(5)

# ------------------------------------------------------------------ sections

func day10() -> void:
	await at_slot(view_index("downstream_10h"))
	await open_claim({"day": "10", "hour": "10", "weather": "clear"}, 10.0)
	var description := ""
	if await begin("downstream_10h"):
		description = await place(DOWNSTREAM); await shot("downstream_10h", "downstream (+X) along the bar: " + description)
	if await begin("upstream_10h"):
		description = await place(UPSTREAM); await shot("upstream_10h", "upstream (-X) along the bar: " + description)
	if await begin("across_river_10h"):
		description = await place(ACROSS); await shot("across_river_10h", "across the river from the waterline: " + description)
	if await begin("far_wall_10h"):
		description = await place(FAR_WALL); await shot("far_wall_10h", "far canyon wall, looking up across the river: " + description)
	if await begin("near_wall_10h"):
		description = await place(NEAR_WALL); await shot("near_wall_10h", "near canyon wall, looking inland and up over the bar and camp: " + description)
	var camp: Vector3 = claim.get_node("Camp").global_position
	if await begin("camp_10h"):
		view(camp + Vector3(6, 3, -8), camp + Vector3(0, .8, .8), 55)
		await shot("camp_10h", "camp from the river side, 10 m out, 3 m up")
	if await begin("shoreline_close_10h"):
		var x := 2.0
		var edge := River.shore_z(x, game.water_level())
		walker.position = Vector3(x, Layout.height_at(x, edge + .15) + .05, edge + .15)
		walker.velocity = Vector3.ZERO; walker.get_node("Visual").rotation.y = 0
		for i in 30: await physics_frame
		var eye := Vector3(x + 3.2, 0, edge + 1.3)
		eye.y = Layout.height_at(eye.x, eye.z) + .55
		view(eye, Vector3(x - .6, game.water_level() + .35, edge - .2), 50, true)
		await shot("shoreline_close_10h", "miner at the waterline, camera 0.55 m above the bank looking along the wet edge")
	if await begin("gravel_close_10h"):
		var spot := Vector3(-4, 0, Layout.shore_z(-4) + 5)
		spot.y = Layout.height_at(spot.x, spot.z)
		view(spot + Vector3(0, 1.5, 1.5), spot, 55)
		await shot("gravel_close_10h", "bar gravel, camera 1.5 m up looking 45 degrees down toward the river")
	var oak := under_oak_camera()
	if await begin("under_oak_10h"):
		view(oak[0], oak[1], 65); await shot("under_oak_10h", oak[2])
	if await begin("overview_10h"):
		view(Vector3(95, 100, 18), Vector3(-15, 0, -3), 60)
		await shot("overview_10h", "high overview from downstream above the near wall")
	if await begin("valley_low_10h"):
		view(Vector3(-60, 6, 2), Vector3(60, 8, -10), 55)
		await shot("valley_low_10h", "low view down the valley from above the upstream riffle")
	if await begin("fish_underwater_10h"):
		await fish_view()
	var series := [["downstream_06h", 6.0], ["downstream_13h", 13.0], ["downstream_1925", 19.25], ["downstream_00h", 0.0]]
	for item in series:
		if not await begin(item[0]): continue
		pose_time(item[1])
		description = await place(DOWNSTREAM)
		await shot(item[0], "downstream (+X) along the bar at %05.2f h: %s" % [item[1], description])
	await close_claim()

func under_oak_camera() -> Array:
	# The black oak nearest x=13 on the lower bar: off the camp, open to the river.
	var oaks: Array = claim.get_node("Vegetation").placements.black_oak
	var best: Vector3 = oaks[0].origin
	for transform in oaks:
		var p: Vector3 = transform.origin
		if absf(p.x - 13) + absf(p.z - Layout.shore_z(p.x) - 20) < absf(best.x - 13) + absf(best.z - Layout.shore_z(best.x) - 20): best = p
	# Stand inland of the trunk, under the crown, with the trunk in the right third.
	var eye := best + Vector3(-1.5, 0, 2.0)
	eye.y = Layout.height_at(eye.x, eye.z) + 1.5
	return [eye, eye + Vector3(0, .45, -1), "beneath the black oak at (%.1f, %.1f), 2.5 m inland and upstream of the trunk, 1.5 m up, looking up and out to the river" % [best.x, best.z]]

func fish_view() -> void:
	var school: Node = claim.get_node("FishSchool")
	var subject: Node3D = null
	for fish in school.get_children():
		if fish.species == "trout": subject = fish; break
	if subject == null and school.get_child_count() > 0: subject = school.get_child(0)
	if subject == null:
		missing.append("fish_underwater_10h"); push_error("No fish present for fish_underwater_10h"); return
	var f := subject.global_position
	var eye := f + Vector3(1.0, 0, 2.4)
	eye.y = maxf(game.water_level() + 2.6, Layout.height_at(eye.x, eye.z) + 1.2)
	view(eye, f, 40)
	await shot("fish_underwater_10h", "%s holding at (%.1f, %.2f, %.1f), seen through the surface from 2.6 m above the water" % [subject.species, f.x, f.y, f.z])

func rain() -> void:
	await at_slot(view_index("rain_downstream_10h"))
	await open_claim({"day": "10", "hour": "10", "weather": "rain"}, 10.0)
	if await begin("rain_downstream_10h"):
		var description: String = await place(DOWNSTREAM)
		# Let the drops fill the 1.2 s particle lifetime around the camera.
		await shot("rain_downstream_10h", "rain at full scenario strength (overcast 0.8): " + description, 60)
	await close_claim()

func day100() -> void:
	await at_slot(view_index("across_river_d100"))
	await open_claim({"day": "100", "hour": "10", "weather": "clear"}, 10.0)
	if await begin("across_river_d100"):
		var description: String = await place(ACROSS)
		await shot("across_river_d100", "low water across the river (pairs with across_river_10h): " + description)
	if await begin("under_oak_d100"):
		var oak := under_oak_camera()
		view(oak[0], oak[1], 65); await shot("under_oak_d100", oak[2] + " (pairs with under_oak_10h)")
	await close_claim()

func wildlife() -> void:
	# Salmon season brings the bear; at 06:30 every species is out. Lit at 08:30.
	await at_slot(view_index("wildlife_deer"))
	await open_claim({"day": "99", "hour": "6.5", "weather": "clear"}, 8.5, 6.5)
	walker.position = Vector3(38, Layout.height_at(38, 0) + .05, 0)
	var heights := {"bear": .64, "deer": .88, "squirrel": .22, "quail": .18, "jay": .21}
	var plan := [["wildlife_deer", "deer", 10.0, 40.0], ["wildlife_deer_close", "deer", 3.0, 50.0],
		["wildlife_bear", "bear", 10.0, 40.0], ["wildlife_jay", "jay", 8.0, 40.0],
		["wildlife_quail", "quail", 8.0, 40.0], ["wildlife_squirrel", "squirrel", 8.0, 40.0]]
	for item in plan:
		if not await begin(item[0]): continue
		var actor: Node3D = null
		for candidate in claim.get_node("Wildlife").actors:
			if candidate.species == item[1]: actor = candidate; break
		if actor == null:
			missing.append(item[0]); push_error("No %s present for %s" % [item[1], item[0]]); continue
		var target: Vector3 = actor.position + Vector3(0, heights[item[1]], 0)
		var distance: float = item[2]
		var eye := wildlife_eye(actor, target, distance, 1.25 if distance < 5 else 1.7)
		var d := Vector3(target.x - eye.x, 0, target.z - eye.z).normalized()
		# Broadside, turned a little toward the camera.
		actor.rotation.y = atan2(-d.z, d.x) + .35
		freeze_actor(actor)
		view(eye, target, item[3])
		await shot(item[0], "%s at %.1f m, eye %.2f m above ground, broadside" % [item[1], eye.distance_to(target), eye.y - Layout.height_at(eye.x, eye.z)])
	await close_claim()

## Standing point around the animal (inland side first) with dry footing and a clear
## sightline through the physics world; the first with no other animal nearer the lens
## than the subject, else the one that keeps other animals furthest from the lens.
func wildlife_eye(subject: Node3D, target: Vector3, distance: float, height: float) -> Vector3:
	var best := Vector3.INF
	var best_room := -1.0
	for angle in [0.0, .6, -.6, 1.2, -1.2, 1.8, -1.8]:
		var eye := target + Vector3(sin(angle), 0, cos(angle)) * distance
		eye.y = Layout.height_at(eye.x, eye.z) + height
		if absf(eye.x) > 40 or eye.z > Layout.back_z(eye.x) - 1 or eye.z < River.shore_z(eye.x, game.water_level()) + .3: continue
		var query := PhysicsRayQueryParameters3D.create(eye, target)
		query.exclude = [walker.get_rid()]
		if not claim.get_world_3d().direct_space_state.intersect_ray(query).is_empty(): continue
		var room := INF
		for other in claim.get_node("Wildlife").actors:
			if other != subject: room = minf(room, other.position.distance_to(eye))
		if room >= distance: return eye
		if room > best_room: best = eye; best_room = room
	if best == Vector3.INF:
		best = target + Vector3(0, 0, distance); best.y = Layout.height_at(best.x, best.z) + height
	return best

func store_scene() -> void:
	await at_slot(view_index("store"))
	scenario = {"seed": SEED, "day": "30", "hour": "13", "weather": "clear"}
	game.apply_scenario(scenario)
	store = load("res://scenes/store.tscn").instantiate(); root.add_child(store)
	store.set_physics_process(false); store.walker.set_physics_process(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	light_hour = 13.0; clock_hour = 13.0
	store.get_node("Daylight").apply(13)
	fixed_particles(store)
	var mount := Node3D.new(); store.add_child(mount)
	camera = Camera3D.new(); mount.add_child(camera); camera.attributes = store.get_node("Daylight").camera_attributes
	camera.position = Vector3(6.4, 2.15, 10.8); camera.look_at(Vector3(0, 1.35, -.1), Vector3.UP)
	camera.fov = 48; camera.current = true
	if await begin("store"):
		await shot("store", "Lambert's store on arrival, from the trail")
	store.get_node("Soundscape").stop(); store.get_node("Rain").sound.stop()
	store.queue_free(); store = null
	await frames(5)

func crew_scenes() -> void:
	await at_slot(view_index("crew_work_10h"))
	await open_claim({"day": "44", "hour": "10", "dollars": "300", "crew": "7", "pans": "3", "bunks": "2",
		"rocker": "1", "shovel": "1", "crowbar": "1", "pick": "1", "weather": "clear"}, 10.0)
	for p in Gold.peak_points(): Crew.record_prospect(game.crew, Vector3(p.x, 0, p.y), .08, 44)
	for x in range(-30, 31, 7): Crew.record_prospect(game.crew, Vector3(x, 0, Layout.shore_z(x) + .5), .02, 44)
	game.inventory.goods.flour = 60.0; game.inventory.goods.beans = 30.0
	game.mining.owned = true
	Crew.site_cradle(game.crew, game.mining, game.water_level())
	game.morning_orders()
	claim.get_node("Mining").refresh()
	var crew: Node3D = claim.get_node("Crew")
	walker.position = claim.get_node("Camp").position + Vector3(-2, 0, -3)
	# Hire the men in at section open so their animation phase is the same in every run.
	crew.sync(); crew.settle(); crew.set_process(false)
	if await begin("crew_work_10h"):
		pose_time(10.0)
		await crew_settle(crew)
		view(Vector3(26, 7, 4), Vector3(4, -.5, -7), 50)
		await shot("crew_work_10h", "seven-man outfit at work on the bar, from downstream and above")
	if await begin("crew_supper_1936"):
		pose_time(19.6)
		await crew_settle(crew)
		var f: Vector3 = crew.fire_point()
		view(f + Vector3(-3, 2.6, -7.5), f + Vector3(0, .8, 1.5), 52)
		await shot("crew_supper_1936", "crew at the supper fire, 19:36")
	if await begin("crew_lineup"):
		await crew_lineup(crew)
	crew.fire_sound.stop(); crew.music.stop()
	await close_claim()
	# Later runs in this process must not inherit the outfit.
	game.apply_scenario({"crew": "0", "pans": "0"})

## Stage 5: all fourteen hands in roster order on an arc 6 m from the camera at 10:00,
## facing it with the sun behind it, to judge whether every man can be told apart.
func crew_lineup(crew: Node3D) -> void:
	game.apply_scenario({"crew": "14", "pans": "14"})
	crew.sync(); crew.set_process(false)
	pose_time(10.0)
	var forward := Vector3(.75, 0, .66).normalized()
	var centre := Vector3(-2.0, 0, 2.0)
	var eye := centre - forward * 6.0
	eye.y = Layout.height_at(eye.x, eye.z) + 1.15
	var ids: Array = Crew.ROSTER.map(func(m): return m.id)
	for i in ids.size():
		var direction := forward.rotated(Vector3.UP, lerpf(.64, -.64, i / float(ids.size() - 1)))
		var p := Vector3(eye.x, 0, eye.z) + direction * 6.0
		p.y = Layout.height_at(p.x, p.z)
		crew.hands[ids[i]].place(p, crew._face(p, eye), "idle")
	var target := centre; target.y = Layout.height_at(centre.x, centre.z) + .95
	view(eye, target, 52)
	await shot("crew_lineup", "all fourteen hands in roster order, an arc 6 m from the camera, 10:00")
## Stage 6 close-ups. The store here follows claim views, as it does in play.
func props_scenes() -> void:
	await at_slot(view_index("camp_close_10h"))
	await open_claim({"day": "10", "hour": "10", "weather": "clear", "firewood": "6"}, 10.0)
	if await begin("camp_close_10h"):
		var camp: Vector3 = claim.get_node("Camp").global_position
		view(camp + Vector3(2.6, 1.7, -3.2), camp + Vector3(-1.3, .45, 1.6), 55)
		await shot("camp_close_10h", "camp props from the fire's river side, 4 m out, 1.7 m up")
	await close_claim()
	if not wanted("store_shelves"): return
	await at_slot(view_index("store_shelves"))
	scenario = {"seed": SEED, "day": "30", "hour": "13", "weather": "clear"}; game.apply_scenario(scenario)
	store = load("res://scenes/store.tscn").instantiate(); root.add_child(store)
	store.set_physics_process(false); store.walker.set_physics_process(false)
	store.walker.position = Vector3(3, 0, 3)
	light_hour = 13.0; clock_hour = 13.0
	store.get_node("Daylight").apply(13)
	fixed_particles(store)
	var mount := Node3D.new(); store.add_child(mount)
	camera = Camera3D.new(); mount.add_child(camera); camera.attributes = store.get_node("Daylight").camera_attributes
	camera.position = Vector3(-.65, 2.8, 2.5); camera.look_at(Vector3(0, 1.45, -1.3), Vector3.UP)
	camera.fov = 49; camera.current = true
	if await begin("store_shelves"):
		await shot("store_shelves", "Lambert's shelves over the counter, from the customer side")
	store.get_node("Soundscape").stop(); store.get_node("Rain").sound.stop()
	store.queue_free(); store = null
	await frames(5)

func crew_settle(crew: Node3D) -> void:
	crew.set_process(true)
	crew.sync(); crew.settle()
	await frames(90)
	# The crew fire flickers on the wall clock; hold it at its mean for repeatable shots.
	crew.set_process(false)
	crew.light.light_energy = 4.5 * .9

# ------------------------------------------------------------------ main

func run() -> void:
	var started := Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		var parts := arg.split("=", true, 1)
		if parts.size() != 2: continue
		if parts[0] == "label": label = parts[1].validate_filename().replace(" ", "_")
		if parts[0] == "only": only = parts[1].split(",", false)
		if parts[0] == "settle": settle_frames = maxi(1, parts[1].to_int())
	slot_frames = settle_frames + SETUP
	var names: Array = VIEWS.map(func(v): return v[0])
	for name in only:
		if not name in names: push_error("Unknown view '%s'. Views: %s" % [name, ", ".join(names)]); missing.append(name)
	if DisplayServer.get_name() == "headless":
		push_error("visual_tour renders; run it without --headless"); quit(2); return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await frames(3)
	# --fixed-fps is consumed by the engine; detect it by its exact frame step.
	if not is_equal_approx(root.get_process_delta_time(), 1.0 / 60.0):
		push_warning("visual_tour: run with --fixed-fps 60 or captures will not repeat between runs")
	game = root.get_node("GameState")
	out_dir = ProjectSettings.globalize_path("res://").path_join("artifacts/visual-tour").path_join(label)
	DirAccess.make_dir_recursive_absolute(out_dir)
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	tour_start = Engine.get_process_frames() + 1
	# The store goes first. Its lighting depends on which claim views ran earlier in the
	# process even after an SDFGI restart (with SDFGI off it does not), so it is captured
	# before any claim is loaded.
	if section_wanted("store"): await store_scene()
	if section_wanted("day10"): await day10()
	if section_wanted("rain"): await rain()
	if section_wanted("day100"): await day100()
	if section_wanted("wildlife"): await wildlife()
	if section_wanted("crew"): await crew_scenes()
	if section_wanted("props"): await props_scenes()
	write_manifest()
	var seconds := (Time.get_ticks_msec() - started) / 1000.0
	print("VISUAL TOUR %s: %d views in %.1f s -> %s%s%s" % [label, captured, seconds, out_dir,
		"" if missing.is_empty() else "; MISSING " + str(missing), "" if overruns.is_empty() else "; SLOT OVERRUN " + str(overruns)])
	quit(0 if missing.is_empty() and overruns.is_empty() else 1)

func write_manifest() -> void:
	var path := out_dir.path_join("views.json")
	var previous: Dictionary = {}
	if FileAccess.file_exists(path):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
		if parsed is Dictionary:
			for entry in parsed.get("views", []): previous[entry.name] = entry
	previous.merge(entries, true)
	var ordered: Array = []
	for item in VIEWS:
		if previous.has(item[0]): ordered.append(previous[item[0]])
	var manifest := {"label": label, "size": [SIZE.x, SIZE.y], "seed": int(SEED), "settle_frames": settle_frames, "slot_frames": slot_frames, "tour_start_frame": tour_start,
		"conventions": "X downstream, +Z inland; rig yaw 0 faces the river, PI faces inland", "views": ordered}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t", false))
	file.close()
