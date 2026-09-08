@tool
extends RefCounted
## Imported assets share textures and shaders; geometry stays reusable by MultiMesh.
static var meshes: Dictionary = {}
static var materials: Dictionary = {}
const SETS := ["granite", "talus", "gravel", "sand", "duff", "bedrock"]

static func mesh(path: String) -> ArrayMesh:
	if meshes.has(path): return meshes[path]
	var scene: Node3D = load(path).instantiate()
	var node: MeshInstance3D = scene.find_children("*", "MeshInstance3D", true, false)[0]
	var result := node.mesh.duplicate() as ArrayMesh
	scene.free()
	meshes[path] = result
	return result

static func terrain() -> ShaderMaterial:
	if materials.has("terrain"): return materials.terrain
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/terrain.gdshader")
	for set_name in SETS:
		for suffix in ["albedo", "normal", "orm"]:
			result.set_shader_parameter(set_name + "_" + suffix, load("res://assets/textures/%s_%s.png" % [set_name, suffix]))
	materials.terrain = result
	return result

static func rock(set_name := "granite", tile := 4.0) -> ShaderMaterial:
	var key := set_name + str(tile)
	if materials.has(key): return materials[key]
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/rock.gdshader")
	for suffix in ["albedo", "normal", "orm"]:
		result.set_shader_parameter(suffix + "_map", load("res://assets/textures/%s_%s.png" % [set_name, suffix]))
	result.set_shader_parameter("tile", tile)
	materials[key] = result
	return result

static func plant(species: String, bark_color: Color, atlas := true) -> ArrayMesh:
	var tree := mesh("res://assets/%s/%s.glb" % ["trees" if atlas else "plants", species])
	for surface in tree.get_surface_count():
		var result := ShaderMaterial.new()
		result.shader = preload("res://shaders/foliage.gdshader")
		result.set_shader_parameter("leaves", surface == 1 or not atlas)
		result.set_shader_parameter("use_atlas", atlas)
		result.set_shader_parameter("tint", bark_color)
		if atlas: result.set_shader_parameter("leaf_atlas", load("res://assets/textures/foliage_%s_albedo.png" % species))
		tree.surface_set_material(surface, result)
	return tree
