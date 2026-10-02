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
// Mean luminance of the normalised scan albedos (all were tinted to the same mean).
uniform float scan_mean = 0.40;
uniform vec3 slate : source_color = vec3(0.40, 0.43, 0.47);
uniform vec3 greenstone : source_color = vec3(0.36, 0.42, 0.38);
uniform vec3 iron : source_color = vec3(0.50, 0.31, 0.15);
uniform vec3 lichen : source_color = vec3(0.60, 0.63, 0.55);
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

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnormal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	origin = MODEL_MATRIX[3].xyz;
}

void fragment() {
	vec3 scan = texture(albedo_map, UV).rgb;
	float scan_l = dot(scan, vec3(0.2126, 0.7152, 0.0722)) / scan_mean;
	vec3 w = pow(abs(wnormal), vec3(4.0));
	w /= w.x + w.y + w.z;
	vec3 p = world / detail_tile;
	vec3 d = texture(detail_map, p.zy).rgb * w.x + texture(detail_map, p.xz).rgb * w.y + texture(detail_map, p.xy).rgb * w.z;
	// Slate and greenstone in patches tens of metres across, varied per piece.
	float rock_kind = noise(world.xz * 0.025 + origin.xz * 0.11) * 0.7 + noise(world.xy * 0.09) * 0.3;
	vec3 base = mix(slate, greenstone, smoothstep(0.42, 0.72, rock_kind));
	float tone = mix(scan_l, d.r * 2.0, detail_strength);
	vec3 col = base * clamp(tone, 0.25, 1.8);
	// Iron staining: the stain pattern, streaked downward on steep faces.
	float streak = noise(vec2((world.x + world.z) * 0.7, world.y * 0.06)) * noise(vec2((world.x - world.z) * 0.23, world.y * 0.02 + 3.0));
	float steep = 1.0 - smoothstep(0.55, 0.9, wnormal.y);
	float stain = smoothstep(0.45, 0.9, d.g * 0.65 + streak * 0.9 * steep) * iron_amount;
	col = mix(col, iron * clamp(0.6 + 0.5 * scan_l, 0.4, 1.4), stain);
	// Lichen on surfaces that face the sky.
	float lichen_mask = smoothstep(0.45, 0.8, d.b) * smoothstep(0.3, 0.75, wnormal.y) * lichen_amount;
	col = mix(col, lichen * clamp(0.7 + 0.3 * scan_l, 0.5, 1.2), lichen_mask);
	ALBEDO = col;
	NORMAL_MAP = texture(normal_map, UV).rgb;
	vec3 orm = texture(orm_map, UV).rgb;
	AO = orm.r;
	AO_LIGHT_AFFECT = 0.3;
	ROUGHNESS = clamp(mix(orm.g, 0.88, 0.4) + lichen_mask * 0.1, 0.0, 1.0);
}
