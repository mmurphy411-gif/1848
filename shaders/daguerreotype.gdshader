shader_type canvas_item;
render_mode unshaded;
// Photo-mode plate. Re-prints the rendered frame as a period photograph and
// draws its mount procedurally: a brass case mat (daguerreotype), a card
// album mount (salt print) or the brushed edge of a sun print (cyanotype).
// All lengths below are in screen-height units; p is centred on the screen.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform int tone = 0; // 0 daguerreotype, 1 sepia salt print, 2 cyanotype
uniform float mat_visible : hint_range(0.0, 1.0) = 1.0;
uniform float plate_seed = 0.0;
uniform float flash : hint_range(0.0, 1.0) = 0.0;
uniform float develop : hint_range(0.0, 1.0) = 1.0; // latent image fading in during exposure
uniform float aspect = 1.7777778;

const vec2 LIGHT_DIR = vec2(-0.6, -0.8); // towards the light: upper left, y down
const vec2 OVAL = vec2(0.56, 0.372);
const vec2 WINDOW_CENTRE = vec2(0.0, -0.026); // raised to leave room for the label below

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// Integer lattice hash: stays clean at the high frequencies the brass needs.
float lattice(vec2 cell) {
	uvec2 q = uvec2(ivec2(cell)) * uvec2(1597334673u, 3812015801u);
	uint n = (q.x ^ q.y) * 1597334673u;
	return float(n) * (1.0 / 4294967295.0);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(lattice(i), lattice(i + vec2(1.0, 0.0)), u.x),
		mix(lattice(i + vec2(0.0, 1.0)), lattice(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 5; i++) {
		v += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.3);
		a *= 0.5;
	}
	return v;
}

float sd_round_box(vec2 p, vec2 b, vec4 r) {
	// r: right-bottom, right-top, left-bottom, left-top (y points down).
	r.xy = p.x > 0.0 ? r.xy : r.zw;
	r.x = p.y > 0.0 ? r.x : r.y;
	vec2 q = abs(p) - b + r.x;
	return min(max(q.x, q.y), 0.0) + length(max(q, 0.0)) - r.x;
}

// Raw window field (not yet a distance); the caller normalises by its gradient.
float window_field(vec2 p, int style, vec2 seed) {
	if (mat_visible < 0.5) {
		return sd_round_box(p, vec2(aspect * 0.5, 0.5) - 0.004, vec4(0.035));
	}
	p -= WINDOW_CENTRE;
	if (style == 0) {
		return length(p / OVAL) - 1.0;
	}
	if (style == 1) {
		return sd_round_box(p, vec2(0.54, 0.36), vec4(0.018, 0.19, 0.018, 0.19));
	}
	// Cyanotype: hand-brushed emulsion. Strokes run sideways, so the side edges
	// end raggedly at stroke ends while the top and bottom only waver.
	float box = sd_round_box(p, vec2(0.64, 0.372), vec4(0.01));
	float strokes = fbm(vec2(p.x * 2.5, p.y * 38.0) + seed);
	float waver = fbm(vec2(p.x * 9.0, p.y * 9.0) + seed * 1.7);
	float side = smoothstep(0.3, 0.5, abs(p.x) / aspect);
	return box - (strokes - 0.5) * 0.09 * side - (waver - 0.5) * 0.022;
}

vec3 tone_map(float v, int style) {
	if (style == 0) {
		vec3 shadow = vec3(0.028, 0.034, 0.045);
		vec3 mid = vec3(0.39, 0.415, 0.44);
		vec3 high = vec3(0.95, 0.945, 0.91);
		return v < 0.5 ? mix(shadow, mid, v * 2.0) : mix(mid, high, v * 2.0 - 1.0);
	}
	if (style == 1) {
		vec3 shadow = vec3(0.16, 0.07, 0.05);
		vec3 mid = vec3(0.53, 0.33, 0.21);
		vec3 high = vec3(0.94, 0.87, 0.73);
		return v < 0.5 ? mix(shadow, mid, v * 2.0) : mix(mid, high, v * 2.0 - 1.0);
	}
	vec3 shadow = vec3(0.02, 0.07, 0.24);
	vec3 mid = vec3(0.14, 0.33, 0.6);
	vec3 high = vec3(0.9, 0.93, 0.94);
	return v < 0.5 ? mix(shadow, mid, v * 2.0) : mix(mid, high, v * 2.0 - 1.0);
}

