shader_type spatial;
// Normalised CC0 rock scans (bar boulders, margin rocks, cobbles, clutter): the baked maps
// from blender/normalize_asset.py and a per-instance tint (instance uniform for single rocks,
// MultiMesh COLOR rgb with the lichen scale in alpha). +Z is north, +X downstream.
// Granite rocks (`granite` > 0) add, in object space so it travels with the rock: crystal
// grain (biotite, feldspar, quartz; faded out before it aliases), quartz veins, iron spots
// and rust runs, and weathering (darker undersides, paler tops). Every rock gets lichen above
// the spring flood line (scoured, silt-filmed rock below it), a soaked band at the live
// river, darkening and splashed sand where it meets the ground (the bar boulders bake the
// ground height under each vertex into UV2; margin rocks pass a ground plane in
// INSTANCE_CUSTOM), and the rain's wetness (`rain_wetness`, scripts/rain.gd).
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : filter_linear_mipmap;
uniform float water_level = 0.0;
// Splash and capillary wetting above the live river; the terrain's damp margin is wider.
uniform float wet_reach = 0.32;
// Spring flood line (world height): lichen grows above it; below, the river keeps rock clean.
uniform float flood_line = 0.8;
uniform float lichen = 0.45;
uniform vec3 lichen_color : source_color = vec3(0.50, 0.52, 0.45);
// Rust staining on overhangs, scaled per material (granite is low, quartz zero).
uniform float stain = 0.0;
uniform vec3 stain_color : source_color = vec3(0.62, 0.43, 0.24);
// Granite character (0 for cobbles and wood) and the strength of its quartz veins.
uniform float granite = 0.0;
uniform float veins = 0.0;
global uniform float rain_wetness;
instance uniform vec4 tint : source_color = vec4(1.0);
varying vec3 world;
varying vec3 world_normal;
varying vec3 local;
varying float ground;
varying float seed;

float hash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + ivec2(65536));
	uint h = q.x * 0x27d4eb2du ^ q.y * 0x165667b1u;
	h ^= h >> 15u; h *= 0x2c1b3c6du; h ^= h >> 12u;
	return float(h) * (1.0 / 4294967295.0);
}
float hash3(vec3 p) {
	uvec3 q = uvec3(ivec3(floor(p)) + ivec3(65536));
	uint h = q.x * 0x27d4eb2du ^ q.y * 0x165667b1u ^ q.z * 0x9e3779b1u;
	h ^= h >> 15u; h *= 0x2c1b3c6du; h ^= h >> 12u;
	return float(h) * (1.0 / 4294967295.0);
}
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	vec3 origin = MODEL_MATRIX[3].xyz;
	local = VERTEX * length(MODEL_MATRIX[0].xyz);
	seed = hash(floor(origin.xz * 4.0) + vec2(37.0, 11.0));
	ground = UV2.y > .5 ? UV2.x : (INSTANCE_CUSTOM.a > .5 ? INSTANCE_CUSTOM.x + dot(INSTANCE_CUSTOM.yz, world.xz - origin.xz) : -1000.0);
}

