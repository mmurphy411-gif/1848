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

// Wave C: Columbian black-tailed deer coat, laid out from rest-pose landmarks instead of the
// intake's flat material colours (scripts/wildlife_actor.gd DEER sets them per model):
// grey-brown back over a paler flank, cream belly and inner legs, dark lower legs, a white
// rump patch round a tail that is black on top, a grey face with a pale muzzle band, white
// chin and throat patch, darker crown and ear rims. Rest metres: x lateral, y up, head -z.
uniform bool deer_coat = false;
uniform vec4 torso = vec4(.6, 1.03, .16, 1.0);    // belly y, back y, half width, size
uniform vec4 rear = vec4(.66, .9, .1, .38);       // tail z, tail y, rump half width, hind legs' front z
uniform vec4 fore = vec4(-.45, -.27, -.05, 1.14); // head z, neck z, front legs' back z, throat y
uniform vec4 face = vec4(-.75, 1.33, .07, 0.0);   // nose tip z, eye y, ear root |x|
// How far the body's normal bends toward the smooth cross-section (0 keeps the facets).
uniform float body_normal = .85;
// The buck's rack: dark brown-grey beams, paler worn tines (distance from the base).
uniform bool antler = false;
uniform vec4 antler_base = vec4(0.0, 1.55, -.55, .4);