float scratches(vec2 p, vec2 seed) {
	float s = 0.0;
	for (int i = 0; i < 16; i++) {
		float fi = float(i);
		float h1 = hash12(vec2(fi, 1.3) + seed);
		float h2 = hash12(vec2(fi, 7.9) + seed);
		float h3 = hash12(vec2(fi, 4.2) + seed);
		float h4 = hash12(vec2(fi, 9.6) + seed);
		vec2 c = (vec2(h1, h2) - 0.5) * vec2(aspect * 0.9, 0.85);
		// Most scratches follow the buffing direction; a few cross it.
		float ang = (h3 - 0.5) * 0.5 + (h4 > 0.8 ? 1.2 : 0.0);
		vec2 dir = vec2(cos(ang), sin(ang));
		vec2 q = p - c;
		float along = dot(q, dir);
		float across = dot(q, vec2(-dir.y, dir.x)) + along * along * (h1 - 0.5) * 1.2;
		float len = 0.03 + 0.2 * h2 * h2;
		float line = smoothstep(0.0011, 0.0, abs(across)) * smoothstep(len, len * 0.4, abs(along));
		s += line * (0.25 + 0.75 * h4);
	}
	return s;
}

float dust(vec2 p, vec2 seed) {
	vec2 cell = floor(p * 55.0);
	float h = hash12(cell + seed * 3.1);
	if (h < 0.985) return 0.0;
	vec2 centre = (cell + vec2(hash12(cell + 2.7), hash12(cell + 5.1))) / 55.0;
	float r = 0.0008 + 0.0018 * hash12(cell + 8.4);
	return smoothstep(r, r * 0.3, length(p - centre)) * (h > 0.993 ? -1.0 : 1.0);
}

