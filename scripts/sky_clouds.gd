@tool
extends MeshInstance3D
## Stage 1 cloud layer: a camera-centred dome drawn at the far plane over the
## PhysicalSkyMaterial, which stays the environment sky (and so still drives the
## ambient light and reflections), plus a full-screen pass that lays the same
## clouds' shadows on the ground. daylight.gd calls configure() whenever it poses
## the light. Coverage follows the weather and the hour; drift follows the game
## clock (day and hour), never wall time, so posed captures repeat exactly.
## Both hide while the active camera carries its own Environment: the colour-ID
## coverage probes swap one in and must not see clouds or their shade.

const Weather = preload("res://scripts/weather.gd")
## Drift in noise tiles per game hour; a tile spans tens of kilometres of sky.
const DRIFT := Vector2(0.11, 0.05)
## Where the drifting field starts. Picked from 64 seeded candidates so the Stage 1
## gate views (downstream, day 10, 10:00 and 13:00) are not under a cloud shadow and
## the 10:00 overview is (~18 %): exposure is tuned on sunlit ground.
const PHASE := Vector2(0.005, 0.110)
## The phase in use (tools may try others).
var phase := PHASE
## Cloud shadows at full sun: the fraction of light a thick cloud takes away.
const SHADOW_STRENGTH := 0.35
var material := ShaderMaterial.new()
var shadows := MeshInstance3D.new()
var shadow_material := ShaderMaterial.new()
var _shadow_strength := 0.0
var _hidden_for_camera := false

func _init() -> void:
	name = "Clouds"
	var dome := SphereMesh.new()
	dome.radius = 1.0
	dome.height = 2.0
	dome.radial_segments = 32
	dome.rings = 16
	mesh = dome
	_screen_space(self)
	# Off layer 1, so the river's reflection probe keeps the bare physical sky: a
	# lit dome in the probe put warm cloud glare on the whole bar at golden hour.
	layers = 2
	material.shader = preload("res://shaders/sky_clouds.gdshader")
	# First among transparents: rain streaks and the water draw over it.
	material.render_priority = Material.RENDER_PRIORITY_MIN
	material_override = material
	var quad := QuadMesh.new()
	quad.size = Vector2(2, 2)
	shadows.name = "CloudShadows"
	shadows.mesh = quad
	_screen_space(shadows)
	# Last among transparents, so the water darkens with the bar beneath it.
	shadows.layers = 2
	shadow_material.shader = preload("res://shaders/cloud_shadows.gdshader")
	shadow_material.render_priority = Material.RENDER_PRIORITY_MAX
	shadows.material_override = shadow_material
	add_child(shadows)
	var shape := _noise(184820, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 0.0085, 5, false)
	var billow := _noise(184821, FastNoiseLite.TYPE_CELLULAR, 0.022, 3, true)
	for m in [material, shadow_material]:
		m.set_shader_parameter("cloud_shape", shape)
		m.set_shader_parameter("cloud_billow", billow)

## The shaders place these meshes from the camera; never cull them by their boxes.
func _screen_space(node: MeshInstance3D) -> void:
	node.top_level = true
	node.custom_aabb = AABB(Vector3(-1e6, -1e6, -1e6), Vector3(2e6, 2e6, 2e6))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.gi_mode = GeometryInstance3D.GI_MODE_DISABLED

func _noise(seed_value: int, type: FastNoiseLite.NoiseType, frequency: float, octaves: int, invert: bool) -> NoiseTexture2D:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = type
	noise.frequency = frequency
	noise.fractal_octaves = octaves
	noise.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var texture := NoiseTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.seamless = true
	texture.invert = invert
	texture.generate_mipmaps = true
	texture.noise = noise
	return texture

func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_3d() if is_inside_tree() else null
	var own := camera != null and camera.environment != null
	# Only undo a hide this node made, so callers that hide it themselves win.
	if own and visible:
		visible = false
		_hidden_for_camera = true
	elif not own and _hidden_for_camera:
		visible = true
		_hidden_for_camera = false
	var shade := _shadow_strength > 0.001
	if shadows.visible != shade: shadows.visible = shade

