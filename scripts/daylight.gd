@tool
extends Node3D
## Physical sky with deterministic posing and a separate real-time day clock.
signal time_changed(hour: float, daylight: float)

@export_range(0.0, 24.0) var hour := 19.25:
	set(value):
		hour = value
		if is_node_ready():
			apply(hour)
@export var camera_attributes: CameraAttributesPractical
@onready var sun: DirectionalLight3D = $Sun
@onready var moon: DirectionalLight3D = $Moon
@onready var clock: Node = $Clock
@onready var world: WorldEnvironment = $WorldEnvironment
@onready var mist: FogVolume = $RiverMist
@onready var rim_air: FogVolume = $ClearRimAir
var environment: Environment
var sky_material: PhysicalSkyMaterial
var sun_elevation := 0.0
var overcast := 0.0
var current_hour := 19.25
var sun_azimuth := 0.0
## 0 .. 1: how far the light is in golden hour proper (see _update_light).
var golden := 0.0
var _reflection_elapsed := 0.0
var stars = preload("res://scripts/night_sky.gd").new()
## Sun energy as it nears the horizon (1.45 under a high sun).
const GOLDEN_SUN_ENERGY := 2.8
## Sun elevations (degrees) over which dusk gives way to golden hour.
const DUSK_ELEVATION := Vector2(6.5, 9.5)
## Volumetric fog density (1/m) everywhere and in the RiverMist box over the channel,
## by day, at golden hour and at night. Beyond the 96 m froxel range every surface
## carries the haze accumulated up to it, so these set the mid-distance veil. Dusk
## is the sun's last few degrees above the horizon.
const DAY_FOG := 0.0012
const GOLDEN_FOG := 0.0012
const DUSK_FOG := 0.004
const NIGHT_FOG := 0.0045
const DAY_MIST := 0.0008
const GOLDEN_MIST := 0.0014
const DUSK_MIST := 0.006
const NIGHT_MIST := 0.004
## Share of the global volumetric fog that ClearRimAir removes above 10 m.
const RIM_CLEARING := 0.8
## Stage 1: cloud dome over the physical sky (scripts/sky_clouds.gd).
var clouds: MeshInstance3D = preload("res://scripts/sky_clouds.gd").new()

func _ready() -> void:
	environment = Environment.new()
	sky_material = PhysicalSkyMaterial.new()
	sky_material.night_sky = stars.texture
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	world.environment = environment
	mist.material = FogMaterial.new()
	rim_air.material = FogMaterial.new()
	add_child(clouds)
	clock.advanced.connect(_animate)
	apply(hour)

func apply(time: float) -> void:
	# Explicit poses stay frozen for the editor and all existing capture tools.
	clock.running = false
	_update_light(time)
	_refresh_reflection()

func _animate(time: float) -> void:
	_update_light(time)
	_reflection_elapsed += get_process_delta_time()
	if _reflection_elapsed >= 8.0:
		_reflection_elapsed = 0.0
		_refresh_reflection()

func _refresh_reflection() -> void:
	var probe := get_node_or_null("../Greybox/RiverReflection") as ReflectionProbe
	if probe:
		# A transform notification queues one new cubemap; continuous mode would
		# render six extra views every frame. Keep the existing reflection feature.
		probe.position.y = 4.0 if probe.position.y > 4.0 else 4.001

