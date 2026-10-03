shader_type spatial;
// Stage 2 cliff, outcrop and talus kit (assets/cliffs/). The Poly Haven scans are tan
// sandstone and granite; the normaliser already pulled them to a neutral grey, and this
// shader re-skins them as the North Yuba's blue-grey slate and greenstone: the scan's
// own light and dark (cracks, ledges, baked AO) times a world-space slate-strata detail,
// iron staining that runs down steep faces, and pale lichen on upward-facing rock.
uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : filter_linear_mipmap;
// R slate strata, G iron-stain pattern, B lichen mask (tools/art/build_cliff_detail.py).
uniform sampler2D detail_map : filter_linear_mipmap_anisotropic, repeat_enable;
uniform float detail_tile = 2.6;
uniform float detail_strength = 0.5;
// Mean linear luminance of the normalised scan albedos (cliff pieces 0.146-0.152, talus
// 0.138). Wave C: Stage 2 used their sRGB mean (0.40), which left the kit at about two
// thirds of its intended albedo and half the terrain's slate - outcrops read as dark rock
// set onto pale walls.
uniform float scan_mean = 0.147;
// Wave C: the terrain shader's slate (its bedrock set averages 0.24/0.265/0.266 linear),
// so kit pieces and the walls they stand on are the same rock.
uniform vec3 slate : source_color = vec3(0.43, 0.455, 0.46);
uniform vec3 greenstone : source_color = vec3(0.40, 0.45, 0.40);
uniform vec3 iron : source_color = vec3(0.52, 0.33, 0.17);
uniform vec3 lichen : source_color = vec3(0.62, 0.64, 0.56);
uniform float iron_amount = 0.55;
uniform float lichen_amount = 0.6;
varying vec3 world;
varying vec3 wnormal;
varying vec3 origin;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
// terrain.gdshader's integer hash, value noise and fbm, so the strata below continue
// the walls' bands across the kit pieces exactly.
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
float ifbm(vec2 p) { return (inoise(p) + .5 * inoise(p * 2.07 + vec2(17.3, 5.1))) / 1.5; }

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	origin = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 scan = texture(albedo_map, UV).rgb;
	// The scan's light and dark, eased: in linear light its crevices ran near black.
	float scan_l = pow(dot(scan, vec3(0.2126, 0.7152, 0.0722)) / scan_mean, 0.75);
	vec3 w = pow(abs(wnormal), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 p = world / detail_tile;
	vec3 d = texture(detail_map, p.zy).rgb * w.x + texture(detail_map, p.xz).rgb * w.y + texture(detail_map, p.xy).rgb * w.z;
	// Slate and greenstone in patches tens of metres across, varied per piece.
	float rock_kind = noise(world.xz * 0.025 + origin.xz * 0.11) * 0.7 + noise(world.xy * 0.09) * 0.3;
	vec3 base = mix(slate, greenstone, smoothstep(0.42, 0.72, rock_kind));
	float tone = mix(scan_l, d.r * 2.0, detail_strength);
	vec3 col = base * clamp(tone, 0.3, 1.7);
	// The walls' strata (terrain.gdshader): slate, greenstone, weathered brown and dark
	// layers 2.7 m thick, dipping gently, so a piece's bands line up with the wall's.
	float steep_w = 1.0 - smoothstep(0.55, 0.8, wnormal.y);
	float sc = world.y + .12 * world.x - .05 * world.z + (ifbm(world.xz * .021) - .5) * 7.0;
	float sid = floor(sc / 2.7), sf = fract(sc / 2.7);
	float stone = mix(ihash(vec2(sid, 5.0)), ihash(vec2(sid + 1.0, 5.0)), smoothstep(.88, 1.0, sf));
	vec3 strata = stone < .3 ? vec3(.84, .94, 1.10) * .92 : stone < .55 ? vec3(.88, 1.04, .92) : stone < .78 ? vec3(1.16, 1.0, .80) * 1.08 : vec3(.78, .80, .85) * .62;
	col *= mix(vec3(1.0), strata, 0.7 + 0.2 * steep_w);
	// Iron staining: the stain pattern, streaked downward on steep faces.
	float streak = noise(vec2((world.x + world.z) * 0.7, world.y * 0.06)) * noise(vec2((world.x - world.z) * 0.23, world.y * 0.02 + 3.0));
	float steep = 1.0 - smoothstep(0.55, 0.9, wnormal.y);
	float stain = smoothstep(0.45, 0.9, d.g * 0.65 + streak * 0.9 * steep) * iron_amount;
	col = mix(col, iron * clamp(0.6 + 0.5 * scan_l, 0.4, 1.4), stain);
	// Lichen on surfaces that face the sky.
	float lichen_mask = smoothstep(0.45, 0.8, d.b) * smoothstep(0.3, 0.75, wnormal.y) * lichen_amount;
	col = mix(col, lichen * clamp(0.7 + 0.3 * scan_l, 0.5, 1.2), lichen_mask);
	// In the bend the pieces stand on ridge_forest.gdshader's rock, which is paler.
	col *= 1.0 + 0.3 * smoothstep(170.0, 280.0, abs(world.x));
	ALBEDO = col;
	// Rock is a poor mirror; the default 0.5 put moonlit sheen on faces turned to the moon.
	SPECULAR = 0.3;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	vec3 orm = texture(orm_map, UV).rgb;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.3;
	ROUGHNESS = clamp(mix(orm.g, 0.88, 0.4) + lichen_mask * 0.1, 0.0, 1.0);
}
