@tool
extends RefCounted
## Imported assets share textures and shaders; geometry stays reusable by MultiMesh.
static var meshes: Dictionary = {}
static var materials: Dictionary = {}
const SETS := ["granite", "talus", "gravel", "sand", "duff", "bedrock", "soil"]
## Live river height for the wet bands of the terrain and the claim's rock sets.
static var water_level := 0.0
const WET_ROCK_SETS := ["granite", "bedrock"]

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
	result.set_shader_parameter("water_level", water_level)
	materials.terrain = result
	return result

## Tri-planar scan material; any mesh, any set. Granite and bedrock are the claim's
## river rocks and darken at the live water line; the other sets stay dry.
static func rock(set_name := "granite", tile := 4.0) -> ShaderMaterial:
	var key := set_name + str(tile)
	if materials.has(key): return materials[key]
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/rock.gdshader")
	for suffix in ["albedo", "normal", "orm"]:
		result.set_shader_parameter(suffix + "_map", load("res://assets/textures/%s_%s.png" % [set_name, suffix]))
	result.set_shader_parameter("tile", tile)
	if set_name in WET_ROCK_SETS: result.set_shader_parameter("water_level", water_level)
	result.set_meta("wet", set_name in WET_ROCK_SETS)
	materials[key] = result
	return result

static func set_water_level(level: float) -> void:
	water_level = level
	terrain().set_shader_parameter("water_level", level)
	for material in materials.values():
		if material.get_meta("wet", false): material.set_shader_parameter("water_level", level)

## Stage 4 vegetation. Mesh variants per tree species: `<species>.glb`, `<species>_2.glb`, ...
## (tools/art/build_trees.mjs), each with a `_distant` LOD.
const TREE_VARIANTS := {"ponderosa": 3, "incense_cedar": 3, "douglas_fir": 3, "black_oak": 3}
## Layer of the bark Texture2DArray (tools/art/build_foliage_atlases.py BARK_LAYERS).
const BARK_LAYER := {"ponderosa": 0, "incense_cedar": 1, "douglas_fir": 2, "fir_sapling": 2,
	"black_oak": 3, "toyon": 3, "alder": 4, "willow": 4, "deerbrush": 4, "manzanita": 5}
## Seasonal leaf response: autumn colour (sRGB), season window (0 = June 26, 1 = first snow),
## strength, leaf-drop start, atlas mean luminance (linear), and optionally the timing spread
## per instance / per card / toward the outer crown (foliage.gdshader `timing_spread`).
## Black oak turns through late September and October, crown by crown and outside in; grass
## is gold by August; chaparral and conifers barely change; leaf litter is always last year's.
const SEASON := {
	"black_oak": [Color(.74, .58, .17), Vector2(.60, .86), 1.0, .9, .075, Vector3(.10, .14, .16)],
	"ponderosa": [Color(.55, .52, .28), Vector2(.25, .75), .10, 2.0, .10],
	"incense_cedar": [Color(.55, .50, .26), Vector2(.25, .75), .10, 2.0, .11],
	"douglas_fir": [Color(.50, .50, .30), Vector2(.25, .75), .08, 2.0, .065],
	"grass": [Color(.78, .66, .40), Vector2(.02, .30), 1.0, 2.0, .11],
	"fern": [Color(.60, .40, .20), Vector2(.55, .85), .85, 2.0, .10],
	"sedge": [Color(.70, .62, .36), Vector2(.45, .95), .6, 2.0, .09],
	"shrub": [Color(.58, .56, .36), Vector2(.10, .60), .22, 2.0, .10],
	"riparian": [Color(.76, .64, .25), Vector2(.62, .88), 1.0, .97, .10, Vector3(.10, .12, .10)],
	"litter": [Color(.43, .31, .17), Vector2(-2.0, -1.0), .92, 2.0, .075],
}
## Understory meshes (assets/plants/) -> season key. Saplings use their species atlas; leaf
## litter lies flat and uses the oak atlas (UNDERSTORY_ATLAS).
const UNDERSTORY := {"grass_clump": "grass", "sedge_clump": "sedge", "fern": "fern",
	"manzanita": "shrub", "toyon": "shrub", "deerbrush": "shrub",
	"willow": "riparian", "alder": "riparian",
	"fir_sapling": "douglas_fir", "oak_sapling": "black_oak", "leaf_litter": "litter"}
const UNDERSTORY_ATLAS := {"leaf_litter": "black_oak"}
## Per-plant overrides on the shared leaf material: white alder darker and bluer than the
## grey-green willow, later and duller in autumn.
const PLANT_LOOK := {
	"alder": {"leaf_tint": Vector3(.72, .84, .80), "autumn_color": Color(.58, .52, .26), "autumn_window": Vector2(.70, .98), "autumn_strength": .7},
	"willow": {"leaf_tint": Vector3(1.1, 1.08, .92)},
	"oak_sapling": {"leaf_tint": Vector3(1.05, 1.08, .95)},
	"leaf_litter": {"flat_cards": true},
}
## Bark grade per layer of the bark array: [gain, saturation, normal depth, cavity, mean linear
## luminance of the layer]. The oak scan reads grey-brown and keeps its plates in crown shade.
const BARK_LOOK := {0: [1.0, 1.0, 1.2, .45, .097], 1: [1.1, .95, 1.2, .45, .041], 2: [1.1, .95, 1.2, .45, .041],
	3: [1.3, .4, 1.7, .85, .104], 4: [1.15, .8, 1.3, .5, .087], 5: [1.0, 1.0, 1.0, .3, .10]}