func _update_light(time: float) -> void:
	var h := fposmod(time, 24.0)
	current_hour=h
	# Late-June daylight, oriented so northwest/sunset is downstream (+X).
	# Direction is continuous through midnight and both horizon crossings.
	if h >= 4.75 and h <= 20.5:
		var phase := (h - 4.75) / 15.75
		sun_elevation = 74.0 * pow(maxf(sin(PI * phase), 0.0), 1.42)
		sun_azimuth = lerpf(-180.0, 0.0, pow(phase, 1.75))
	else:
		var phase := fposmod(h - 20.5, 24.0) / 8.25
		sun_elevation = -25.0 * sin(PI * phase)
		sun_azimuth = 180.0 * phase
	var elevation := deg_to_rad(sun_elevation)
	var azimuth := deg_to_rad(sun_azimuth)
	var direction := Vector3(cos(azimuth) * cos(elevation), sin(elevation), sin(azimuth) * cos(elevation))
	sun.basis = Basis.looking_at(-direction, Vector3.UP)
	var daylight := smoothstep(-3.0, 5.0, sun_elevation)
	stars.fade(1.0-smoothstep(-10.0,-3.0,sun_elevation))
	var warmth := 1.0 - smoothstep(10.0, 40.0, sun_elevation)
	# Wave C: golden hour proper (the sun 9-15 degrees up, on the bar) gets a deeper
	# amber sun and clear air; dusk (the sun's last few degrees, the supper camp in
	# the canyon's shade) keeps the Stage 1 light and its cool blue haze.
	golden = warmth * smoothstep(DUSK_ELEVATION.x, DUSK_ELEVATION.y, sun_elevation)
	moon.basis = Basis.looking_at(-Vector3(1,.28,-.15).normalized(),Vector3.UP)
	# Wave C: moonlight a little less saturated, so night is blue-grey, not all blue.
	moon.light_color = Color(.75,.83,1.0)
	moon.light_energy = .26*(1.0-daylight)
	moon.light_angular_distance = .5
	# A dim, broad source: full specular put a bright 'waterfall' sheen on the steep
	# far-wall rock bands that face the low moon downstream.
	moon.light_specular = .05
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 100.0
	moon.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	# Wave C: the low sun is a deeper amber, so golden hour reads warm through AgX
	# instead of cream.
	sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.82, 0.62), warmth).lerp(Color(1.0, 0.76, 0.50), golden)
	sun.light_energy = (lerpf(1.45, 1.9, warmth) + (GOLDEN_SUN_ENERGY - 1.9) * golden) * daylight
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.shadow_bias = .12
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 200.0
	# Wave C perf: hard cascade seams are invisible at this map resolution and range;
	# blending them cost ~0.18 ms a frame (artifacts/perf_probe/attribution.md).
	sun.directional_shadow_blend_splits = false
	sun.light_volumetric_fog_energy = 1.0
	sky_material.rayleigh_coefficient = 2.2
	sky_material.rayleigh_color = Color(0.25, 0.42, 0.70)
	sky_material.mie_coefficient = lerpf(0.003, 0.004, warmth)
	# Warm forward glow around a low sun; neutral by day.
	sky_material.mie_color = Color(0.96, 0.98, 1.0).lerp(Color(1.0, 0.86, 0.68), golden)
	sky_material.mie_eccentricity = 0.8
	sky_material.turbidity = lerpf(2.0, 3.0, warmth)
	sky_material.energy_multiplier = lerpf(0.18, 2.5, daylight)
	sky_material.ground_color = Color(0.55, 0.58, 0.60)
	sky_material.sun_disk_scale = 1.0
	environment.background_mode = Environment.BG_SKY
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = lerpf(0.6, 0.8, warmth)
	environment.ambient_light_sky_contribution = 1.0
	environment.tonemap_mode = Environment.TONE_MAPPER_AGX
	environment.tonemap_white = 1.0
	environment.tonemap_exposure = 1.0
	camera_attributes.auto_exposure_enabled = false
	# Stage 1 darkened the ground albedo into range; low sun and night get more
	# exposure so golden hour and moonlight hold their baseline brightness.
	camera_attributes.exposure_multiplier = lerpf(1.0, 1.6, warmth) * (1.0 + .3 * (1.0 - daylight))
	camera_attributes.dof_blur_far_enabled = false
	camera_attributes.dof_blur_near_enabled = false
	_configure_indirect_light()
	_configure_fog(warmth)
	if daylight < 1.0:
		var night := 1.0-daylight
		# Wave C: blue-grey rather than saturated blue.
		environment.fog_light_color = environment.fog_light_color.lerp(Color(.065,.088,.14),night)
		environment.fog_light_energy = lerpf(.85,.2,night)
		environment.volumetric_fog_density = lerpf(environment.volumetric_fog_density,NIGHT_FOG,night)
		environment.volumetric_fog_albedo = environment.volumetric_fog_albedo.lerp(Color(.58,.66,.80),night)
		mist.material.density = lerpf(mist.material.density,NIGHT_MIST,night)
		mist.material.albedo = mist.material.albedo.lerp(Color(.32,.39,.54),night)
		# Moonlit haze veils the night sky as it veils the far ridges.
		environment.fog_sky_affect = lerpf(environment.fog_sky_affect,.6,night)
	var weather := "clear"
	var day := 0
	var game_seed := 1848
	if not Engine.is_editor_hint():
		var state := get_node_or_null("/root/GameState")
		if state:
			weather = state.weather()
			day = state.day
			game_seed = state.seed
	_configure_grade()
	_configure_weather(weather, h)
	# Clear most of the air above the channel, whatever its density now.
	rim_air.material.density = -RIM_CLEARING * environment.volumetric_fog_density
	_configure_reach_reflection()
	clouds.configure({"hour": h, "day": day, "seed": game_seed, "weather": weather, "overcast": overcast,
		"sun_direction": direction, "sun_elevation": sun_elevation, "sun_color": sun.light_color,
		"sun_energy": sun.light_energy, "moon_direction": Vector3(1, .28, -.15).normalized(),
		"moon_color": moon.light_color, "moon_energy": moon.light_energy})
	time_changed.emit(h,daylight)

