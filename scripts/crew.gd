extends Node3D
## The visible outfit: hands at their work, men waiting at the trail, the crew's
## fire, bunk tents, the claim notice and the harmonica after supper. Season
## records and yields belong to GameState and CrewModel; this only shows them.
const Model=preload("res://scripts/crew_model.gd")
const Layout=preload("res://scripts/claim_layout.gd")
const Hand=preload("res://scripts/crew_hand.gd")
const Calendar=preload("res://scripts/calendar.gd")
const Visual=preload("res://scripts/miner_visual.gd")
const Look=preload("res://scripts/crew_look.gd")
const FIRE_OFFSET:=Vector3(7.5,0,.6)
const BUNK_SPOTS:=[Vector3(6.2,0,5.2),Vector3(9.8,0,5.6),Vector3(5.6,0,8.6),Vector3(9.4,0,9.0)]
const TUNES:=["tune_susanna","tune_traveler","tune_home"]
var library:=AnimationLibrary.new()
var hands: Dictionary={}
var waiting: Dictionary={}
var bunks: Array[Node3D]=[]
var fire:=Node3D.new()
var flame:=GPUParticles3D.new()
var light:=OmniLight3D.new()
var fire_sound:=AudioStreamPlayer3D.new()
var music:=AudioStreamPlayer3D.new()
var music_gap:=6.0
var tune_index:=0
var notice: Label3D
var cradle_time:=0.0
var focus_id:=""
@onready var game: Node=get_node("/root/GameState")
@onready var claim: Node3D=get_parent()
@onready var clock: Node=claim.get_node("Daylight/Clock")
@onready var camp: Node3D=claim.get_node("Camp")

func _ready() -> void:
	_build_library()
	_build_fire()
	_build_notice()
	game.crew_changed.connect(sync)
	game.changed.connect(sync)
	game.new_day.connect(sync)
	sync()
	_schedule(true)

func _build_library() -> void:
	var mining: Node3D=load("res://assets/mining/miner_clips.glb").instantiate()
	var source: AnimationPlayer=mining.find_children("*","AnimationPlayer",true,false)[0]
	for name in ["crevice","spoon","shovel","pick","rock"]:
		var animation:=source.get_animation(name).duplicate() as Animation
		animation.loop_mode=Animation.LOOP_LINEAR
		library.add_animation(name,animation)
	mining.free()

## The base clips need the same frame-one crop and loop modes as the miner's rig.
func prepare(player: AnimationPlayer) -> void:
	for name in Visual.CLIPS:
		if not player.has_animation(name): continue
		var animation:=player.get_animation(name)
		animation.length=Visual.CLIPS[name]
		animation.loop_mode=Animation.LOOP_LINEAR if name in ["idle","walk","wade","pan_swirl","fish_idle","fish_wait","fight","cook","eat"] else Animation.LOOP_NONE
	for name in ["pan_swirl_2","pan_swirl_3"]:
		if player.has_animation(name):
			player.get_animation(name).length=2.0;player.get_animation(name).loop_mode=Animation.LOOP_LINEAR

func fire_point() -> Vector3:
	var p:=camp.global_position+FIRE_OFFSET
	p.y=Layout.height_at(p.x,p.z);return p

func _build_fire() -> void:
	add_child(fire)
	fire.global_position=fire_point()
	var ring: MeshInstance3D=camp.props.FireRing.get_child(0).duplicate()
	fire.add_child(ring);ring.transform=camp.props.FireRing.get_child(0).transform
	flame.amount=40;flame.lifetime=.45;flame.position.y=.1;flame.visibility_aabb=AABB(Vector3(-2,0,-2),Vector3(4,4,4))
	var process:=ParticleProcessMaterial.new();process.emission_shape=ParticleProcessMaterial.EMISSION_SHAPE_SPHERE;process.emission_sphere_radius=.16
	process.direction=Vector3.UP;process.spread=20;process.initial_velocity_min=.25;process.initial_velocity_max=.75;process.gravity=Vector3(0,.8,0);process.scale_min=.35;process.scale_max=1.1
	flame.process_material=process
	var mesh:=SphereMesh.new();mesh.radius=.12;mesh.height=.2;mesh.radial_segments=6;mesh.rings=3
	var fire_material:=ShaderMaterial.new();fire_material.shader=preload("res://shaders/fire.gdshader");mesh.material=fire_material
	flame.draw_pass_1=mesh;flame.emitting=false;fire.add_child(flame)
	light.position.y=.55;light.light_color=Color(1,.5,.17);light.omni_range=8;light.shadow_enabled=false;light.visible=false
	fire.add_child(light)
	fire_sound.stream=preload("res://assets/audio/fire.wav").duplicate()
	fire_sound.stream.loop_mode=AudioStreamWAV.LOOP_FORWARD
	fire_sound.stream.loop_end=roundi(fire_sound.stream.get_length()*fire_sound.stream.mix_rate)
	fire_sound.bus="Ambience";fire_sound.unit_size=4;fire_sound.volume_db=-24;fire.add_child(fire_sound)
	music.bus="Music" if AudioServer.get_bus_index("Music")>=0 else "Ambience";music.unit_size=6;music.volume_db=-9;music.position.y=1.3
	fire.add_child(music)
	music.finished.connect(func(): music_gap=randf_range(8,20);tune_index+=1)
	fire.visible=false

