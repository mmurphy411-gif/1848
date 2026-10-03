shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
// Slopes above the rims of the bent canyon reach (scripts/canyon.gd, greybox.gd), seen
// from 150-600 m, and the treeline meshes standing on them (canyon_dressing.gd).
// Terrain: greybox.gd passes canyon.gd's ground cover per vertex - COLOR.r forest density
// (before slope), COLOR.g draw (x0.45), COLOR.b rock (cliff bands, tors), COLOR.a scree.
// Steep ground is rock whatever the cover says. Open ground is a dry Sierra slope in late
// summer: needle duff and red-brown soil under the timber, olive chaparral and cured tan
// grass on the sunny (south, -Z) faces, grey slate and greenstone in dipping strata with
// pale scree fans below. Timber is clumped crowns with self-shadowed relief.
// Treeline meshes (COLOR.g = 1): spires (COLOR.a = 1; r = tint, b = height in the tier)
// and oak domes (COLOR.a = 0.5).
uniform vec3 pine_crowns : source_color = vec3(0.15, 0.20, 0.095);
uniform vec3 fir_crowns : source_color = vec3(0.095, 0.15, 0.115);
uniform vec3 oak_crowns : source_color = vec3(0.23, 0.26, 0.12);
uniform vec3 chaparral : source_color = vec3(0.30, 0.30, 0.19);
uniform vec3 grass : source_color = vec3(0.47, 0.40, 0.26);
uniform vec3 duff : source_color = vec3(0.31, 0.25, 0.19);
uniform vec3 rock : source_color = vec3(0.31, 0.32, 0.325);
uniform vec3 scree : source_color = vec3(0.42, 0.41, 0.38);
uniform float crown_size = 5.5;
varying vec3 world;
varying vec3 geom_normal;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// terrain.gdshader's integer hash and value noise, so the strata continue the claim
// walls' bands exactly where the two materials meet.
float ihash(vec2 p) {
	uvec2 q = uvec2(ivec2(floor(p)) + ivec2(65536));
	uint h = q.x * 0x27d4eb2du ^ q.y * 0x165667b1u;
	h ^= h >> 15u; h *= 0x2c1b3c6du; h ^= h >> 12u;
	return float(h) * (1.0 / 4294967295.0);
}
float inoise(vec2 p) {
	vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(ihash(i), ihash(i + vec2(1, 0)), f.x), mix(ihash(i + vec2(0, 1)), ihash(i + vec2(1, 1)), f.x), f.y);
}
float crowns(vec2 p) { return noise(p / crown_size) * 0.65 + noise(p / (crown_size * 0.41) + 9.3) * 0.35; }
void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	geom_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}

