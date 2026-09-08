shader_type spatial;
uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : repeat_enable, filter_linear_mipmap;
uniform float tile=4.0;
varying vec3 world;
varying vec3 normal_world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 p=world/tile,w=pow(abs(normal_world),vec3(4)); w/=w.x+w.y+w.z;
 ALBEDO=(texture(albedo_map,p.zy).rgb*w.x+texture(albedo_map,p.xz).rgb*w.y+texture(albedo_map,p.xy).rgb*w.z)*COLOR.rgb;
 vec3 nx=texture(normal_map,p.zy).xyz*2.0-1.0,ny=texture(normal_map,p.xz).xyz*2.0-1.0,nz=texture(normal_map,p.xy).xyz*2.0-1.0;
 vec3 n=normalize(vec3(nx.z*sign(normal_world.x),nx.y,nx.x)*w.x+vec3(ny.x,ny.z,-ny.y)*w.y+vec3(nz.x,nz.y,nz.z*sign(normal_world.z))*w.z);
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(normal_world,n,.6*(1.0-smoothstep(40.0,70.0,distance(world,CAMERA_POSITION_WORLD))))),0)).xyz);
 vec3 orm=texture(orm_map,p.xz).rgb; ROUGHNESS=orm.g; AO=orm.r;
}
