extends Node3D
## One man's body: the shared crew kit dressed from a look (crew_look.gd) by instance
## shader parameters, blend shapes and a bone-scale build. Meshes, atlases, materials and
## clips are shared by every figure, so fourteen men cost one kit, not fourteen.
##
## The kit faces +Z like Lambert's old rig; crew hands turn it round as they did the miner.
const Look=preload("res://scripts/crew_look.gd")
const Build=preload("res://scripts/crew_build.gd")
const Pose=preload("res://scripts/crew_pose.gd")
const KIT:="res://assets/crew/crew_kit.glb"
const MINER:="res://assets/miner/intrepid/miner.glb"
## Kit mesh -> miner atlas whose textures it samples.
const ATLAS:={"Body":"Body","Hat":"Body","Skin":"Skin","Hair":"Hair","Pack":"Pack","Satchel":"Satchel","Canteen":"Canteen"}
const EQUIPMENT:={"Pack":"pack","Satchel":"satchel","Canteen":"canteen"}
static var _materials: Dictionary={}
## The hero's own gear meshes and skins, drawn on each figure's skeleton.
static var _gear: Dictionary={}
static var _library: AnimationLibrary
var kit: Node3D
var skeleton: Skeleton3D
var player: AnimationPlayer
var build: Node
var pose: Node
var meshes: Dictionary={}
var equipment: Dictionary={}
var look: Dictionary={}

## Build the figure. `library` replaces the miner's clips as the default library.
func dress(man: Dictionary, library: AnimationLibrary=null) -> void:
	look=man
	kit=load(KIT).instantiate();kit.name="Kit";add_child(kit)
	skeleton=kit.find_children("*","Skeleton3D",true,false)[0]
	player=AnimationPlayer.new();player.name="AnimationPlayer";kit.add_child(player)
	player.root_node=NodePath("..")
	player.add_animation_library("",library if library else _miner_library())
	_shared_materials()
	var body_skeleton: Node3D=skeleton
	for part in EQUIPMENT:
		var gear:=MeshInstance3D.new();gear.name=part;gear.mesh=_gear[part][0];gear.skin=_gear[part][1]
		body_skeleton.add_child(gear);gear.skeleton=gear.get_path_to(skeleton)
	var uniforms: Dictionary=Look.uniforms(man);var shapes: Dictionary=Look.shapes(man)
	for node: MeshInstance3D in kit.find_children("*","MeshInstance3D",true,false):
		var part:=String(node.name)
		meshes[part]=node
		# Crouches and reaching poses leave the rest-pose bounds.
		node.extra_cull_margin=1.25
		node.set_surface_override_material(0,_materials[part])
		for key in uniforms: node.set_instance_shader_parameter(key,uniforms[key])
		var weights: Dictionary=shapes.get(part,{})
		for shape in weights:
			var index:=node.find_blend_shape_by_name(shape)
			if index>=0: node.set_blend_shape_value(index,weights[shape])
		if EQUIPMENT.has(part): equipment[EQUIPMENT[part]]=node
	meshes.Hat.visible=man.get("hat","slouch")!="none"
	for item in equipment: equipment[item].visible=bool(man.get(item,false))
	# Off-duty pose (relaxed hands, seats, a cup) runs first; the build then only scales.
	pose=Pose.new();pose.name="Pose";skeleton.add_child(pose);pose.configure("")
	build=Build.new();build.name="Build";skeleton.add_child(build)
	var body: Dictionary=Look.BUILDS.get(man.get("build","average"),{}).duplicate()
	if man.has("head"): body["head"]=man.head
	build.configure(skeleton,body)
	scale=Vector3.ONE*float(man.get("height",1.0))

func show_equipment(item: String, on: bool) -> void:
	if equipment.has(item): equipment[item].visible=on

## The miner's clips, shared: every figure plays the same Animation resources.
static func _miner_library() -> AnimationLibrary:
	if _library==null:
		var miner: Node=load(MINER).instantiate()
		var source: AnimationPlayer=miner.find_children("*","AnimationPlayer",true,false)[0]
		_library=source.get_animation_library("")
		miner.free()
	return _library

## One material per kit surface for all men, sampling the miner's own atlases.
static func _shared_materials() -> void:
	if not _materials.is_empty(): return
	var miner: Node=load(MINER).instantiate()
	var sources: Dictionary={}
	for node: MeshInstance3D in miner.find_children("*","MeshInstance3D",true,false):
		var source:=node.mesh.surface_get_material(0) as StandardMaterial3D
		var part:=source.resource_name.trim_prefix("Intrepid_")
		sources[part]=source
		if EQUIPMENT.has(part): _gear[part]=[node.mesh,node.skin]
	miner.free()
	for part in ATLAS:
		var source: StandardMaterial3D=sources[ATLAS[part]]
		var material:=ShaderMaterial.new();material.resource_name="Crew_"+part
		material.shader=preload("res://shaders/crew.gdshader")
		material.set_shader_parameter("albedo_atlas",source.albedo_texture)
		material.set_shader_parameter("normal_atlas",source.normal_texture)
		material.set_shader_parameter("surface_atlas",source.roughness_texture)
		material.set_shader_parameter("hair_cutout",part=="Hair")
		_materials[part]=material
