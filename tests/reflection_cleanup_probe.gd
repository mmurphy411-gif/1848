extends SceneTree
## Minimal engine-level reproduction, without the miner, water or asset caches.
## https://github.com/godotengine/godot/issues/122498
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var scene:=Node3D.new();root.add_child(scene)
	var mesh:=MeshInstance3D.new();mesh.mesh=SphereMesh.new();scene.add_child(mesh)
	var camera:=Camera3D.new();scene.add_child(camera)
	camera.position=Vector3(0,1,3);camera.look_at(Vector3.ZERO);camera.current=true
	var world:=WorldEnvironment.new();world.environment=Environment.new()
	world.environment.background_mode=Environment.BG_COLOR
	world.environment.background_color=Color(.4,.5,.6)
	scene.add_child(world)
	if not "--without-probe" in OS.get_cmdline_user_args():
		var probe:=ReflectionProbe.new();probe.size=Vector3.ONE*8;scene.add_child(probe)
	for i in 120:await process_frame
	print("Reflection cleanup reproduction: ","without probe" if "--without-probe" in OS.get_cmdline_user_args() else "with probe")
	scene.queue_free()
	for i in 16:await process_frame
	quit()