void fragment() {
	vec3 albedo = texture(albedo_map, UV).rgb * COLOR.rgb * tint.rgb;
	vec3 orm = texture(orm_map, UV).rgb;
	float rough = orm.g;
	float ao = orm.r;
	float n = noise(world.xz * 1.3 + world.y * .7) * .65 + noise(world.xz * 5.3 - world.y * 2.1) * .35;
	float flood = smoothstep(flood_line - .2, flood_line + .2, world.y + (n - .5) * .35);
	if (granite > 0.0) {
		// The scans' baked moss and shadow blotches, flattened toward the mean (at full
		// contrast they read as camouflage); the grain below supplies the texture.
		float raw = max(dot(albedo, vec3(.2126, .7152, .0722)), .001);
		albedo *= mix(1.0, (.25 + (raw - .25) * .6) / raw, granite);
		// Crystal grain: two octaves of object-space cells, about 9 and 4 mm.
		vec3 q = local * 110.0;
		float fade = granite * (1.0 - smoothstep(.4, 1.0, length(fwidth(q))));
		if (fade > 0.0) {
			float g = hash3(q), g2 = hash3(q * 2.3 + 17.0);
			float grain = g < .16 ? .4 : (g > .84 ? 1.28 : .78 + .36 * g2);
			albedo *= mix(1.0, grain, fade * .55);
		}
		// Weathering: undersides dark with grime, sun-bleached tops.
		albedo *= mix(.8, 1.05, smoothstep(-.6, .6, world_normal.y));
		// Quartz veins: planes through each rock, oriented by its seed; some cells only.
		vec3 vn = normalize(vec3(hash(vec2(seed * 97.0, 3.0)) - .5, (hash(vec2(seed * 61.0, 5.0)) - .5) * .7, hash(vec2(seed * 29.0, 7.0)) - .5) + vec3(.01));
		float vd = dot(local, vn) * (.55 + .5 * seed) + (noise(local.xz * 1.6 + local.y * 1.1) - .5) * .4;
		float cell = floor(vd);
		float width = .012 + .03 * hash(vec2(cell, seed * 11.0 + 2.0));
		float vein = step(.5, hash(vec2(cell, seed * 53.0 + 1.0))) * (1.0 - smoothstep(width, width * 1.8, abs(fract(vd) - .5)));
		vein *= veins * (1.0 - smoothstep(width * .5, width * 2.0, fwidth(vd)));
		albedo = mix(albedo, vec3(.58, .57, .54) * (.85 + .3 * n), vein);
		rough = mix(rough, .5, vein);
		// Iron: rust spots where the scan's hollows are, and runs down the steep faces.
		float cavity = 1.0 - smoothstep(.08, .35, dot(albedo, vec3(.2126, .7152, .0722)));
		float spots = smoothstep(.64, .86, noise(local.xz * .9 + vec2(local.y * .7, seed * 41.0))) * (.5 + .5 * cavity);
		float steep = 1.0 - smoothstep(.35, .8, abs(world_normal.y));
		float runs = steep * smoothstep(.62, .88, noise(vec2(dot(local.xz, vec2(.8, .6)) * 4.0, local.y * .3 + seed * 9.0)));
		float rust = granite * clamp(spots * .75 + runs * .45, 0.0, 1.0) * (1.0 - vein);
		albedo = mix(albedo, albedo * stain_color * 2.1, rust);
		// Dark and pale crustose lichen dots above the flood line.
		float dots = smoothstep(.66, .8, noise(local.xz * 6.0 + vec2(local.y * 4.0, seed * 13.0))) * flood;
		albedo *= 1.0 - .4 * dots * lichen;
	}
	// Soft ceiling: pale crystals and quartz keep their texture without blowing out in sun.
	float bright = max(dot(albedo, vec3(.2126, .7152, .0722)), .001);
	albedo *= bright > .36 ? (.36 + (bright - .36) * .35) / bright : 1.0;
	// Lichen: tops and the north (shaded) side, patchy, above the flood line only.
	float facing = smoothstep(.25, .85, world_normal.y + max(world_normal.z, 0.0) * .45);
	float patches = smoothstep(.52, .72, n + facing * .18);
	float l = lichen * tint.a * COLOR.a * facing * patches * flood;
	albedo = mix(albedo, lichen_color * (.75 + .5 * n), l);
	rough = mix(rough, .95, l);
	// Iron staining runs down undersides and overhangs.
	float under = smoothstep(.1, -.6, world_normal.y) * smoothstep(.35, .7, noise(world.xz * .9 + 17.0));
	albedo = mix(albedo, albedo * stain_color * 2.2, stain * under);
	// Below the flood line: scoured clean, a faint buff silt film.
	float lum = dot(albedo, vec3(.2126, .7152, .0722));
	albedo = mix(albedo, vec3(lum) * vec3(1.1, 1.03, .9), (1.0 - flood) * .22 * granite);
	// Ground contact: shade and splashed sand at the foot of the rock.
	float above = world.y - water_level;
	float wet = 1.0 - smoothstep(0.0, wet_reach, above - (n - .5) * .16);
	if (ground > -999.0) {
		float h = world.y - ground + (n - .5) * .12;
		float contact = 1.0 - smoothstep(0.0, .55, h);
		albedo *= mix(1.0, .45, contact * contact);
		ao *= mix(1.0, .6, contact);
		albedo = mix(albedo, vec3(.27, .23, .17), (1.0 - smoothstep(.0, .25, h)) * (1.0 - wet) * .4);
	}
	// River wet band (soaked at the waterline) and rain: darker and glossier.
	float soak = 1.0 - smoothstep(-.05, .05, above);
	float rain = rain_wetness * (.5 + .5 * smoothstep(-.5, .3, world_normal.y));
	float damp = max(wet, rain * .85);
	albedo *= mix(1.0, .5, damp) * mix(1.0, .82, soak);
	rough = mix(rough, .2, max(wet, rain));
	ALBEDO = albedo;
	ROUGHNESS = clamp(rough, 0.0, 1.0);
	AO = ao;
	NORMAL_MAP = texture(normal_map, UV).rgb;
}
