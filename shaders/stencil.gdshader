// Painted shipping marks on sacks, crates and kegs (Wave C prop kit): a patch of the
// prop's own surface lifted 2-3 mm, cut out by the stencil atlas's worn paint mask.
shader_type spatial;
render_mode cull_back;
uniform sampler2D mask : hint_default_black, filter_linear_mipmap, repeat_disable;
uniform vec3 ink : source_color = vec3(.10, .075, .05);
void fragment() {
 float a = texture(mask, UV).r;
 ALBEDO = ink * COLOR.rgb;
 ROUGHNESS = .9;
 ALPHA = a;
 ALPHA_SCISSOR_THRESHOLD = .42;
}
