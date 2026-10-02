shader_type spatial;
render_mode diffuse_burley;
uniform vec4 coat_color : source_color = vec4(.25,.20,.15,1);
uniform bool feathered = false;
// Skinned intake models: fur noise follows rest-pose coordinates carried in UV/UV2
// (blender/normalize_animal.py --rest-uv), so it does not swim as the legs move.
uniform bool rest_uv = false;
// Textured intake models: photo coat in the albedo map, noise only as fine strands.
uniform bool use_texture = false;
uniform sampler2D coat_texture : source_color, filter_linear_mipmap_anisotropic;
uniform float strand_scale = 1.0;
varying vec3 local_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
	vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex() {
	local_position=rest_uv ? vec3(UV.x,UV2.x,UV.y-1.0) : VERTEX;
}
void fragment() {
	vec3 p=local_position*strand_scale;
	float broad=noise(p*24.0);
	float strand=noise(p*vec3(1400.0,120.0,240.0));
	float detail=mix(strand,.5,clamp(length(fwidth(p))*650.0,0.0,1.0));
	float tone=.94+.08*broad+.28*(detail-.5);
	if (feathered) tone=.96+.07*broad+.035*sin(p.z*2100.0+p.y*350.0)*(1.0-clamp(length(fwidth(p))*900.0,0.0,1.0));
	vec3 base=coat_color.rgb*COLOR.rgb;
	float wet=0.0;
	if (use_texture) {
		base*=texture(coat_texture,UV).rgb; tone=1.0+.18*(detail-.5);
		// Near-black coat texels are the painted eyes: give them a wet glint.
		wet=1.0-smoothstep(.02,.06,dot(base,vec3(.3,.59,.11)));
	}
	ALBEDO=base*tone;
	ROUGHNESS=mix(.92,.1,wet);
	SPECULAR=mix(.23,.75,wet);
	NORMAL_MAP=vec3(.5+(detail-.5)*.22,.5+(broad-.5)*.08,1.0);
	NORMAL_MAP_DEPTH=.45;
}