## sky: Dictionary from daylight.gd with hour, day, seed, weather, overcast,
## sun_direction, sun_elevation, sun_color, sun_energy, moon_direction,
## moon_color, moon_energy.
func configure(sky: Dictionary) -> void:
	var hour: float = sky.hour
	var weather: String = sky.weather
	var elevation: float = sky.sun_elevation
	var day: int = sky.day
	# Fair-weather cumulus build through the afternoon and thin out after dusk.
	# Wave C: the first heaps stand by mid-morning (the 10:00 sky was all but empty).
	var build := smoothstep(8.0, 14.0, hour) * (1.0 - smoothstep(16.5, 20.5, hour))
	var variation := Weather.noise(int(sky.seed), day, 23) - 0.5
	var cover := 0.33 + 0.15 * build + 0.12 * variation
	var haze := 0.06
	var scale := 0.06
	match weather:
		"hot":
			cover = 0.12 + 0.08 * build
			haze = 0.75
		"frost":
			cover = 0.04
			haze = 0.0
	# Rain.gd's overcast drives the deck; on hot days its 0.35 is haze, not cloud.
	var deck := 0.0 if weather == "hot" else smoothstep(0.05, 0.75, float(sky.overcast))
	cover = lerpf(cover, 1.08, deck)
	scale = lerpf(scale, 0.035, deck)
	var hours := float(day) * 24.0 + hour
	var shared := {"coverage": cover, "softness": lerpf(0.1, 0.3, deck), "layer_scale": scale,
		"shape_offset": _wrap(DRIFT * hours + phase),
		"billow_offset": _wrap((DRIFT * hours + phase) * 2.3 + Vector2(0.0, 0.013) * hours)}
	for key in shared:
		material.set_shader_parameter(key, shared[key])
		shadow_material.set_shader_parameter(key, shared[key])
	material.set_shader_parameter("opacity", lerpf(0.93, 1.0, deck))
	material.set_shader_parameter("overcast", deck)
	material.set_shader_parameter("haze", haze)
	material.set_shader_parameter("haze_offset", _wrap((DRIFT * hours + phase) * 0.4))
	# Clouds high above the canyon catch the sun before the floor does.
	var sunlit := smoothstep(-6.0, 3.0, elevation)
	var moonlit := 1.0 - smoothstep(-8.0, -2.0, elevation)
	var direction: Vector3 = sky.sun_direction if sunlit > 0.0 else sky.moon_direction
	var warm := 1.0 - smoothstep(4.0, 30.0, elevation)
	var sun_color: Color = sky.sun_color
	var light_color := sun_color.lerp(Color(1.0, 0.62, 0.42), warm * 0.5)
	if sunlit <= 0.0: light_color = sky.moon_color
	var energy := 0.82 * sunlit * maxf(float(sky.sun_energy), 1.2 * sunlit) + 0.07 * moonlit * float(sky.moon_energy)
	material.set_shader_parameter("light_direction", direction.normalized())
	material.set_shader_parameter("light_color", light_color)
	material.set_shader_parameter("light_energy", energy)
	# A sun just above the horizon lights the heaps' flat bases from below.
	material.set_shader_parameter("underlight", 0.35 * warm * sunlit * (1.0 - deck))
	var ambient := Color(0.46, 0.54, 0.66).lerp(Color(0.56, 0.5, 0.52), warm * sunlit)
	material.set_shader_parameter("ambient_color", ambient)
	material.set_shader_parameter("ambient_energy", lerpf(0.01, 0.7, sunlit) * lerpf(1.0, 0.75, deck))
	material.set_shader_parameter("overcast_color", Color(0.62, 0.64, 0.67))
	# Shadows need direct sun: none at night, fading at a low sun, gone under the deck.
	var sun_direction: Vector3 = sky.sun_direction
	_shadow_strength = SHADOW_STRENGTH * smoothstep(3.0, 14.0, elevation) * (1.0 - deck) * (1.0 - 0.6 * haze)
	shadow_material.set_shader_parameter("light_direction", sun_direction.normalized())
	shadow_material.set_shader_parameter("strength", _shadow_strength)
	_process(0.0)

func _wrap(offset: Vector2) -> Vector2:
	return Vector2(fposmod(offset.x, 1.0), fposmod(offset.y, 1.0))
