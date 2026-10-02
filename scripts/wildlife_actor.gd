extends Node3D
## Wildlife actor: local steering and an idle/alert/flee state machine; wildlife never
## blocks the miner. Intake species (SKELETAL) play skinned clips (idle, walk, run,
## graze, alert) on an AnimationPlayer advanced from animate(); legacy species animate
## authored part nodes procedurally.
const Model = preload("res://scripts/wildlife_model.gd")
const Layout = preload("res://scripts/claim_layout.gd")
enum State { IDLE, ALERT, FLEE }
## Skinned intake models (VISUAL_UPGRADE_NOTES.md, Stage 5). `parts` maps the anatomy the
## game and tests name to bones; `feet` names each leg's lowest bone, whose lowest skinned
## vertex is the hoof. Speeds are the ground speed (m/s at scale 1) each clip was
## authored at, so playback follows actual travel without foot slide.
const SKELETAL := {
	"deer": {"parts": {"Head": "Head", "Tail": "Tail1", "FrontL": "FrontUpperLeg.L", "FrontR": "FrontUpperLeg.R",
			"HindL": "BackUpperLeg.L", "HindR": "BackUpperLeg.R"},
		"feet": {"FrontL": "FF.L", "FrontR": "FF.R", "HindL": "FFB.L", "HindR": "FFB.R"},
		"walk_speed": .95, "run_speed": 3.8},
	# Sitting squirrels rest on their hind feet only; the bound doubles as the foraging gait.
	"squirrel": {"parts": {"Head": "Head", "Tail": "Tail", "FrontL": "Arm_L", "FrontR": "Arm_R", "HindL": "Leg_L", "HindR": "Leg_R"},
		"feet": {"HindL": "Leg_L.003", "HindR": "Leg_R.003"}, "walk_clip": "run", "walk_speed": .65, "run_speed": .65},
}
static var materials: Dictionary={}
static var foot_offsets: Dictionary={}
var species := "deer"
var state := State.IDLE
var phase := 0.0
var elapsed := 0.0
var state_time := 0.0
var distance_moved := 0.0
var home := Vector3.ZERO
var destination := Vector3.ZERO
var visual: Node3D
var parts: Dictionary={}
var rest: Dictionary={}
var legs: Dictionary={}
var manager: Node3D
var departed := false
var retiring := false
var direction := Vector3.FORWARD
var walking := false
var review_pose := false
var skeleton: Skeleton3D
var player: AnimationPlayer
var clip := ""
var step_speed := 0.0

## Model file for a species; the second deer of the pair (identity deer1) is a buck.
static func model_path(kind: String, identity := "") -> String:
	if kind=="deer" and identity.ends_with("1"): return "res://assets/wildlife/deer_buck.glb"
	return "res://assets/wildlife/"+kind+".glb"

## Fur shader on an intake model's coat surfaces (vertex colours, rest-pose noise, photo
## coat texture); eyes keep their glossy imported material. Shared per species and surface.
static func coat(model: Node3D, kind: String) -> void:
	for mesh_instance in model.find_children("*","MeshInstance3D",true,false):
		for surface in mesh_instance.mesh.get_surface_count():
			var source: Material=mesh_instance.mesh.surface_get_material(surface)
			if not source is StandardMaterial3D or "Eye" in source.resource_name: continue
			var key: String=kind+":"+mesh_instance.name+":"+source.resource_name
			if not materials.has(key):
				var mat := ShaderMaterial.new();mat.shader=preload("res://shaders/wildlife.gdshader")
				mat.set_shader_parameter("coat_color",source.albedo_color)
				mat.set_shader_parameter("rest_uv",source.albedo_texture==null and mesh_instance.mesh.surface_get_format(surface)&Mesh.ARRAY_FORMAT_TEX_UV2!=0)
				if source.albedo_texture:
					mat.set_shader_parameter("use_texture",true);mat.set_shader_parameter("coat_texture",source.albedo_texture)
				materials[key]=mat
			mesh_instance.set_surface_override_material(surface,materials[key])

## Expedition carcass for a kill record: intake models lie in the last frame of their
## death clip; legacy part models are laid on their side as before.
static func carcass(parent: Node3D, record: Dictionary) -> Node3D:
	var body: Node3D=load(model_path(record.species,str(record.get("id","")))).instantiate()
	parent.add_child(body)
	var players := body.find_children("*","AnimationPlayer",true,false)
	if SKELETAL.has(record.species) and not players.is_empty() and players[0].has_animation("death"):
		coat(body,record.species)
		var death: AnimationPlayer=players[0]
		death.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
		death.play("death");death.seek(death.get_animation("death").length,true)
		body.global_position=record.position;body.rotation=Vector3(0,record.rotation,0)
	else:
		body.global_position=record.position+Vector3.UP*.28;body.rotation=Vector3(0,record.rotation,PI/2)
	return body

