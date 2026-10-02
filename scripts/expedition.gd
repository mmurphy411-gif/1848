extends Node3D
## Live encounter actions; all irreversible results are recorded on GameState.
const Model=preload("res://scripts/expedition_model.gd")
const Layout=preload("res://scripts/claim_layout.gd")
const Pack=preload("res://scripts/pack.gd")
var selected: Node3D
var tool: Node3D
var elapsed:=0.0
var raid_bear: Node3D
var raid_elapsed:=0.0
var rifle_selected:=false
var corpses: Dictionary={}
var sound:=AudioStreamPlayer3D.new()
@onready var game: Node=get_node("/root/GameState")
@onready var walker: CharacterBody3D=get_parent().get_node("Walker")
@onready var activities: Node=get_parent().get_node("Activities")
@onready var clock: Node=get_parent().get_node("Daylight/Clock")
@onready var wildlife: Node3D=get_parent().get_node("Wildlife")
func _ready() -> void:
	sound.bus="Foley";sound.volume_db=-12;add_child(sound)
	process_physics_priority=40
func animal_near(species: String, reach: float) -> Node3D:
	var nearest: Node3D=null
	var candidates: Array=wildlife.actors.duplicate()
	if species=="bear" and is_instance_valid(raid_bear): candidates.append(raid_bear)
	for actor in candidates:
		if actor.species!=species or actor.departed or actor.retiring: continue
		var delta: Vector3=actor.global_position-walker.global_position
		if delta.length()<reach and (-walker.get_node("Visual").global_basis.z).dot(delta.normalized())>0.55:
			reach=delta.length();nearest=actor
	return nearest
func salmon_near() -> Node3D:
	var nearest: Node3D=null;var reach:=3.3
	for fish in get_parent().get_node("FishSchool").get_children():
		if fish.species!="salmon" or fish.retired or not fish.visible or fish.flee_time>=0: continue
		var delta: Vector3=fish.global_position-walker.global_position
		if delta.length()<reach and (-walker.get_node("Visual").global_basis.z).dot(delta.normalized())>.45:
			reach=delta.length();nearest=fish
	return nearest
func prompt() -> String:
	if is_instance_valid(raid_bear) and not raid_bear.retiring and walker.global_position.distance_to(raid_bear.global_position)<12:
		if rifle_selected and game.inventory.get("rifle",false): return "Aim rifle at bear · F / Y to shout instead"
		return "Shout at bear · F / Y to select rifle" if game.inventory.get("rifle",false) else "Shout at bear"
	# Nearby camp furniture and mining equipment outrank distant quarry.
	if get_parent().get_node("Mining").target()!="" or get_parent().get_node("Camp").target(walker)!="": return ""
	if corpse_near()>=0: return "Dress game · take meat and hide"
	if rifle_selected and animal_near("bear",30)!=null: return "Aim rifle at bear · F / Y to shout instead"
	var quarry:=animal_near("deer",30)
	if quarry!=null:
		if not game.inventory.get("rifle",false): return "Deer · rifle needed"
		return "Aim rifle · %d shots" % game.inventory.get("ammo",0)
	if animal_near("bear",12)!=null: return "Shout at bear · F / Y to select rifle" if game.inventory.get("rifle",false) else "Shout at bear"
	if salmon_near()!=null:
		if Model.bear_claims(game.expedition,game.day,clock.hour_at(clock.elapsed)): return "Bear holds the riffle · drive it away"
		return "Spear salmon" if game.inventory.get("spear",false) else "Salmon · spear needed"
	return ""
func interact() -> bool:
	var text:=prompt()
	if text=="": return false
	if text.begins_with("Dress game"):
		activities.start("harvest","gather",4);elapsed=0;return true
	if text.begins_with("Aim rifle"):
		var target:=animal_near("bear" if "at bear" in text else "deer",30)
		if target==null: return true
		if game.inventory.get("ammo",0)<=0: get_parent().get_node("HUD").notify("Need powder and ball");return true
		if target.state==target.State.FLEE or target.walking or not clear_shot(target):
			get_parent().get_node("HUD").notify("Wait for a standing animal in a clear lane");return true
		selected=target;_begin("rifle","rifle",3);return true
	if text.begins_with("Shout at bear"):
		game.expedition.bear_driven_day=game.day;game.event("Shouted the bear away.")
		for actor in wildlife.actors:
			if actor.species=="bear": actor.retiring=true
		if is_instance_valid(raid_bear): raid_bear.retiring=true
		play_sound("shout");return true
	if text!="Spear salmon": return true
	var taken: int=game.expedition.salmon_taken.get(game.day,0)
	var weight:=Model.salmon_weight(game.seed,game.day,taken)
	if Pack.field_weight(game.inventory)+weight>Pack.LIMIT_LB:
		get_parent().get_node("HUD").notify("Make room in the pack · salmon can weigh 20 lb");return true
	selected=salmon_near()
	if selected==null: return true
	selected.approach=true;selected.approach_target=selected.global_position
	_begin("spear","spear",1.4)
	return true
