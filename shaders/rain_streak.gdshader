shader_type spatial;
// Wave C rain streak, drawn for each drop by scripts/rain.gd. The quad mesh gives the
// streak's length (it trails above the drop, so roof and ground cut-offs on the drop
// still hold) and nominal width; here it is turned to slant with the wind and to face
// the lens about that slanted axis. Streaks never draw thinner than about a pixel:
// a narrower one fades instead, so distant rain thins out into a soft depth falloff
// rather than shimmering.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

uniform vec4 tint : source_color = vec4(0.9, 0.93, 0.97, 1.0);
// Peak opacity of a streak's core relative to tint alpha (the core is soft-edged).
uniform float strength = 1.7;
// Direction the drops fall (wind-slanted); the streak lies along it.
uniform vec3 fall = vec3(0.16, -1.0, 0.05);
// Fade in from the lens (streaks passing it would smear across the frame) and out
// with distance.
uniform vec2 near_fade = vec2(3.0, 7.0);
uniform vec2 far_fade = vec2(16.0, 30.0);
// Length of the trail in the quad mesh (metres).
uniform float trail_length = 0.55;
varying float fade;
varying float trail;
varying float edge;

void vertex() {
	trail = VERTEX.y / trail_length;
	edge = sign(VERTEX.x);
	fade = 0.0;
	POSITION = vec4(2.0, 2.0, 2.0, 1.0);
	vec3 drop = MODEL_MATRIX[3].xyz;
	vec3 axis = -normalize(fall);
	vec3 to_lens = CAMERA_POSITION_WORLD - drop;
	vec3 across_axis = cross(axis, to_lens);
	// Inactive drops come through with a collapsed transform: keep them off screen,
	// as any drop seen end-on (straight up or down its own trail).
	if (dot(MODEL_MATRIX[1].xyz, MODEL_MATRIX[1].xyz) > 1e-8 && dot(across_axis, across_axis) > 1e-6) {
		float distance = length(to_lens);
		vec3 side = normalize(across_axis);
		// World size of one pixel at the drop.
		float pixel = 2.0 * distance / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y);
		float width = abs(VERTEX.x) * 2.0;
		float drawn = max(width, pixel * 1.5);
		fade = pow(width / drawn, 0.3);
		fade *= smoothstep(near_fade.x, near_fade.y, distance) * (1.0 - smoothstep(far_fade.x, far_fade.y, distance));
		vec3 world = drop + side * edge * drawn * 0.5 + axis * VERTEX.y;
		POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
	}
}

void fragment() {
	// Brightest just behind the drop, tapering along the trail; soft across.
	float along = clamp(trail, 0.0, 1.0);
	float body = smoothstep(0.0, 0.15, along) * (1.0 - smoothstep(0.35, 1.0, along));
	float across = clamp(1.0 - edge * edge, 0.0, 1.0);
	ALBEDO = tint.rgb;
	ALPHA = clamp(tint.a * strength * fade * body * across, 0.0, 1.0);
}