## Wave C: what the river reflects beyond its reflection probe (shaders/water.gdshader):
## canyon walls lit like the hour, and above them the hazy sky.
func _configure_reach_reflection() -> void:
	var water := get_node_or_null("../Greybox/River/WaterSurface") as GeometryInstance3D
	if water == null or not water.material_override is ShaderMaterial: return
	var lit := clampf(sun.light_energy / 1.45, 0.0, 1.4) + 0.5 * moon.light_energy
	var sky := environment.fog_light_color * environment.fog_light_energy
	sky = sky.lerp(sun.light_color * environment.fog_light_energy, 0.35 * (1.0 - smoothstep(10.0, 30.0, sun_elevation)) * float(sun_elevation > 0.0))
	water.material_override.set_shader_parameter("reach_sky", sky)
	water.material_override.set_shader_parameter("reach_wall", Color(0.25, 0.29, 0.25) * clampf(lit, 0.0, 1.4))

## Restrained grade over AgX: a little contrast and colour under a high sun, none
## at golden hour or night, so the low-sun look and the fire-lit camp are untouched.
## Saturation stays well within +10 %.
func _configure_grade() -> void:
	var high_sun := smoothstep(4.0, 25.0, sun_elevation)
	environment.adjustment_enabled = true
	environment.adjustment_brightness = 1.0
	environment.adjustment_contrast = lerpf(1.0, 1.05, high_sun)
	environment.adjustment_saturation = lerpf(1.0, 1.03, high_sun)

## Rain's overcast becomes a low grey deck: the physical sky greys (it still lights
## the ambient and the reflections), the sun all but goes, the air thickens. On hot
## days rain.gd's 0.35 is heat haze instead; frost keeps a clear, cold sky.
func _configure_weather(weather: String, h: float) -> void:
	if weather == "hot":
		var haze := clampf(overcast / .35, 0, 1)
		sun.light_energy *= lerpf(1.0, .85, haze)
		sky_material.turbidity = lerpf(sky_material.turbidity, 5.0, haze)
		sky_material.mie_coefficient = lerpf(sky_material.mie_coefficient, .007, haze)
		environment.volumetric_fog_density *= 1.0 + .5 * haze
		return
	if weather == "frost":
		mist.material.density *= lerpf(3.0, 1.0, smoothstep(9, 10, h))
		sky_material.turbidity = minf(sky_material.turbidity, 1.7)
		sky_material.rayleigh_coefficient = 2.6
	var deck := smoothstep(0.0, .8, overcast)
	if deck <= 0.0: return
	var sun_left := lerpf(1.0, .12, deck)
	sun.light_energy *= sun_left
	# The sky's radiance scales with the sun's energy to about the 0.6 power;
	# hold an overcast sky near half its clear brightness, grey rather than blue.
	sky_material.energy_multiplier *= lerpf(1.0, pow(1.0 / sun_left, .62) * .55, deck)
	sky_material.rayleigh_coefficient = lerpf(sky_material.rayleigh_coefficient, .45, deck)
	sky_material.mie_coefficient = lerpf(sky_material.mie_coefficient, .03, deck)
	sky_material.mie_eccentricity = lerpf(sky_material.mie_eccentricity, .35, deck)
	sky_material.mie_color = Color(.96, .97, 1.0)
	sky_material.turbidity = lerpf(sky_material.turbidity, 9.0, deck)
	var grey := Color(.6, .62, .65)
	environment.ambient_light_color = grey
	environment.ambient_light_sky_contribution = lerpf(1.0, .4, deck)
	environment.ambient_light_energy *= lerpf(1.0, 1.35, deck)
	environment.volumetric_fog_density *= 1.0 + 2.5 * deck
	environment.volumetric_fog_albedo = environment.volumetric_fog_albedo.lerp(grey, deck)
	environment.fog_light_color = environment.fog_light_color.lerp(grey * .9, deck)
	environment.fog_aerial_perspective = lerpf(environment.fog_aerial_perspective, .15, deck)
	environment.adjustment_saturation = lerpf(environment.adjustment_saturation, .92, deck)
	mist.material.albedo = mist.material.albedo.lerp(grey, deck)

