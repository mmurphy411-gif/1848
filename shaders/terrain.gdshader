shader_type spatial;
// Seven samples on cliffs (three albedos/normals and dominant-plane ORM).
uniform sampler2D granite_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D granite_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D granite_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D talus_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D talus_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D talus_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D duff_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D duff_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D duff_orm : filter_linear_mipmap, repeat_enable;
uniform sampler2D bedrock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bedrock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bedrock_orm : filter_linear_mipmap, repeat_enable;
varying vec3 world;
varying vec3 geom_normal;
varying float kind;
uniform vec4 oak_canopies[10];
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() {
 world=(MODEL_MATRIX*vec4(VERTEX,1)).xyz;
 geom_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL); kind=COLOR.r*4.0;
}
void planar(sampler2D a,sampler2D n,sampler2D o,vec2 uv,out vec3 albedo,out vec3 normal,out vec3 orm) {
 albedo=texture(a,uv).rgb; vec3 t=texture(n,uv).xyz*2.0-1.0;
 normal=normalize(vec3(t.x,t.z,-t.y)); orm=vec3(.85,texture(o,uv).r,0);
}
void tri(sampler2D a,sampler2D n,sampler2D o,float tile,out vec3 albedo,out vec3 normal,out vec3 orm) {
 vec3 w=pow(abs(geom_normal),vec3(4)); w/=w.x+w.y+w.z;
 vec3 p=world/tile;
 albedo=texture(a,p.zy).rgb*w.x+texture(a,p.xz).rgb*w.y+texture(a,p.xy).rgb*w.z;
 vec3 nx=texture(n,p.zy).xyz*2.0-1.0,ny=texture(n,p.xz).xyz*2.0-1.0,nz=texture(n,p.xy).xyz*2.0-1.0;
 normal=normalize(vec3(nx.z*sign(geom_normal.x),nx.y,nx.x)*w.x+vec3(ny.x,ny.z,-ny.y)*w.y+vec3(nz.x,nz.y,nz.z*sign(geom_normal.z))*w.z);
 vec2 uv=w.x>w.y && w.x>w.z?p.zy:(w.y>w.z?p.xz:p.xy); orm=vec3(.85,texture(o,uv).r,0);
}
void fragment() {
 vec3 a,n,o;
 float shore=-6.0+.0075*pow(clamp(world.x,-42.0,42.0),2.0);
 float inland=world.z-shore;
 float macro=noise(world.xz*.08);
 float under_oak=0.0;
 for(int i=0;i<10;i++) under_oak=max(under_oak,1.0-smoothstep(4.0,6.0,distance(world.xz,oak_canopies[i].xy)));
 if(kind>2.5 && kind<3.5) {
   float apron=smoothstep(.48,.67,geom_normal.y+(noise(world.xz*.2)-.5)*.10);
   if(apron<.99) tri(granite_albedo,granite_normal,granite_orm,4.0,a,n,o);
   if(apron>.01) {
     vec3 ta,tn,to; tri(talus_albedo,talus_normal,talus_orm,3.0,ta,tn,to);
     if(apron>=.99) { a=ta;n=tn;o=to; }
     else { a=mix(a,ta,apron);n=normalize(mix(n,tn,apron));o=mix(o,to,apron); }
   }
   float forest=smoothstep(.82,.92,geom_normal.y)*smoothstep(.30,.65,noise(world.xz*.18));
   if(forest>.01) { vec3 da,dn,d_o;planar(duff_albedo,duff_normal,duff_orm,world.xz/2.0,da,dn,d_o);a=mix(a,da,forest);n=normalize(mix(n,dn,forest));o=mix(o,d_o,forest); }

 } else {
   planar(gravel_albedo,gravel_normal,gravel_orm,world.xz/1.5,a,n,o);
   float sand_band=smoothstep(1.0,1.9,inland+noise(world.xz*2.0)*.5)*(1.0-smoothstep(2.6,3.3,inland+noise(world.xz*2.0)*.5));
   sand_band=max(sand_band,smoothstep(.40,.70,noise(world.xz*.20+vec2(noise(world.xz*.13)*2.0)))*.92);
   if(sand_band>.01) { vec3 sa,sn,so; planar(sand_albedo,sand_normal,sand_orm,world.xz/2.0,sa,sn,so); a=mix(a,sa,sand_band); n=normalize(mix(n,sn,sand_band)); o=mix(o,so,sand_band); }
   float duff=smoothstep(11.5,13.0,inland)*smoothstep(.08,.75,under_oak-noise(world.xz*1.5)*.25);
   if(duff>.01) { vec3 da,dn,d_o;planar(duff_albedo,duff_normal,duff_orm,world.xz/2.0,da,dn,d_o);a=mix(a,da,duff);n=normalize(mix(n,dn,duff));o=mix(o,d_o,duff); }
   float wet=(1.0-smoothstep(1.0,1.5,inland))*smoothstep(-.4,-.3,world.y);
   a*=mix(1.0,.56,wet); o.g=mix(o.g,.46,wet);
 }
 ALBEDO=a*(kind>2.5 && kind<3.5 ? .60+.65*noise(world.xy*.09)+.17*noise(world.zy*.38) : .94+.10*macro);
 ROUGHNESS=clamp(o.g+(macro-.5)*.06,0.0,1.0); AO=o.r;
 float strength=1.0-smoothstep(40.0,70.0,distance(CAMERA_POSITION_WORLD,world));
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(mix(geom_normal,n,strength*.8)),0)).xyz);
}
