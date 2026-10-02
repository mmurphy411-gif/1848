shader_type spatial;
// Normalised CC0 rock scans (bar boulders, margin rocks, cobbles, clutter): the baked
// maps from blender/normalize_asset.py, a per-instance tint (instance uniform for single
// rocks, MultiMesh COLOR rgb and lichen scale in alpha), a wet band at the river matching the
// terrain's, and lichen on up- and north-facing (shaded) surfaces. +Z is north.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : filter_linear_mipmap;
uniform float water_level = 0.0;
// Splash and capillary wetting above the waterline; the terrain uses .155-.17 m.
uniform float wet_reach = 0.22;
uniform float lichen = 0.45;
uniform vec3 lichen_color : source_color = vec3(0.52, 0.54, 0.46);
// Rust staining on overhangs, scaled per material (granite is low, quartz zero).
uniform float stain = 0.0;
uniform vec3 stain_color : source_color = vec3(0.56, 0.34, 0.18);
instance uniform vec4 tint : source_color = vec4(1.0);
varying vec3 world;
varying vec3 world_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(mat3(MODEL_MATRIX) * NORMAL);
}

void fragment() {
	vec3 albedo = texture(albedo_map, UV).rgb * COLOR.rgb * tint.rgb;
	vec3 orm = texture(orm_map, UV).rgb;
	float rough = orm.g;
	float n = noise(world.xz * 1.3 + world.y * 0.7) * 0.65 + noise(world.xz * 5.3 - world.y * 2.1) * 0.35;
	// Lichen: tops and the north (shaded) side; patchy, never on the wet band.
	float facing = smoothstep(0.25, 0.85, world_normal.y + max(world_normal.z, 0.0) * 0.45);
	float patches = smoothstep(0.52, 0.72, n + facing * 0.18);
	float dry = smoothstep(wet_reach, wet_reach + 0.5, world.y - water_level);
	float l = lichen * tint.a * COLOR.a * facing * patches * dry;
	albedo = mix(albedo, lichen_color * (0.75 + 0.5 * n), l);
	rough = mix(rough, 0.95, l);
	// Iron staining runs down undersides and overhangs.
	float under = smoothstep(0.1, -0.6, world_normal.y) * smoothstep(0.35, 0.7, noise(world.xz * 0.9 + 17.0));
	albedo = mix(albedo, albedo * stain_color * 2.2, stain * under);
	// Wet band: darker and glossier up to wet_reach above the river, ragged edge.
	float wet = 1.0 - smoothstep(0.0, wet_reach, world.y - water_level - (n - 0.5) * 0.12);
	albedo *= mix(1.0, 0.55, wet);
	rough = mix(rough, 0.32, wet);
	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	AO = orm.r;
	NORMAL_MAP = texture(normal_map, UV).rgb;
}
