shader_type spatial;
render_mode cull_disabled;
// Hired hands and Lambert (visual upgrade Stage 5). One material per kit surface is shared
// by every man; the per-man look arrives as instance uniforms (scripts/crew_look.gd), so
// the crew costs no extra textures or materials. The kit (blender/build_crew_kit.py)
// carries the source garment of every face in UV2 and its rest position in CUSTOM0.
uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_atlas : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_atlas : filter_linear_mipmap_anisotropic;
uniform bool hair_cutout = false;
uniform bool show_parts = false;

// rgb are linear albedo targets; an rgb of zero keeps the miner's own dye.
instance uniform vec4 shirt = vec4(0.0);                 // a: 0 plain, 1 check, 2 stripe, 3 plaid
instance uniform vec4 shirt_b = vec4(0.0, 0.0, 0.0, .05); // second yarn, a: repeat in metres
instance uniform vec4 vest = vec4(0.0, 0.0, 0.0, 1.0);   // a: worn
instance uniform vec4 trousers = vec4(0.0);              // a: knee 0 torn, 1 patched, 2 whole
instance uniform vec4 scarf = vec4(0.0, 0.0, 0.0, 1.0);  // a: worn
instance uniform vec4 braces = vec4(0.0, 0.0, 0.0, 1.0); // a: worn
instance uniform vec4 sash = vec4(0.0);                  // a: 0 none, 1 plain faja, 2 arrow (flechee)
instance uniform vec4 hat = vec4(0.0);                   // a: knitted wool
instance uniform vec4 band = vec4(0.0);
instance uniform vec4 skin = vec4(1.0, 1.0, 1.0, 0.0);   // rgb tone multiplier, a: shaven
instance uniform vec4 scalp = vec4(0.0);                 // a: bald crown
instance uniform vec4 hair = vec4(0.0);
instance uniform vec4 beard = vec4(0.0, 0.0, 0.0, 15.0); // a: shown regions, bits moustache, chin, jaw, cheek

const int SHIRT = 1; const int VEST = 2; const int TROUSERS = 3; const int SCARF = 5; const int LEATHER = 6;
const int HAT = 7; const int BAND = 8; const int FACE = 9; const int HANDS = 10; const int SCALP = 12;
const int MOUSTACHE = 13; const int CHEEK = 16; const int STRAPS = 17; const int KNEE = 18;
const vec3 LUMA = vec3(.2126, .7152, .0722);
// Mean linear luminance of each part in the miner's atlases (artifacts/crew-kit/report.json).
const float REF[19] = { 1.0, .324, .0257, .0813, .0132, .0272, .0408, .0354, .0191, .1646, .1842, .3848, .0136, .0347, .0357, .0363, .0359, .0172, .1724 };
const vec3 CHEEK_TONE = vec3(.4369, .1668, .0846);

varying flat int part;
varying flat int trim;
varying vec2 pattern;
varying vec3 rest;

void vertex() {
	// Garment ids are stored as id / 255 (normalised bytes in the kit).
	part = int(UV2.x * 255.0 + .5);
	// Blender writes the trim flag in v and glTF flips v.
	trim = int(1.5 - UV2.y);
	pattern = vec2(CUSTOM0.x, 1.0 - CUSTOM0.y);
	rest = vec3(CUSTOM0.z, 1.0 - CUSTOM0.w, 1.0 - CUSTOM0.y);
	bool shown = true;
	if (part == VEST) { shown = vest.a > .5; }
	else if (part == SCARF) { shown = scarf.a > .5; }
	else if (part == STRAPS) { shown = braces.a > .5; }
	else if (part == KNEE) { shown = trousers.a < .5; }
	else if (part >= MOUSTACHE && part <= CHEEK) { shown = ((int(beard.a + .5) >> (part - MOUSTACHE)) & 1) == 1; }
	// Collapse what the man is not wearing: degenerate triangles are never rasterised.
	if (!shown) { VERTEX = vec3(0.0); }
}

