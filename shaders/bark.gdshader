shader_type spatial;
render_mode diffuse_lambert, specular_disabled;
uniform vec3 tint : source_color=vec3(.2,.12,.06);
uniform float review_time=-1.0;
varying vec3 local;
void vertex(){
 local=VERTEX;
 vec3 world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float phase=MODEL_MATRIX[3].x*.71+MODEL_MATRIX[3].z*.39;
 float wind_time=review_time>=0.0?review_time:TIME;
 float sway=(sin(wind_time*.83+phase+world.y*.14)*.095+sin(wind_time*1.91+phase*.73)*.045)*COLOR.r;
 vec3 offset=vec3(sway,0.0,sway*.24);
 vec3 x=MODEL_MATRIX[0].xyz,y=MODEL_MATRIX[1].xyz,z=MODEL_MATRIX[2].xyz;
 VERTEX+=vec3(dot(x,offset)/dot(x,x),dot(y,offset)/dot(y,y),dot(z,offset)/dot(z,z));
}
void fragment(){
 float fissure=pow(.5+.5*sin(local.x*34.0+sin(local.y*1.7)*2.0+local.z*31.0),8.0);
 float plate=.90+.10*sin(floor(local.y*2.7)*3.71+floor(atan(local.z,local.x)*7.0));
 ALBEDO=tint*plate*(1.0-fissure*.58);
 ROUGHNESS=.93;
}
