extends SceneTree
func _initialize() -> void: run.call_deferred()
func run() -> void:
	root.size=Vector2i(1920,1080)
	root.get_node("GameState").apply_scenario({"day":100,"hour":13,"weather":"rain"})
	var store: Node3D=load("res://scenes/store.tscn").instantiate();root.add_child(store)
	store.camera_rig.focus(Vector3(0,1.7,5),Vector3(0,1.8,-1),65)
	var rain: Node=store.get_node("Rain");rain.current=1
	for mesh in store.find_children("*","GeometryInstance3D",true,false):
		if mesh!=rain.particles: mesh.hide()
	var shader:=Shader.new()
	shader.code="shader_type spatial;render_mode unshaded,fog_disabled,cull_disabled;varying vec3 p;void vertex(){p=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}void fragment(){bool below=abs(p.x)<2.7&&p.z> -2.5&&p.z<1.3&&p.y>.05&&p.y<3.4-abs(p.x)*.23-.35;ALBEDO=below?vec3(1.,0.,0.):vec3(0.,1.,0.);}"
	var material:=ShaderMaterial.new();material.shader=shader;rain.particles.draw_pass_1.material=material
	var env:=Environment.new();env.background_mode=Environment.BG_COLOR;env.background_color=Color.BLACK
	store.camera_rig.camera.environment=env;store.camera_rig.camera.attributes=CameraAttributesPractical.new()
	for i in 120: await process_frame
	var bad:=0;var visible:=0
	for sample in 12:
		for i in 15: await process_frame
		await RenderingServer.frame_post_draw
		var im:=root.get_texture().get_image()
		for y in range(0,1080,2):
			for x in range(0,1920,2):
				var c:=im.get_pixel(x,y)
				if c.r>.7 and c.g<.2: bad+=1
				if c.g>.7 and c.r<.2: visible+=1
	var result:={"samples":12,"below_canvas_pixels":bad,"outside_rain_pixels":visible}
	FileAccess.open("res://artifacts/store-rain-probe.json",FileAccess.WRITE).store_string(JSON.stringify(result,"\t"));print(result)
	store.get_node("Soundscape").stop();rain.sound.stop();quit(0 if bad==0 and visible>0 else 1)
