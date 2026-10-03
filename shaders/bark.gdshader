shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
#include "res://shaders/wind.gdshaderinc"
// Scanned bark (CC0, Poly Haven) in one Texture2DArray; layer per species, see Assets.BARK_LAYER.
// UVs are in tiles: tools/art/build_trees.mjs maps them in metres along each branch.
uniform sampler2DArray bark_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2DArray bark_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float layer=3.0;
// Gentle multiplier from the caller's bark colour (Assets.plant normalises it).
uniform vec3 tint : source_color=vec3(1.0);
// Per-layer grade (Assets.BARK_LOOK): albedo gain and saturation, normal depth, and how much
// the scan's own dark furrows occlude indirect light. A trunk in crown shade is lit only
// indirectly, so the furrows (cavity) are what keep its plates readable there.
uniform float gain=1.0;
uniform float saturation=1.0;
uniform float normal_depth=1.2;
uniform float cavity=0.0;
// Mean linear luminance of the layer, the furrow reference.
uniform float mean_luma=.1;
uniform float review_time=-1.0;
varying vec3 local;
varying float brightness;
void vertex(){
 local=VERTEX;
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float phase=MODEL_MATRIX[3].x*.71+MODEL_MATRIX[3].z*.39;
 float wind_time=review_time>=0.0?review_time:TIME;
 float sway=wind_sway(wind_time,phase,world.y,COLOR.r);
 vec3 offset=vec3(sway,0.0,sway*.24);
 vec3 x=MODEL_MATRIX[0].xyz,y=MODEL_MATRIX[1].xyz,z=MODEL_MATRIX[2].xyz;
 VERTEX+=vec3(dot(x,offset)/dot(x,x),dot(y,offset)/dot(y,y),dot(z,offset)/dot(z,z));
 brightness=1.0+INSTANCE_CUSTOM.x*.25;
}
void fragment(){
 vec3 uvw=vec3(UV,layer);
 vec3 a=texture(bark_albedo,uvw).rgb;
 float l=dot(a,vec3(.2126,.7152,.0722));
 ALBEDO=mix(vec3(l),a,saturation)*gain*tint*brightness;
 NORMAL_MAP=texture(bark_normal,uvw).rgb;
 NORMAL_MAP_DEPTH=normal_depth;
 AO=mix(1.0,clamp(pow(l/mean_luma,.8),.3,1.0),cavity);
 AO_LIGHT_AFFECT=cavity*.35;
 ROUGHNESS=.92;
}