func _build_notice() -> void:
	var stake:=MeshInstance3D.new();var pole:=BoxMesh.new();pole.size=Vector3(.09,1.3,.09);stake.mesh=pole
	var wood:=StandardMaterial3D.new();wood.albedo_color=Color(.38,.27,.16);wood.roughness=.9;stake.material_override=wood
	var p:=camp.global_position+Vector3(2.1,0,4.6);p.y=Layout.height_at(p.x,p.z)
	add_child(stake);stake.global_position=p+Vector3(0,.65,0)
	var paper:=MeshInstance3D.new();var sheet:=BoxMesh.new();sheet.size=Vector3(.62,.5,.012);paper.mesh=sheet
	var mat:=StandardMaterial3D.new();mat.albedo_color=Color(.88,.83,.68);mat.roughness=.95;paper.material_override=mat
	stake.add_child(paper);paper.position=Vector3(0,.42,-.055)
	notice=Label3D.new();notice.font=preload("res://assets/fonts/Cedarville-Cursive.ttf");notice.font_size=40;notice.pixel_size=.0011
	notice.modulate=Color(.15,.11,.07);notice.outline_size=0;notice.shaded=true;notice.rotation.y=PI
	paper.add_child(notice);notice.position=Vector3(0,0,-.008)
	stake.visible=false

## Each man's fixed casting (hat, hair, beard, garments, skin and build): crew_look.gd.
func _look(id: String) -> Dictionary: return Look.look(id)

func _spawn(id: String) -> Node3D:
	var hand: Node3D=Hand.new();hand.manager=self;hand.name="Hand_"+id
	add_child(hand);hand.setup(id,_look(id));prepare(hand.player)
	return hand

## Match the scene to the books: hire, dismiss, arrivals and the notice.
func sync() -> void:
	if not is_inside_tree(): return
	var keep: Array=[]
	for h in game.crew.hands:
		keep.append(h.id)
		if not hands.has(h.id):
			if waiting.has(h.id):
				hands[h.id]=waiting[h.id];waiting.erase(h.id)
				# Hired, he leaves his bedroll pack at camp.
				hands[h.id].figure.show_equipment("pack",bool(_look(h.id).get("pack",false)))
			else:
				hands[h.id]=_spawn(h.id)
				var start:=Trip_point()+Vector3(0,0,1.5);hands[h.id].place(start,PI,"idle")
	for id in hands.keys():
		if not id in keep: hands[id].queue_free();hands.erase(id)
	var arrivals: Array=Model.applicants(game.crew,game.day).map(func(m): return m.id) if not game.season_ended else []
	for id in waiting.keys():
		if not id in arrivals: waiting[id].queue_free();waiting.erase(id)
	for i in arrivals.size():
		var id: String=arrivals[i]
		if waiting.has(id): continue
		waiting[id]=_spawn(id)
		# Men come up the trail with their blankets on their backs.
		waiting[id].figure.show_equipment("pack",true)
		var spot:=Trip_point()+Vector3(1.3+i*.9,0,.4+i*.5);spot.y=Layout.height_at(spot.x,spot.z)
		waiting[id].place(spot,PI*.85,"idle")
	var count: int=game.inventory.get("bunks",0)
	while bunks.size()<mini(count,BUNK_SPOTS.size()):
		var tent: Node3D=load("res://assets/expedition/tent.glb").instantiate();add_child(tent)
		var p: Vector3=camp.global_position+BUNK_SPOTS[bunks.size()];p.y=Layout.height_at(p.x,p.z)
		tent.global_position=p;tent.rotation.y=PI+(bunks.size()%2)*.18-.09
		for model in tent.find_children("*","MeshInstance3D",true,false): model.create_trimesh_collision()
		bunks.append(tent)
	while bunks.size()>count: bunks.pop_back().queue_free()
	var stake: Node3D=notice.get_parent().get_parent()
	stake.visible=not game.crew.hands.is_empty()
	if stake.visible:
		var names: Array=game.crew.hands.slice(0,4).map(func(h): return h.name.get_slice(" ",1))
		notice.text="NOTICE\n%s\nclaimed and worked\nby the undersigned & Co.\n%s" % [game.crew.bar_name,", ".join(names)]

