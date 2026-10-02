extends Node3D
const Layout=preload("res://scripts/claim_layout.gd")
const Fishery=preload("res://scripts/fishery.gd")
const Fight=preload("res://scripts/fight_model.gd")
const Cooking=preload("res://scripts/cooking.gd")
enum State { IDLE, STANCE, CAST, DRIFT, BITE, FIGHT, LAND, SHOWING, SNAGGED }
var state := State.IDLE
var reproducible := false
var rng := RandomNumberGenerator.new()
var elapsed := 0.0
var bait_type := ""
var bait_loaded := false
var target := Vector3.ZERO
var cast_from := Vector3.ZERO
var hazard := 1.0
var bite_in := -1.0
var hooked_species := "trout"
var hooked_spot := -1
var weight := 1.0
var fight: Dictionary={}
var fish: Node3D
var trophy: MeshInstance3D
var line: Node3D
var flow_vertices := PackedVector3Array()
var flow_colors := PackedColorArray()
var flow := Vector2(.25,0)
var flow_time := 0.0
var flow_mesh: Mesh
@onready var walker: CharacterBody3D=get_parent()
@onready var visual: Node3D=walker.get_node("Visual")
@onready var game: Node=get_node("/root/GameState")
@onready var school: Node3D=walker.get_parent().get_node("FishSchool")
@onready var clock: Node=walker.get_parent().get_node("Daylight/Clock")
func _ready() -> void:
	line=preload("res://scripts/fishing_line.gd").new()
	add_child(line)
	process_physics_priority=25
	game.changed.connect(refresh_flow)
	refresh_flow()

func refresh_flow() -> void:
	if not is_inside_tree(): return
	var water: MeshInstance3D=walker.get_parent().get_node("Greybox/River/WaterSurface")
	if flow_mesh==water.mesh: return
	flow_mesh=water.mesh
	var arrays: Array=water.mesh.surface_get_arrays(0)
	flow_vertices=arrays[Mesh.ARRAY_VERTEX];flow_colors=arrays[Mesh.ARRAY_COLOR]

func sample_flow(point: Vector3) -> Vector2:
	var nearest := INF
	var index := 0
	for i in flow_vertices.size():
		var d := Vector2(flow_vertices[i].x-point.x,flow_vertices[i].z-point.z).length_squared()
		if d<nearest: nearest=d;index=i
	var color := flow_colors[index]
	return Vector2(color.r*2-1,color.g*2-1).normalized()*color.b
func can_fish() -> bool:
	if game.season_ended: return false
	var p := walker.global_position
	return state==State.IDLE and walker.panner.state==0 and walker.river.work_edge(p,walker.wade_limit()) and game.inventory.hooks>0 and game.inventory.line_m>=6 and has_bait() and not walker.get_parent().get_node("Activities").busy
func has_bait() -> bool:
	for kind in Fishery.BAITS:
		if game.inventory.bait[kind]>0: return true
	return bait_loaded
func message(text: String,seconds := 1.5) -> void: walker.get_parent().get_node("HUD").notify(text,seconds)
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and state!=State.IDLE:
		if state==State.SHOWING: stance()
		else: cancel()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("interact") and state==State.STANCE:
		cycle_bait();get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed and state==State.STANCE and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		cycle_bait();get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fish") and not event.is_echo():
		press();get_viewport().set_input_as_handled()
func press() -> void:
	match state:
		State.IDLE:
			if can_fish():
				rng.seed=hash(walker.position)^game.seed^game.day
				if not reproducible: rng.seed^=Time.get_ticks_usec()
				visual.turn_to(atan2(Layout.inland_normal(walker.position.x).x,Layout.inland_normal(walker.position.x).z))
				stance()
			else: message("No hooks" if game.inventory.hooks<=0 else "Not enough line" if game.inventory.line_m<6 else "No bait" if not has_bait() else "Fish from the water's edge")
		State.STANCE: cast()
		State.DRIFT: stance()
		State.BITE:
			if elapsed<.15:
				if is_instance_valid(fish): fish.flee()
				stance()
			elif elapsed<=.75:
				weight=Fishery.roll_weight(hooked_species,rng)
				fight=Fight.begin(weight,walker.global_position.distance_to(target),rng.randi())
				change(State.FIGHT,"strike")
		State.SHOWING: stance()