func _ready() -> void:
	visual=load(model_path(species,str(get_meta("identity","")))).instantiate()
	var found := visual.find_children("*","Skeleton3D",true,false)
	if SKELETAL.has(species) and not found.is_empty():
		skeleton=found[0]
		add_child(visual)
		_ready_skeletal()
	else:
		_ready_parts()
	home=position;destination=home;rotation.y=phase

func _ready_parts() -> void:
	for part in visual.find_children("*","Node3D",true,false):
		parts[part.name]=part;rest[part.name]=part.transform
		if part is MeshInstance3D:
			for surface in part.mesh.get_surface_count():
				var source: Material=part.mesh.surface_get_material(surface)
				if not source is StandardMaterial3D or "Wet eye" in source.resource_name or "Nose" in source.resource_name or "Hoof" in source.resource_name or "Paw" in source.resource_name or "feet" in source.resource_name: continue
				var key: String=species+source.resource_name+str(source.albedo_color)
				if not materials.has(key):
					var mat := ShaderMaterial.new();mat.shader=preload("res://shaders/wildlife.gdshader")
					mat.set_shader_parameter("coat_color",source.albedo_color)
					mat.set_shader_parameter("feathered",species in ["quail","jay"])
					materials[key]=mat
				part.set_surface_override_material(surface,materials[key])
		if part.name in ["FlightL","FlightR"]: part.hide()
	add_child(visual)
	for key in ["FrontL","FrontR","HindL","HindR"]:
		if not parts.has(key+"Lower"): continue
		var upper: Node3D=parts[key]
		var lower: MeshInstance3D=parts[key+"Lower"]
		var transform_to_model: Transform3D=rest[key]*rest[key+"Lower"]
		var lowest := INF
		var points: Array[Vector3]=[]
		for surface in lower.mesh.get_surface_count():
			for vertex in lower.mesh.surface_get_arrays(surface)[Mesh.ARRAY_VERTEX]:
				var p: Vector3=transform_to_model*vertex
				lowest=minf(lowest,p.y);points.append(p)
		var foot := Vector3.ZERO
		var count := 0
		for p in points:
			if p.y<lowest+.008: foot+=p;count+=1
		foot/=maxi(1,count)
		legs[key]={"hip":upper.position,"knee":transform_to_model.origin,"foot":foot,"end":transform_to_model.affine_inverse()*foot}

func _ready_skeletal() -> void:
	var config: Dictionary=SKELETAL[species]
	coat(visual,species)
	player=visual.find_children("*","AnimationPlayer",true,false)[0]
	player.callback_mode_process=AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	for name in ["idle","walk","run","graze","alert","headlow"]:
		if player.has_animation(name): player.get_animation(name).loop_mode=Animation.LOOP_LINEAR
	for key in config.parts:
		var attachment := BoneAttachment3D.new();attachment.name="Part"+key
		skeleton.add_child(attachment);attachment.bone_name=config.parts[key]
		parts[key]=attachment
	var offsets: Dictionary=_foot_offsets(config.feet)
	for key in config.feet:
		legs[key]={"bone":skeleton.find_bone(config.feet[key]),"end":offsets[key]}
	play(_idle_clip(),0.0)
	player.advance(0)

## Each leg's hoof: the lowest rest-pose vertex mostly weighted to the leg's last bone,
## stored in that bone's space. Computed once per model file.
func _foot_offsets(feet: Dictionary) -> Dictionary:
	var file: String=model_path(species,str(get_meta("identity","")))
	if foot_offsets.has(file): return foot_offsets[file]
	var result: Dictionary={}
	var lowest: Dictionary={}
	for mesh_instance in skeleton.find_children("*","MeshInstance3D",true,false):
		var skin: Skin=mesh_instance.skin
		if skin==null: continue
		var bind_of: Dictionary={}
		for i in skin.get_bind_count():
			var bone: int=skin.get_bind_bone(i)
			if bone<0: bone=skeleton.find_bone(skin.get_bind_name(i))
			bind_of[i]=bone
		for surface in mesh_instance.mesh.get_surface_count():
			var arrays: Array=mesh_instance.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
			var bones: PackedInt32Array=arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array=arrays[Mesh.ARRAY_WEIGHTS]
			var stride: int=bones.size()/vertices.size()
			for v in vertices.size():
				var best := 0
				for j in stride:
					if weights[v*stride+j]>weights[v*stride+best]: best=j
				var bind: int=bones[v*stride+best]
				var bone: int=bind_of.get(bind,-1)
				for key in feet:
					if skeleton.find_bone(feet[key])!=bone or weights[v*stride+best]<.5: continue
					var model_point: Vector3=mesh_instance.transform*vertices[v]
					if not lowest.has(key) or model_point.y<lowest[key].y:
						lowest[key]=model_point
						result[key]=skin.get_bind_pose(bind)*vertices[v]
	foot_offsets[file]=result
	return result

