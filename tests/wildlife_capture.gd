extends SceneTree
const Layout=preload("res://scripts/claim_layout.gd")
var claim: Node3D
var camera: Camera3D
var subject: Node3D
var failures := 0
var coverage: Dictionary={}
func _initialize() -> void: run.call_deferred()
func shot(label: String, eye: Vector3, target: Vector3, fov := 40.0) -> void:
	camera.position=eye;camera.look_at(target);camera.fov=fov;camera.make_current()
	for i in 24: await process_frame
	await RenderingServer.frame_post_draw
	if not preload("res://tests/composition_guard.gd")._ray(self,label,minf(2,camera.position.distance_to(target)),[]): failures+=1
	root.get_texture().get_image().save_png("res://artifacts/wildlife-"+label+".png")
	print("CAPTURE ",label)
	if subject!=null: await measure(label)

func measure(label: String) -> void:
	var mat := ShaderMaterial.new();var shader := Shader.new()
	shader.code="shader_type spatial; render_mode unshaded, fog_disabled; void fragment(){ALBEDO=vec3(1,0,1);}"
	mat.shader=shader
	var saved: Dictionary={}
	for mesh in subject.find_children("*","MeshInstance3D",true,false):
		saved[mesh]=mesh.material_override;mesh.material_override=mat
	var environment := camera.environment;var attributes := camera.attributes
	var neutral := Environment.new();neutral.tonemap_mode=Environment.TONE_MAPPER_LINEAR
	camera.environment=neutral;camera.attributes=CameraAttributesPractical.new()
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var im := root.get_texture().get_image()
	var count := 0
	for y in range(0,im.get_height(),2):
		for x in range(0,im.get_width(),2):
			var c := im.get_pixel(x,y)
			if c.r>.98 and c.b>.98 and c.g<.02: count+=1
	var fraction := float(count)/float(ceili(im.get_width()/2.0)*ceili(im.get_height()/2.0))
	coverage[label]=fraction
	print("COVERAGE ",label,": ",fraction)
	if fraction<.08: failures+=1;push_error("Wildlife close-up subject under 8% of frame: "+label)
	for mesh in saved: mesh.material_override=saved[mesh]
	camera.environment=environment;camera.attributes=attributes

func motion(species: String) -> void:
	for actor in claim.get_node("Wildlife").actors:
		if actor.species!=species: continue
		actor.review_pose=false;actor.set_physics_process(false)
		claim.get_node("Walker").position=actor.position+Vector3(2,0,1)
		var origin: Vector3=actor.position
		var distance := 4.0 if species=="deer" else 1.6
		for frame in 20:
			for step in 3: actor._physics_process(1.0/60)
			var target: Vector3=actor.position+Vector3(0,.8 if species=="deer" else .18,0)
			camera.position=target+Vector3(distance,.3,-distance*.4);camera.look_at(target);camera.fov=42;camera.make_current()
			for i in 3: await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://artifacts/wildlife-%s-motion-%02d.png" % [species,frame])
		actor.review_pose=true
		print("MOTION ",species, " traveled ",actor.position.distance_to(origin))
		return
func run() -> void:
	root.size=Vector2i(1440,1000)
	var game: Node=root.get_node("GameState")
	game.apply_scenario({"day":"99","weather":"clear","hour":"6.5"})
	claim=load("res://scenes/claim.tscn").instantiate();root.add_child(claim)
	claim.get_node("Daylight/Clock").start(6.5);claim.get_node("Daylight").apply(8.5)
	claim.get_node("Wildlife").refresh(true)
	claim.get_node("HUD").hide();claim.get_node("Walker").set_physics_process(false)
	claim.get_node("Walker").position=Vector3(30,3,25)
	camera=Camera3D.new();claim.add_child(camera);camera.attributes=claim.get_node("Daylight").camera_attributes
	for actor in claim.get_node("Wildlife").actors: actor.review_pose=true
	for species in ["bear","deer","squirrel","quail","jay"]:
		for actor in claim.get_node("Wildlife").actors:
			if actor.species!=species: continue
			actor.rotation.y=.35
			actor.animate(1.0/60)
			subject=actor
			var p: Vector3=actor.position
			var height: float={"bear":.64,"deer":.88,"squirrel":.22,"quail":.18,"jay":.21}[species]
			var distance: float={"bear":3.5,"deer":3.5,"squirrel":.85,"quail":.68,"jay":.72}[species]
			var lens := 38.0 if species=="bear" else 34.0 if species=="squirrel" else 25.0
			await shot(species,p+Vector3(distance*.85,height+distance*.27,-distance),p+Vector3(0,height,0),lens)
			await shot(species+"-profile",p+Vector3(distance*(-1.2 if species=="deer" else 1.2),height+.12,.1),p+Vector3(0,height,0),lens+3.5 if species=="deer" else lens)
			break
	subject=null
	await shot("habitat",Vector3(-20,4.8,-12),Vector3(-27,.7,-2),54)
	for species in ["deer","jay"]: await motion(species)
	claim.get_node("Wildlife").focus("deer")
	claim.get_node("HUD").show()
	claim.get_node("CameraRig/SpringArm3D/Camera3D").make_current()
	for i in 60: await process_frame
	await RenderingServer.frame_post_draw
	if not preload("res://tests/composition_guard.gd").check(self,"wildlife player view"): failures+=1
	root.get_texture().get_image().save_png("res://artifacts/wildlife-player.png")
	var file := FileAccess.open("res://artifacts/wildlife-coverage.json",FileAccess.WRITE);file.store_string(JSON.stringify(coverage,"\t"));file.close()
	print("WILDLIFE CAPTURES: ","PASS" if failures==0 else "FAIL")
	quit(0 if failures==0 else 1)
