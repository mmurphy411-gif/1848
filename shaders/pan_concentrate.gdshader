shader_type spatial;
render_mode cull_disabled;
varying vec3 local;
void vertex() { local=VERTEX; }
float grain(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 p=local.xz;
 float g=grain(floor(p*1800.0));
 float fines=grain(floor(p*510.0));
 float edge=.146+.004*sin(atan(p.y,p.x)*5.0)+.002*sin(atan(p.y,p.x)*13.0);
 if(length(p)>edge) discard;
 ALBEDO=mix(vec3(.018,.02,.019),vec3(.055,.048,.034),g*.6+fines*.4);
 ROUGHNESS=.67+g*.2;
 METALLIC=.12;
}