func _configure_indirect_light() -> void:
	environment.sdfgi_enabled = true
	environment.sdfgi_cascades = 4
	environment.sdfgi_cascade0_distance = 20.0
	environment.sdfgi_use_occlusion = true
	environment.sdfgi_bounce_feedback = 0.5
	environment.sdfgi_energy = 1.0
	environment.sdfgi_y_scale = Environment.SDFGI_Y_SCALE_75_PERCENT
	environment.ssao_enabled = true
	environment.ssao_radius = 2.0
	environment.ssao_intensity = 1.2
	environment.ssil_enabled = true
	environment.ssil_intensity = 0.7
	environment.ssr_enabled = false
	environment.glow_enabled = true
	environment.glow_hdr_threshold = 2.5
	environment.glow_strength = 0.7
	environment.glow_intensity = 0.25
	environment.glow_bloom = 0.0

## Wave C: air thin enough that the bar, the near walls and the middle distance
## (50-200 m) keep their contrast and colour; depth haze builds only toward the far
## ridges (about 10 % at 300 m, a third at 450 m, half at 600 m by day).
func _configure_fog(warmth: float) -> void:
	var tint := Color(0.58, 0.68, 0.82).lerp(Color(0.52, 0.68, 0.90), warmth)
	# Golden hour has clear air lit amber; as the sun sinks toward the rim the canyon
	# fills with the cool blue dusk haze of Stage 1 (the supper camp).
	var dusk := warmth - golden
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = lerpf(lerpf(DAY_FOG, GOLDEN_FOG, warmth), DUSK_FOG, dusk)
	# Haze takes its colour from the light, so it scatters near-neutrally; the former
	# dense blue veil lit by the amber sun turned golden hour a milky cream. At dusk
	# the sky's blue fills the shade (ambient inject) as the sun leaves the floor.
	environment.volumetric_fog_albedo = Color(0.78, 0.84, 0.92).lerp(Color(0.95, 0.93, 0.90), warmth).lerp(Color(0.52, 0.68, 0.90), dusk)
	environment.volumetric_fog_emission = Color.BLACK
	# Godot 4.7 calls volumetric sun scattering 'anisotropy'. A low sun gets a
	# tighter forward lobe: a glow around the sun rather than a veil over the view.
	environment.volumetric_fog_anisotropy = lerpf(0.4, 0.6, golden)
	environment.volumetric_fog_length = 96.0
	# The sky behind the far ridges takes the same veil as they do; at 0.04 the hazed
	# ridge tops outshone the sky at dusk and night and their trees read as dark shapes
	# hanging from the top of the frame. By day the clear rim air makes this ~0.
	environment.volumetric_fog_sky_affect = 1.0
	environment.volumetric_fog_ambient_inject = 0.3
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	# Haze down the canyon from just beyond the claim (smoothstep ramp, so the first
	# 150 m beyond the begin distance stay nearly clear).
	environment.fog_depth_begin = 120.0
	environment.fog_depth_end = lerpf(1000.0, 1100.0, warmth)
	environment.fog_depth_curve = 1.0
	# In depth mode density is maximum opacity, not extinction per meter.
	environment.fog_density = 1.0
	environment.fog_light_color = tint
	environment.fog_light_energy = 0.85
	environment.fog_sun_scatter = lerpf(0.3, 0.4, warmth)
	environment.fog_aerial_perspective = lerpf(0.6, 1.0, warmth)
	# Little depth haze on the open sky by day, so cumulus above the ridges stand
	# against blue; the low sun keeps a hazier horizon.
	environment.fog_sky_affect = lerpf(0.05, 0.15, warmth)
	mist.material.density = lerpf(lerpf(DAY_MIST, GOLDEN_MIST, warmth), DUSK_MIST, dusk)
	mist.material.albedo = tint
	mist.material.emission = Color.BLACK
	mist.material.height_falloff = 0.3
	mist.material.edge_fade = 0.5
	# Most global fog is subtracted above 10 m (density set in _update_light), with a
	# soft transition. Dense air stays in the channel; the higher cliff bands retain
	# contrast against the sky.
	rim_air.material.albedo = tint
	rim_air.material.emission = Color.BLACK
	rim_air.material.edge_fade = 0.02
