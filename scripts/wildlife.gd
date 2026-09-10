extends Node3D
## Small bounded population. Refreshes on season/time-window changes, never each frame.
const Model = preload("res://scripts/wildlife_model.gd")
const Actor = preload("res://scripts/wildlife_actor.gd")
const Layout = preload("res://scripts/claim_layout.gd")
var population_key := ""
var check_timer := 0.0
var actors: Array[Node3D]=[]
var body_shape := SphereShape3D.new()
@onready var game: Node=get_node("/root/GameState")
@onready var clock: Node=get_parent().get_node("Daylight/Clock")

func _ready() -> void:
	refresh()

func _process(delta: float) -> void:
	check_timer+=delta
	if check_timer>=.5:
		check_timer=0;refresh()

func refresh(force := false) -> void:
	var hour: float=clock.hour_at(clock.elapsed)
	for actor in actors.duplicate():
		if actor.retiring and (actor.departed or Model.active(actor.species,game.day,hour)):
			remove_child(actor);actor.queue_free();actors.erase(actor)
	var key := "%d:%d:%.3f" % [game.seed,game.day,game.water_level()]
	for species in Model.SPECIES: key+=":"+str(Model.active(species,game.day,hour))
	if not force and key==population_key: return
	var reset_day := population_key.get_slice(":",0)!=str(game.seed) or population_key.get_slice(":",1)!=str(game.day)
	var reset_water := population_key.get_slice(":",2)!=key.get_slice(":",2)
	population_key=key
	if reset_day or reset_water or force:
		for actor in actors: remove_child(actor);actor.queue_free()
		actors.clear()
	else:
		for actor in actors: actor.retiring=not Model.active(actor.species,game.day,hour)
	var present: Array=[]
	for actor in actors:
		if not actor.retiring: present.append(actor.species)
	for data in Model.population(game.seed,game.day,hour,game.water_level()):
		if data.species in present: continue
		var p: Vector3=data.position
		var found := false
		# Authored habitats are nudged around actual camp/trunk geometry.
		for attempt in 32:
			var trial := p+Vector3(sin(attempt*2.4),0,cos(attempt*2.4))*float(attempt)*.18
			if safe(trial,data.species): p=trial;found=true;break
		if not found: continue
		var actor := Actor.new();actor.species=data.species;actor.phase=data.phase;actor.manager=self
		actor.name=data.species+str(actors.size());actor.position=p;actor.scale=Vector3.ONE*data.scale
		add_child(actor);actors.append(actor)

func safe(p: Vector3, species: String) -> bool:
	var radius := .42 if species=="bear" else .25 if species=="deer" else .10
	if not Model.dry_clear(p,game.water_level(),radius): return false
	var camp: Node3D=get_parent().get_node("Camp")
	if Vector2(p.x-camp.position.x,p.z-camp.position.z).length()<5.5: return false
	for oak in get_parent().get_node("Vegetation").placements.black_oak:
		if Vector2(p.x-oak.origin.x,p.z-oak.origin.z).length()<.8+radius: return false
	return true

func steer(actor: Node3D, wanted: Vector3, distance: float) -> Vector3:
	var radius := .35 if actor.species=="bear" else .2 if actor.species=="deer" else .065
	for turn in [0.0,.45,-.45,.9,-.9,1.35,-1.35,1.8,-1.8]:
		var direction := wanted.rotated(Vector3.UP,turn)
		var step := direction*distance
		var next := actor.position+step
		# Check ahead as well as the next step so bodies don't penetrate scenery.
		if not safe(next+direction*.55,actor.species): continue
		if absf(Layout.height_at(next.x,next.z)-Layout.height_at(actor.position.x,actor.position.z))>distance*.65: continue
		# The jay's query rises with its flight, clearing low obstacles.
		body_shape.radius=radius
		var query := PhysicsShapeQueryParameters3D.new();query.shape=body_shape
		query.transform=Transform3D(Basis.IDENTITY,actor.position+Vector3(0,.45,0))
		query.motion=direction*(distance+.5);query.collision_mask=1
		var hit := get_world_3d().direct_space_state.cast_motion(query)
		if hit[0]<1.0: continue
		return step
	return Vector3.ZERO

func focus(species: String) -> void:
	# Explicit sandbox preset: puts the real season and clock into the right window.
	if species=="bear": game.day=99;game.changed.emit()
	get_parent().get_node("Daylight").apply(6.5);clock.start(6.5)
	refresh(true)
	for actor in actors:
		if actor.species!=species: continue
		var walker: CharacterBody3D=get_parent().get_node("Walker")
		var origin: Vector3=actor.position
		for offset in [Vector3(0,0,13),Vector3(10,0,8),Vector3(-10,0,8),Vector3(0,0,9)]:
			var p: Vector3=origin+offset
			if safe(p,"deer"):
				p.y=Layout.height_at(p.x,p.z)+.05;walker.position=p;walker.velocity=Vector3.ZERO;break
		var rig: Node3D=get_parent().get_node("CameraRig")
		var toward := origin-walker.position
		rig.yaw=atan2(-toward.x,-toward.z);rig.pitch=-.24
		return
