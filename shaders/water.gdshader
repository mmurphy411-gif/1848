shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform sampler2D normal_large : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_small : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D foam_noise : repeat_enable, filter_linear_mipmap;
// Stage 1: clear green-brown over cobble (tannin takes blue, water takes red),
// in place of the former emerald (0.35, 0.08, 0.20) / (0.02, 0.10, 0.09).
uniform vec3 absorption = vec3(0.15, 0.115, 0.26);
uniform vec3 scatter : source_color = vec3(0.03, 0.044, 0.024);
uniform float foam_distance : hint_range(0.1, 1.0) = 0.35;
uniform float foam_texture_scale = 0.8;
uniform float normal_strength : hint_range(0.0, 1.0) = 0.35;
uniform float wave_amplitude : hint_range(0.0, 0.1) = 0.03;
uniform float flow_speed_multiplier = 1.0;
uniform float refraction_strength : hint_range(0.0, 0.04) = 0.015;
// Broken water: UV.x marks riffles, UV.y obstacle wakes (baked by greybox.gd).
uniform float riffle_chop : hint_range(0.0, 1.0) = 0.55;
uniform float riffle_amplitude : hint_range(0.0, 0.2) = 0.06;
uniform vec4 shin_contacts[2];
// 2.0 wing dam: the river surface inside the crib is cut away.
uniform float dam_on = 0.0;
uniform vec2 dam_x = vec2(-14.0, 6.0);
uniform float dam_reach = 9.0;
uniform float dam_margin = 0.25;
// Project-wide rain state (0 dry .. 1 downpour), set by rain.gd; see project.godot.
global uniform float rain_wetness;
// Wave C: beyond the river reflection probe's box (x min, x max, z min, z max) the
// engine can only reflect the open sky, which the canyon walls hide from the water:
// the long reaches read as a flat milky pond. There the water reflects an
// approximate canyon instead, walls below and a strip of sky above, coloured by
// daylight.gd for the hour.
uniform vec4 probe_box = vec4(-55.0, 55.0, -37.0, 13.0);
uniform vec3 reach_wall : source_color = vec3(0.05, 0.06, 0.05);
uniform vec3 reach_sky : source_color = vec3(0.35, 0.45, 0.6);
// Elevation (sine) of the canyon rim seen in a reach's reflection.
uniform vec2 reach_rim = vec2(0.5, 0.85);
// Wave C: shallow margins show their bed even at a grazing angle (the eye adapts to
// the bright bed; ripples there are small): reflection eases off over shallow water
// seen from low down.
uniform float shallow_clarity : hint_range(0.0, 1.0) = 1.0;
uniform vec2 shallow_depth = vec2(0.4, 2.2);
varying vec3 world_position;
varying vec4 flow_data;
varying vec2 broken;
// The current's direction in the world (UV2, turned with the canyon bend).
varying vec2 world_flow;

vec3 view_position(vec2 uv, float depth, mat4 inverse_projection) {
	// Forward+ uses reverse Z, with NDC depth already in [0, 1].
	vec4 p = inverse_projection * vec4(uv * 2.0 - 1.0, depth, 1.0);
	return p.xyz / p.w;
}

