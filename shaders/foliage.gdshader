shader_type spatial;
render_mode cull_disabled, alpha_to_coverage, diffuse_lambert, specular_disabled;
#include "res://shaders/wind.gdshaderinc"
// Calendar progress, 0 = June 26 ... 1 = November 5 (first snow); see scripts/vegetation.gd.
global uniform float season;
uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap;
uniform bool leaves=false;
uniform bool use_atlas=true;
uniform float review_time=-1.0;
uniform vec3 tint : source_color=vec3(.2,.35,.08);
// Seasonal response: leaves move toward autumn_color (keeping their luminance detail) over the
// season window x..y, weighted by autumn_strength; past drop_start, cards fall away in random order.
uniform vec3 autumn_color : source_color=vec3(.62,.5,.18);
uniform vec2 autumn_window=vec2(2.0,3.0);
uniform float autumn_strength=1.0;
uniform float drop_start=2.0;
// Luminance of the atlas's mean leaf colour (linear), so the autumn colour keeps texture detail.
uniform float atlas_luma=.08;
// Leaf flutter on top of the shared sway (metres at full wind weight).
uniform float flutter=.025;
// Flowers (non-atlas plants) fade out of bloom over this season window.
uniform vec2 bloom_window=vec2(2.0,3.0);
// Understory stems share the leaf surface (one draw): COLOR.b = 1 marks opaque bark.
uniform vec3 stem_color : source_color=vec3(.32,.26,.2);
varying vec3 local;
varying float distance_fade;
varying float timing;
varying vec3 variation;
varying float stem;
void vertex(){
 local=VERTEX;
 stem=use_atlas?COLOR.b:0.0;
 vec3 w=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 distance_fade=smoothstep(20.0,140.0,distance(w,CAMERA_POSITION_WORLD));
 float phase=MODEL_MATRIX[3].x*.71+MODEL_MATRIX[3].z*.39;
 float wind_time=review_time>=0.0?review_time:TIME;
 float sway=wind_sway(wind_time,phase,w.y,COLOR.r);
 // World amplitude remains <= 14 cm, including instances scaled to 1.2.
 vec3 offset=vec3(sway,0.0,sway*.24);
 if(leaves && use_atlas && stem<.5) offset+=NORMAL*sin(wind_time*3.1+COLOR.g*37.0+phase)*flutter*COLOR.r;
 vec3 x=MODEL_MATRIX[0].xyz,y=MODEL_MATRIX[1].xyz,z=MODEL_MATRIX[2].xyz;
 // Orthogonal instance bases: inverse direction without a per-vertex 4x4 inverse.
 VERTEX+=vec3(dot(x,offset)/dot(x,x),dot(y,offset)/dot(y,y),dot(z,offset)/dot(z,z));
 // Per-instance variation (MultiMesh custom data; zero for plain MeshInstance3D):
 // x brightness, y season timing, z hue. Per-card COLOR.g adds timing spread inside a crown.
 variation=INSTANCE_CUSTOM.xyz;
 timing=INSTANCE_CUSTOM.y*.10+(COLOR.g-.5)*.10;
}
void fragment(){
 if(leaves){
   vec4 c;
   if(use_atlas && stem>.5){
     float grain=.82+.28*fract(sin(dot(floor(local*vec3(40.0,9.0,40.0)),vec3(12.99,78.23,37.71)))*43758.55);
     c=vec4(stem_color*grain*(1.0+variation.x*.35),1.0);
   }else if(use_atlas){
     c=texture(leaf_atlas,UV);
     // Mip levels lose alpha coverage; lower the cut with distance so crowns keep their mass.
     c.a=clamp(c.a*mix(1.0,1.45,distance_fade),0.0,1.0);
     float s=season+timing;
     float turn=smoothstep(autumn_window.x,autumn_window.y,s)*autumn_strength;
     float detail=clamp(dot(c.rgb,vec3(.2126,.7152,.0722))/atlas_luma,.35,1.8);
     // Some cards turn browner than others.
     vec3 autumn=mix(autumn_color,autumn_color*vec3(.78,.55,.45),step(.72,fract(COLOR.g*7.13)));
     c.rgb=mix(c.rgb,autumn*detail,turn);
     if(s>drop_start && fract(COLOR.g*13.7)<(s-drop_start)*3.0) c.a=0.0;
     c.rgb*=1.0+variation.x*.35;
     c.rgb=mix(c.rgb,c.rgb*vec3(1.12,1.04,.78),clamp(variation.z,0.0,1.0));
   }else{
     c=vec4(COLOR.b>0.0?tint:vec3(.19,.23,.095),1);
     if(COLOR.b==0.0) {
       float blade=0.0;
       for(int i=0;i<6;i++) { float f=float(i); float height=.64+.35*sin(f*1.71+1.0); float bend=sin(f*2.3)*.10*UV.y*UV.y; float width=.014*(1.0-UV.y/height); blade=max(blade,(1.0-smoothstep(width,width+.003,abs(UV.x-(.08+f*.165+bend))))*(1.0-smoothstep(height-.04,height,UV.y))); }
       c.a=blade;
       c.rgb=mix(c.rgb,vec3(.42,.33,.13),smoothstep(.03,.30,season));
     }else{
       c.a*=1.0-smoothstep(bloom_window.x,bloom_window.y,season);
     }
   }
   ALBEDO=c.rgb; ALPHA=c.a; ALPHA_SCISSOR_THRESHOLD=.38; ALPHA_ANTIALIASING_EDGE=.25; ALPHA_TEXTURE_COORDINATE=UV*2048.0;
   // Card normals are bent outward from the crown; keep them outward on back faces too.
   if(use_atlas && stem<.5 && !FRONT_FACING) NORMAL=-NORMAL;
   BACKLIGHT=c.rgb*.32*(1.0-stem);
   ROUGHNESS=.85;
 }else{
   float fissure=pow(.5+.5*sin(local.x*34.0+sin(local.y*1.7)*2.0+local.z*31.0),8.0);
   float plate=.90+.10*sin(floor(local.y*2.7)*3.71+floor(atan(local.z,local.x)*7.0));
   ALBEDO=tint*plate*(1.0-fissure*.58);
   ROUGHNESS=.93;
 }
}
