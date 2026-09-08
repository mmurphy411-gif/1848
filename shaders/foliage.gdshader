shader_type spatial;
render_mode cull_disabled, alpha_to_coverage, diffuse_lambert, specular_disabled;
uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap;
uniform bool leaves=false;
uniform bool use_atlas=true;
uniform vec3 tint : source_color=vec3(.2,.35,.08);
varying vec3 local;
varying float atlas_bias;
void vertex(){
 local=VERTEX;
 vec3 w=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 atlas_bias=smoothstep(25.0,90.0,distance(w,CAMERA_POSITION_WORLD));
 float phase=MODEL_MATRIX[3].x*.71+MODEL_MATRIX[3].z*.39;
 float sway=(sin(TIME*.83+phase+w.y*.14)*.095+sin(TIME*1.91+phase*.73)*.045)*COLOR.r;
 // World amplitude remains <= 14 cm, including instances scaled to 1.2.
 vec3 offset=vec3(sway,0.0,sway*.24);
 vec3 x=MODEL_MATRIX[0].xyz,y=MODEL_MATRIX[1].xyz,z=MODEL_MATRIX[2].xyz;
 // Orthogonal instance bases: inverse direction without a per-vertex 4x4 inverse.
 VERTEX+=vec3(dot(x,offset)/dot(x,x),dot(y,offset)/dot(y,y),dot(z,offset)/dot(z,z));
}
void fragment(){
 if(leaves){
   vec4 c=use_atlas?texture(leaf_atlas,UV,atlas_bias):vec4(COLOR.b>0.0?tint:vec3(.19,.23,.095),1);
   if(!use_atlas && COLOR.b==0.0) {
     float blade=0.0;
     for(int i=0;i<6;i++) { float f=float(i); float height=.64+.35*sin(f*1.71+1.0); float bend=sin(f*2.3)*.10*UV.y*UV.y; float width=.014*(1.0-UV.y/height); blade=max(blade,(1.0-smoothstep(width,width+.003,abs(UV.x-(.08+f*.165+bend))))*(1.0-smoothstep(height-.04,height,UV.y))); }
     c.a=blade;
   }
   ALBEDO=c.rgb; ALPHA=c.a; ALPHA_SCISSOR_THRESHOLD=.38; ALPHA_ANTIALIASING_EDGE=.25; ALPHA_TEXTURE_COORDINATE=UV*2048.0;
   BACKLIGHT=c.rgb*.18;
 }else{
   float fissure=pow(.5+.5*sin(local.x*34.0+sin(local.y*1.7)*2.0+local.z*31.0),8.0);
   float plate=.90+.10*sin(floor(local.y*2.7)*3.71+floor(atan(local.z,local.x)*7.0));
   ALBEDO=tint*plate*(1.0-fissure*.58);
 }
 ROUGHNESS=.93;
}
