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
	var mesh:=MeshInstance3D.new()
	mesh.mesh=sources.get(item+"_"+str(fill),sources.get(item))
	return mesh
func refresh() -> void:
	for child in display.get_children(): display.remove_child(child);child.queue_free()
	for good in Stock.catalogue():
		var count: int=counter.available(good.item)
		var bulk: bool=good.unit=="lb"
		var fill:=clampi(ceili(4.0*count/maxi(good.opening,count))-1,0,3)
		for i in (1 if bulk and count>0 else count):
			var node:=object(good.item,fill)
			display.add_child(node);node.position=Layout.item_position(good.item)
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
		var peg:=MeshInstance3D.new();var shape:=BoxMesh.new();shape.size=Vector3(.025,.025,.18);peg.mesh=shape
		display.add_child(peg);peg.position=Layout.item_position(good.item)+Vector3(0,.10,-.1)