func play(name: String, blend := .35) -> void:
	if name==clip or not player.has_animation(name): return
	clip=name;player.play(name,blend)
	# Desynchronise the herd: start loops at a phase-dependent point.
	if blend==0.0: player.seek(fposmod(phase*1.7,player.get_animation(name).length),false)

func _idle_clip() -> String:
	# Long foraging bouts broken by short heads-up looks; the phase staggers the pair.
	return "graze" if fposmod(elapsed*.11+phase,1.0)<.62 else "idle"

func transition(next: State) -> void:
	if state==next: return
	state=next;state_time=0

func _physics_process(delta: float) -> void:
	if departed or review_pose: return
	elapsed+=delta;state_time+=delta
	var walker: Node3D=manager.get_parent().get_node("Walker")
	var distance := global_position.distance_to(walker.global_position)
	var noise := 1.25 if walker.velocity.length()>2.0 else 1.0
	if retiring or (species!="bear" and distance<Model.FLEE[species]*noise):
		transition(State.FLEE)
	elif state==State.IDLE and distance<Model.ALERT[species]*noise:
		transition(State.ALERT)
	elif state==State.ALERT and distance>Model.ALERT[species]*1.25 and state_time>3:
		transition(State.IDLE)
	walking=false
	var speed := 0.0
	if state==State.FLEE:
		direction=Model.away(position,walker.position)
		# Exit toward inland cover without circling the person indefinitely.
		direction=(direction+Vector3.BACK*.32).normalized()
		speed=Model.SPEED[species]
		if state_time>9.0:
			departed=true;hide();return
	elif state==State.IDLE:
		# Short, separated foraging steps leave time to look, peck and breathe.
		var cycle := fposmod(elapsed+phase*3,13.0)
		if cycle<3.0:
			destination=home+Vector3(sin(phase+floor((elapsed+phase*3)/13)*1.7)*2.0,0,cos(phase+floor((elapsed+phase*3)/13)*1.7)*1.2)
			direction=destination-position;direction.y=0;direction=direction.normalized()
			if position.distance_to(destination)>.2: speed=.32 if species in ["bear","deer"] else .16
	step_speed=0.0
	if speed>0:
		var step: Vector3=manager.steer(self,direction,speed*delta)
		if step.length_squared()>.000001:
			position+=step;distance_moved+=Vector2(step.x,step.z).length();walking=true
			step_speed=Vector2(step.x,step.z).length()/delta
			rotation.y=lerp_angle(rotation.y,atan2(-step.x,-step.z),minf(1,delta*8))
	position.y=Layout.height_at(position.x,position.z)
	if species=="jay" and state==State.FLEE: position.y+=minf(state_time*1.5,4.5)
	animate(delta)

func animate(delta: float) -> void:
	if skeleton:
		animate_skeletal(delta);return
	var gait := distance_moved*(7.0 if species in ["bear","deer"] else 35.0)
	var amount := (.62 if state==State.FLEE else .24) if walking else 0.0
	for key in parts:
		var part: Node3D=parts[key]
		var target: Transform3D=rest[key]
		var angle := 0.0
		if key in ["FrontL","FrontR","HindL","HindR"]:
			var offset := PI if key in ["FrontR","HindL"] else 0.0
			angle=sin(gait+offset)*amount
		elif key.ends_with("Lower"):
			var offset := PI if key in ["FrontRLower","HindLLower"] else 0.0
			angle=maxf(0,sin(gait+offset+.55))*amount*.85
		elif key=="Head":
			angle=sin(elapsed*.9+phase)*.045
			if state==State.IDLE and not walking:
				angle-=maxf(0,sin(elapsed*.48+phase))*(.61 if species=="deer" else .24)
		elif key=="Tail": angle=sin(elapsed*2.1+phase)*(.15 if species=="squirrel" else .045)
		if angle!=0: target.basis=target.basis*Basis(Vector3.RIGHT,angle)
		if key=="Head" and state==State.ALERT: target.basis=target.basis*Basis(Vector3.UP,sin(elapsed*.9)*.17)
		if species=="jay":
			if key in ["WingL","WingR"]: part.visible=state!=State.FLEE
			if key in ["FlightL","FlightR"]:
				part.visible=state==State.FLEE
				target.basis=target.basis*Basis(Vector3.FORWARD,sin(elapsed*35)*.85*(-1 if key=="FlightL" else 1))
		part.transform=part.transform.interpolate_with(target,minf(1,delta*18))
	visual.position.y=(absf(sin(gait))*.025 if walking else sin(elapsed*1.7+phase)*.003)
	if not legs.is_empty():
		_tilt_to_ground()
	for key in legs: plant_leg(key,gait)

