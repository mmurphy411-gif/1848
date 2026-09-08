shader_type spatial;
render_mode cull_disabled;
uniform sampler2D leaf_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform bool leaves=false;
uniform bool use_atlas=true;
uniform vec3 tint : source_color=vec3(.2,.35,.08);
varying vec3 local;
void vertex(){
 local=VERTEX;
 vec3 w=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 float phase=MODEL_MATRIX[3].x*.71+MODEL_MATRIX[3].z*.39;
 float sway=(sin(TIME*.83+phase+w.y*.14)*.095+sin(TIME*1.91+phase*.73)*.045)*COLOR.r;
 // World amplitude remains <= 14 cm, including instances scaled to 1.2.
 VERTEX+=(inverse(MODEL_MATRIX)*vec4(sway,0.0,sway*.24,0)).xyz;
}
void fragment(){
 if(leaves){
   vec4 c=use_atlas?texture(leaf_atlas,UV):vec4(COLOR.b>0.0?tint:vec3(.10,.22,.035),1);
   ALBEDO=c.rgb; ALPHA=c.a; ALPHA_SCISSOR_THRESHOLD=.38;
   BACKLIGHT=c.rgb*.18;
 }else{
   float fissure=pow(.5+.5*sin(local.x*34.0+sin(local.y*1.7)*2.0+local.z*31.0),8.0);
   float plate=.90+.10*sin(floor(local.y*2.7)*3.71+floor(atan(local.z,local.x)*7.0));
   ALBEDO=tint*plate*(1.0-fissure*.58);
 }
 ROUGHNESS=.93;
}