func _begin(kind: String, clip: String, seconds: float) -> void:
	elapsed=0;activities.start(kind,clip,seconds);walker.velocity=Vector3.ZERO
	tool=load("res://assets/expedition/"+kind+".glb").instantiate();add_child(tool)
func complete(kind: String) -> void:
	if kind=="harvest":
		harvest();cleanup();return
	if kind=="rifle":
		fire_rifle();cleanup();return
	if kind=="spear" and is_instance_valid(selected) and not selected.retired:
		var taken: int=game.expedition.salmon_taken.get(game.day,0)
		var weight:=Model.salmon_weight(game.seed,game.day,taken)
		if Pack.field_weight(game.inventory)+weight<=Pack.LIMIT_LB:
			game.inventory.fish.append_array(Model.food("salmon",weight,game.day))
			game.inventory.catches.salmon=game.inventory.catches.get("salmon",0)+1
			game.expedition.salmon_taken[game.day]=taken+1
			selected.retired=true;selected.hide()
			game.event("Speared a %.2f lb salmon; cut it into portions." % weight);play_sound("spear")
	cleanup()
func cleanup() -> void:
	if is_instance_valid(selected) and "approach" in selected: selected.approach=false
	selected=null
	if is_instance_valid(tool): tool.queue_free()
	tool=null
func cancel() -> void:
	cleanup();activities.busy=false;activities.action="";walker.get_node("Visual").stop_activity()
func play_sound(kind: String) -> void:
	var path: String="res://assets/audio/"+kind+".wav"
	if ResourceLoader.exists(path): sound.stream=load(path);sound.global_position=walker.global_position;sound.play()
func _physics_process(delta: float) -> void:
	if not is_instance_valid(tool) or not is_instance_valid(selected): return
	elapsed+=delta
	var hand: Node3D=walker.get_node("Visual").right_hand
	var point: Vector3=selected.global_position+Vector3.UP*(.65 if activities.action=="rifle" else 0)
	tool.global_position=hand.global_position
	tool.look_at(point,Vector3.UP)
	# Keep the authored grip at the hand; thrust forward along the shaft.
	tool.global_position-=tool.global_basis.z*.12*sin(clampf(elapsed/1.4,0,1)*PI)
func exposed_food() -> float:
	var food: Array=game.inventory.fish.duplicate()
	if not game.inventory.get("rack",{}).is_empty(): food.append(game.inventory.rack)
	return Model.raid_food(food).lost_lb
func _process(delta: float) -> void:
	refresh_corpses()
	var hour: float=clock.hour_at(clock.elapsed)
	var night: bool=hour>=20.5 or hour<4.75
	if clock.running and night and Model.raid_due(game.expedition,game.day) and exposed_food()>0:
		if not is_instance_valid(raid_bear):
			raid_bear=preload("res://scripts/wildlife_actor.gd").new();raid_bear.species="bear";raid_bear.manager=wildlife
			var camp: Node3D=get_parent().get_node("Camp")
			raid_bear.position=camp.position+Vector3(4,0,-5);raid_bear.position.y=Layout.height_at(raid_bear.position.x,raid_bear.position.z)
			add_child(raid_bear);raid_bear.review_pose=true;raid_elapsed=0
			raid_bear.look_at(camp.position,Vector3.UP)
			get_parent().get_node("HUD").notify("A bear is nosing around the camp · G / X to shout",5)
		if not raid_bear.retiring:
			raid_elapsed+=delta
			raid_bear.elapsed+=delta;raid_bear.animate(delta)
			if raid_elapsed>=12: game.resolve_raid();raid_bear.review_pose=false;raid_bear.retiring=true
	if is_instance_valid(raid_bear) and (not night or raid_bear.retiring):
		raid_bear.review_pose=false;raid_bear.retiring=true
		if raid_bear.departed or not night: raid_bear.queue_free();raid_bear=null