varying vec3 local_position;
float hash(vec3 p) { return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453); }
float noise(vec3 p) {
	vec3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
	return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
float band(float x, float a, float b, float soft) { return smoothstep(a - soft, a + soft, x) * (1.0 - smoothstep(b - soft, b + soft, x)); }

vec3 deer_color(vec3 p) {
	const vec3 DORSAL = vec3(.135, .106, .080);
	const vec3 FLANK = vec3(.195, .148, .100);
	const vec3 CREAM = vec3(.34, .29, .23);
	const vec3 WHITE = vec3(.50, .47, .41);
	const vec3 LEG = vec3(.150, .116, .083);
	const vec3 LOWLEG = vec3(.072, .060, .050);
	const vec3 FACE = vec3(.140, .115, .090);
	const vec3 BLACK = vec3(.018, .016, .014);
	float s = torso.w;
	float ax = abs(p.x);
	float t = (p.y - torso.x) / (torso.y - torso.x);
	// Body: the flank darkens to a grey-brown saddle; the neck carries the saddle forward.
	vec3 c = mix(FLANK, DORSAL, smoothstep(.55, 1.05, t));
	// Legs below the body line, darker to the hoof.
	float leg = 1.0 - smoothstep(torso.x - .1 * s, torso.x + .03 * s, p.y);
	c = mix(c, mix(LOWLEG, LEG, smoothstep(.22 * s, .42 * s, p.y)), leg);
	// Belly between the legs, and the inside of the legs.
	float between = band(p.z, fore.z, rear.w, .05 * s);
	c = mix(c, CREAM, (1.0 - smoothstep(-.02, .3, t)) * between);
	float inner = (1.0 - smoothstep(.045 * s, .075 * s, ax)) * band(p.y, .3 * s, torso.x + .05 * s, .05 * s);
	c = mix(c, CREAM, inner * .85);
	// Rump patch round the tail.
	float rump = smoothstep(rear.x - .2 * s, rear.x - .06 * s, p.z) * (1.0 - smoothstep(rear.z * .55, rear.z * 1.25, ax))
		* band(p.y, rear.y - .28 * s, rear.y, .05 * s);
	c = mix(c, WHITE, rump * .9);
	// Tail: black over its outer face, the tip blackest; white beneath.
	float tail = (1.0 - smoothstep(.03 * s, .05 * s, ax)) * smoothstep(rear.x - .005, rear.x + .025 * s, p.z)
		* smoothstep(rear.y - .1 * s, rear.y - .06 * s, p.y);
	c = mix(c, BLACK, tail);
	// Throat patch.
	float throat = 1.0 - smoothstep(.035 * s, .075 * s, length(vec3(p.x * 1.2, p.y - fore.w, p.z - (fore.x + .02 * s))));
	c = mix(c, WHITE, throat);
	// Head: grey face, darker crown, pale muzzle band and chin, ears with dark rims.
	float head = smoothstep(fore.x + .03 * s, fore.x - .02 * s, p.z) * smoothstep(fore.w + .01 * s, fore.w + .05 * s, p.y);
	vec3 h = FACE;
	h = mix(h, DORSAL * .75, smoothstep(face.y + .01 * s, face.y + .05 * s, p.y) * (1.0 - smoothstep(face.z * .8, face.z * 1.2, ax)));
	float muzzle = band(p.z, face.x + .03 * s, face.x + .1 * s, .015 * s);
	h = mix(h, CREAM * .9, muzzle);
	float chin = (1.0 - smoothstep(face.y - .1 * s, face.y - .07 * s, p.y)) * (1.0 - smoothstep(face.x + .12 * s, face.x + .2 * s, p.z));
	h = mix(h, WHITE, chin);
	float ear = smoothstep(face.z, face.z + .02 * s, ax) * smoothstep(face.y - .1 * s, face.y - .06 * s, p.y);
	h = mix(h, mix(FACE * 1.05, BLACK * 2.0, smoothstep(face.z + .11 * s, face.z + .16 * s, ax)), ear);
	return mix(c, h, head);
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
	float normal_depth=.45;
	if (use_texture) {
		base*=texture(coat_texture,UV).rgb; tone=1.0+.18*(detail-.5);
		// Near-black coat texels are the painted eyes: give them a wet glint.
		wet=1.0-smoothstep(.02,.06,dot(base,vec3(.3,.59,.11)));
	}
	if (deer_coat) {
		base=deer_color(local_position);
		// Fur lies along the body: fine strands only, no blotches.
		tone=.97+.04*broad+.16*(detail-.5);
		normal_depth=.25;
		// The low-poly body's facets and muscle lumps shade as dark blotches on the flank:
		// bend the normal toward an elliptical body cross-section (rest space, carried to
		// view space through the screen-space derivatives of both positions).
		vec3 rp=local_position;
		float yc=(torso.x+torso.y)*.5, ry=(torso.y-torso.x)*.5, rx=torso.z;
		float body=band(rp.z,fore.y,rear.x-.08*torso.w,.08*torso.w)*smoothstep(torso.x-.05*torso.w,torso.x+.08*torso.w,rp.y);
		if (body>0.0) {
			vec3 proxy=normalize(vec3(rp.x/(rx*rx),(rp.y-yc)/(ry*ry),0.0));
			vec3 a1=dFdx(rp),a2=dFdy(rp),b1=dFdx(VERTEX),b2=dFdy(VERTEX);
			vec3 a3=cross(a1,a2),b3=cross(b1,b2);
			float la=length(a3),lb=length(b3);
			if (la>1e-12 && lb>1e-12) {
				float scale=sqrt(lb/la);
				// Rest -> view is a rotation times a scale s: it takes a3 to b3 / s.
				mat3 A=mat3(a1,a2,a3);
				mat3 B=mat3(b1,b2,b3/scale);
				vec3 view_proxy=normalize(B*inverse(A)*proxy);
				if (dot(view_proxy,NORMAL)<0.0) view_proxy=-view_proxy;
				NORMAL=normalize(mix(NORMAL,view_proxy,body_normal*body));
			}
		}
	}
	if (antler) {
		float d=length(local_position-antler_base.xyz)/antler_base.w;
		base=mix(vec3(.048,.038,.028),vec3(.20,.18,.15),smoothstep(.8,1.15,d));
		tone=.96+.06*broad;
		normal_depth=.2;
	}
	ALBEDO=base*tone;
	ROUGHNESS=mix(.92,.1,wet);
	SPECULAR=mix(.23,.75,wet);
	NORMAL_MAP=vec3(.5+(detail-.5)*.22,.5+(broad-.5)*.08,1.0);
	NORMAL_MAP_DEPTH=normal_depth;
}
