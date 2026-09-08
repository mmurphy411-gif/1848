shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
varying vec3 local;
void vertex(){local=VERTEX;}
void fragment(){
 float flicker=.82+.18*sin(TIME*9.0+local.y*31.0+UV.x*7.0);
 float grain=.78+.22*fract(sin(dot(local.xz+local.y,vec2(127.1,311.7)))*43758.5453);
 vec3 heat=mix(vec3(.95,.075,.004),vec3(1.0,.48,.055),UV.y);
 ALBEDO=heat*grain;EMISSION=heat*grain*flicker*2.0;
 ALPHA=.75;
}
