// Stage 1 cloud field shared by the sky dome (sky_clouds.gdshader) and the ground
// shadows (cloud_shadows.gdshader), so every shadow belongs to a visible cloud.
// Uniforms are set together by scripts/sky_clouds.gd.
uniform sampler2D cloud_shape : repeat_enable, filter_linear_mipmap;
uniform sampler2D cloud_billow : repeat_enable, filter_linear_mipmap;
// 0 open sky .. 1 closed overcast; softness widens the cloud edges.
uniform float coverage : hint_range(0.0, 1.2) = 0.35;
uniform float softness : hint_range(0.01, 0.5) = 0.12;
// Texture tiles per (metre / layer height): larger values make smaller clouds.
uniform float layer_scale = 0.06;
// Height of the layer above the claim, metres: anchors the clouds to the world
// and sets their ground size (shadows of a few hundred metres to a kilometre).
uniform float layer_height = 400.0;
uniform vec2 shape_offset = vec2(0.0);
uniform vec2 billow_offset = vec2(0.0);

float cloud_threshold() {
	return mix(0.72, 0.2, coverage);
}

// Heaped field: cluster placement, cauliflower detail, puffy rims.
float cloud_field(vec2 p) {
	float macro = texture(cloud_shape, p + shape_offset).r;
	float detail = texture(cloud_shape, p * 3.7 + billow_offset).r;
	float puffs = texture(cloud_billow, p * 7.0 + billow_offset * 1.9).r;
	return macro * 0.6 + detail * 0.24 + puffs * 0.16;
}

// The same field without the small puffs, for soft-edged ground shadows.
float cloud_field_soft(vec2 p) {
	float macro = texture(cloud_shape, p + shape_offset).r;
	float detail = texture(cloud_shape, p * 3.7 + billow_offset, 1.5).r;
	return macro * 0.6 + detail * 0.24 + 0.08;
}

// Layer coordinates of the world point `xz` (metres) on the cloud layer.
vec2 cloud_layer_uv(vec2 xz) {
	return xz * layer_scale / layer_height;
}
