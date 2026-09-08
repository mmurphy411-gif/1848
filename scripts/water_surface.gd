@tool
extends MeshInstance3D
## Owns only the water material and its deterministic procedural textures.

func _ready() -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/water.gdshader")
	material.set_shader_parameter("normal_large", _noise(1848, true, 0.025))
	material.set_shader_parameter("normal_small", _noise(1849, true, 0.035))
	material.set_shader_parameter("foam_noise", _noise(1850, false, 0.045))
	material_override = material

func _noise(seed_value: int, normal: bool, frequency: float) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	texture.as_normal_map = normal
	texture.bump_strength = 8.0
	return texture