func cycle_bait() -> void:
	if bait_loaded:
		game.inventory.bait[bait_type]+=1
		bait_loaded=false
	var start := Fishery.BAITS.find(bait_type)
	for i in range(1,5):
		var kind: String=Fishery.BAITS[posmod(start+i,4)]
		if game.inventory.bait[kind]>0: bait_type=kind;return
	bait_type=""
func change(next: State,clip: String) -> void:
	state=next;elapsed=0
	visual.play_activity(clip)
func stance() -> void:
	walker.camera_rig.release_focus()
	if is_instance_valid(trophy): trophy.queue_free();trophy=null
	if is_instance_valid(fish): fish.approach=false
	fish=null
	if game.inventory.hooks<=0 or game.inventory.line_m<6 or not has_bait(): cancel();return
	if bait_type=="" or (not bait_loaded and game.inventory.bait.get(bait_type,0)<=0): cycle_bait()
	change(State.STANCE,"fish_idle")
	line.show();line.ring.show();line.mesh.hide();line.bait.hide()
func cancel() -> void:
	if bait_loaded:
		game.inventory.bait[bait_type]+=1
		bait_loaded=false
	if is_instance_valid(fish): fish.approach=false
	if is_instance_valid(trophy): trophy.queue_free();trophy=null
	state=State.IDLE;visual.stop_activity();line.hide();walker.camera_rig.release_focus()
func aim() -> Vector3:
	var camera: Camera3D=get_viewport().get_camera_3d()
	var direction := -camera.global_basis.z
	var point := walker.global_position-Layout.inland_normal(walker.position.x)*6
	if direction.y<-.015:
		point=camera.global_position+direction*((game.water_level()-camera.global_position.y)/direction.y)
	var origin := Vector2(walker.position.x,walker.position.z)
	var horizontal := Vector2(point.x,point.z)-origin
	horizontal=horizontal.limit_length(12 if game.inventory.get("rod",false) else 8)
	point=Vector3(origin.x+horizontal.x,game.water_level()+.025,origin.y+horizontal.y)
	if point.z>walker.river.shore_z(point.x)-.35:
		point=walker.global_position-Layout.inland_normal(walker.position.x)*5
	point.y=game.water_level()+.025
	return point
func cast() -> void:
	if bait_type=="": return
	if not bait_loaded:
		if game.inventory.bait[bait_type]<=0: cycle_bait();return
		game.inventory.bait[bait_type]-=1;game.changed.emit()
		bait_loaded=true
	target=aim();cast_from=visual.fishing_origin()
	line.ring.hide();line.mesh.show();line.bait.show()
	change(State.CAST,"cast")
func snag_chance(point: Vector3) -> float:
	for b in Layout.BOULDERS:
		if Vector2(point.x-b.x,point.z-b.y).length()<b.z+1: return .25
	for b in Layout.BEDROCK:
		if absf(point.x-b.x)<b.z*.5+1 and absf(point.z-b.y)<b.w*.5+1: return .25
	return 0.0
func drift() -> void:
	change(State.DRIFT,"fish_wait")
	hazard=-log(maxf(.00001,rng.randf()));bite_in=-1
static func step_with_rod(old: Dictionary,delta: float,pull: bool,rod: bool) -> Dictionary:
	var input:=old.duplicate()
	if rod and pull and input.elapsed+delta>=input.run_at and input.elapsed+delta<input.run_at+.8:
		input.tension-=Fight.RUN_TENSION_RATE*.2*delta
	var next:=Fight.step(input,delta,pull)
	if rod and not next.broken and not old.landed:
		next.distance=clampf(old.distance+(-1.2 if pull else .5)*delta,.65,12)
		next.landed=next.stamina<=0 and next.distance<=1
	return next