void vertex() {
	flow_data = COLOR;
	broken = UV;
	vec2 flow = dot(UV2, UV2) > 0.25 ? normalize(UV2) : normalize(COLOR.rg * 2.0 - 1.0);
	world_flow = flow;
	vec2 world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
	float along = dot(world_xz, flow);
	float across = dot(world_xz, vec2(-flow.y, flow.x));
	float t = TIME * flow_speed_multiplier;
	VERTEX.y += wave_amplitude * COLOR.b * (sin(along * 0.7 - t * 0.5) + 0.5 * sin(along * 1.1 - t * 0.8) + 0.3 * sin(along * 0.43 - t * 0.3)) / 1.8;
	// Riffle waves stand still over the bed while the water runs through them.
	VERTEX.y += riffle_amplitude * UV.x * sin(along * 2.1 + 1.7 * sin(across * 0.6)) * sin(across * 0.9 + 0.3 * t);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	if (dam_on > 0.5 && world_position.x > dam_x.x + dam_margin && world_position.x < dam_x.y - dam_margin && world_position.z > -6.0 + 0.0075 * world_position.x * world_position.x - dam_reach + dam_margin) { discard; }
	vec2 flow = normalize(world_flow);
	vec2 side = vec2(-flow.y, flow.x);
	float t = TIME * flow_speed_multiplier * flow_data.b;
	vec2 n1 = texture(normal_large, (world_position.xz - flow * t * 0.35) / 6.0).xy * 2.0 - 1.0;
	vec2 n2 = texture(normal_small, (world_position.xz - flow * t * 0.55) / 1.7).xy * 2.0 - 1.0;
	vec2 ripple = (n1 + n2 * 0.6) * normal_strength;
	float rough_water = max(broken.x, broken.y * 0.6);
	if (rough_water > 0.01) {
		// Standing chop plus fast small waves carried through it.
		vec2 standing_uv = vec2(dot(world_position.xz, flow) / 0.9, dot(world_position.xz, side) / 2.2);
		vec2 s1 = texture(normal_small, standing_uv * 0.5 + vec2(0.0, TIME * 0.03)).xy * 2.0 - 1.0;
		vec2 m1 = texture(normal_small, (world_position.xz - flow * TIME * 1.4) / 0.8).xy * 2.0 - 1.0;
		ripple += (s1 * 0.9 + m1 * 0.6) * riffle_chop * rough_water;
	}
	if (rain_wetness > 0.01) {
		// Drop-pitted surface: tiny normals that jump and cross-fade several times a second.
		float rt = TIME * 7.0;
		vec2 jump = floor(rt) * vec2(0.371, 0.613);
		vec2 r1 = texture(normal_small, world_position.xz / 0.32 + jump).xy * 2.0 - 1.0;
		vec2 r2 = texture(normal_small, world_position.xz / 0.32 + jump + vec2(0.371, 0.613)).xy * 2.0 - 1.0;
		ripple += mix(r1, r2, fract(rt)) * 0.45 * rain_wetness;
	}
	vec3 normal_world = normalize(vec3(ripple.x, 1.0, ripple.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);
	vec3 bed_view = view_position(SCREEN_UV, texture(depth_texture, SCREEN_UV).r, INV_PROJECTION_MATRIX);
	vec3 bed_world = (INV_VIEW_MATRIX * vec4(bed_view, 1.0)).xyz;
	float vertical_depth = max(world_position.y - bed_world.y, 0.0);
	// Distance from the surface to the solid seen through it. Unlike the vertical
	// depth it stays large at grazing angles over the steep far bank, so foam no
	// longer paints a continuous white line there; rock faces and legs still hit.
	float contact_depth = max(length(bed_world - world_position), vertical_depth);
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
	// Wave C: light from the bed reaches the surface along the refracted ray, which
	// Snell's law keeps within 49 degrees of the vertical. The absorption above was
	// tuned on the straight view ray, which is fine from above but at a grazing
	// angle ran six times the depth and turned clear shallows opaque: cap it at
	// twice the depth (views steeper than 30 degrees are unchanged).
	vec3 to_eye_world = normalize(CAMERA_POSITION_WORLD - world_position);
	float bed_depth = max(world_position.y - refracted_world.y, 0.0);
	ray_distance = min(ray_distance, 2.0 * bed_depth);
	vec3 transmission = exp(-absorption * min(ray_distance, 40.0));
	// Explicit level of detail: at a grazing angle the screen derivatives are steep,
	// and automatic mip selection blurred even a shallow bed into a murky smear.
	// The bed blurs only with depth, as light scattered in the water would blur it.
	vec3 bed = textureLod(screen_texture, refracted_uv, clamp(bed_depth * 1.2, 0.0, 3.0)).rgb;
	vec3 through_water = bed * transmission + scatter * (vec3(1.0) - transmission);
	vec2 moving = world_position.xz - flow * t * 0.35;
	vec2 streak_uv = vec2(dot(moving, flow) / 3.5, dot(moving, side));
	float breakup = texture(foam_noise, streak_uv * foam_texture_scale).r;
	float contact = 1.0 - smoothstep(0.08, foam_distance, contact_depth);
	float obstacle = smoothstep(0.2, 0.6, flow_data.a * 5.0 - contact_depth);
	contact = mix(contact, pow(contact, 0.25), obstacle);
	float broken_foam = smoothstep(0.51, 0.61, breakup);
	// Rock faces and legs hold a denser collar; gently sloped shallows stay clear.
	float foam = contact * mix(broken_foam, 0.9 + 0.1 * broken_foam, sqrt(obstacle));
	if (rough_water > 0.01) {
		// White water only where it breaks: riffle crests and the shear lines
		// trailing the bar boulders. Far away the pattern resolves to its mean.
		// Breaks are fixed to the bed (where stones lie under the riffle); each
		// trails a tail downstream, and bubbly detail runs through with the current.
		vec2 bed_uv = world_position.xz / 11.0;
		float b0 = smoothstep(0.5, 0.64, texture(foam_noise, bed_uv).r);
		float b1 = smoothstep(0.5, 0.64, texture(foam_noise, bed_uv - flow * 0.22).r);
		float b2 = smoothstep(0.5, 0.64, texture(foam_noise, bed_uv - flow * 0.45).r);
		float tail = max(b0, max(0.7 * b1, 0.45 * b2));
		float crest = 0.6 + 0.4 * sin(dot(world_position.xz, flow) * 2.1 + 6.0 * b0);
		vec2 fast = world_position.xz - flow * TIME * 1.6;
		vec2 white_uv = vec2(dot(fast, flow) / 1.3, dot(fast, side) / 0.5);
		float bubbles = texture(foam_noise, white_uv * 0.7).r * 0.65 + texture(foam_noise, white_uv * 2.3 + vec2(0.37, 0.11)).r * 0.35;
		float blur = clamp(length(fwidth(white_uv)) * 0.6 - 0.15, 0.0, 1.0);
		float cover = broken.x * tail * crest;
		float riffle_white = 0.92 * mix(smoothstep(0.68 - 0.3 * cover, 0.76 - 0.28 * cover, bubbles) * step(0.04, cover), 0.45 * cover, blur);
		float shear = broken.y * (0.55 + 0.45 * b0);
		float wake_white = mix(smoothstep(0.7 - 0.25 * shear, 0.76 - 0.25 * shear, bubbles) * step(0.05, shear), 0.5 * shear, blur);
		foam = max(foam, max(riffle_white, wake_white));
		// Aerated water is paler even between the white crests.
		through_water += vec3(0.05, 0.055, 0.05) * cover;
	}
	float shin_foam = 0.0;
	for (int i=0;i<2;i++) {
		if (shin_contacts[i].w>0.5) {
			float radius=length(world_position.xz-shin_contacts[i].xy);
			float collar=smoothstep(0.065,0.09,radius)*(1.0-smoothstep(0.15,0.21,radius));
			shin_foam=max(shin_foam,collar*(0.85+0.15*broken_foam));
		}
	}
	foam=max(foam,shin_foam);
	// Wave C: seen from afar, ripple detail averages away and a long reach reads as a
	// still pond. Current lines take over there: long streaks of rougher, aerated
	// water and smoother slicks, drawn out along the flow and carried with it.
	float far = smoothstep(25.0, 90.0, length(VERTEX)) * (0.35 + 0.65 * flow_data.b);
	float lines = 0.5;
	if (far > 0.0) {
		vec2 drift = world_position.xz - flow * TIME * flow_speed_multiplier * 0.8;
		vec2 line_uv = vec2(dot(drift, flow) / 70.0, dot(drift, side) / 7.0);
		lines = texture(foam_noise, line_uv).r * 0.65 + texture(foam_noise, line_uv * vec2(2.3, 0.45) + vec2(0.31, 0.57)).r * 0.35;
		lines = mix(0.5, smoothstep(0.3, 0.7, lines), far);
		through_water *= mix(0.82, 1.18, lines);
		through_water += vec3(0.05, 0.055, 0.052) * smoothstep(0.65, 0.95, lines) * far;
	}
	float fresnel = 0.064 + 0.936 * pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 5.0);
	// Only near the viewer and at a grazing angle: seen from higher up the margins
	// already show their bed, and the sun's glint further out stays whole.
	float clear = (1.0 - smoothstep(shallow_depth.x, shallow_depth.y, vertical_depth)) * (1.0 - smoothstep(0.3, 0.5, to_eye_world.y)) * (1.0 - smoothstep(18.0, 35.0, length(VERTEX)));
	fresnel *= 1.0 - shallow_clarity * clear;
	vec2 outside_xz = max(vec2(probe_box.x - world_position.x, probe_box.z - world_position.z), vec2(world_position.x - probe_box.y, world_position.z - probe_box.w));
	float reach = smoothstep(0.0, 14.0, max(outside_xz.x, outside_xz.y));
	// White foam stays readable around the miner's much narrower shins.
	ALBEDO = vec3(0.95, 0.98, 0.96) * foam;
	// The screen sample is already lit. Emission here transports bed light;
	// foam uses ordinary diffuse lighting and has no emissive contribution.
	EMISSION = through_water * (1.0 - fresnel) * (1.0 - foam);
	if (reach > 0.0) {
		vec3 mirrored = reflect(-to_eye_world, normal_world);
		vec3 canyon = mix(reach_wall, reach_sky, smoothstep(reach_rim.x, reach_rim.y, mirrored.y));
		// Mottled like the forest and rock bands it mirrors, shivered by the ripples.
		canyon *= (0.7 + 0.6 * texture(foam_noise, world_position.xz / 45.0 + ripple * 0.35).r) * mix(1.25, 0.75, lines);
		EMISSION += canyon * fresnel * reach * (1.0 - foam);
	}
	ROUGHNESS = mix(mix(0.06, 0.14, rain_wetness), 0.85, foam);
	METALLIC = 0.0;
	// The engine's reflection follows SPECULAR: eased in the shallows, and in the
	// reaches cut to a trace (the sun's glint) in favour of the canyon above.
	SPECULAR = mix(0.8, 0.25, foam) * (1.0 - 0.8 * shallow_clarity * clear) * (1.0 - 0.7 * reach);
	ALPHA = max(shin_foam,smoothstep(0.0, 0.05, min(vertical_depth, flow_data.a * 5.0)));
}
