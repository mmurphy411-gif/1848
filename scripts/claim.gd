extends Node3D
var quitting := false
## Scene instances stay posed for tools; launching this as the main scene starts play.
func _ready() -> void:
	var mining := preload("res://scripts/mining.gd").new();mining.name="Mining";add_child(mining)
	var wildlife := preload("res://scripts/wildlife.gd").new();wildlife.name="Wildlife";add_child(wildlife)
	var expedition := preload("res://scripts/expedition.gd").new();expedition.name="Expedition";add_child(expedition)
	var season := preload("res://scripts/season_end.gd").new();season.name="SeasonEnd";add_child(season)
	var photo := preload("res://scripts/photo_mode.gd").new();photo.name="PhotoMode";add_child(photo)
	var crew := preload("res://scripts/crew.gd").new();crew.name="Crew";add_child(crew)
	var book := preload("res://scripts/crew_book.gd").new();book.name="CrewBook";add_child(book)
	var dam := preload("res://scripts/wing_dam.gd").new();dam.name="WingDam";add_child(dam)
	get_node("/root/Trip").configure(self)
	var path:=MeshInstance3D.new();path.name="StoreTrail"
	var layout=preload("res://scripts/claim_layout.gd")
	var surface:=SurfaceTool.new();surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trail: Vector3=get_node("/root/Trip").trail
	for step in 24:
		for corner in [Vector2(0,0),Vector2(1,1),Vector2(1,0),Vector2(0,0),Vector2(0,1),Vector2(1,1)]:
			var point:=trail+Vector3((corner.x-.5)*1.2,0,-1+(step+corner.y)*.25)
			point.y=layout.height_at(point.x,point.z)+.025
			surface.add_vertex(point)
	surface.generate_normals();path.mesh=surface.commit()
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.31,.25,.16,.6);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
	path.material_override=mat;add_child(path)
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
			$Daylight/Clock.advanced.connect(state.crew_tick)
		for script in ["pause_menu","time_skip"]:
			var node: Node=load("res://scripts/%s.gd" % script).new();node.name=script.to_pascal_case();add_child(node)
		# A plain launch opens on the title; development presets go straight in.
		if OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name()!="headless":
			var title: Node=preload("res://scripts/title.gd").new();title.name="Title";add_child(title)
			$Soundscape.start()
			return
		begin_play()

## Start (or resume) the season once the title has stepped aside.
func begin_play(save: Dictionary = {}) -> void:
	var state := get_node("/root/GameState")
	if not save.is_empty():
		preload("res://scripts/save_game.gd").apply(state,save)
	# Only a real, windowed launch keeps a save; tests and presets never write one.
	state.autosave = OS.get_cmdline_user_args().is_empty() and DisplayServer.get_name()!="headless" and not OS.has_feature("editor_hint")
	$Walker.set_physics_process(true)
	$"CameraRig/SpringArm3D/Camera3D".make_current()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if DisplayServer.get_name()!="headless" else Input.MOUSE_MODE_VISIBLE
	$Daylight/Clock.start(state.start_hour)
	$Soundscape.start()
	if state.day>=132: state.finish_season();return
	if state.scene=="store":
		$Daylight/Clock.start(7)
		get_node("/root/Trip").depart(true)
		get_node("/root/Trip").shop.walker.position=Vector3(0,0,1.3)
		return
	if state.start_encounter!="":
		$Expedition.focus(state.start_encounter)
	elif state.start_work!="":
		$Mining.focus_site(state.start_work)
	elif state.day>=81 and state.day<=127 and state.start_hour>=5 and state.start_hour<=8:
		var layout=preload("res://scripts/claim_layout.gd")
		var z: float=layout.shore_z(-34)-.8
		$Walker.position=Vector3(-34,layout.height_at(-34,z)+.05,z)
		$CameraRig.yaw=.25;$CameraRig.pitch=-.38
	if not save.is_empty(): preload("res://scripts/save_game.gd").place(self,save)
	$Crew.sync();$Crew.settle()

## Esc from the orbit camera opens the pause book during play.
func open_pause() -> bool:
	if has_node("Title") or not has_node("PauseMenu") or get_node("/root/Trip").travelling: return false
	if $Activities.ui_open() or $Activities.busy or $Walker/Panner.state!=0 or $Walker/Fisher.state!=0: return false
	if has_node("PhotoMode") and $PhotoMode.get("active"): return false
	$PauseMenu.open();return true

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
