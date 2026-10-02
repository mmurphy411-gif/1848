extends Node3D
## The wing dam as it stands: courses of logs rise with the crew's man-hours, and
## once closed the river surface inside the crib is cut away to show the dry bed.
const Model=preload("res://scripts/crew_model.gd")
const Layout=preload("res://scripts/claim_layout.gd")
const LOG_RADIUS:=.17
const LOG_LENGTH:=2.6
const TOP:=-.2
var logs:=MultiMeshInstance3D.new()
var stones:=MultiMeshInstance3D.new()
var walls:=StaticBody3D.new()
var transforms: Array[Transform3D]=[]
var shown:=-1
var built:=false
@onready var game: Node=get_node("/root/GameState")

func _ready() -> void:
	var log_mesh:=CylinderMesh.new();log_mesh.top_radius=LOG_RADIUS;log_mesh.bottom_radius=LOG_RADIUS*1.08;log_mesh.height=LOG_LENGTH;log_mesh.radial_segments=9;log_mesh.rings=1
	var bark:=StandardMaterial3D.new();bark.albedo_color=Color(.36,.26,.17);bark.roughness=.93
	log_mesh.material=bark
	logs.multimesh=MultiMesh.new();logs.multimesh.transform_format=MultiMesh.TRANSFORM_3D;logs.multimesh.mesh=log_mesh
	add_child(logs)
	var stone_mesh:=SphereMesh.new();stone_mesh.radius=.32;stone_mesh.height=.5;stone_mesh.radial_segments=7;stone_mesh.rings=4
	stone_mesh.material=preload("res://scripts/asset_library.gd").rock("granite",.6)
	stones.multimesh=MultiMesh.new();stones.multimesh.transform_format=MultiMesh.TRANSFORM_3D;stones.multimesh.mesh=stone_mesh
	add_child(stones)
	walls.collision_layer=1;walls.collision_mask=0;add_child(walls)
	_layout()
	game.crew_changed.connect(refresh);game.changed.connect(refresh)
	refresh()

func _corners() -> Array[Vector3]:
	var x0: float=Model.DAM_X.x;var x1: float=Model.DAM_X.y
	var points: Array[Vector3]=[]
	for p in [Vector2(x0,Layout.shore_z(x0)+.4),Vector2(x0,Layout.shore_z(x0)-Model.DAM_REACH),Vector2(x1,Layout.shore_z(x1)-Model.DAM_REACH),Vector2(x1,Layout.shore_z(x1)+.4)]:
		points.append(Vector3(p.x,0,p.y))
	return points

## Every log of the finished crib, bottom course first, so a partial dam rises.
func _layout() -> void:
	var corners:=_corners()
	var rng:=RandomNumberGenerator.new();rng.seed=184849
	var courses: Array=[]
	for segment in 3:
		var a: Vector3=corners[segment];var b: Vector3=corners[segment+1]
		var length:=Vector2(b.x-a.x,b.z-a.z).length()
		var direction:=(b-a).normalized()
		var count:=ceili(length/(LOG_LENGTH*.92))
		for i in count:
			var t:=(i+.5)/count
			var p:=a.lerp(b,t)
			var bed:=Layout.height_at(p.x,p.z)
			var layer:=0
			var y:=bed+LOG_RADIUS
			while y<TOP+LOG_RADIUS:
				var basis:=Basis(Quaternion(Vector3.UP,direction))*Basis(Vector3.UP,rng.randf()*TAU)
				var offset:=direction*(.35 if layer%2==1 else 0.0)+Vector3(rng.randf_range(-.04,.04),0,rng.randf_range(-.04,.04))
				while courses.size()<=layer: courses.append([])
				courses[layer].append(Transform3D(basis.scaled(Vector3.ONE*rng.randf_range(.92,1.06)),p+offset+Vector3(0,y,0)))
				y+=LOG_RADIUS*1.85;layer+=1
		# Rock fill on the river face and a collider the full height of the crib.
		var shape:=BoxShape3D.new()
		var mid:=(a+b)*.5;var low:=minf(Layout.height_at(a.x,a.z),Layout.height_at(b.x,b.z))-.2
		shape.size=Vector3(.7,TOP+.35-low,length+.4)
		var collider:=CollisionShape3D.new();collider.shape=shape
		collider.transform=Transform3D(Basis(Vector3.UP,atan2(direction.x,direction.z)),Vector3(mid.x,(TOP+.35+low)*.5,mid.z))
		walls.add_child(collider)
	for layer in courses: transforms.append_array(layer)
	logs.multimesh.instance_count=transforms.size();logs.multimesh.visible_instance_count=0
	for i in transforms.size(): logs.multimesh.set_instance_transform(i,transforms[i])
	var outer: Array[Transform3D]=[]
	for i in 26:
		var t:=(i+.5)/26.0
		var p:=corners[1].lerp(corners[2],t)-Layout.inland_normal(lerpf(corners[1].x,corners[2].x,t))*.55
		p.y=Layout.height_at(p.x,p.z)+.12
		outer.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(1,.7,1)*rng.randf_range(.8,1.3)),p))
	stones.multimesh.instance_count=outer.size();stones.multimesh.visible_instance_count=0
	for i in outer.size(): stones.multimesh.set_instance_transform(i,outer[i])

func refresh() -> void:
	if not is_inside_tree(): return
	var dam: Dictionary=game.crew.get("dam",{})
	var fraction: float=1.0 if dam.get("built",false) else clampf(float(dam.get("progress",0.0))/Model.DAM_HOURS,0,1)
	var count:=roundi(transforms.size()*fraction)
	if count!=shown:
		shown=count
		logs.multimesh.visible_instance_count=count
		stones.multimesh.visible_instance_count=roundi(stones.multimesh.instance_count*clampf(fraction*1.6-.6,0,1))
	visible=count>0
	walls.collision_layer=1 if dam.get("built",false) else 0
	if built!=dam.get("built",false):
		built=dam.get("built",false)
		var water: MeshInstance3D=get_parent().get_node_or_null("Greybox/River/WaterSurface")
		if water and water.material_override:
			water.material_override.set_shader_parameter("dam_on",1.0 if built else 0.0)
			water.material_override.set_shader_parameter("dam_x",Model.DAM_X)
			water.material_override.set_shader_parameter("dam_reach",Model.DAM_REACH)
			water.material_override.set_shader_parameter("dam_margin",Model.DAM_MARGIN)
		if get_parent().has_node("FishSchool"): get_parent().get_node("FishSchool").refresh()