// Brass case mat: polished bevel, engraved line, a ring of stamped beads,
// engine-turned field, rolled outer edge, all lit from the upper left.
vec3 brass_mat(vec2 p, float d, vec2 n, vec2 seed) {
	vec2 L = normalize(LIGHT_DIR);
	vec3 brass = vec3(0.7, 0.55, 0.31);
	// Metal reads through its reflections: a broad falloff away from the light
	// plus two soft sheen bands, over a frosted (stamped) matte finish.
	float broad = 0.58 + 0.62 * smoothstep(1.0, -0.8, dot(p, vec2(0.62, 0.78)));
	float band = p.x * 0.55 + p.y;
	float streak = exp(-pow((band + 0.22) * 4.0, 2.0)) * 0.34 + exp(-pow((band - 0.42) * 6.0, 2.0)) * 0.16;
	float stipple = vnoise(p * 1300.0) * 0.6 + vnoise(p * 520.0 + seed) * 0.4;
	float hammer = fbm(p * 18.0 + seed);
	vec3 col = brass * (broad + streak) * (0.78 + 0.3 * stipple) * (0.88 + 0.24 * hammer);
	col = mix(vec3(dot(col, vec3(0.33))), col, 0.88);

	// Ellipse parameter corrected towards arc length so beads are evenly spaced.
	vec2 q = p - WINDOW_CENTRE;
	float t = atan(q.y / OVAL.y, q.x / OVAL.x);
	float m = (OVAL.x * OVAL.x + OVAL.y * OVAL.y) * 0.5;
	float k = (OVAL.x * OVAL.x - OVAL.y * OVAL.y) * 0.5 / (4.0 * m);
	float s = (t - k * sin(2.0 * t)) / 6.2831853;
	vec2 tangent = vec2(-n.y, n.x);

	// Engine-turned guilloche in the field beyond the beads.
	float field = smoothstep(0.06, 0.07, d);
	float g = sin(d * 640.0 + 1.1 * sin(s * 6.2831853 * 40.0) + 0.6 * sin(s * 6.2831853 * 8.0));
	float fade = smoothstep(0.24, 0.1, d); // the engine-turning dies away into plain frosting
	col *= 1.0 - field * fade * 0.16 * smoothstep(0.4, 1.0, g);
	col += field * fade * brass * 0.1 * smoothstep(0.4, 1.0, -g);

	// Polished bevel sloping down into the window.
	float bevel_w = 0.016;
	if (d < bevel_w) {
		float facing = dot(-n, L);
		float shade = 0.55 + 0.75 * facing;
		float spec = pow(clamp(facing, 0.0, 1.0), 6.0) * 0.42;
		vec3 polished = brass * (0.95 + 0.2 * vnoise(p * 60.0)) * shade + vec3(1.0, 0.92, 0.78) * spec;
		col = mix(polished, col, smoothstep(bevel_w - 0.0015, bevel_w, d));
		col *= 0.7 + 0.3 * smoothstep(0.0, 0.003, d); // the bevel's foot sits in shadow
	}
	// Bright lip on top of the bevel.
	col += vec3(0.95, 0.8, 0.5) * smoothstep(0.0016, 0.0, abs(d - bevel_w - 0.0008)) * (0.25 + 0.35 * clamp(dot(n, L) * -1.0 + 0.6, 0.0, 1.0));

	// Two engraved lines either side of the beads.
	for (int i = 0; i < 2; i++) {
		float at = i == 0 ? 0.027 : 0.058;
		float groove = smoothstep(0.0014, 0.0003, abs(d - at));
		float edge = smoothstep(0.0012, 0.0, abs(d - at - 0.0019)) * clamp(0.5 - dot(n, L), 0.0, 1.0);
		col = col * (1.0 - 0.62 * groove) + vec3(1.0, 0.86, 0.55) * edge * 0.35;
	}

	// Stamped beads.
	float spacing = 0.0118;
	float count = floor(6.2831853 * sqrt(m) / spacing);
	float u = fract(s * count) - 0.5;
	vec2 local = vec2(u * 6.2831853 * sqrt(m) / count, d - 0.0425);
	float R = 0.0047;
	float r = length(local);
	vec2 L2 = vec2(dot(L, tangent), dot(L, n));
	if (r < R * 1.5) {
		float base = smoothstep(R * 1.5, R, r);
		col *= 1.0 - 0.4 * base * smoothstep(-R * 0.2, R * 1.2, dot(local, -L2)); // contact shadow
	}
	if (r < R) {
		vec3 N = normalize(vec3(local / R, sqrt(max(1.0 - r * r / (R * R), 0.0))));
		vec3 L3 = normalize(vec3(L2 * 0.75, 0.66));
		float lambert = clamp(dot(N, L3), 0.0, 1.0);
		float spec = pow(clamp(dot(reflect(-L3, N), vec3(0.0, 0.0, 1.0)), 0.0, 1.0), 18.0);
		vec3 bead = brass * (0.35 + 0.95 * lambert) + vec3(1.0, 0.92, 0.75) * spec * 0.8;
		col = mix(col, bead, smoothstep(R, R * 0.8, r));
	}

	// Rolled outer rim with an engraved border line inside it.
	vec2 half_size = vec2(aspect * 0.5, 0.5);
	float edge_d = -sd_round_box(p, half_size, vec4(0.0));
	float border = -sd_round_box(p, half_size - 0.028, vec4(0.035));
	col *= 1.0 - 0.55 * smoothstep(0.0013, 0.0002, abs(border));
	col += vec3(1.0, 0.86, 0.55) * 0.22 * smoothstep(0.0011, 0.0, abs(border - 0.0018));
	if (edge_d < 0.012) {
		float x = edge_d / 0.012;
		float roll = sin(x * 3.14159);
		vec2 outward = abs(p.x) / half_size.x > abs(p.y) / half_size.y ? vec2(sign(p.x), 0.0) : vec2(0.0, sign(p.y));
		float lit = 0.65 + 0.5 * dot(outward, L) * (1.0 - x * 2.0);
		col = brass * (0.45 + 0.55 * roll) * lit + vec3(1.0, 0.9, 0.7) * pow(roll, 8.0) * 0.18;
		col *= smoothstep(0.0, 0.003, edge_d) * 0.7 + 0.3;
	}

	// Tarnish creeping in from the edges and corners.
	float tarnish = smoothstep(0.48, 0.78, fbm(p * 3.2 + seed * 0.37)) * (0.3 + 0.7 * smoothstep(0.2, 0.0, edge_d));
	col = mix(col, col * vec3(0.52, 0.47, 0.36), tarnish * 0.6);
	float verdigris = smoothstep(0.66, 0.82, fbm(p * 9.0 - seed)) * smoothstep(0.08, 0.0, edge_d);
	col = mix(col, vec3(0.3, 0.36, 0.28), verdigris * 0.35);
	col *= 0.93 + 0.07 * fbm(p * 7.0 - seed);
	return col;
}

