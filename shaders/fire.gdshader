// Camp and crew fire (Wave C). Two uses share this shader:
//  mode 0 (default): the flame particles camp.gd and crew.gd emit (sphere draw pass).
//    Each sphere is stretched into an upward-tapering lick, soft at its silhouette,
//    yellow at birth and burning down to orange and red as it rises and dies.
//  mode 1: the crossed flame ribbons of assets/camp/flames.glb (u across, v up;
//    COLOR.r is each ribbon's phase). Noise scrolling up the ribbon cuts it into
//    flickering tongues with a hot root and torn, reddening tips.
//  mode 2: the coals under them, glowing through cracks in their crust and pulsing.
// Additive: overlapping tongues get hotter, not milky; peaks stay orange-yellow.
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, fog_disabled;
uniform int mode = 0;
uniform float strength = 1.0;
varying vec3 local;
varying float life;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
 vec2 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
 return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
vec3 heat(float t) {
 // 0 = dying red, 1 = the yellow root of a flame.
 return mix(mix(vec3(.55, .05, .006), vec3(1.0, .32, .04), smoothstep(0.0, .5, t)), vec3(1.0, .58, .15), smoothstep(.55, 1.0, t));
}

void vertex() {
 local = VERTEX;
 life = 0.0;
 if (mode == 0) {
   life = clamp(INSTANCE_CUSTOM.y, 0.0, 1.0);
   float t = clamp(VERTEX.y / .2 + .5, 0.0, 1.0);
   VERTEX.xz *= mix(1.0, .28, t * t) * (1.0 - .45 * life);
   VERTEX.y *= 2.1 * (1.0 - .3 * life);
 }
}

void fragment() {
 if (mode == 1) {
   float phase = COLOR.r * 7.0;
   vec2 uv = vec2(UV.x, 1.0 - UV.y); // glTF UVs run top-down; v = 0 at the root here
   float rise = TIME * 1.6 + phase;
   float n = vnoise(vec2(uv.x * 3.0 + phase, uv.y * 2.4 - rise));
   float n2 = vnoise(vec2(uv.x * 7.0 - phase, uv.y * 5.0 - rise * 1.7));
   float x = (uv.x - .5) * 2.0 + (n - .5) * 1.1 * uv.y + (n2 - .5) * .35 * uv.y;
   float width = pow(1.0 - uv.y, .8) * (.7 + .4 * n);
   float body = 1.0 - smoothstep(width * .7, width, abs(x));
   // Tips tear into separate licks that rise and vanish.
   float tear = smoothstep(.25, .6, n2 + .65 - uv.y * 1.1);
   float root = smoothstep(0.0, .12, uv.y);
   float a = body * tear * root;
   float t = clamp((1.0 - uv.y) * .9 + (1.0 - abs(x)) * .25 - .1 + .2 * n2, 0.0, 1.0);
   float flicker = .85 + .15 * sin(TIME * 13.0 + phase * 3.0);
   // Unshaded: ALBEDO is the output (HDR, so the root can bloom a little).
   // Kept low: night exposure and AgX turn anything brighter (and overlapping) white.
   ALBEDO = heat(t * t) * flicker * strength * .55;
   ALPHA = a;
 } else if (mode == 2) {
   // Coals: a glow that lives in the cracks and breathes slowly; additive over the ash.
   float crack = vnoise(local.xz * 38.0 + local.y * 20.0);
   float breathe = .7 + .3 * sin(TIME * 1.7 + local.x * 23.0 + local.z * 17.0);
   float hot = smoothstep(.42, .78, crack) * breathe;
   ALBEDO = heat(.2 + .5 * hot) * hot * .6 * strength;
   ALPHA = hot;
 } else {
   float rim = abs(dot(normalize(NORMAL), normalize(VIEW)));
   float soft = smoothstep(.05, .75, rim);
   float flicker = .82 + .18 * sin(TIME * 9.0 + local.y * 31.0 + local.x * 7.0);
   float t = clamp(1.0 - life * 1.25 + (rim - .5) * .4, 0.0, 1.0);
   float fade = (1.0 - smoothstep(.45, 1.0, life));
   ALBEDO = heat(t * .7) * flicker * .06 * strength;
   ALPHA = soft * fade;
 }
}
