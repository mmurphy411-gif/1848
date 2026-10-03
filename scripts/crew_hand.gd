extends Node3D
## One hired hand (or a man waiting for work) on the bar. Visual only: the crew
## model decides what he produces; this walks him to it and plays the work.
const Layout=preload("res://scripts/claim_layout.gd")
const Figure=preload("res://scripts/crew_figure.gd")
const WALK_SPEED:=1.35
const LOD_BIAS:=.25
const PAN_SEQUENCE:=[["pan_enter",2.0],["pan_swirl",2.0],["pan_swirl_2",2.0],["pan_swirl_3",2.0],["pan_wash",1.5],["pan_lift",1.5]]
## Off-duty clips (crew.gd at the supper fire) -> [clip played, crew_pose kind, seated].
## "eat" and "harmonica" sit on the ground in the clip itself; the "sup_" poses sit on a
## round, a crate or a stool, or stand with a tin cup, over the idle clip's breathing.
const OFF_DUTY:={"idle":["idle","hands",false],"sup_cup":["idle","cup",false],"sup_sit":["idle","sit",true],
	"sup_sit_cup":["idle","sit_cup",true],"sup_lean":["idle","sit_lean",true],"eat":["eat","fingers",false],
	"lie_down":["lie_down","fingers",false],"harmonica":["eat","fingers",false]}
## Seats a man brings to the fire: scene, scale, top above the ground (m).
const SEATS:=[["res://assets/camp/chopping_block.glb",Vector3(1.15,1.15,1.15),.414],
	["res://assets/props/crate.glb",Vector3(.62,1.2,1.0),.415],
	["res://assets/props/stool.glb",Vector3(.9,.9,.9),.414]]
var seat: Node3D
var cup: MeshInstance3D
var plate: MeshInstance3D
var right_hand: BoneAttachment3D
var left_hand: BoneAttachment3D
var id:=""
var manager: Node3D
var miner: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var pan_prop: Node3D
var harmonica: MeshInstance3D
var tool: Node3D
var tool_kind:=""
var equipment: Dictionary={}
var target:=Vector3.ZERO
var facing:=0.0
var work_clip:="idle"
var work_tool:=""
var walking:=false
var away:=false
var clip:=""
var sequence_time:=0.0
var rate:=1.0
var figure: Node3D

## look: a casting from crew_look.gd (hat, hair, beard, garments, skin, build, gear).
func setup(hand_id: String, look: Dictionary) -> void:
	id=hand_id
	figure=Figure.new();figure.name="Figure"
	add_child(figure);figure.dress(look)
	# The kit faces +Z; hands face -Z like the miner.
	figure.rotation.y=PI
	miner=figure
	skeleton=figure.skeleton
	player=figure.player
	player.add_animation_library("crew",manager.library)
	equipment=figure.equipment
	# Hired hands are seen at working distance: coarser automatic LODs sooner (the
	# perf attribution: 0.19 ms at supper; no visible change at 2.5 m). Lambert keeps 1.0.
	for mesh: MeshInstance3D in figure.meshes.values(): mesh.lod_bias=LOD_BIAS
	var pan_socket:=_attachment("pan_socket")
	pan_prop=preload("res://assets/miner/pan.glb").instantiate();pan_socket.add_child(pan_prop);pan_prop.hide()
	var hand:=_attachment("RightHand")
	right_hand=hand;left_hand=_attachment("LeftHand")
	harmonica=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.10,.022,.028);harmonica.mesh=box
	var tin:=StandardMaterial3D.new();tin.albedo_color=Color(.72,.70,.64);tin.metallic=.9;tin.roughness=.3;harmonica.material_override=tin
	hand.add_child(harmonica);harmonica.position=Vector3(0,.09,.03);harmonica.hide()
	_play("idle")

## A man's seat at the fire, his tin cup and plate: made the first evening he needs them.
func _seat() -> Node3D:
	if seat==null:
		var choice: Array=SEATS[absi(hash(id+"seat"))%SEATS.size()]
		seat=load(choice[0]).instantiate();seat.name="Seat";add_child(seat)
		seat.scale=choice[1];seat.set_meta("top",choice[2])
		# Under his hips, turned a little off square.
		seat.position=Vector3(0,0,.03);seat.rotation.y=.15*sin(hash(id)*.1)
		for mesh: MeshInstance3D in seat.find_children("*","MeshInstance3D",true,false):
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		seat.hide()
	return seat

func _tinware() -> void:
	if cup: return
	var tin:=StandardMaterial3D.new();tin.albedo_color=Color(.46,.45,.42);tin.metallic=.75;tin.roughness=.42
	cup=MeshInstance3D.new();var cylinder:=CylinderMesh.new()
	cylinder.top_radius=.036;cylinder.bottom_radius=.032;cylinder.height=.085;cylinder.radial_segments=12;cylinder.rings=1
	cup.mesh=cylinder;cup.material_override=tin;cup.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	right_hand.add_child(cup);cup.hide()
	plate=MeshInstance3D.new();var dish:=CylinderMesh.new()
	dish.top_radius=.11;dish.bottom_radius=.085;dish.height=.018;dish.radial_segments=16;dish.rings=1
	plate.mesh=dish;plate.material_override=tin;plate.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	left_hand.add_child(plate);plate.hide()