func Trip_point() -> Vector3:
	var trail: Vector3=get_node("/root/Trip").trail
	return trail+Vector3(0,0,2.5)

## Push walkers around boulders, oak trunks and the camp furniture.
func avoidance(p: Vector3) -> Vector3:
	var push:=Vector3.ZERO
	for b in Layout.BOULDERS:
		var d:=Vector2(p.x-b.x,p.z-b.y);var reach: float=b.z+1.0
		if d.length()<reach: push+=Vector3(d.x,0,d.y).normalized()*(reach-d.length())*1.4
	for key in ["FireRing","Rack","Pot","Crate","LeanTo"]:
		if not camp.props.has(key): continue
		var c: Vector3=camp.props[key].global_position
		var d:=Vector2(p.x-c.x,p.z-c.z)
		if d.length()<1.3: push+=Vector3(d.x,0,d.y).normalized()*(1.3-d.length())
	var f:=fire_point();var df:=Vector2(p.x-f.x,p.z-f.z)
	if df.length()<1.2: push+=Vector3(df.x,0,df.y).normalized()*(1.2-df.length())
	return push

func _ring(index: int, count: int, radius := 2.1) -> Vector3:
	var angle:=TAU*index/maxi(1,count)+.4
	var p:=fire_point()+Vector3(cos(angle),0,sin(angle))*radius
	p.y=Layout.height_at(p.x,p.z);return p

func _face(from: Vector3, to: Vector3) -> float: return atan2(-(to.x-from.x),-(to.z-from.z))

## Who goes where at this hour. `snap` places men without walking (load, sleep).
func _schedule(snap := false) -> void:
	var hour: float=clock.hour_at(clock.elapsed)
	var water: float=game.water_level()
	var working: bool=((hour>=5.6 and hour<12) or (hour>=13 and hour<19)) and not Model.rest_day(game.crew,game.day)
	var evening: bool=hour>=19 and hour<21.75
	var night: bool=hour>=21.75 or hour<4.75
	var ids: Array=hands.keys();ids.sort()
	var team:=0;var sheltered:=int(game.inventory.get("bunks",0))*4
	var player_rocking: bool=claim.get_node("Activities").busy and claim.get_node("Activities").action=="rocker"
	for i in ids.size():
		var hand: Node3D=hands[ids[i]]
		var h: Dictionary=Model.hand(game.crew,ids[i])
		if h.is_empty(): continue
		var ready: bool=Model.job_ready(game.crew,h,game.inventory,game.mining,water)==""
		var point:=Vector3.INF;var yaw:=0.0;var clip:="idle";var tool:=""
		if night:
			if i<sheltered: point=camp.global_position+BUNK_SPOTS[mini(i/4,3)];point.y=Layout.height_at(point.x,point.z);clip=""
			else: point=_ring(i,ids.size(),2.6);yaw=_face(point,fire_point());clip="lie_down"
		elif evening:
			point=_ring(i,ids.size());yaw=_face(point,fire_point())
			clip="harmonica" if i==0 and ids.size()>=2 else "idle"
		elif working and ready and h.job!="rest":
			match h.job:
				"pan":
					point=Model.job_point(game.crew,h,game.mining,water,game.seed)
					var river:=-Layout.inland_normal(point.x);yaw=atan2(-river.x,-river.z);clip="pan"
				"rocker":
					var rocker: Node3D=claim.get_node("Mining").rocker
					var stance: Array=[Vector3(1.0,0,.05),Vector3(-.2,0,1.9),Vector3(1.3,0,2.4)]
					point=rocker.to_global(stance[mini(team,2)]);point.y=Layout.height_at(point.x,point.z)
					yaw=rocker.global_rotation.y+PI/2 if team==0 else _face(point,rocker.global_position)
					clip=["rock","shovel","pick"][mini(team,2)]
					if team==0 and player_rocking: clip="idle"
					team+=1
				"crevice":
					point=Model.job_point(game.crew,h,game.mining,water,game.seed)+Vector3(0,0,.85)
					yaw=0.0;clip="crevice"
				"fish":
					point=Model.job_point(game.crew,h,game.mining,water,game.seed,game.day,floorf(hour),game.inventory.get("catch_log",[]))
					var river:=-Layout.inland_normal(point.x);yaw=atan2(-river.x,-river.z);clip="fish_wait"
				"cook":
					point=fire_point()+Vector3(0,0,-.95);point.y=Layout.height_at(point.x,point.z)
					yaw=_face(point,fire_point());clip="cook" if fmod(hour,2.0)<1.4 else "tend_fire"
				"dam":
					# Builders cut and carry at the two shore ends of the crib.
					var x: float=Model.DAM_X.x+.9 if i%2==0 else Model.DAM_X.y-.9
					x+=(i/2)*(.9 if i%2==0 else -.9)
					var z: float=preload("res://scripts/river_model.gd").shore_z(x,water)+.6+(i%3)*.5
					point=Vector3(x,Layout.height_at(x,z),z)
					yaw=_face(point,point-Layout.inland_normal(x));clip=["shovel","pick","shovel"][i%3]
				"channel":
					var spot: Vector2=Model.channel_spot(game.crew,h)
					point=Vector3(spot.x,Layout.height_at(spot.x,spot.y),spot.y)
					yaw=_face(point,point+Layout.inland_normal(spot.x));clip=["shovel","pan","pick"][i%3]
				"haul":
					point=get_node("/root/Trip").trail+Vector3(0,0,5.5)
					clip="" if hour<18.3 else "idle"
					if hour>=18.3: point=_ring(i,ids.size())
		else:
			if working and Calendar.weekday(game.day)=="Sunday" and i%2==0:
				# Sunday wash-day at the river below camp.
				var x:=-3.0+i*1.6;var z: float=preload("res://scripts/river_model.gd").shore_z(x,water)+.5
				point=Vector3(x,Layout.height_at(x,z),z);yaw=PI;clip="gather"
			else:
				point=_ring(i,ids.size(),3.2);yaw=_face(point,fire_point())
		if point==Vector3.INF:
			point=_ring(i,ids.size(),3.2);yaw=_face(point,fire_point());clip="idle"
		if snap: hand.place(point,yaw,clip,tool)
		else: hand.go(point,yaw,clip,tool)
		hand.rate=hand_rate()
	for id in waiting: waiting[id].rate=hand_rate()
	# The cradle rocks while a man is on the handle and the miner is not.
	var mining: Node3D=claim.get_node("Mining")
	if team>0 and working and not player_rocking:
		cradle_time+=get_process_delta_time()*hand_rate()
		mining.cradle.rotation.z=sin(cradle_time*PI*1.3)*.10
	elif not player_rocking: mining.cradle.rotation.z=0
	# Supper fire and music.
	var lit: bool=not hands.is_empty() and (evening or (working and ids.any(func(id): return Model.hand(game.crew,id).get("job","")=="cook")) or (hour>=4.75 and hour<5.8))
	fire.visible=lit;flame.emitting=lit;light.visible=lit
	light.light_energy=4.5*(.9+.08*sin(Time.get_ticks_msec()*.009))
	if lit and evening: game.crew.fire_tonight=true
	var sound_on: bool=claim.get_node("Soundscape").active
	if lit and sound_on and not fire_sound.playing: fire_sound.play()
	elif (not lit or not sound_on) and fire_sound.playing: fire_sound.stop()
	var playing_hour: bool=evening and ids.size()>=2 and sound_on
	if playing_hour and not music.playing:
		music_gap-=get_process_delta_time()
		if music_gap<=0:
			music.stream=load("res://assets/audio/%s.wav" % (TUNES[2] if hour>=21 else TUNES[tune_index%2]))
			music.play()
	elif not playing_hour and music.playing: music.stop();music_gap=4

