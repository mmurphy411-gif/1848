extends RefCounted
## Stage 6 prop materials. Built props (blender/build_camp_kit.py, build_store.py) carry
## placeholder materials named kit_*; the textured versions live once in
## assets/props/kit_materials.glb and tile in metres. dress() swaps them into a mesh
## resource in place, so every instance (and any duplicate) shares them.
const KIT := "res://assets/props/kit_materials.glb"
static var kit: Dictionary = {}
static var meshes: Dictionary = {}

static func materials() -> Dictionary:
	if not kit.is_empty(): return kit
	var scene: Node = load(KIT).instantiate()
	for node in scene.find_children("*", "MeshInstance3D", true, false):
		for i in node.mesh.get_surface_count():
			var source: Material = node.mesh.surface_get_material(i)
			if source == null: continue
			var m := source.duplicate() as BaseMaterial3D
			# Built props bake dirt and contact shading into COLOR_0.
			m.vertex_color_use_as_albedo = true
			m.vertex_color_is_srgb = false # glTF COLOR_0 is linear
			if m.resource_name == "kit_glass":
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
			if m.resource_name == "kit_canvas":
				# Sun through the cloth: the lit underside of a lean-to or store roof.
				m.backlight_enabled = true
				m.backlight = Color(.42, .39, .33)
			kit[source.resource_name] = m
	scene.free()
	return kit

static func dress(mesh: Mesh) -> Mesh:
	if mesh == null: return mesh
	var k := materials()
	for i in mesh.get_surface_count():
		var m: Material = mesh.surface_get_material(i)
		if m and k.has(m.resource_name) and m != k[m.resource_name]: mesh.surface_set_material(i, k[m.resource_name])
	return mesh

static func dress_tree(root: Node) -> void:
	for node in root.find_children("*", "MeshInstance3D", true, false): dress(node.mesh)
	if root is MeshInstance3D: dress(root.mesh)

## First mesh of a GLB, dressed and cached (like Assets.mesh, but for props).
static func mesh(path: String) -> Mesh:
	if meshes.has(path): return meshes[path]
	var scene: Node = load(path).instantiate()
	var node: MeshInstance3D = scene if scene is MeshInstance3D else scene.find_children("*", "MeshInstance3D", true, false)[0]
	var result: Mesh = dress(node.mesh)
	scene.free()
	meshes[path] = result
	return result

## Every named mesh of a multi-object GLB, dressed.
static func named(path: String) -> Dictionary:
	if meshes.has(path): return meshes[path]
	var result := {}
	var scene: Node = load(path).instantiate()
	for node in scene.find_children("*", "MeshInstance3D", true, false): result[str(node.name)] = dress(node.mesh)
	scene.free()
	meshes[path] = result
	return result

## A MeshInstance3D for a prop GLB with an optional transform.
static func instance(path: String, at := Transform3D.IDENTITY) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh(path)
	node.transform = at
	return node
