@tool
extends Node3D
## A deterministic lighting rig. Milestone 7 will animate hour; there is no clock here.

@export_range(0.0, 24.0) var hour := 19.25:
	set(value):
		hour = value
		if is_node_ready():
			apply(hour)
@export var camera_attributes: CameraAttributesPractical
@onready var sun: DirectionalLight3D = $Sun
@onready var world: WorldEnvironment = $WorldEnvironment
@onready var mist: FogVolume = $RiverMist
@onready var rim_air: FogVolume = $ClearRimAir
var environment: Environment
var sky_material: PhysicalSkyMaterial
var sun_elevation := 0.0
var sun_azimuth := 0.0

func _ready() -> void:
	environment = Environment.new()
	sky_material = PhysicalSkyMaterial.new()
	environment.sky = Sky.new()
	environment.sky.sky_material = sky_material
	world.environment = environment
	mist.material = FogMaterial.new()
	rim_air.material = FogMaterial.new()
	apply(hour)

func apply(time: float) -> void:
	var h := fposmod(time, 24.0)
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
	var warmth := 1.0 - smoothstep(10.0, 40.0, sun_elevation)
	sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.82, 0.62), warmth)
	sun.light_energy = lerpf(1.45, 1.9, warmth) * daylight
	sun.light_angular_distance = 0.6
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 200.0
	sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 1.0
	sky_material.rayleigh_coefficient = 2.2
	sky_material.rayleigh_color = Color(0.25, 0.42, 0.70)
	sky_material.mie_coefficient = lerpf(0.003, 0.004, warmth)
	sky_material.mie_color = Color(0.96, 0.98, 1.0)
	sky_material.mie_eccentricity = 0.8
	sky_material.turbidity = lerpf(2.0, 3.0, warmth)
	sky_material.energy_multiplier = lerpf(0.03, 2.5, daylight)
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
	camera_attributes.exposure_multiplier = lerpf(1.0, 1.3, warmth)
	camera_attributes.dof_blur_far_enabled = false
	camera_attributes.dof_blur_near_enabled = false
	_configure_indirect_light()
	_configure_fog(warmth)

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

func _configure_fog(warmth: float) -> void:
	var tint := Color(0.72, 0.80, 0.90).lerp(Color(0.86, 0.83, 0.77), warmth)
	environment.volumetric_fog_enabled = true
	environment.volumetric_fog_density = 0.01
	environment.volumetric_fog_albedo = tint
	environment.volumetric_fog_emission = Color.BLACK
	# Godot 4.7 calls volumetric sun scattering 'anisotropy'.
	environment.volumetric_fog_anisotropy = 0.4
	environment.volumetric_fog_length = 96.0
	environment.volumetric_fog_sky_affect = 0.04
	environment.volumetric_fog_ambient_inject = 0.3
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_depth_begin = 75.0
	environment.fog_depth_end = 450.0
	environment.fog_depth_curve = 1.4
	# In depth mode density is maximum opacity, not extinction per meter.
	environment.fog_density = 1.0
	environment.fog_light_color = tint
	environment.fog_light_energy = 0.85
	environment.fog_sun_scatter = 0.4
	environment.fog_aerial_perspective = 1.0
	environment.fog_sky_affect = 0.15
	mist.material.density = lerpf(0.003, 0.006, warmth)
	mist.material.albedo = tint
	mist.material.emission = Color.BLACK
	mist.material.height_falloff = 0.3
	mist.material.edge_fade = 0.5
	# Subtract most global fog above 10 m, with a soft transition. Dense air
	# stays in the channel; the higher cliff bands retain contrast against the sky.
	rim_air.material.density = -0.009
	rim_air.material.albedo = tint
	rim_air.material.emission = Color.BLACK
	rim_air.material.edge_fade = 0.02
