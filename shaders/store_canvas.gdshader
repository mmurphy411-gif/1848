shader_type spatial;
render_mode cull_disabled;
uniform sampler2D atlas : source_color, filter_linear_mipmap;
void fragment(){
 vec3 cloth=texture(atlas,UV).rgb;
 ALBEDO=cloth;ROUGHNESS=.94;BACKLIGHT=cloth*.55;
}
