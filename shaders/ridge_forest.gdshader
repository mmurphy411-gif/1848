shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Forested ridges of the bent canyon reach (scripts/canyon.gd, canyon_dressing.gd), seen
// from 150-600 m. On the terrain: clumped conifer crowns with self-shadowed relief, gaps
// of red-brown soil, grey rock where the slope is too steep to hold trees. On the
// treeline spires (COLOR.g = 1): needle-dark tiers, lighter at the tips.
uniform vec3 pine_crowns : source_color = vec3(0.16, 0.21, 0.10);
uniform vec3 fir_crowns : source_color = vec3(0.11, 0.17, 0.13);
uniform vec3 soil : source_color = vec3(0.36, 0.29, 0.22);
uniform vec3 rock : source_color = vec3(0.38, 0.40, 0.42);
uniform float crown_size = 6.5;
varying vec3 world;
varying vec3 geom_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
float crowns(vec2 p) { return noise(p / crown_size) * 0.65 + noise(p / (crown_size * 0.41) + 9.3) * 0.35; }

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	geom_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	ROUGHNESS = 0.94;
	if (COLOR.g > 0.5) {
		vec3 needles = mix(pine_crowns, fir_crowns, COLOR.r);
		ALBEDO = needles * (0.55 + 0.6 * COLOR.b) * (0.85 + 0.3 * noise(world.xz * 0.7 + world.y * 0.9));
	} else {
		vec2 p = world.xz;
		float c = crowns(p);
		float stands = noise(p / 55.0 + 3.1) * 0.7 + noise(p / 17.0 + 1.7) * 0.3;
		float slope_ok = smoothstep(0.45, 0.65, geom_normal.y);
		float cover = smoothstep(0.25, 0.45, c * 0.45 + stands * 0.6) * slope_ok;
		vec3 trees = mix(pine_crowns, fir_crowns, smoothstep(0.35, 0.65, noise(p / 40.0 + 5.0)));
		trees *= 0.6 + 0.55 * c;
		// Steep faces: slate in dipping strata with darker joints.
		float strata = noise(vec2((world.x + world.z) * 0.04, world.y * 0.35)) * 0.6 + noise(world.xz * 0.11 + world.y * 0.2) * 0.4;
		vec3 ground = mix(rock * (0.7 + 0.45 * strata), soil, slope_ok * smoothstep(0.3, 0.7, noise(p / 23.0)));
		ALBEDO = mix(ground, trees, cover);
		// Crown relief: the canopy height field tilts the normal, so the sun and shadow
		// sides of tree clumps read at distance.
		float e = 0.6;
		vec2 grad = vec2(crowns(p + vec2(e, 0.0)) - c, crowns(p + vec2(0.0, e)) - c) / e;
		vec3 n = normalize(geom_normal - vec3(grad.x, 0.0, grad.y) * 7.0 * cover);
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
	}
}