## Pose, seat and tinware for an off-duty clip (or none while walking and working).
func _off_duty(work: String) -> void:
	var spec: Array=OFF_DUTY.get(work,["","",false])
	var kind: String=spec[1]
	var pose: Node=figure.pose
	if pose.kind!=kind:
		var height: float=figure.scale.x
		var top: float=_seat().get_meta("top") if spec[2] else .42
		pose.configure(kind,top/height,hash(id))
	if spec[2]: _seat().show()
	elif seat: seat.hide()
	var holds_cup: bool=kind in ["cup","sit_cup"]
	if holds_cup or work=="eat": _tinware()
	if cup:
		cup.visible=holds_cup;plate.visible=work=="eat"
		# Tinware stays level in the hand: the cup in the curled fingers, the plate on the palm.
		if cup.visible:
			cup.global_basis=Basis.IDENTITY.scaled(Vector3.ONE*figure.scale.x)
			cup.global_position=right_hand.global_transform*Vector3(0,.075,.028)
		if plate.visible:
			plate.global_basis=Basis.IDENTITY.scaled(Vector3.ONE*figure.scale.x)
			plate.global_position=left_hand.global_transform*Vector3(0,.06,.03)

func _attachment(bone: String) -> BoneAttachment3D:
	var a:=BoneAttachment3D.new();skeleton.add_child(a);a.bone_name=bone;return a

## Send the man somewhere to do something. A clip of "" hides him on arrival.
func go(point: Vector3, yaw: float, work: String, with_tool := "") -> void:
	if point.distance_to(target)>.05 or work!=work_clip:
		target=point;facing=yaw;work_clip=work;work_tool=with_tool

func place(point: Vector3, yaw: float, work: String, with_tool := "") -> void:
	go(point,yaw,work,with_tool)
	global_position=point;rotation.y=yaw;walking=false
	away=work=="";visible=not away

func _physics_process(delta: float) -> void:
	if manager==null: return
	var step:=delta*rate
	var to:=target-global_position;to.y=0
	if to.length()>.12:
		if away: away=false;visible=true
		walking=true
		var direction: Vector3=to.normalized()+manager.avoidance(global_position)
		direction.y=0;direction=direction.normalized()
		var depth: float=manager.claim.get_node("Greybox/River").depth_at(global_position)
		var speed:=WALK_SPEED*(.55 if depth>.08 else 1.0)
		global_position+=direction*minf(speed*step,to.length())
		global_position.y=Layout.height_at(global_position.x,global_position.z)
		rotation.y=lerp_angle(rotation.y,atan2(-direction.x,-direction.z),minf(1,step*7))
		_show_tool("")
		pan_prop.hide();harmonica.hide()
		_off_duty("")
		_play("wade" if depth>.08 else "walk",speed/(1.05 if depth>.08 else 2.4)*rate)
		return
	if walking:
		walking=false
		global_position=Vector3(target.x,Layout.height_at(target.x,target.z),target.z)
	rotation.y=lerp_angle(rotation.y,facing,minf(1,step*5))
	if work_clip=="":
		away=true;visible=false;return
	_work(step)

func _work(step: float) -> void:
	pan_prop.visible=work_clip=="pan"
	harmonica.visible=work_clip=="harmonica"
	_off_duty(work_clip)
	if work_clip in ["sup_cup","sup_sit","sup_sit_cup","sup_lean"]:
		# Sitting or standing easy: the idle clip's breathing, slowed.
		_play("idle",.6*rate);_show_tool("")
	elif work_clip=="eat": _play("eat",.5*rate);_show_tool("")
	elif work_clip=="pan":
		sequence_time=fposmod(sequence_time+step,15.0)
		var t:=sequence_time
		for part in PAN_SEQUENCE:
			if t<part[1]: _play(part[0],rate);break
			t-=part[1]
		if sequence_time>=11.0: _play("pan_lift",rate)
	elif work_clip=="crevice":
		sequence_time=fposmod(sequence_time+step,18.0)
		_play("crew/spoon" if sequence_time>11 else "crew/crevice",rate)
		_show_tool("spoon" if sequence_time>11 else "crowbar")
	elif work_clip=="harmonica": _play("eat",.35*rate)
	elif work_clip in ["rock","shovel","pick"]:
		_play("crew/"+work_clip,rate)
		_show_tool("" if work_clip=="rock" else work_clip)
	else:
		_play(work_clip,rate)
		_show_tool(work_tool)
	_pose_tool()

func _play(name: String, speed := 1.0) -> void:
	if clip!=name:
		clip=name
		player.play(name,.3)
	player.speed_scale=speed

func _show_tool(kind: String) -> void:
	if kind==tool_kind: return
	tool_kind=kind
	if is_instance_valid(tool): tool.queue_free();tool=null
	if kind=="": return
	tool=load("res://assets/mining/"+kind+".glb").instantiate()
	add_child(tool)

func _grip(side: String) -> Vector3:
	var knuckle:=skeleton.get_bone_global_pose(skeleton.find_bone(side+"MiddleProximal")).origin
	var distal:=skeleton.get_bone_global_pose(skeleton.find_bone(side+"MiddleDistal"))
	return skeleton.to_global((knuckle+distal*Vector3(0,.0382,0))*.5)

## Same hand-to-hand shaft placement as the miner's mining tools.
func _pose_tool() -> void:
	if not is_instance_valid(tool): return
	var hand:=_grip("Right");var upper:=_grip("Left")
	var axis:=(upper-hand).normalized()
	if axis.length_squared()<.5: axis=Vector3.UP
	var shaft:=Basis(Quaternion(Vector3.UP,axis))
	match tool_kind:
		"crowbar":
			tool.global_basis=shaft
			tool.global_position=hand-axis*((hand.y-Layout.height_at(hand.x,hand.z)-.035)/maxf(.3,axis.y))
		"spoon": tool.global_basis=Basis(Vector3.RIGHT,PI);tool.global_position=hand
		"pick": tool.global_basis=shaft*Basis(Vector3.RIGHT,PI);tool.global_position=hand+axis*.25
		"shovel": tool.global_basis=shaft;tool.global_position=hand-axis*.65
	tool.scale=Vector3.ONE/scale.x
