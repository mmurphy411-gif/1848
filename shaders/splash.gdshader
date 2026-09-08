shader_type spatial;
render_mode unshaded, cull_disabled;
varying float world_y;
void vertex() { world_y=(MODEL_MATRIX*vec4(VERTEX,1)).y; }
void fragment() { if(world_y<.003) discard; ALBEDO=vec3(.85,.91,.91); }