// Card album mount: cream board, white bevel, gilt rule and an ink rule.
vec3 card_mount(vec2 p, float d, vec2 n, vec2 seed) {
	vec2 L = normalize(LIGHT_DIR);
	vec3 board = vec3(0.84, 0.79, 0.68);
	float fibre = fbm(vec2(p.x * 160.0, p.y * 60.0) + seed) * 0.6 + vnoise(p * 700.0) * 0.4;
	vec3 col = board * (0.92 + 0.1 * fibre);
	col *= 0.9 + 0.12 * smoothstep(0.9, -0.7, dot(p, vec2(0.62, 0.78)));
	// Foxing: small rusty spots, denser near the edges.
	float fox = smoothstep(0.72, 0.86, fbm(p * 18.0 + seed * 0.71));
	col = mix(col, vec3(0.62, 0.45, 0.28), fox * 0.35);
	// Cut white bevel.
	if (d < 0.009) {
		float facing = dot(-n, L);
		col = vec3(0.95, 0.91, 0.83) * (0.84 + 0.18 * facing);
		col *= 0.75 + 0.25 * smoothstep(0.0, 0.002, d);
	}
	// Gilt rule then a fine ink rule.
	float gilt = smoothstep(0.0024, 0.0008, abs(d - 0.022));
	vec3 gold = vec3(0.78, 0.6, 0.3) * (0.75 + 0.5 * vnoise(p * 300.0 + seed));
	col = mix(col, gold, gilt);
	col = mix(col, vec3(0.32, 0.22, 0.14), smoothstep(0.0011, 0.0002, abs(d - 0.034)) * 0.8);
	float edge_d = -sd_round_box(p, vec2(aspect * 0.5, 0.5), vec4(0.0));
	col *= 0.82 + 0.18 * smoothstep(0.0, 0.05, edge_d); // board darkened by handling
	return col;
}

vec3 cyanotype_paper(vec2 p, float d, vec2 seed) {
	float fibre = fbm(vec2(p.x * 120.0, p.y * 120.0) + seed) * 0.5 + vnoise(p * 800.0) * 0.5;
	vec3 col = vec3(0.92, 0.91, 0.86) * (0.94 + 0.07 * fibre);
	col *= 0.93 + 0.08 * smoothstep(0.9, -0.7, dot(p, vec2(0.62, 0.78)));
	// Thin blue wash where the brush was lightly loaded just past the image.
	float wash = smoothstep(0.03, 0.0, d) * fbm(vec2(p.x * 3.0, p.y * 30.0) + seed * 2.0);
	col = mix(col, vec3(0.42, 0.58, 0.76), wash * 0.55);
	return col;
}