func animate_skeletal(delta: float) -> void:
	var config: Dictionary=SKELETAL[species]
	var rate := 1.0
	if walking and state==State.FLEE:
		play("run",.2);rate=step_speed/(config.run_speed*scale.x)
	elif walking:
		play(config.get("walk_clip","walk"),.3);rate=step_speed/(config.walk_speed*scale.x)
	elif state==State.ALERT:
		play("alert" if player.has_animation("alert") else "idle",.45)
	else:
		play(_idle_clip(),.6)
	player.speed_scale=clampf(rate,.15,2.0)
	player.advance(delta)
	visual.position.y=0
	_tilt_to_ground()
	# The clip's hooves stand on a plane and the bank is never flat under four hooves:
	# settle the standing body by the mean hoof gap.
	if not walking:
		var mean := 0.0
		for key in legs:
			var foot := foot_world(key)
			mean+=foot.y-Layout.height_at(foot.x,foot.z)
		mean/=legs.size()
		visual.position.y=-clampf(mean,-.06,.06)

func _tilt_to_ground() -> void:
	var forward := Basis(Vector3.UP,rotation.y)*Vector3.FORWARD*.5
	var right := Basis(Vector3.UP,rotation.y)*Vector3.RIGHT*.5
	visual.rotation.x=atan(Layout.height_at(position.x+forward.x,position.z+forward.z)-Layout.height_at(position.x-forward.x,position.z-forward.z))
	visual.rotation.z=atan(Layout.height_at(position.x+right.x,position.z+right.z)-Layout.height_at(position.x-right.x,position.z-right.z))

func plant_leg(key: String, gait: float) -> void:
	var data: Dictionary=legs[key]
	var hip: Vector3=data.hip
	var a: Vector3=data.knee-hip
	var b: Vector3=data.foot-data.knee
	var target: Vector3=data.foot
	var stride := .26 if species=="deer" else .17 if species=="bear" else .035
	if state!=State.FLEE: stride*=.45
	var offset := PI if key in ["FrontR","HindL"] else 0.0
	var lift := 0.0
	if walking:
		target.z+=cos(gait+offset)*stride
		lift=maxf(0,sin(gait+offset))*stride*.65
	var ground_point: Vector3=visual.global_transform*target
	ground_point.y=Layout.height_at(ground_point.x,ground_point.z)+lift*scale.y
	target=visual.global_transform.affine_inverse()*ground_point
	var reach := target-hip
	var length_a := a.length()
	var length_b := b.length()
	var distance := clampf(reach.length(),absf(length_a-length_b)+.001,length_a+length_b-.001)
	var axis := reach.normalized()
	var bend := a-axis*a.dot(axis)
	if bend.length()<.001: bend=Vector3.FORWARD-axis*Vector3.FORWARD.dot(axis)
	bend=bend.normalized()
	var along := (length_a*length_a-length_b*length_b+distance*distance)/(2*distance)
	var knee := axis*along+bend*sqrt(maxf(0,length_a*length_a-along*along))
	var upper: Node3D=parts[key]
	var lower: Node3D=parts[key+"Lower"]
	upper.transform=rest[key]
	upper.basis=Basis(Quaternion(a.normalized(),knee.normalized()))*upper.basis
	lower.transform=rest[key+"Lower"]
	var rest_lower: Basis=rest[key].basis*rest[key+"Lower"].basis
	lower.basis=upper.basis.inverse()*Basis(Quaternion(b.normalized(),(axis*distance-knee).normalized()))*rest_lower

func foot_world(key: String) -> Vector3:
	if skeleton:
		return skeleton.global_transform*skeleton.get_bone_global_pose(legs[key].bone)*legs[key].end
	return parts[key+"Lower"].global_transform*legs[key].end
