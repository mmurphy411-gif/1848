shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_large : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_small : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
uniform vec3 absorption = vec3(0.35, 0.08, 0.20);
uniform vec3 scatter : source_color = vec3(0.02, 0.10, 0.09);
uniform float foam_distance : hint_range(0.1, 1.0) = 0.6;
uniform float foam_texture_scale = 0.8;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.35;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.03;
uniform float flow_speed_multiplier = 1.0;
uniform float refraction_strength : hint_range(0.0, 0.04) = 0.015;
varying vec3 world_position;
varying vec4 flow_data;

vec3 view_position(vec2 uv, float depth, mat4 inverse_projection) {
	// Forward+ uses reverse Z, with NDC depth already in [0, 1].
	vec4 p = inverse_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return p.xyz / p.w;
}

void vertex() {
	flow_data = COLOR;
	vec2 flow = normalize(COLOR.rg * 2.0 - 1.0);
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float along = dot(world_xz, flow);
	float t = TIME * flow_speed_multiplier;
	VERTEX.y += wave_amplitude * COLOR.b * (sin(along * 0.7 - t * 0.5) + 0.5 * sin(along * 1.1 - t * 0.8) + 0.3 * sin(along * 0.43 - t * 0.3)) / 1.8;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 flow = normalize(flow_data.rg * 2.0 - 1.0);
	float t = TIME * flow_speed_multiplier * flow_data.b;
	vec2 n1 = texture(normal_large, (world_position.xz - flow * t * 0.35) / 6.0).xy * 2.0 - 1.0;
	vec2 n2 = texture(normal_small, (world_position.xz - flow * t * 0.55) / 1.7).xy * 2.0 - 1.0;
	vec2 ripple = (n1 + n2 * 0.6) * normal_strength;
	vec3 normal_world = normalize(vec3(ripple.x, 1.0, ripple.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);
	vec3 bed_view = view_position(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	vec3 bed_world = (INV_VIEW_MATRIX * vec4(bed_view, 1.0)).xyz;
	float vertical_depth = max(world_position.y - bed_world.y, 0.0);
	vec2 perturbation = (VIEW_MATRIX * vec4(normal_world - vec3(0.0, 1.0, 0.0), 0.0)).xy;
	vec2 offset = clamp(perturbation * refraction_strength * min(vertical_depth, 1.0), vec2(-0.02), vec2(0.02));
	vec2 refracted_uv = clamp(SCREEN_UV + offset, vec2(0.001), vec2(0.999));
	vec3 refracted_view = view_position(refracted_uv, texture(depth_texture, refracted_uv).r, INV_PROJECTION_MATRIX);
	vec3 refracted_world = (INV_VIEW_MATRIX * vec4(refracted_view, 1.0)).xyz;
	// Reject foreground rocks and the walker above the surface, not just near depth.
	if (refracted_world.y > world_position.y || refracted_view.z > VERTEX.z) {
		refracted_uv = SCREEN_UV;
		refracted_view = bed_view;
	}
	float ray_distance = max(length(refracted_view) - length(VERTEX), 0.0);
	vec3 transmission = exp(-absorption * min(ray_distance, 40.0));
	vec3 bed = texture(screen_texture, refracted_uv).rgb;
	vec3 through_water = bed * transmission + scatter * (vec3(1.0) - transmission);
	float breakup = texture(foam_noise, (world_position.xz - flow * t * 0.35) * foam_texture_scale).r;
	float contact = 1.0 - smoothstep(0.15, foam_distance, vertical_depth);
	vec3 bed_normal = normalize(cross(dFdx(bed_world), dFdy(bed_world)));
	float obstacle = 1.0 - smoothstep(0.3, 0.8, abs(bed_normal.y));
	float broken_foam = smoothstep(0.55, 0.8, breakup);
	// Rock faces and legs hold a denser collar; gently sloped shallows stay clear.
	float foam = contact * mix(broken_foam, 0.9 + 0.1 * broken_foam, obstacle);
	float fresnel = 0.064 + 0.936 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	ALBEDO = vec3(0.85, 0.90, 0.88) * foam;
	// The screen sample is already lit. Emission here transports bed light;
	// foam uses ordinary diffuse lighting and has no emissive contribution.
	EMISSION = through_water * (1.0 - fresnel) * (1.0 - foam);
	ROUGHNESS = mix(0.06, 0.85, foam);
	METALLIC = 0.0;
	SPECULAR = mix(0.8, 0.25, foam);
	ALPHA = smoothstep(0.0, 0.05, min(vertical_depth, flow_data.a * 5.0));
}