void fragment() {
	vec2 seed = vec2(fract(plate_seed * 0.6180339) * 97.0, fract(plate_seed * 0.4142135) * 61.0);
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);
	int style = clamp(tone, 0, 2);

	// Signed distance to the window edge (positive on the mount) and its outward normal.
	float e = 0.0015;
	float f = window_field(p, style, seed);
	vec2 grad = vec2(window_field(p + vec2(e, 0.0), style, seed) - window_field(p - vec2(e, 0.0), style, seed),
		window_field(p + vec2(0.0, e), style, seed) - window_field(p - vec2(0.0, e), style, seed)) / (2.0 * e);
	float d = f / max(length(grad), 0.05);
	vec2 n = normalize(grad + vec2(1e-6));
	vec2 L = normalize(LIGHT_DIR);

	// --- The photograph ---
	// A Petzval portrait lens: sharp centre, softness swirling round the edges.
	float r = clamp(1.0 + d / 0.42, 0.0, 1.2);
	float soft = smoothstep(0.35, 1.0, r) + (style == 1 ? 0.12 : 0.0);
	vec2 tang = normalize(vec2(-p.y, p.x) + vec2(1e-5));
	tang.x /= aspect;
	vec3 acc = vec3(0.0);
	float wsum = 0.0;
	for (int i = -3; i <= 3; i++) {
		float fi = float(i) / 3.0;
		float wi = 1.0 - abs(fi) * 0.55;
		acc += textureLod(screen_tex, SCREEN_UV + tang * fi * soft * 0.007, soft * 1.8).rgb * wi;
		wsum += wi;
	}
	vec3 src = acc / wsum;
	// Plates were blue-sensitive: skies burn out pale and warm colours sink.
	vec3 weights = style == 1 ? vec3(0.26, 0.47, 0.27) : vec3(0.2, 0.43, 0.37);
	float lum = dot(src, weights) * 1.12;
	vec3 glow = textureLod(screen_tex, SCREEN_UV, 4.5).rgb * 0.6 + textureLod(screen_tex, SCREEN_UV, 3.0).rgb * 0.4;
	float halo = max(dot(glow, weights) * 1.12 - 0.5, 0.0);
	lum += halo * (style == 0 ? 0.75 : 0.45);
	float v = clamp(lum, 0.0, 1.0);
	v = mix(v, v * v * (3.0 - 2.0 * v), style == 1 ? 0.45 : 0.6);
	if (style == 2) v = smoothstep(0.06, 0.82, v); // Prussian blue shadows, paper-white skies
	else v = pow(v, 0.92);
	if (style == 1) v = 0.05 + 0.9 * v; // matte paper never reaches full black or white

	vec3 photo = tone_map(v, style);
	vec3 blank = style == 0 ? vec3(0.6, 0.62, 0.64) : style == 1 ? vec3(0.9, 0.84, 0.7) : vec3(0.86, 0.9, 0.92);
	photo = mix(blank, photo, develop);

	if (style == 0) {
		// Polished silver: shadows hold a faint cool reflection.
		float sheen = smoothstep(0.7, -0.5, dot(p, vec2(0.62, 0.78)));
		photo += (1.0 - v) * sheen * vec3(0.03, 0.045, 0.06);
		// Buffing hairlines and scratches catching the light.
		float hair = vnoise(vec2(p.x * 3.0, p.y * 1400.0) + seed) * vnoise(vec2(p.x * 9.0, p.y * 300.0) - seed);
		photo += vec3(0.85, 0.88, 0.9) * smoothstep(0.55, 0.9, hair) * 0.035;
	} else {
		float fibre = fbm(vec2(p.x * 160.0, p.y * 60.0) + seed) * 0.5 + vnoise(p * 900.0) * 0.5;
		photo *= 0.94 + 0.08 * fibre;
		if (style == 2) {
			float strokes = fbm(vec2(p.x * 2.5, p.y * 38.0) + seed);
			photo = mix(photo, photo * vec3(0.85, 0.9, 1.0), smoothstep(0.45, 0.75, strokes) * 0.35);
		}
	}
	float edge_glow = smoothstep(-0.18, 0.0, d);
	float sc = scratches(p, seed) * (0.35 + 0.65 * edge_glow);
	photo += vec3(0.9, 0.9, 0.88) * sc * (style == 0 ? 0.16 : 0.0); // paper does not take silver scratches
	float speck = dust(p, seed);
	photo = mix(photo, speck > 0.0 ? vec3(0.95) : vec3(0.03), abs(speck) * (style == 0 ? 0.5 : 0.35));

	// Strong vignette, then the edge treatment of each process.
	float vig = smoothstep(-0.36, 0.0, d);
	photo *= 1.0 - (style == 0 ? 0.62 : style == 1 ? 0.45 : 0.3) * vig * vig;
	if (style == 0) {
		// Iridescent tarnish blooms in patches just inside the mat, over a dark rim.
		float rim = smoothstep(-0.05, 0.0, d);
		photo *= 1.0 - rim * 0.35 * (0.5 + fbm(p * 11.0 + seed));
		float bloom = smoothstep(-0.07, -0.004, d) * smoothstep(0.5, 0.78, fbm(p * 5.0 + seed));
		vec3 film = 0.5 + 0.5 * cos(6.2831853 * (fbm(p * 3.0 - seed) * 1.4 + d * 22.0 + vec3(0.0, 0.33, 0.67)));
		film = mix(vec3(0.5), film, 0.7) * vec3(0.95, 0.85, 1.0);
		photo = mix(photo, photo * 0.5 + film * 0.32, bloom * 0.5);
		// The mat stands proud of the plate and shades its lit-side rim.
		photo *= 1.0 - 0.55 * smoothstep(-0.02, 0.0, d) * clamp(dot(n, L) + 0.25, 0.0, 1.0);
	} else if (style == 1) {
		photo = mix(photo, photo * vec3(0.92, 0.8, 0.62), smoothstep(-0.12, 0.0, d) * 0.6); // yellowed edges
	}
	float grain = hash12(floor(SCREEN_UV / SCREEN_PIXEL_SIZE) + seed) - 0.5;
	photo += grain * (style == 0 ? 0.03 : 0.045);

	// --- The mount ---
	vec3 mount;
	if (mat_visible < 0.5) {
		mount = vec3(0.025, 0.02, 0.022); // bare plate on dark velvet
	} else if (style == 0) {
		mount = brass_mat(p, d, n, seed);
	} else if (style == 1) {
		mount = card_mount(p, d, n, seed);
	} else {
		mount = cyanotype_paper(p, d, seed);
	}
	float aa = max(fwidth(d), 0.0008);
	float inside = style == 2 && mat_visible > 0.5 ? smoothstep(0.004, -0.004, d) : smoothstep(aa, -aa, d);
	vec3 col = mix(mount, photo, inside);
	col = mix(col, vec3(1.0), flash);
	COLOR = vec4(clamp(col, 0.0, 1.0), 1.0);
}