// Box-filtered pulse train (duty d): a woven stripe that greys out instead of aliasing.
float pulse_sum(float x, float d) { return floor(x) * d + max(fract(x) - (1.0 - d), 0.0); }
float weave(float x, float d) {
	float w = max(fwidth(x), 1e-4);
	return clamp((pulse_sum(x + .5 * w, d) - pulse_sum(x - .5 * w, d)) / w, 0.0, 1.0);
}

bool dyed(vec4 v) { return v.r + v.g + v.b > 0.0; }

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float value_noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

vec3 dye(vec3 base, vec3 target, int p) {
	return target * clamp(dot(base, LUMA) / REF[p], 0.0, 2.6);
}

vec3 cloth(vec3 base, int p) {
	if (p == SHIRT && dyed(shirt)) {
		float size = max(shirt_b.a, .01);
		float kind = shirt.a;
		float mixv = 0.0;
		if (kind > 2.5) {
			// Plaid: a broad check with a narrow over-check.
			mixv = .5 * (weave(pattern.x / size, .5) + weave(pattern.y / size, .5));
			mixv = max(mixv, .9 * max(weave(pattern.x / size + .25, .12), weave(pattern.y / size + .25, .12)));
		} else if (kind > 1.5) {
			mixv = weave(pattern.x / size, .42);
		} else if (kind > .5) {
			mixv = .5 * (weave(pattern.x / size, .5) + weave(pattern.y / size, .5));
		}
		return dye(base, mix(shirt.rgb, shirt_b.rgb, mixv), p);
	}
	if (p == VEST && dyed(vest)) { return dye(base, vest.rgb, p); }
	if (p == TROUSERS) {
		vec3 c = dyed(trousers) ? dye(base, trousers.rgb, p) : base;
		if (trousers.a > .5) {
			// The torn right knee: a square patch sewn over it (1), or a whole pair (2).
			bool whole = trousers.a > 1.5;
			vec2 d = abs(vec2(rest.x + .108, rest.z - .618)) - vec2(.058, .046);
			float edge = whole ? .02 : .002;
			float patch = (1.0 - smoothstep(-.003 - edge, edge, max(d.x, d.y))) * (1.0 - smoothstep(-.03, -.01, rest.y));
			vec3 cloth_tone = dyed(trousers) ? trousers.rgb : vec3(.13, .072, .032);
			if (!whole) { cloth_tone *= vec3(.8, .85, .9) * (.9 + .1 * weave(rest.x / .006, .5)); }
			c = mix(c, cloth_tone, patch);
		}
		return c;
	}
	if (p == SCARF && dyed(scarf)) { return dye(base, scarf.rgb, p); }
	return base;
}

// A voyageur's ceinture flechee or a plain faja wound round the waist over the belt.
vec3 waist(vec3 c, vec3 base, int p) {
	if (sash.a < .5 || abs(rest.x) > .215 || (p != SHIRT && p != VEST && p != TROUSERS && p != LEATHER && p != STRAPS)) { return c; }
	float top = 1.075; float bottom = .955;
	float on = smoothstep(bottom - .004, bottom + .004, rest.z) * (1.0 - smoothstep(top - .004, top + .004, rest.z));
	if (on <= 0.0) { return c; }
	float shade = clamp(dot(base, LUMA) / REF[p], .55, 1.5);
	vec3 yarn = sash.rgb;
	if (sash.a > 1.5) {
		// Arrow pattern: chevrons running round the body in navy, green and gold.
		float v = (rest.z - bottom) / (top - bottom);
		float chevron = v * 2.0 + abs(fract(pattern.x / .055) - .5) * 1.6;
		vec3 navy = vec3(.018, .03, .09); vec3 green = vec3(.03, .09, .04); vec3 gold = vec3(.55, .36, .06);
		yarn = mix(yarn, navy, weave(chevron, .16));
		yarn = mix(yarn, gold, weave(chevron + .3, .07));
		yarn = mix(yarn, green, weave(chevron + .55, .1));
	} else {
		yarn *= 1.0 - .25 * weave(rest.z / .012, .3);
	}
	return mix(c, yarn * shade, on);
}