func focus(kind: String) -> void:
	if kind in ["deer","bear"]:
		game.apply_scenario({"rifle":"1","ammo":"20"});rifle_selected=kind=="bear"
		wildlife.focus(kind)
		var actor: Node3D=null
		for candidate in wildlife.actors:
			if candidate.species==kind and not candidate.departed: actor=candidate;break
		if actor:
			var original: Vector3=walker.position
			for turn in range(16):
				var point: Vector3=actor.position+Vector3.BACK.rotated(Vector3.UP,turn*TAU/16)*12
				if not wildlife.safe(point,"deer"): continue
				point.y=Layout.height_at(point.x,point.z)+.05;walker.position=point
				if clear_shot(actor): break
				walker.position=original
			var toward: Vector3=actor.position-walker.position
			walker.camera_rig.yaw=atan2(-toward.x,-toward.z);walker.camera_rig.pitch=-.24
			walker.get_node("Visual").rotation.y=atan2(-toward.x,-toward.z)
		return
	if kind=="salmon":
		game.apply_scenario({"day":"99","spear":"1","hour":"9"});get_parent().get_node("Daylight").apply(9);clock.start(9)
		get_parent().get_node("FishSchool").refresh()
		for fish in get_parent().get_node("FishSchool").get_children():
			if fish.species!="salmon" or fish.retired: continue
			var p: Vector3=fish.home+Vector3(0,0,2.65);p.y=Layout.height_at(p.x,p.z)+.05
			walker.position=p;walker.velocity=Vector3.ZERO;walker.get_node("Visual").rotation.y=0
			walker.camera_rig.yaw=0;walker.camera_rig.pitch=-.4;return
	elif kind=="raid":
		game.apply_scenario({"day":"99","hour":"21","fish.smoked":"3"});game.expedition.bear_driven_day=-1;game.expedition.raided_day=-1
		get_parent().get_node("Daylight").apply(21);clock.start(21)
		walker.position=get_parent().get_node("Camp").position+Vector3(3,0,-2)
		walker.position.y=Layout.height_at(walker.position.x,walker.position.z)+.05;walker.velocity=Vector3.ZERO
		walker.get_node("Visual").rotation.y=0;walker.camera_rig.yaw=0;walker.camera_rig.pitch=-.25

func _input(event: InputEvent) -> void:
	if activities.idle() and event.is_action_pressed("fish") and game.inventory.get("rifle",false) and animal_near("bear",30)!=null:
		rifle_selected=not rifle_selected;get_viewport().set_input_as_handled()
func clear_shot(actor: Node3D) -> bool:
	var from: Vector3=walker.global_position+Vector3.UP*1.3
	var to: Vector3=actor.global_position+Vector3.UP*.65
	if from.distance_to(to)>30: return false
	var query:=PhysicsRayQueryParameters3D.create(from,to,1,[walker.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()
func fire_rifle() -> void:
	if game.inventory.get("ammo",0)<=0 or not game.inventory.get("rifle",false): return
	game.inventory.ammo-=1
	var attempt: int=game.expedition.shots;game.expedition.shots+=1
	play_sound("rifle")
	var hit: bool=is_instance_valid(selected) and not selected.departed and not selected.retiring and selected.state!=selected.State.FLEE and not selected.walking and clear_shot(selected)
	if hit: hit=Model.shot(game.seed,game.day,attempt,game.condition,walker.global_position.distance_to(selected.global_position),3)
	if not hit:
		game.expedition.deer_spooked_until=game.day+3
		for actor in wildlife.actors:
			if actor.species in ["deer","bear"]: actor.retiring=true
		game.expedition.bear_driven_day=game.day
		if is_instance_valid(raid_bear): raid_bear.retiring=true
		game.event("The shot missed. Deer fled for three days.");return
	var identity: String=selected.get_meta("identity",selected.species+"0")
	if selected.species=="bear": game.expedition.bear_dead=true
	else: game.expedition.deer_dead.append(identity)
	game.expedition.carcasses.append({"id":identity,"species":selected.species,"position":selected.global_position,"rotation":selected.rotation.y,"day":game.day,"meat":30.0 if selected.species=="bear" else 12.0,"hide":true})
	selected.departed=true;selected.hide()
	game.event("Took a %s. Dress it before the meat spoils." % selected.species)
func corpse_near() -> int:
	for i in game.expedition.carcasses.size():
		var record: Dictionary=game.expedition.carcasses[i]
		if (record.meat>0 or record.hide) and walker.global_position.distance_to(record.position)<2.4: return i
	return -1
func harvest() -> void:
	var index:=corpse_near()
	if index<0: return
	var record: Dictionary=game.expedition.carcasses[index]
	var room:=maxf(0,Pack.LIMIT_LB-Pack.field_weight(game.inventory));var hide_weight:=6.0 if record.species=="bear" else 3.0
	if record.hide and room>=hide_weight:
		game.inventory.hides.append({"id":record.id,"species":record.species,"weight_lb":hide_weight});record.hide=false;room-=hide_weight
	var meat:=minf(floorf(room),record.meat)
	if meat>0:
		game.inventory.fish.append_array(Model.food("bear meat" if record.species=="bear" else "venison",meat,game.day));record.meat-=meat
	game.event("Dressed game: %.0f lb of meat taken; %.0f lb remain. %s" % [meat,record.meat,"Hide remains; make pack space." if record.hide else "Hide taken."])
	play_sound("harvest")
func refresh_corpses() -> void:
	var wanted: Array=[]
	for record in game.expedition.carcasses:
		if game.day>record.day: record.meat=0.0
		if record.meat<=0 and not record.hide: continue
		wanted.append(record.id)
		if corpses.has(record.id): continue
		var body: Node3D=preload("res://scripts/wildlife_actor.gd").carcass(self,record)
		corpses[record.id]=body
	for id in corpses.keys():
		if id not in wanted: corpses[id].queue_free();corpses.erase(id)
