extends Node3D
## One hired hand (or a man waiting for work) on the bar. Visual only: the crew
## model decides what he produces; this walks him to it and plays the work.
const Layout=preload("res://scripts/claim_layout.gd")
const WALK_SPEED:=1.35
const PAN_SEQUENCE:=[["pan_enter",2.0],["pan_swirl",2.0],["pan_swirl_2",2.0],["pan_swirl_3",2.0],["pan_wash",1.5],["pan_lift",1.5]]
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
var materials: Array[ShaderMaterial]=[]

## look: {"tint":Color, "hair":Color, "scale":float, "pack":bool, "satchel":bool, "canteen":bool}
func setup(hand_id: String, look: Dictionary) -> void:
	id=hand_id
	miner=preload("res://assets/miner/intrepid/miner.glb").instantiate()
	miner.rotation.y=PI
	add_child(miner)
	scale=Vector3.ONE*float(look.get("scale",1.0))
	skeleton=miner.find_children("*","Skeleton3D",true,false)[0]
	player=miner.find_children("*","AnimationPlayer",true,false)[0]
	player.add_animation_library("crew",manager.library)
	var keys:={"Pack":"pack","Satchel":"satchel","Canteen":"canteen","Pickaxe":"pickaxe","TravelPan":"travel_pan"}
	for node: MeshInstance3D in miner.find_children("*","MeshInstance3D",true,false):
		node.extra_cull_margin=1.25
		for surface in node.mesh.get_surface_count():
			var source:=node.mesh.surface_get_material(surface) as StandardMaterial3D
			if source==null: continue
			var part:=source.resource_name.trim_prefix("Intrepid_")
			var material:=ShaderMaterial.new()
			material.shader=preload("res://shaders/intrepid_miner.gdshader")
			material.set_shader_parameter("albedo_atlas",source.albedo_texture)
			material.set_shader_parameter("normal_atlas",source.normal_texture)
			material.set_shader_parameter("surface_atlas",source.roughness_texture)
			material.set_shader_parameter("hair_cutout",part=="Hair")
			var tint: Color=look.get("hair",Color.WHITE) if part=="Hair" else look.get("tint",Color.WHITE) if part=="Body" else Color.WHITE
			material.set_shader_parameter("tint",Vector3(tint.r,tint.g,tint.b))
			node.set_surface_override_material(surface,material)
			if keys.has(part): equipment[keys[part]]=node
	for item in equipment: equipment[item].visible=bool(look.get(item,false))
	var pan_socket:=_attachment("pan_socket")
	pan_prop=preload("res://assets/miner/pan.glb").instantiate();pan_socket.add_child(pan_prop);pan_prop.hide()
	var hand:=_attachment("RightHand")
	harmonica=MeshInstance3D.new();var box:=BoxMesh.new();box.size=Vector3(.10,.022,.028);harmonica.mesh=box
	var tin:=StandardMaterial3D.new();tin.albedo_color=Color(.72,.70,.64);tin.metallic=.9;tin.roughness=.3;harmonica.material_override=tin
	hand.add_child(harmonica);harmonica.position=Vector3(0,.09,.03);harmonica.hide()
	_play("idle")

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
	if work_clip=="pan":
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
