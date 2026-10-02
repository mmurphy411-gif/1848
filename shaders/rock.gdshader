shader_type spatial;
// Tri-planar scan set for boulders, cobbles, bedrock ledges and small props
// (Assets.rock()). Maps: albedo, RGTC normal (Z rebuilt), ORM = AO, roughness,
// height. Height darkens crevices; world-space noise adds grey/warm/rust families
// and moss on north-facing (+Z) upper faces; rock at the river line is wet.
uniform sampler2D albedo_map : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D orm_map : repeat_enable, filter_linear_mipmap_anisotropic;
uniform float tile = 4.0;
// Live river height (Assets.set_water_level); the default keeps props dry.
uniform float water_level = -1000.0;
varying vec3 world;
varying vec3 normal_world;
float hash(vec2 p) {
 uvec2 q = uvec2(ivec2(floor(p)) + ivec2(65536));
 uint h = q.x * 0x27d4eb2du ^ q.y * 0x165667b1u;
 h ^= h >> 15u; h *= 0x2c1b3c6du; h ^= h >> 12u;
 return float(h) * (1.0 / 4294967295.0);
}
float noise(vec2 p) {
 vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;normal_world=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 p=world/tile,w=pow(abs(normal_world),vec3(4)); w/=w.x+w.y+w.z;
 vec3 o=texture(orm_map,p.zy).rgb*w.x+texture(orm_map,p.xz).rgb*w.y+texture(orm_map,p.xy).rgb*w.z;
 vec3 albedo=(texture(albedo_map,p.zy).rgb*w.x+texture(albedo_map,p.xz).rgb*w.y+texture(albedo_map,p.xy).rgb*w.z)*COLOR.rgb;
 vec2 tx=texture(normal_map,p.zy).rg*2.0-1.0,ty=texture(normal_map,p.xz).rg*2.0-1.0,tz=texture(normal_map,p.xy).rg*2.0-1.0;
 vec3 n=normalize(vec3(sqrt(max(1.0-dot(tx,tx),0.0))*sign(normal_world.x),-tx.y,tx.x)*w.x+vec3(ty.x,sqrt(max(1.0-dot(ty,ty),0.0))*sign(normal_world.y),-ty.y)*w.y+vec3(tz.x,-tz.y,sqrt(max(1.0-dot(tz,tz),0.0))*sign(normal_world.z))*w.z);
 float h=o.b;
 albedo*=mix(.68,1.05,smoothstep(.05,.5,h));
 vec3 fam=mix(vec3(1.0),vec3(1.12,.98,.84),smoothstep(.5,.8,noise(world.xz*.09+vec2(3.0,7.0))));
 fam=mix(fam,vec3(1.18,.92,.78),smoothstep(.62,.85,noise(world.xz*.13+vec2(-11.0,2.0)))*.7);
 albedo*=mix(vec3(1.0),fam,.6);
 float moss=smoothstep(.15,.6,normal_world.z)*smoothstep(-.1,.5,normal_world.y)*smoothstep(.45,.75,noise(world.xz*.6+vec2(world.y*.4)))*(1.0-smoothstep(.4,.85,h));
 albedo=mix(albedo,vec3(.06,.075,.032),moss*.6);
 float above=world.y-water_level;
 float wet=1.0-smoothstep(.04+(h-.5)*.06,.22,above+(noise(world.xz*1.3)-.5)*.06);
 ALBEDO=albedo*mix(1.0,.5,wet);
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(normal_world,n,.6*(1.0-smoothstep(40.0,70.0,distance(world,CAMERA_POSITION_WORLD))))),0)).xyz);
 ROUGHNESS=mix(mix(o.g,.95,moss),.3,wet); AO=o.r;
}