static func _bark_material(layer: int, bark_color: Color) -> ShaderMaterial:
	# Callers pass a bark colour; on scanned bark it is only a gentle hue hint.
	var hint := bark_color / maxf(bark_color.get_luminance(), .05)
	var key := "bark%d_%s" % [layer, Color.WHITE.lerp(hint, .15).to_html()]
	if materials.has(key): return materials[key]
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/bark.gdshader")
	result.set_shader_parameter("bark_albedo", load("res://assets/textures/bark_albedo.png"))
	result.set_shader_parameter("bark_normal", load("res://assets/textures/bark_normal.png"))
	result.set_shader_parameter("layer", float(layer))
	result.set_shader_parameter("tint", Color.WHITE.lerp(hint, .15))
	var look: Array = BARK_LOOK.get(layer, [1.0, 1.0, 1.2, 0.0, .1])
	for i in 5: result.set_shader_parameter(["gain", "saturation", "normal_depth", "cavity", "mean_luma"][i], look[i])
	materials[key] = result
	return result

static func _leaf_material(atlas_name: String, season_key: String) -> ShaderMaterial:
	var key := "leaves_%s_%s" % [atlas_name, season_key]
	if materials.has(key): return materials[key]
	var result := ShaderMaterial.new()
	result.shader = preload("res://shaders/foliage.gdshader")
	result.set_shader_parameter("leaves", true)
	result.set_shader_parameter("use_atlas", true)
	result.set_shader_parameter("leaf_atlas", load("res://assets/textures/foliage_%s_albedo.png" % atlas_name))
	var s: Array = SEASON[season_key]
	result.set_shader_parameter("autumn_color", s[0])
	result.set_shader_parameter("autumn_window", s[1])
	result.set_shader_parameter("autumn_strength", s[2])
	result.set_shader_parameter("drop_start", s[3])
	result.set_shader_parameter("atlas_luma", s[4])
	if s.size() > 5: result.set_shader_parameter("timing_spread", s[5])
	result.set_shader_parameter("flutter", .025 if season_key in ["black_oak", "riparian", "shrub"] else .012)
	materials[key] = result
	return result

## Trees (atlas) and the legacy procedural flower/grass cards (atlas = false). Variant 0 is
## `<species>.glb`; variant n > 0 loads `<species>_<n+1>.glb`.
static func plant(species: String, bark_color: Color, atlas := true, distant := false, variant := 0) -> ArrayMesh:
	var file := species if variant <= 0 else "%s_%d" % [species, variant + 1]
	var tree := mesh("res://assets/%s/%s%s.glb" % ["trees" if atlas else "plants", file, "_distant" if distant else ""])
	for surface in tree.get_surface_count():
		if atlas:
			tree.surface_set_material(surface, _bark_material(BARK_LAYER.get(species, 3), bark_color) if surface == 0 else _leaf_material(species, species))
			continue
		var result := ShaderMaterial.new()
		result.shader = preload("res://shaders/foliage.gdshader")
		result.set_shader_parameter("leaves",true)
		result.set_shader_parameter("use_atlas",false)
		result.set_shader_parameter("tint", bark_color)
		tree.surface_set_material(surface, result)
	return tree

## Stem colour of one-surface understory plants (sRGB): manzanita's red-brown is the tell.
const STEM := {"manzanita": Color(.45, .17, .1), "toyon": Color(.33, .27, .22), "deerbrush": Color(.42, .4, .33),
	"willow": Color(.38, .32, .25), "alder": Color(.56, .55, .52), "fir_sapling": Color(.3, .22, .16), "oak_sapling": Color(.34, .3, .26)}

## Shrubs, saplings, ferns and grass clumps from assets/plants/ (Stage 4 understory): one
## surface each, stems flagged in vertex colour (tools/art/build_trees.mjs).
static func understory(plant_name: String) -> ArrayMesh:
	var result := mesh("res://assets/plants/%s.glb" % plant_name)
	var season_key: String = UNDERSTORY[plant_name]
	var atlas_name: String = UNDERSTORY_ATLAS.get(plant_name, season_key if season_key in TREE_VARIANTS else "understory")
	var key := "understory_" + plant_name
	if not materials.has(key):
		var material := _leaf_material(atlas_name, season_key).duplicate() as ShaderMaterial
		material.set_shader_parameter("stem_color", STEM.get(plant_name, Color(.32, .26, .2)))
		var look: Dictionary = PLANT_LOOK.get(plant_name, {})
		for parameter in look: material.set_shader_parameter(parameter, look[parameter])
		materials[key] = material
	for surface in result.get_surface_count():
		result.surface_set_material(surface, materials[key])
	return result