func _physics_process(delta: float) -> void:
	if state==State.IDLE: return
	elapsed+=delta
	if not walker.river.work_edge(walker.global_position,walker.wade_limit()):
		cancel();return
	if state==State.STANCE:
		target=aim();line.ring.global_position=target;return
	var end := target
	if state==State.CAST:
		var u := clampf(elapsed/1.2,0,1)
		end=cast_from.lerp(target,u)+Vector3.UP*sin(u*PI)*1.5
		if elapsed>=1.2:
			if rng.randf()<snag_chance(target): change(State.SNAGGED,"fish_wait");message("Snagged")
			else: drift()
	elif state==State.DRIFT:
		flow_time-=delta
		if flow_time<=0: flow=sample_flow(target);flow_time=1.0
		var speed := .6 if bait_type=="grasshopper" else .25
		var point := target+Vector3(flow.x,0,flow.y)*speed*delta
		if Vector2(point.x-walker.position.x,point.z-walker.position.z).length()<=(12 if game.inventory.get("rod",false) else 8): target=point
		target.y=game.water_level()+.025+sin(elapsed*3)*.008 if bait_type=="grasshopper" else lerpf(game.water_level(),Layout.height_at(target.x,target.z),.6)
		if bite_in>=0:
			bite_in-=delta
			if is_instance_valid(fish): fish.approach_target=target
			if bite_in<=0:
				change(State.BITE,"fish_wait")
				walker.get_node("ActionAudio").twitch()
		else:
			var spot := Fishery.spot_at(target.x,target.z)
			var total := 0.0
			var rates: Dictionary={}
			for species in Fishery.SPECIES:
				var rate := Fishery.bite_rate(species,spot,game.day,clock.hour_at(clock.elapsed),bait_type,game.seed,game.weather(),game.inventory.get("catch_log",[]))
				if school.nearest(species,target)==null: rate=0
				rates[species]=rate;total+=rate
			hazard-=total*delta
			if hazard<=0 and total>0:
				var roll := rng.randf()*total
				for species in rates:
					roll-=rates[species]
					if roll<=0 and rates[species]>0: hooked_species=species;hooked_spot=spot.get("spot_index",-1);break
				fish=school.nearest(hooked_species,target)
				if is_instance_valid(fish): fish.approach=true;fish.approach_target=target;bite_in=2
				else: hazard=1
	elif state==State.BITE:
		end+=Vector3(sin(elapsed*40)*.15,0,0)
		if elapsed>.75:
			bait_loaded=false
			if is_instance_valid(fish): fish.flee()
			message("The bait is gone");stance()
	elif state==State.FIGHT:
		# A visible surge precedes the run by .4 s, allowing a human release.
		if is_instance_valid(fish) and fight.run_at-fight.elapsed<.4:
			fish.approach_target=target+Vector3(-.35,0,0)
		if elapsed>.4 and visual.activity_clip=="strike": visual.play_activity("fight")
		fight=step_with_rod(fight,delta,Input.is_action_pressed("fish"),game.inventory.get("rod",false))
		visual.activity_rate=1.25 if Input.is_action_pressed("fish") else .5
		var direction := (target-walker.position).normalized()
		target=walker.position+direction*fight.distance
		target.y=-.12
		if is_instance_valid(fish) and fight.run_at-fight.elapsed>=.4: fish.approach_target=target
		if fight.broken:
			game.lose_hook();bait_loaded=false
			if is_instance_valid(fish): fish.flee()
			message("Line broke — 100% tension. Release F / Y during runs.",4);stance()
		elif fight.landed: land()
	elif state==State.LAND:
		if is_instance_valid(trophy): trophy.global_position=visual.right_hand.global_position
		if elapsed>=2:
			state=State.SHOWING;elapsed=0
			game.caught(Cooking.fresh(hooked_species,weight,game.day),hooked_spot)
			bait_loaded=false
	elif state==State.SHOWING:
		if is_instance_valid(trophy):
			trophy.global_position=visual.right_hand.global_position
			walker.camera_rig.focus(trophy.global_transform,true)
		if elapsed>=2.5: stance()
	elif state==State.SNAGGED:
		if not Input.is_action_pressed("fish"): elapsed=0
		if elapsed>=1.5:
			if rng.randf()>=.5: game.lose_hook();bait_loaded=false;message("Hook lost")
			else: message("Line freed")
			stance()
	line.draw_line(visual.fishing_origin(),end,state in [State.FIGHT,State.SNAGGED])
func land() -> void:
	if is_instance_valid(fish): fish.retired=true
	trophy=MeshInstance3D.new();trophy.mesh=school.sources[hooked_species]
	preload("res://scripts/fish.gd").dress(trophy,hooked_species)
	trophy.scale=Vector3.ONE*pow(weight,1.0/3.0)
	walker.get_parent().add_child(trophy)
	change(State.LAND,"land")
	line.hide()
