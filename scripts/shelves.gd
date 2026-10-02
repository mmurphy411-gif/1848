extends Node3D
const Layout=preload("res://scripts/store_layout.gd")
const Stock=preload("res://scripts/store_stock.gd")
const Kit=preload("res://scripts/prop_kit.gd")
## Goods that exist as full props; everything else is a named mesh in goods.glb.
const PROPS := {"pick":"res://assets/props/pick.glb","shovel":"res://assets/props/spade.glb",
	"crowbar":"res://assets/props/crowbar.glb","pan":"res://assets/miner/pan.glb"}
const BULK := ["flour","beans","pork","coffee","salt"]
## Where a good sits relative to its Layout.item_position (display only: aim targets and
## reach stay on the layout) and its scale. Bulk goods stand on the deep bottom shelf,
## hooks lie on the middle shelf, coils hang from the peg rail, tools stand on the top shelf.
const SHOW := {
	"flour":[Vector3(0,-.02,-.25),1.0],"beans":[Vector3(0,-.02,-.25),1.0],"pork":[Vector3(0,-.02,-.25),1.0],
	"coffee":[Vector3(0,-.02,-.25),1.0],"salt":[Vector3(0,-.02,-.25),1.0],
	"hook":[Vector3(0,-.214,0),.45],"line":[Vector3(0,0,.01),1.0],"rod":[Vector3(0,-.23,.03),1.0],
	"crowbar":[Vector3(0,-.2,-.05),.95],"pick":[Vector3(0,-.2,-.12),.72],"shovel":[Vector3(0,-.2,-.14),.72],
	"boots":[Vector3(0,-.2,-.12),1.0],"rocker":[Vector3(0,-.2,-.12),.8],"spear":[Vector3(0,-.2,0),.65],
	"rifle":[Vector3(0,-.2,0),.65],"powder":[Vector3(0,-.2,-.1),1.0],"tent":[Vector3(0,-.2,-.12),.8],
}
var counter: Node
var sources: Dictionary={}
var display := Node3D.new()
func _ready() -> void:
	add_child(display)
	sources=Kit.named("res://assets/store/goods.glb").duplicate()
	for item in PROPS: sources[item]=Kit.mesh(PROPS[item])
	sources["tub"]=Kit.mesh("res://assets/props/tub.glb")
func object(item: String,fill := 3) -> Node3D:
	if item in ["rifle","spear"]:
		var prop: Node3D=load("res://assets/expedition/"+item+".glb").instantiate();prop.rotation.x=PI/2;return prop
	var mesh:=MeshInstance3D.new()
	mesh.mesh=sources.get(item+"_"+str(fill),sources.get(item))
	if item=="pork":
		var tub:=MeshInstance3D.new();tub.mesh=sources.tub;mesh.add_child(tub)
	if item=="rocker": mesh.rotation.y=PI/2
	return mesh
## What lands on the counter: bulk goods are weighed out into a tied paper parcel.
func pile_object(item: String) -> Node3D:
	if item in BULK:
		var parcel:=MeshInstance3D.new();parcel.mesh=sources.parcel;parcel.rotation.y=.25*sin(item.length());return parcel
	return object(item)
## Outfitting goods are props in their own right (crate-side pans, bottles, rolls).
static func outfit_prop(item: String) -> Node3D:
	var holder:=Node3D.new()
	var node:=MeshInstance3D.new()
	node.mesh=Kit.mesh(PROPS.pan) if item=="pan" else Kit.named("res://assets/store/goods.glb")[item]
	holder.add_child(node)
	return holder
func refresh() -> void:
	for child in display.get_children(): display.remove_child(child);child.queue_free()
	for good in Stock.catalogue():
		var count: int=counter.available(good.item)
		var bulk: bool=good.unit=="lb"
		var fill:=clampi(ceili(4.0*count/maxi(good.opening,count))-1,0,3)
		var shown: int={"pan":8,"bunk":4,"strongbox":1,"whiskey":12,"timber":2}.get(good.item,count)
		var show: Array=SHOW.get(good.item,[Vector3.ZERO,1.0])
		for i in (1 if bulk and count>0 else mini(count,shown)):
			var node:=object(good.item,fill) if not good.item in Stock.OUTFIT else outfit_prop(good.item)
			display.add_child(node);node.position=Layout.item_position(good.item)
			if good.item in Stock.OUTFIT:
				match good.item:
					"pan": node.position.y+=i*.03;node.rotation.y=i*.7
					"whiskey": node.position+=Vector3((i%4)*.1-.15,0,floori(i/4.0)*.1-.1)
					"bunk": node.position.z+=i*.34
					"timber": node.position.y+=i*.33
				continue
			node.position+=show[0];node.scale=Vector3.ONE*show[1]
			if not bulk:
				if good.item=="hook":
					node.position+=Vector3((i%8)*.028,floori(i/64.0)*.007,(floori(i/8.0)%8)*.028-.20)
				elif good.item=="line": node.position+=Vector3((i%12)*.014,floori(i/12.0)*.02,0)
				elif good.item in ["crowbar","pick","shovel","spear","rifle"]:
					# Long tools stand fanned against the back of the top shelf.
					node.position+=Vector3((i%3)*.09-.09,0,-floori(i/3.0)*.06)
					node.rotation.z=((i%3)-1)*.07
				else:
					node.position+=Vector3((i%6)*.028,0,floori(i/6.0)*.028)
				node.rotation.y+=.08*sin(i*1.7)
		if good.item in Stock.OUTFIT: continue
		# The peg (middle rail) or price tag (shelf front) stays when a good sells out.
		var peg:=MeshInstance3D.new()
		var at: Vector3=Layout.item_position(good.item)
		if good.item in ["hook","line","rod"]:
			peg.mesh=sources.peg;peg.position=at+Vector3(0,.10,-.19)
		else:
			peg.mesh=sources.tag
			peg.position=Vector3(at.x,.37,-1.202) if bulk else Vector3(at.x,1.83,-1.422)
		display.add_child(peg)