void fragment() {
	ROUGHNESS = 0.94;
	if (COLOR.g > 0.5) {
		if (COLOR.a < 0.75) {
			// Oak dome: olive, lit crown top over a darker skirt.
			ALBEDO = oak_crowns * (0.6 + 0.5 * COLOR.b) * (0.85 + 0.3 * COLOR.r);
		} else {
			vec3 needles = mix(pine_crowns, fir_crowns, COLOR.r);
			ALBEDO = needles * (0.55 + 0.6 * COLOR.b) * (0.85 + 0.3 * noise(world.xz * 0.7 + world.y * 0.9));
		}
	} else {
		vec2 p = world.xz;
		vec3 n = geom_normal;
		float big = noise(p / 60.0 + 3.1);
		float fine = noise(p * 0.21);
		// Near the claim reach the slopes take the terrain shader's look (duff floor, slate),
		// so the material change at |x| ~ 185 m does not show as a line.
		float seam = 1.0 - smoothstep(30.0, 95.0, abs(world.x) - 160.0);
		// The cliff bands take the ridge shader 45-85 m into the bend; there its rock
		// matches the terrain shader's sunlit slate, then settles darker up the ridges.
		float slate_match = 1.0 - smoothstep(50.0, 140.0, abs(world.x) - 160.0);
		float draw = COLOR.g / 0.45;
		// The bent reach's walls are sheared along the valley, so their fall lines run
		// steeper than the profile: timber holds to about 60 degrees, rock takes over beyond.
		float steep = 1.0 - smoothstep(0.38, 0.52, n.y + (fine - 0.5) * 0.16);
		// The first metres above the rim are the cliff top: broken slate going over to duff.
		// (UV.x is metres above the rim; below it the slope alone decides: cliff bands are
		// rock, the aprons scree, the benches duff and a little timber.)
		float rim_edge = (1.0 - smoothstep(8.0, 22.0, UV.x + (noise(p * 0.08) - 0.5) * 10.0)) * smoothstep(-4.0, -1.0, UV.x);
		float rock_m = clamp(max(max(COLOR.b * smoothstep(0.25, 0.55, COLOR.b + (fine - 0.5) * 0.5), steep), rim_edge * 0.85), 0.0, 1.0);
		float scree_m = smoothstep(0.25, 0.6, COLOR.a + (noise(p * 0.5) - 0.5) * 0.35) * (1.0 - rock_m);
		float forest = COLOR.r * smoothstep(0.36, 0.6, n.y) * (1.0 - scree_m);

		// Open ground: duff under timber and in shade, chaparral and cured grass on the sun side.
		float sunny = smoothstep(-0.05, -0.45, n.z) * (1.0 - 0.6 * draw);
		float chap_m = smoothstep(0.42, 0.62, noise(p / 34.0 + 11.0) * 0.7 + big * 0.3 + sunny * 0.25 - forest * 0.3);
		float grass_m = smoothstep(0.55, 0.8, noise(p / 22.0 + 5.0) * 0.6 + sunny * 0.45 + n.y * 0.2 - forest * 0.5 - draw * 0.4) * (1.0 - seam);
		vec3 ground = duff * (0.85 + 0.3 * fine) * mix(1.0, 0.8, draw);
		ground = mix(ground, chaparral * (0.8 + 0.4 * fine), chap_m * (1.0 - 0.7 * seam));
		ground = mix(ground, grass * (0.85 + 0.3 * fine), grass_m);
		// Scree: pale angular rubble below bands and tors.
		ground = mix(ground, scree * (0.82 + 0.36 * noise(p * 1.3)), scree_m);

		vec3 rock_n = n;
		if (rock_m > 0.01) {
		// Rock: slate, greenstone and rust-weathered strata dipping like the claim walls'.
		float fbm_s = (inoise(p * 0.021) + 0.5 * inoise(p * 0.021 * 2.07 + vec2(17.3, 5.1))) / 1.5;
		float sc = world.y + 0.12 * world.x - 0.05 * world.z + (fbm_s - 0.5) * 7.0;
		float sid = floor(sc / 2.7), sf = fract(sc / 2.7);
		float tone = mix(ihash(vec2(sid, 5.0)), ihash(vec2(sid + 1.0, 5.0)), smoothstep(0.88, 1.0, sf));
		vec3 strata = tone < 0.3 ? vec3(0.84, 0.94, 1.10) * 0.92 : tone < 0.55 ? vec3(0.88, 1.04, 0.92) : tone < 0.78 ? vec3(1.16, 1.0, 0.80) * 1.08 : vec3(0.78, 0.80, 0.85) * 0.62;
		float band_tone = 0.88 + 0.24 * hash(vec2(floor(sc / 11.0), 9.0));
		// Rain streaks darken the faces in vertical runs.
		float along = world.x + 0.3 * world.z;
		float streak = smoothstep(0.55, 0.85, noise(vec2(along * 0.35, world.y * 0.012))) * steep;
		vec3 rock_col = rock * mix(vec3(1.0), strata, mix(0.55, 0.85, slate_match)) * mix(band_tone, 1.0, slate_match) * (1.0 - 0.3 * streak);
		{
			// Broken, jointed rock: blocks 5-12 m along the bedding and 3.5 m through it,
			// courses offset like masonry and their edges warped so no joint runs straight,
			// each block its own tone and tilt, so outcrops read as rock lit block by block,
			// not as grey paint on a smooth slope.
			vec2 q = vec2(along / 8.0, sc / 3.5);
			q += (vec2(noise(q * 0.6 + 1.3), noise(q * 0.6 + 7.7)) - 0.5) * 1.6;
			float course = floor(q.y);
			float len = 0.6 + 0.9 * hash(vec2(course, 2.0));
			float bx = q.x / len + hash(vec2(course, 7.0)) * 5.0;
			vec2 cell = vec2(floor(bx), course);
			vec2 f = vec2(fract(bx) * len * 8.0, fract(q.y) * 3.5);
			float edge = min(min(f.x, len * 8.0 - f.x), min(f.y, 3.5 - f.y) * 1.6);
			float tone_b = hash(cell + 3.7);
			float tilt = hash(cell + 8.1);
			float joint = (1.0 - smoothstep(0.15, 0.7, edge)) * step(0.3, tilt);
			// Next to the claim walls' slate the blocks fade, so the two materials meet softly.
			float blocky = 1.0 - 0.7 * slate_match;
			rock_col *= mix(1.0, (0.8 + 0.4 * tone_b) * (1.0 - 0.38 * joint), blocky);
			vec3 side = normalize(vec3(-n.z, 0.0, n.x) + vec3(0.0001));
			rock_n = normalize(n + (side * (tilt - 0.5) * 0.7 + vec3(0.0, (tone_b - 0.45) * 0.6, 0.0)) * blocky);
		}
		rock_col *= mix(1.35, 2.1, slate_match);
		ground = mix(ground, rock_col, rock_m);
		}

		// Timber: clumped crowns, pine on the open slopes, fir and cedar in the draws,
		// oaks scattered through the lower, sunnier stands.
		float c = crowns(p);
		float threshold = mix(0.8, 0.24, forest);
		float canopy = smoothstep(threshold - 0.07, threshold + 0.07, c + (big - 0.5) * 0.12) * (1.0 - rock_m);
		vec3 trees = mix(pine_crowns, fir_crowns, clamp(smoothstep(0.35, 0.65, noise(p / 40.0 + 5.0)) + draw * 0.5, 0.0, 1.0));
		trees = mix(trees, oak_crowns, smoothstep(0.62, 0.8, noise(p / 28.0 + 21.0)) * sunny * (1.0 - smoothstep(60.0, 140.0, world.y)));
		trees *= 0.55 + 0.6 * c;
		ALBEDO = mix(ground, trees, canopy);
		// Crown relief: the canopy height field tilts the normal, so the sun and shadow
		// sides of tree clumps read at distance.
		vec3 nn = mix(n, rock_n, rock_m);
		if (canopy > 0.01) {
			float e = 0.6;
			vec2 grad = vec2(crowns(p + vec2(e, 0.0)) - c, crowns(p + vec2(0.0, e)) - c) / e;
			nn -= vec3(grad.x, 0.0, grad.y) * 7.0 * canopy;
		}
		nn = normalize(nn);
		NORMAL = normalize((VIEW_MATRIX * vec4(nn, 0.0)).xyz);
		ROUGHNESS = mix(0.94, 0.85, rock_m);
	}
}
