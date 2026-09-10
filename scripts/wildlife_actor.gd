extends Node3D
## Lightweight authored-part animation and local steering; wildlife never blocks the miner.
const Model = preload("res://scripts/wildlife_model.gd")
const Layout = preload("res://scripts/claim_layout.gd")
enum State { IDLE, ALERT, FLEE }
static var materials: Dictionary={}
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

func _ready() -> void:
	visual=load("res://assets/wildlife/"+species+".glb").instantiate()
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
	home=position;destination=home;rotation.y=phase

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
	if speed>0:
		var step: Vector3=manager.steer(self,direction,speed*delta)
		if step.length_squared()>.000001:
			position+=step;distance_moved+=Vector2(step.x,step.z).length();walking=true
			rotation.y=lerp_angle(rotation.y,atan2(-step.x,-step.z),minf(1,delta*8))
	position.y=Layout.height_at(position.x,position.z)
	if species=="jay" and state==State.FLEE: position.y+=minf(state_time*1.5,4.5)
	animate(delta)

func animate(delta: float) -> void:
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
		var forward := Basis(Vector3.UP,rotation.y)*Vector3.FORWARD*.5
		var right := Basis(Vector3.UP,rotation.y)*Vector3.RIGHT*.5
		visual.rotation.x=atan(Layout.height_at(position.x+forward.x,position.z+forward.z)-Layout.height_at(position.x-forward.x,position.z-forward.z))
		visual.rotation.z=atan(Layout.height_at(position.x+right.x,position.z+right.z)-Layout.height_at(position.x-right.x,position.z-right.z))
	for key in legs: plant_leg(key,gait)

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
	return parts[key+"Lower"].global_transform*legs[key].end
