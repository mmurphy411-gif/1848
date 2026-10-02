shader_type spatial;
// Stage 1 cloud layer over the PhysicalSkyMaterial. A unit sphere centred on the
// camera is pushed to the far plane, so any geometry in range hides it and only
// open sky shows clouds. Lit by uniforms from scripts/sky_clouds.gd.
render_mode unshaded, blend_mix, depth_draw_never, cull_front, fog_disabled, shadows_disabled;

#include "res://shaders/clouds.gdshaderinc"
// Toward the light that tints the clouds: the sun by day, the moon by night.
uniform vec3 light_direction = vec3(0.0, 1.0, 0.0);
uniform vec3 light_color : source_color = vec3(1.0);
uniform float light_energy = 1.0;
uniform vec3 ambient_color : source_color = vec3(0.45, 0.52, 0.62);
uniform float ambient_energy = 1.0;
uniform float opacity : hint_range(0.0, 1.0) = 0.95;
// Overcast: how far the deck flattens to an even grey.
uniform float overcast : hint_range(0.0, 1.0) = 0.0;
uniform vec3 overcast_color : source_color = vec3(0.55, 0.57, 0.6);
// High cirrus and milky haze (hot days).
uniform float haze : hint_range(0.0, 1.0) = 0.0;
uniform vec2 haze_offset = vec2(0.0);
uniform float horizon_fade = 0.07;
varying vec3 direction;

void vertex() {
	direction = VERTEX;
	vec3 world = CAMERA_POSITION_WORLD + VERTEX * 50.0;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	// Reverse Z: just in front of the far plane, behind everything in range.
	POSITION.z = POSITION.w * 1e-7;
}

void fragment() {
	vec3 dir = normalize(direction);
	if (dir.y < -0.03) discard;
	float up = max(dir.y, 0.0);
	// A flat layer seen in perspective, eased just above the horizon, and
	// anchored to the world so the ground shadows line up with it.
	vec2 p = dir.xz / (up + 0.035) * layer_scale + cloud_layer_uv(CAMERA_POSITION_WORLD.xz);
	float threshold = cloud_threshold();
	float field = cloud_field(p);
	float alpha = smoothstep(threshold, threshold + softness, field);
	float thick = clamp((field - threshold) / 0.22, 0.0, 1.0);
	// Thickness a step toward the light: the near side of a heap is the lit side.
	vec2 toward = normalize(light_direction.xz + vec2(1e-4)) * 0.018;
	float thick_light = clamp((cloud_field(p + toward) - threshold) / 0.22, 0.0, 1.0);
	float sunward = clamp(0.55 + (thick - thick_light) * 2.4, 0.0, 1.0);
	float sun_height = clamp(light_direction.y * 2.0 + 0.25, 0.0, 1.0);
	// Overhead we see grey bases with bright rims; toward the horizon, lit sides.
	float side = mix(0.25, 0.9, smoothstep(0.75, 0.08, up));
	float bright = clamp((side * (1.0 - 0.55 * thick) + 0.6 * sunward * thick) * mix(0.55, 1.0, sun_height), 0.0, 1.0);
	float cos_light = dot(dir, light_direction);
	float silver = pow(max(cos_light, 0.0), 12.0) * (1.0 - 0.7 * thick);
	vec3 sun = light_color * light_energy;
	vec3 ambient = ambient_color * ambient_energy;
	vec3 base = ambient * 0.78 + sun * 0.08;
	vec3 top = ambient * 0.55 + sun * 0.95;
	vec3 color = mix(base, top, bright) + sun * silver * 1.6;
	// Overcast: an even grey deck with soft mottling in place of lit cumulus.
	float mottle = texture(cloud_shape, p * 2.2 + shape_offset).r;
	vec3 deck = overcast_color * ambient_energy * (0.78 + 0.44 * mottle) + sun * 0.06 * silver;
	color = mix(color, deck, overcast);
	// Thin toward the sun so its disk and glow (golden hour) still show through.
	alpha *= opacity * (1.0 - 0.7 * smoothstep(0.965, 0.9995, cos_light));
	// High haze: thin streaks and a milky veil toward the horizon.
	if (haze > 0.001) {
		// Fibrous, warped wisps in patches rather than ruled stripes.
		vec2 hp = dir.xz / (up + 0.06) * 0.045 + haze_offset;
		float warp = texture(cloud_shape, hp * 0.9 + vec2(0.41, 0.17)).r;
		float streak = texture(cloud_shape, (hp + warp * 0.22) * vec2(1.0, 2.4)).r;
		float patches = smoothstep(0.3, 0.65, texture(cloud_shape, hp * 0.35).r);
		float cirrus = smoothstep(0.5, 0.8, streak) * patches * haze * 0.6;
		float veil = haze * (0.12 + 0.26 * (1.0 - smoothstep(0.0, 0.5, up)));
		float haze_alpha = clamp(cirrus + veil, 0.0, 0.8);
		vec3 haze_color = ambient * 1.05 + sun * (0.5 + silver);
		float out_alpha = alpha + haze_alpha * (1.0 - alpha);
		color = mix(haze_color, color, alpha / max(out_alpha, 0.001));
		alpha = out_alpha;
	}
	alpha *= smoothstep(-0.02, horizon_fade, dir.y);
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
