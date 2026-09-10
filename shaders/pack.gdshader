shader_type spatial;
uniform vec3 canvas_color : source_color = vec3(.29,.235,.145);
varying vec3 rest_position;
void vertex() { rest_position=VERTEX; }
void fragment() {
    float weave=sin(UV.x*1600.0)*sin(UV.y*1900.0);
    float broad=sin(rest_position.x*23.0+sin(rest_position.y*17.0))*sin(rest_position.y*32.0+rest_position.z*15.0);
    float dirt=1.0-smoothstep(-.23,-.10,rest_position.y);
    ALBEDO=canvas_color*(.96+.06*broad+.015*weave)*(1.0-.24*dirt);
    ROUGHNESS=.96;
}
