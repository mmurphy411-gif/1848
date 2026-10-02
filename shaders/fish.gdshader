shader_type spatial;
render_mode cull_disabled;
// River fish (VISUAL_UPGRADE_NOTES.md, Stage 5): the species atlas colours the flanks;
// the shader adds a dark dorsal and pale belly (countershading, the read from above),
// species spotting, overlapping-scale relief that fades with distance, silvered flanks
// and a wet slime coat.
uniform sampler2D scales : source_color, filter_linear_mipmap;
uniform float length_m=.36;
uniform float pace=1.0;
uniform float phase=0.0;
uniform float visibility=1.0;
// Half the body depth in model units; the mesh's vertical extent.
uniform float half_depth=.07;
uniform vec3 back_color : source_color = vec3(.17,.20,.14);
uniform vec3 belly_color : source_color = vec3(.80,.80,.76);
uniform float countershade=.9;
// Round black spots on back, upper flank and tail (trout, Chinook), as density 0..1.
uniform float spot_density=0.0;
uniform float silver=.35;
// The eye spheres (surfaces after the first) share the fade but are glossy black.
uniform bool eye=false;
varying vec3 local;
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
// Distance to the nearest jittered cell centre (cellular noise).
float cells(vec2 p){
	vec2 i=floor(p),f=fract(p);float d=8.0;
	for(int y=-1;y<=1;y++)for(int x=-1;x<=1;x++){
		vec2 o=vec2(float(x),float(y));
		vec2 c=o+vec2(hash(i+o),hash(i+o+17.3))*.8+.1;
		d=min(d,length(c-f));
	}
	return d;
}
void vertex(){
	local=VERTEX;
	float tail=smoothstep(-length_m*.35,length_m*.5,VERTEX.x);
	VERTEX.z+=sin(TIME*pace*6.0-VERTEX.x*18.0+phase)*.018*tail;
}
void fragment(){
	vec3 flank=texture(scales,UV).rgb;
	float h=clamp(local.y/max(half_depth,.001),-1.0,1.0);
	float dorsal=smoothstep(-.05,.85,h);
	float belly=smoothstep(.05,-.8,h);
	vec3 col=mix(flank,back_color*(.7+.6*flank),dorsal*countershade);
	col=mix(col,belly_color*(.75+.25*flank/max(max(flank.r,flank.g),max(flank.b,.05))),belly*countershade*.8);
	// Spots: cells across the side (x along the body, angle around it) above the belly.
	float around=atan(local.y,local.z);
	vec2 sp=vec2(local.x/length_m*34.0,around*4.2);
	float spot=1.0-smoothstep(.16,.24,cells(sp));
	spot*=step(hash(floor(sp)+3.1),spot_density)*smoothstep(-.35,.1,h);
	col*=1.0-.72*spot;
	// Overlapping scale rows: a crescent relief that fades out where texels shrink.
	vec2 sc=vec2(local.x/length_m*95.0,around*11.0);
	sc.y+=floor(sc.x)*.5;
	vec2 f=fract(sc)-.5;
	float rim=smoothstep(.5,.15,length(f*vec2(1.0,1.3)));
	float fade=1.0-clamp(length(fwidth(sc))*.9,0.0,1.0);
	NORMAL_MAP=vec3(.5+f.x*.35*rim*fade,.5+f.y*.35*rim*fade,1.0);
	NORMAL_MAP_DEPTH=.6;
	ALBEDO=col*(1.0-.06*rim*fade);
	// Opaque dither fade keeps fish in the screen/depth snapshot the existing
	// water shader refracts. Alpha blending would draw fish over the water.
	if(fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453)>visibility)discard;
	METALLIC=silver*(1.0-dorsal*.75);
	ROUGHNESS=mix(.40,.26,belly);
	SPECULAR=.55;
	CLEARCOAT=.35;
	CLEARCOAT_ROUGHNESS=.14;
	if(eye){ALBEDO=vec3(.015,.014,.012);METALLIC=0.0;ROUGHNESS=.08;NORMAL_MAP=vec3(.5,.5,1.0);}
}