void fragment() {
	vec4 pigment = texture(albedo_atlas, UV);
	// Cutouts stay in the opaque depth pass, avoiding sorting among hair layers.
	if (hair_cutout && pigment.a < .25) { discard; }
	vec3 base = pigment.rgb;
	vec3 c = base;
	vec3 surface = texture(surface_atlas, UV).rgb;
	float roughness = surface.g;
	vec3 normal_map = texture(normal_atlas, UV).rgb;
	bool shell = !hair_cutout && part >= MOUSTACHE && part <= CHEEK;
	if (shell) {
		// The beard shell: combed strands running down the face, frayed at its edge.
		float fray = pattern.x;
		float n = value_noise(vec2(rest.x * 700.0 + rest.y * 500.0, rest.z * 160.0));
		if (n > fray * 2.0 + .3) { discard; }
		vec3 tone = dyed(beard) ? beard.rgb : dyed(hair) ? hair.rgb : vec3(.045, .03, .02);
		float strand = value_noise(vec2(rest.x * 1300.0 + rest.y * 900.0, rest.z * 70.0));
		c = tone * mix(.45, 1.55, strand) * mix(.8, 1.15, value_noise(vec2(rest.x, rest.z) * 110.0));
		roughness = .82;
		normal_map = vec3(.5, .5, 1.0);
	} else if (trim == 0) {
		if (part >= SHIRT && part <= SCARF) { c = cloth(base, part); }
		if (part == STRAPS && dyed(braces)) { c = dye(base, braces.rgb, part); }
		if (part == HAT && dyed(hat)) {
			c = dye(base, hat.rgb, part);
			roughness = mix(roughness, .95, hat.a);
		}
		if (part == BAND && dyed(band)) { c = dye(base, band.rgb, part); }
		if (part == FACE || part == HANDS || part == KNEE) {
			if (part == FACE) {
				// Shaving lifts the painted stubble on the lower face to the cheek tone.
				float jaw = (1.0 - smoothstep(1.568, 1.588, rest.z)) * smoothstep(1.46, 1.49, rest.z)
					* (1.0 - smoothstep(.066, .084, abs(rest.x))) * (1.0 - smoothstep(-.02, .02, rest.y));
				float dark = smoothstep(.0, .5, 1.0 - dot(c, LUMA) / dot(CHEEK_TONE, LUMA));
				vec3 cheek = mix(CHEEK_TONE, vec3(dot(CHEEK_TONE, LUMA)), .22);
				c = mix(c, cheek * (.96 + .08 * dot(base, LUMA) / REF[FACE]), skin.a * jaw * dark);
				// Bald crown, or the painted hairline toned to the man's own hair.
				float crown = smoothstep(1.635, 1.66, rest.z) * smoothstep(-.085, -.06, rest.y);
				if (scalp.a > .5) {
					c = mix(c, CHEEK_TONE * vec3(1.05, 1.0, .98), crown);
					roughness = mix(roughness, .42, crown);
				} else if (dyed(hair)) {
					float painted = crown * (1.0 - smoothstep(.02, .05, dot(base, LUMA)));
					c = mix(c, dye(base, hair.rgb, SCALP), painted);
				}
			}
			c *= skin.rgb;
		}
		if (part == SCALP && dyed(hair)) { c = dye(base, hair.rgb, part); }
		if (part >= MOUSTACHE && part <= CHEEK) {
			vec3 tone = dyed(beard) ? beard.rgb : hair.rgb;
			if (tone.r + tone.g + tone.b > 0.0) { c = dye(base, tone, part); }
		}
	}
	c = waist(c, base, part);
	if (show_parts) {
		c = vec3(fract(float(part) * .37), fract(float(part) * .61), fract(float(part) * .83)) * (trim == 1 ? .3 : 1.0);
	}
	ALBEDO = c;
	NORMAL_MAP = normal_map;
	ROUGHNESS = roughness;
	METALLIC = surface.b;
}
