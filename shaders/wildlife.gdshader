shader_type spatial;
render_mode diffuse_burley;
uniform vec4 coat_color : source_color = vec4(.25,.20,.15,1);
uniform bool feathered = false;
varying vec3 local_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
	vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() { local_position=VERTEX; }
void fragment() {
	vec3 p=local_position;
	float broad=noise(p*24.0);
	float strand=noise(p*vec3(1400.0,120.0,240.0));
	float detail=mix(strand,.5,clamp(length(fwidth(p))*650.0,0.0,1.0));
	float tone=.94+.08*broad+.28*(detail-.5);
	if (feathered) tone=.96+.07*broad+.035*sin(p.z*2100.0+p.y*350.0)*(1.0-clamp(length(fwidth(p))*900.0,0.0,1.0));
	ALBEDO=coat_color.rgb*COLOR.rgb*tone;
	ROUGHNESS=.92;
	SPECULAR=.23;
	NORMAL_MAP=vec3(.5+(detail-.5)*.22,.5+(broad-.5)*.08,1.0);
	NORMAL_MAP_DEPTH=.45;
}