func hand_rate() -> float: return clock.rate if "rate" in clock else 1.0

func _process(_delta: float) -> void:
	if not is_inside_tree() or game.season_ended:
		fire.visible=false;music.stop();return
	_schedule(false)

## Snap everyone to where the hour puts them (after sleep, load or a trip).
func settle() -> void: _schedule(true)

# ------------------------------------------------------------ interaction

func nearest(reach := 1.8) -> Dictionary:
	var walker: Node3D=claim.get_node("Walker")
	var best:={};var distance:=reach
	for group in [waiting,hands]:
		for id in group:
			var hand: Node3D=group[id]
			if not hand.visible: continue
			var d:=hand.global_position.distance_to(walker.global_position)
			if d<distance: distance=d;best={"id":id,"waiting":group==waiting}
	return best

func prompt() -> String:
	var near:=nearest()
	if near.is_empty(): return ""
	var man:=Model.roster_entry(near.id)
	if near.waiting:
		return "Hire %s, %s · $%.2f a day" % [man.name,man.origin,Model.wage(near.id,game.day,game.seed)]
	var h:=Model.hand(game.crew,near.id)
	return "%s · %s · %s" % [man.name,Model.JOB_NAMES[h.job],Model.mood(h.morale)]

func interact() -> bool:
	var near:=nearest()
	if near.is_empty(): return false
	if near.waiting:
		if Model.hire(game.crew,near.id,game.day):
			var man:=Model.roster_entry(near.id)
			game.event("Hired %s at $%.2f a day." % [man.name,Model.wage(near.id,game.day,game.seed)])
			Model.assign_spots(game.crew,game.water_level());game.crew_changed.emit()
			claim.get_node("HUD").notify("%s hired · C opens the crew book" % man.name,3)
		return true
	claim.get_node("CrewBook").open_book(near.id)
	return true
