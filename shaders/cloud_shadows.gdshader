shader_type spatial;
// Stage 1 cloud shadows: one full-screen multiply over the opaque scene. Each
// pixel's world point is traced toward the sun to the cloud layer, so shadows
// drift with the clouds the dome draws. Strength is set by scripts/sky_clouds.gd
// (zero at night, under overcast, and when a capture swaps in its own environment).
render_mode unshaded, blend_mul, depth_draw_never, depth_test_disabled, cull_disabled, fog_disabled, shadows_disabled;

#include "res://shaders/clouds.gdshaderinc"
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
// Toward the sun.
uniform vec3 light_direction = vec3(0.0, 1.0, 0.0);
uniform float strength : hint_range(0.0, 1.0) = 0.0;
// Aerial perspective: distant shadows fade into the haze.
uniform vec2 fade_distance = vec2(180.0, 650.0);

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

void fragment() {
	float depth = texture(depth_texture, SCREEN_UV).r;
	vec3 shade = vec3(1.0);
	// Reverse Z clears to 0: open sky is never shadowed.
	if (depth > 0.0 && strength > 0.0) {
		vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
		view.xyz /= view.w;
		vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
		vec3 sun = normalize(light_direction);
		vec2 at_layer = world.xz + sun.xz / max(sun.y, 0.08) * (layer_height - world.y);
		float field = cloud_field_soft(cloud_layer_uv(at_layer));
		float threshold = cloud_threshold();
		// Only under the opaque body of a cloud, with a soft penumbra.
		float shadow = smoothstep(threshold + 0.02, threshold + 0.09, field);
		shadow *= strength * (1.0 - smoothstep(fade_distance.x, fade_distance.y, length(view.xyz)));
		// Shade keeps the sky's blue: warm sun is what the cloud takes away.
		shade = vec3(1.0) - shadow * vec3(0.9, 0.85, 0.72);
	}
	ALBEDO = shade;
}
