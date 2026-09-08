shader_type spatial;
render_mode cull_disabled;
uniform sampler2D scales : source_color;
uniform float length_m=.36;
uniform float pace=1.0;
uniform float phase=0.0;
uniform float visibility=1.0;
void vertex(){
 float tail=smoothstep(-length_m*.35,length_m*.5,VERTEX.x);
 VERTEX.z+=sin(TIME*pace*6.0-VERTEX.x*18.0+phase)*.018*tail;
}
void fragment(){
 ALBEDO=texture(scales,UV).rgb;
 // Opaque dither fade keeps fish in the screen/depth snapshot the existing
 // water shader refracts. Alpha blending would draw fish over the water.
 if(fract(sin(dot(FRAGCOORD.xy,vec2(12.9898,78.233)))*43758.5453)>visibility)discard;
 METALLIC=.18;ROUGHNESS=.38;
}
