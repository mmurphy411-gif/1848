shader_type spatial;
// Stage 1 cloud layer over the PhysicalSkyMaterial. A unit sphere centred on the
// camera is pushed to the far plane, so any geometry in range hides it and only
// open sky shows clouds. Lit by uniforms from scripts/sky_clouds.gd.
// Wave C: the layer is a slab of heaped cumulus rather than a flat sheet. A short
// march through it gives flat grey bases and rounded, sunlit tops: overhead it reads
// as before, and in the thin band of sky above the canyon ridges the clouds stand up
// as heaps instead of flattening into streaks.
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
uniform float horizon_fade = 0.04;
// Depth of the heaps as a fraction of the base height, and how dense they are.
uniform float thickness = 0.6;
uniform float density = 7.0;
// Light from below at a low sun: warm cloud bases at golden hour.
uniform float underlight = 0.0;
varying vec3 direction;

const int STEPS = 10;

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
	// A layer seen in perspective, eased just above the horizon, and anchored to the
	// world so the ground shadows line up with it. Height s (0 base .. 1 top of the
	// slab) moves the sample outward along the view ray.
	vec2 slope = dir.xz / (up + 0.02) * layer_scale;
	vec2 origin = cloud_layer_uv(CAMERA_POSITION_WORLD.xz);
	float threshold = cloud_threshold();
	// Near the horizon the slab spans many clouds; cap the march at about one
	// cloud's width so the heaps there do not alias into speckle.
	float depth = min(thickness, 0.22 / max(length(slope), 1e-4));
	// Path length per step, in base heights; long near the horizon.
	float dl = depth / (float(STEPS) * max(up, 0.06));
	// Per-pixel step offset, varied every frame so temporal AA smooths the steps.
	float jitter = fract(52.9829189 * fract(dot(FRAGCOORD.xy, vec2(0.06711056, 0.00583715))) + TIME * 37.08204);
	vec3 sun = light_color * light_energy;
	vec3 ambient = ambient_color * ambient_energy;
	float sun_height = clamp(light_direction.y * 2.0 + 0.25, 0.0, 1.0);
	vec2 toward = normalize(light_direction.xz + vec2(1e-4)) * 0.018;
	float transmittance = 1.0;
	vec3 color = vec3(0.0);
	float first = -1.0;
	vec2 first_p = slope + origin;
	for (int i = 0; i < STEPS; i++) {
		float s = (float(i) + jitter) / float(STEPS);
		vec2 p = slope * (1.0 + depth * s) + origin;
		vec3 parts = cloud_parts(p);
		float field = parts.x * 0.6 + parts.y * 0.24 + parts.z * 0.16;
		// A heap stands tallest over the core of its cluster and slopes to its rim;
		// the finer octaves break its top into a cauliflower outline. Small wisps
		// that only just clear the threshold stay low.
		float column = clamp((field - threshold) / 0.2, 0.0, 1.0);
		float core = clamp((parts.x * 0.6 + 0.2 - threshold) / 0.16, 0.0, 1.0);
		float top = clamp(core * column * 1.3 + (parts.z - 0.5) * 0.25 + (parts.y - 0.5) * 0.3, 0.0, 1.0);
		float edge = smoothstep(threshold, threshold + softness * 0.6, field);
		float present = edge * (1.0 - smoothstep(top - 0.07, top + 0.02, s));
		if (present <= 0.001) continue;
		if (first < 0.0) { first = s; first_p = p; }
		float a = 1.0 - exp(-density * present * dl);
		// Grey, flat bases (darker under the thick cores); bright, rounded tops.
		float rise = clamp(s / max(top, 0.08), 0.0, 1.0);
		vec3 base = (ambient * 0.85 + sun * 0.16) * mix(1.0, 0.72, column) + sun * underlight;
		vec3 crown = ambient * 0.45 + sun * 1.0;
		vec3 c = mix(base, crown, smoothstep(0.0, 0.9, rise) * mix(0.55, 1.0, sun_height));
		color += transmittance * a * c;
		transmittance *= 1.0 - a;
		if (transmittance < 0.02) break;
	}
	float alpha = 1.0 - transmittance;
	color /= max(alpha, 1e-4);
	if (first >= 0.0) {
		// The heap's sunward flank is lit, its far flank in its own shade.
		float thick = clamp((cloud_field(first_p) - threshold) / 0.22, 0.0, 1.0);
		float thick_light = clamp((cloud_field(first_p + toward) - threshold) / 0.22, 0.0, 1.0);
		float sunward = clamp(0.55 + (thick - thick_light) * 2.4, 0.0, 1.0);
		color *= mix(0.78, 1.12, sunward);
		float cos_light = dot(dir, light_direction);
		float silver = pow(max(cos_light, 0.0), 12.0) * (1.0 - 0.7 * thick);
		color += sun * silver * 1.6;
	}
	float cos_light = dot(dir, light_direction);
	// Overcast: an even grey deck with soft mottling in place of lit cumulus.
	vec2 p0 = slope + origin;
	float mottle = texture(cloud_shape, p0 * 2.2 + shape_offset).r;
	vec3 deck = overcast_color * ambient_energy * (0.78 + 0.44 * mottle) + sun * 0.06 * pow(max(cos_light, 0.0), 12.0);
	color = mix(color, deck, overcast);
	alpha = mix(alpha, smoothstep(threshold, threshold + softness, cloud_field(p0)), overcast);
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
		float silver = pow(max(cos_light, 0.0), 12.0);
		vec3 haze_color = ambient * 1.05 + sun * (0.5 + silver);
		float out_alpha = alpha + haze_alpha * (1.0 - alpha);
		color = mix(haze_color, color, alpha / max(out_alpha, 0.001));
		alpha = out_alpha;
	}
	alpha *= smoothstep(-0.02, horizon_fade, dir.y);
	ALBEDO = color;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
