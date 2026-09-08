shader_type spatial;
uniform sampler2D body_albedo : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D body_normal : hint_normal, filter_linear_mipmap_anisotropic;
uniform vec3 tint : source_color = vec3(1.0);
uniform bool textured = true;
uniform bool wettable = false;
uniform bool worn_knees = false;
uniform float normal_strength = .65;
uniform float wet_line = 0.0;
uniform float feet_y = 0.0;
varying float height;
void vertex() { height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y-feet_y; }
void fragment() {
 ALBEDO=textured ? texture(body_albedo,UV).rgb : tint;
 if(worn_knees) {
   float wear=1.0-smoothstep(.35,1.0,length((UV-vec2(.865,.232))/vec2(.045,.045)));
   ALBEDO=mix(ALBEDO,ALBEDO*1.40,wear*.65);
 }
 if(textured) { NORMAL_MAP=texture(body_normal,UV).rgb; NORMAL_MAP_DEPTH=normal_strength; }
 float wet=wettable ? (1.0-smoothstep(max(0.0,wet_line-.10),wet_line+.10,height))*smoothstep(0.0,.03,wet_line) : 0.0;
 ALBEDO*=mix(1.0,.48,wet);
 ROUGHNESS=mix(.88,.30,wet);
}
