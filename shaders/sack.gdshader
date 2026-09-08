shader_type spatial;
uniform vec3 growth=vec3(.65,.85,.28);
void vertex() {
 // Keep the gathered neck and tie attached at their empty-poke size.
 float body=smoothstep(.025,.10,-VERTEX.y);
 vec3 correction=mix(vec3(.65,.85,.28)/growth,vec3(1.0),body);
 VERTEX*=correction;
 NORMAL=normalize(NORMAL/correction);
}
void fragment() {
 float weave=(sin(UV.x*370.0)*sin(UV.y*440.0))*.035;
 float folds=.5+.5*sin(UV.x*31.4+UV.y*2.0);
 ALBEDO=vec3(.30,.225,.125)*(.86+folds*.14+weave);
 ROUGHNESS=.96;
}
