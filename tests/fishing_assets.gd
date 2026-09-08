extends SceneTree
func _initialize() -> void:
	for path in ["res://assets/fish/fish.glb","res://assets/camp/camp.glb","res://assets/miner/handline.glb"]:
		var scene: Node=load(path).instantiate()
		var total := 0
		for node in scene.find_children("*","MeshInstance3D",true,false):
			var count := 0
			for s in node.mesh.get_surface_count():
				var arrays: Array=node.mesh.surface_get_arrays(s)
				count+=arrays[Mesh.ARRAY_INDEX].size()/3 if arrays[Mesh.ARRAY_INDEX]!=null else arrays[Mesh.ARRAY_VERTEX].size()/3
			total+=count
			if str(node.name) in ["trout","sucker","pikeminnow","hardhead","salmon"]: assert(count>=300 and count<=600)
			print(node.name,": ",count," triangles")
		if "camp" in path: assert(total<6000)
		if "handline" in path: assert(total<400)
		print(path," total: ",total)
		scene.free()
	print("M9 ASSET BUDGET PASS")
	quit()
