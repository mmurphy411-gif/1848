extends Node3D
const Layout=preload("res://scripts/store_layout.gd")
const Stock=preload("res://scripts/store_stock.gd")
var counter: Node
var sources: Dictionary={}
var display := Node3D.new()
func _ready() -> void:
	add_child(display)
	var asset: Node3D=load("res://assets/store/goods.glb").instantiate()
	for node in asset.find_children("*","MeshInstance3D",true,false): sources[str(node.name)]=node.mesh
	asset.free()
func object(item: String,fill := 3) -> Node3D:
	if item in ["rifle","spear"]:
		var prop: Node3D=load("res://assets/expedition/"+item+".glb").instantiate();prop.rotation.x=PI/2;return prop
	if item in Stock.OUTFIT: return outfit_prop(item)
	var mesh:=MeshInstance3D.new()
	mesh.mesh=sources.get(item+"_"+str(fill),sources.get(item))
	return mesh
## Simple turned and boxed shapes for the outfitting corner.
static func outfit_prop(item: String) -> Node3D:
	var node:=MeshInstance3D.new()
	var mat:=StandardMaterial3D.new();mat.roughness=.55
	match item:
		"pan":
			var pan:=CylinderMesh.new();pan.top_radius=.2;pan.bottom_radius=.15;pan.height=.06;pan.radial_segments=20;pan.rings=1
			node.mesh=pan;mat.albedo_color=Color(.62,.62,.6);mat.metallic=.85;mat.roughness=.4
		"whiskey":
			var bottle:=CylinderMesh.new();bottle.top_radius=.025;bottle.bottom_radius=.045;bottle.height=.3;bottle.radial_segments=10
			node.mesh=bottle;mat.albedo_color=Color(.32,.17,.05,.85);mat.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;mat.roughness=.12
			node.position.y=.15
		"strongbox":
			var box:=BoxMesh.new();box.size=Vector3(.62,.36,.4);node.mesh=box
			mat.albedo_color=Color(.13,.13,.14);mat.metallic=.7;mat.roughness=.6;node.position.y=.18
			var band:=MeshInstance3D.new();var strap:=BoxMesh.new();strap.size=Vector3(.64,.05,.42);band.mesh=strap;band.position.y=.08
			var brass:=StandardMaterial3D.new();brass.albedo_color=Color(.55,.42,.16);brass.metallic=.9;brass.roughness=.35;band.material_override=brass;node.add_child(band)
		"timber":
			var planks:=BoxMesh.new();planks.size=Vector3(1.6,.32,.62);node.mesh=planks;node.position.y=.16
			mat.albedo_color=Color(.62,.47,.3);mat.roughness=.9
		"bunk":
			var roll:=CylinderMesh.new();roll.top_radius=.14;roll.bottom_radius=.14;roll.height=1.0;roll.radial_segments=12
			node.mesh=roll;node.rotation.z=PI/2;node.position.y=.14;mat.albedo_color=Color(.78,.72,.58);mat.roughness=.95
	node.material_override=mat
	var holder:=Node3D.new();holder.add_child(node)
	return holder
func refresh() -> void:
	for child in display.get_children(): display.remove_child(child);child.queue_free()
	for good in Stock.catalogue():
		var count: int=counter.available(good.item)
		var bulk: bool=good.unit=="lb"
		var fill:=clampi(ceili(4.0*count/maxi(good.opening,count))-1,0,3)
		var shown: int={"pan":8,"bunk":4,"strongbox":1,"whiskey":12,"timber":2}.get(good.item,count)
		for i in (1 if bulk and count>0 else mini(count,shown)):
			var node:=object(good.item,fill)
			display.add_child(node);node.position=Layout.item_position(good.item)
			if good.item in Stock.OUTFIT:
				match good.item:
					"pan": node.position.y+=i*.03;node.rotation.y=i*.7
					"whiskey": node.position+=Vector3((i%4)*.1-.15,0,floori(i/4.0)*.1-.1)
					"bunk": node.position.z+=i*.34
					"timber": node.position.y+=i*.33
				continue
			if not bulk:
				if good.item=="hook":
					node.scale=Vector3.ONE*.45
					node.position+=Vector3((i%8)*.028,floori(i/64.0)*.007,(floori(i/8.0)%8)*.028-.20)
				elif good.item=="line": node.position+=Vector3((i%12)*.014,floori(i/12.0)*.02,0)
				else:
					node.scale=Vector3.ONE*(1.0 if good.item=="rod" else .65)
					node.position+=Vector3((i%6)*.028,0,floori(i/6.0)*.028)
				node.rotation.y=.08*sin(i*1.7)
				if good.item=="line": node.rotation.x=PI/2
		if good.item in Stock.OUTFIT: continue
		var peg:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=Vector3(.025,.025,.18);peg.mesh=shape
		display.add_child(peg);peg.position=Layout.item_position(good.item)+Vector3(0,.10,-.1)
