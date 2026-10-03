shader_type spatial;
// Ground of the claim and the canyon (VISUAL_UPGRADE_PLAN.md stages 1 and 3).
// Seven CC0 scan sets (albedo; RGTC normal; ORM = AO, roughness, height) are layered
// by procedural masks and each layer's height, so sand fills between cobbles and soil
// and duff creep between stones instead of meeting along mesh strips. Planar layers
// use rotated, offset copies per noise patch, joined in narrow height-blended seams
// (stochastic anti-tiling, about 1.2 samples per map). Walls are tri-planar slate with
// strata, joints, rust streaks and moss on north-facing (+Z) rock.
// greybox.gd::_triangle passes the mesh kind in COLOR.r*4: 3 is canyon wall or far
// bank, the rest is the bar and river bed. Any other mesh (no vertex colours, so
// COLOR.g is 1) gets plain ground: soil with redder, darker and trampled reaches, drifts
// of litter and duff, stony patches, no river or claim-shaped masks (the store clearing:
// scripts/store.gd copies this material and swaps the gravel maps for duff). Wave C (bar):
// cobble-size zones (each anti-tiling patch has its own scale), low swales that tilt the
// shading normal and hold sand, toned-down white and orange pebbles, contact shade, banked
// sand and lee drifts at every bar boulder (boulder_at/boulder_shape, set by
// scripts/scan_rocks.gd from each fitted rock's ground outline), a noise-edged oak litter
// fringe, a damp margin 0.5-1.5 m wide that follows the live water_level, and the rain's
// wetness (global rain_wetness). Gameplay never reads this shader.
uniform float snow_amount = 0.0;
uniform float water_level = 0.0;
uniform vec4 oak_canopies[10];
// Bar boulders (Layout.BOULDERS order): centre x, z, mean ground radius, top height; and the
// outline's radius terms against angle a: cos a, sin a, cos 2a, sin 2a. Radius 0 = unused.
uniform vec4 boulder_at[7];
uniform vec4 boulder_shape[7];
uniform int review_mode = 0;
global uniform float rain_wetness;
uniform sampler2D gravel_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D soil_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D duff_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D duff_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D duff_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D talus_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D talus_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D talus_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bedrock_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bedrock_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bedrock_orm : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D granite_albedo : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D granite_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D granite_orm : filter_linear_mipmap_anisotropic, repeat_enable;

// Metres per texture repeat, near each scan's real size.
const float GRAVEL_TILE = 2.2;
const float SAND_TILE = 2.0;
const float SOIL_TILE = 1.7;
const float DUFF_TILE = 1.7;
const float TALUS_TILE = 4.0;
const float BEDROCK_TILE = 4.5;
const float GRANITE_TILE = 3.0;

varying vec3 world;
varying vec3 geom_normal;
varying float kind;

struct Surf { vec3 albedo; vec3 n; float ao; float rough; float h; };

// Exact integer hash. The old fract(sin()) hash rounded differently in
// neighbouring cells on the GPU, so value noise jumped at cell edges and drew sand
// rectangles on the bar.
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
float fbm(vec2 p) { return (noise(p) + .5 * noise(p * 2.07 + vec2(17.3, 5.1))) / 1.5; }

void vertex() {
 world = (MODEL_MATRIX * vec4(VERTEX, 1)).xyz;
 geom_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL); kind = COLOR.g > .5 ? -1.0 : COLOR.r * 4.0;
}

Surf blend(Surf a, Surf b, float w) {
 Surf r;
 r.albedo = mix(a.albedo, b.albedo, w); r.n = normalize(mix(a.n, b.n, w));
 r.ao = mix(a.ao, b.ao, w); r.rough = mix(a.rough, b.rough, w); r.h = mix(a.h, b.h, w);
 return r;
}
// Cover `under` with `top` as mask m rises: the top fills the lowest spots first, so
// stones poke through thin sand. Exactly 0 at m = 0 and 1 at m = 1.
Surf cover(Surf under, Surf top, float m, float soft) {
 float level = mix(-soft - .08, 1.0 + soft + .08, m) + (top.h - .5) * .16;
 return blend(under, top, smoothstep(under.h - soft, under.h + soft, level));
}

// One planar (top-down) sample of a set, rotated, scaled and offset by variant
// v = (cos, sin) * scale, offset.
Surf planar(sampler2D A, sampler2D N, sampler2D O, vec2 uv, vec2 dx, vec2 dy, vec4 v, vec3 n0, bool want_n) {
 mat2 r = mat2(vec2(v.x, v.y), vec2(-v.y, v.x));
 vec2 ruv = r * uv + v.zw, rdx = r * dx, rdy = r * dy;
 Surf s;
 s.albedo = textureGrad(A, ruv, rdx, rdy).rgb;
 vec3 o = textureGrad(O, ruv, rdx, rdy).rgb;
 s.ao = o.r; s.rough = o.g; s.h = o.b; s.n = n0;
 if (want_n) {
   // OpenGL map: x along +u, y along image-up (-v). Undo the rotation, then u,v -> x,z.
   vec2 t = textureGrad(N, ruv, rdx, rdy).rg * 2.0 - 1.0;
   vec2 g = transpose(r) * vec2(t.x, -t.y) * inversesqrt(dot(v.xy, v.xy));
   float z = sqrt(max(1.0 - dot(t, t), 0.0));
   s.n = normalize(vec3(n0.x + g.x, n0.y * z, n0.z + g.y));
 }
 return s;
}
// Anti-tiled planar layer: variant a inside one noise patch, b inside the next, and a
// narrow seam between them where the higher stones of either copy win.
Surf layer(sampler2D A, sampler2D N, sampler2D O, vec2 uv, vec2 dx, vec2 dy, vec4 va, vec4 vb, float seam, vec3 n0, bool want_n) {
 if (seam <= 0.0) return planar(A, N, O, uv, dx, dy, va, n0, want_n);
 if (seam >= 1.0) return planar(A, N, O, uv, dx, dy, vb, n0, want_n);
 Surf a = planar(A, N, O, uv, dx, dy, va, n0, want_n);
 Surf b = planar(A, N, O, uv, dx, dy, vb, n0, want_n);
 return blend(a, b, clamp((seam - .5) * 3.6 + (b.h - a.h) * 1.3 + .5, 0.0, 1.0));
}
// Each patch also gets its own texture scale (0.65-1.55), so stone size changes from patch
// to patch: coarse armour next to finer gravel, joined in the same seams.
vec4 variant(float cell) {
 float a = hash(vec2(cell, 17.0)) * 6.2831853;
 float scale = mix(.65, 1.55, hash(vec2(cell, 23.0)));
 return vec4(vec2(cos(a), sin(a)) * scale, hash(vec2(cell, 3.0)), hash(vec2(cell, 9.0)));
}

// Tri-planar sample; axes with under 3 % weight are skipped.
Surf tri(sampler2D A, sampler2D N, sampler2D O, vec3 p, vec3 dpx, vec3 dpy, vec3 n0, bool want_n) {
 vec3 w = pow(abs(n0), vec3(8.0)); w /= w.x + w.y + w.z;
 w = max(w - .03, 0.0); w /= w.x + w.y + w.z;
 Surf s; s.albedo = vec3(0); s.ao = 0.0; s.rough = 0.0; s.h = 0.0;
 vec3 n = vec3(0);
 if (w.x > 0.0) {
   vec3 o = textureGrad(O, p.zy, dpx.zy, dpy.zy).rgb;
   s.albedo += textureGrad(A, p.zy, dpx.zy, dpy.zy).rgb * w.x; s.ao += o.r * w.x; s.rough += o.g * w.x; s.h += o.b * w.x;
   if (want_n) { vec2 t = textureGrad(N, p.zy, dpx.zy, dpy.zy).rg * 2.0 - 1.0; n += vec3(sqrt(max(1.0 - dot(t, t), 0.0)) * sign(n0.x), -t.y, t.x) * w.x; }
 }
 if (w.y > 0.0) {
   vec3 o = textureGrad(O, p.xz, dpx.xz, dpy.xz).rgb;
   s.albedo += textureGrad(A, p.xz, dpx.xz, dpy.xz).rgb * w.y; s.ao += o.r * w.y; s.rough += o.g * w.y; s.h += o.b * w.y;
   if (want_n) { vec2 t = textureGrad(N, p.xz, dpx.xz, dpy.xz).rg * 2.0 - 1.0; n += vec3(t.x, sqrt(max(1.0 - dot(t, t), 0.0)) * sign(n0.y), -t.y) * w.y; }
 }
 if (w.z > 0.0) {
   vec3 o = textureGrad(O, p.xy, dpx.xy, dpy.xy).rgb;
   s.albedo += textureGrad(A, p.xy, dpx.xy, dpy.xy).rgb * w.z; s.ao += o.r * w.z; s.rough += o.g * w.z; s.h += o.b * w.z;
   if (want_n) { vec2 t = textureGrad(N, p.xy, dpx.xy, dpy.xy).rg * 2.0 - 1.0; n += vec3(t.x, -t.y, sqrt(max(1.0 - dot(t, t), 0.0)) * sign(n0.z)) * w.z; }
 }
 s.n = want_n ? normalize(n) : n0;
 return s;
}

// Low-frequency cobble colour families: grey, rust, ochre, slate and dark reaches.
// Wave C: the rust and ochre reaches are browner (the bar read as orange garden gravel).
vec3 family(vec2 xz) {
 vec3 f = vec3(1.0);
 f = mix(f, vec3(1.16, .9, .74) * .94, smoothstep(.50, .78, noise(xz * .060 + vec2(11.0, 3.0))) * .85);
 f = mix(f, vec3(1.1, 1.01, .8) * .96, smoothstep(.55, .80, noise(xz * .045 + vec2(-7.0, 21.0))) * .80);
 f = mix(f, vec3(.92, 1.0, 1.08), smoothstep(.52, .78, noise(xz * .090 + vec2(31.0, -9.0))) * .70);
 return f * mix(1.0, .70, smoothstep(.45, .80, noise(xz * .070 + vec2(50.0, 2.0))));
}

void fragment() {
 vec3 n0 = normalize(geom_normal);
 vec2 xz = world.xz;
 float dist = distance(CAMERA_POSITION_WORLD, world);
 bool want_n = dist < 70.0;
 vec2 dwx = dFdx(xz), dwy = dFdy(xz);
 vec3 dpx = dFdx(world), dpy = dFdy(world);
 float above = world.y - water_level;
 float shore = -6.0 + .0075 * pow(clamp(world.x, -42.0, 42.0), 2.0);
 float inland = world.z - shore;
 float macro = fbm(xz * .05);
 // Bar swales (differentiated here, in uniform control flow) and a 1 m lumpiness; both
 // are reused for the damp edge, ripple fields and boulder skirts to keep the noise count down.
 float swale = noise(xz * .11 + vec2(3.7, -8.1));
 float swale_dx = dFdx(swale), swale_dy = dFdy(swale);
 float lumpy = noise(xz * 1.1 + vec2(4.0, 9.0));
 float review_sand = 0.0, review_stone = 0.0;
 Surf s;
 if (kind < -.5) {
   // Plain ground on other meshes (the store clearing): packed soil with redder, darker and
   // pale trampled reaches, broken drifts of litter (the gravel slot) and duff, stony patches.
   float k = noise(xz * .3) * 4.0; float ki = floor(k);
   float seam = smoothstep(.4, .6, fract(k));
   float fine = noise(xz * 1.3 + vec2(3.0, 1.0)) - .5;
   float gravel_m = smoothstep(.5, .72, fbm(xz * .12 + vec2(2.0, 5.0)) + fine * .3);
   float duff_m = smoothstep(.5, .74, noise(xz * .18 + vec2(-4.0, 6.0)) + fine * .35);
   float stone_m = smoothstep(.64, .8, fbm(xz * .2 + vec2(-9.0, 3.0)) - fine * .3) * (1.0 - gravel_m);
   Surf t = layer(soil_albedo, soil_normal, soil_orm, xz / SOIL_TILE, dwx / SOIL_TILE, dwy / SOIL_TILE, variant(ki), variant(ki + 1.0), seam, n0, want_n);
   float lt = dot(t.albedo, vec3(.2126, .7152, .0722));
   t.albedo *= mix(vec3(1.0), vec3(1.14, .93, .8), smoothstep(.45, .8, noise(xz * .06 + vec2(9.0, 2.0))));
   t.albedo *= mix(1.0, .7, smoothstep(.5, .85, noise(xz * .09 + vec2(-5.0, 7.0))));
   t.albedo = mix(t.albedo, vec3(lt) * vec3(1.2, 1.1, .96), smoothstep(.55, .85, noise(xz * .08 + vec2(13.0, -4.0))) * .3);
   if (stone_m > .01) {
     // Stones trodden into the soil: the slate talus set, dusted with the soil's colour.
     Surf r = layer(talus_albedo, talus_normal, talus_orm, xz / 1.8, dwx / 1.8, dwy / 1.8, variant(ki + 11.0), variant(ki + 12.0), seam, n0, want_n);
     r.albedo = mix(r.albedo * vec3(1.0, .9, .78), t.albedo, .35) * .75;
     t = cover(t, r, stone_m * .6, .1);
   }
   if (gravel_m > .01) {
     s = layer(gravel_albedo, gravel_normal, gravel_orm, xz / GRAVEL_TILE, dwx / GRAVEL_TILE, dwy / GRAVEL_TILE, variant(ki + 3.0), variant(ki + 4.0), seam, n0, want_n);
     s.albedo *= mix(.46, 1.0, smoothstep(.12, .58, s.h));
     s = cover(s, t, 1.0 - gravel_m * .85, .1);
   } else s = t;
   if (duff_m > .01) {
     Surf d = layer(duff_albedo, duff_normal, duff_orm, xz / DUFF_TILE, dwx / DUFF_TILE, dwy / DUFF_TILE, variant(ki + 7.0), variant(ki + 8.0), seam, n0, want_n);
     s = cover(s, d, duff_m, .1);
   }
   s.albedo *= .86 + .22 * macro;
 } else if (kind > 2.5 && kind < 3.5) {
   // Canyon walls and far bank: slate cliffs, slate talus aprons, soil and duff on flats.
   float flood = smoothstep(2.0, 4.5, world.y + (noise(xz * .13) - .5) * 2.0);
   float talus_m = smoothstep(.48, .67, n0.y + (noise(xz * .2) - .5) * .10);
   float flat_m = smoothstep(.76, .9, n0.y + (noise(xz * .31) - .5) * .12) * flood;
   // Flats above the flood line carry red-brown soil; needle duff patches it on the
   // benches and takes over toward the forested rim.
   float soil_m = flat_m;
   float duff_m = flat_m * max(smoothstep(.36, .66, noise(xz * .18)), smoothstep(12.0, 30.0, world.y + (noise(xz * .07) - .5) * 14.0));
   if (soil_m < .99) {
     Surf rock;
     if (talus_m < .99) {
       rock = tri(bedrock_albedo, bedrock_normal, bedrock_orm, world / BEDROCK_TILE, dpx / BEDROCK_TILE, dpy / BEDROCK_TILE, n0, want_n);
       // Pale quartz-granite veins cut the slate here and there (Mother Lode country).
       float vein_d = abs(fract(dot(world, vec3(.031, .012, .017)) + (fbm(xz * .03) - .5) * .5) - .5);
       float vein = (1.0 - smoothstep(.012, .03, vein_d)) * step(.55, hash(vec2(floor(dot(world, vec3(.031, .012, .017)) + (fbm(xz * .03) - .5) * .5), 41.0)));
       if (vein > .01) {
         Surf g = tri(granite_albedo, granite_normal, granite_orm, world / GRANITE_TILE, dpx / GRANITE_TILE, dpy / GRANITE_TILE, n0, want_n);
         g.albedo *= vec3(1.05, 1.04, 1.0);
         rock = blend(rock, g, clamp(vein * 1.6 + (g.h - rock.h) * .6 - .3, 0.0, 1.0));
       }
     }
     if (talus_m > .01) {
       Surf t = tri(talus_albedo, talus_normal, talus_orm, world / TALUS_TILE, dpx / TALUS_TILE, dpy / TALUS_TILE, n0, want_n);
       rock = talus_m >= .99 ? t : cover(rock, t, talus_m, .1);
     }
     // Strata: gently dipping layers 1.5-4 m thick of slate, greenstone and weathered
     // brown, fine laminations, crevice and joint darkening, rust streaks, north moss.
     float sc = world.y + .12 * world.x - .05 * world.z + (noise(xz * .021) - .5) * 7.0;
     float id = floor(sc / 2.7), sf = fract(sc / 2.7);
     float tone_a = hash(vec2(id, 5.0)), tone_b = hash(vec2(id + 1.0, 5.0));
     float tone = mix(tone_a, tone_b, smoothstep(.88, 1.0, sf));
     vec3 strata = tone < .3 ? vec3(.84, .94, 1.10) * .92 : tone < .55 ? vec3(.88, 1.04, .92) : tone < .78 ? vec3(1.16, 1.0, .80) * 1.08 : vec3(.78, .80, .85) * .62;
     strata *= 1.0 + .09 * sin(sc * 7.3 + noise(xz * .7) * 2.0);
     float along = world.x + .3 * world.z;
     float joint = 1.0 - smoothstep(0.0, .03, abs(noise(vec2(along * .32, world.y * .035)) - .5));
     float steep = 1.0 - smoothstep(.55, .8, n0.y);
     rock.albedo *= mix(vec3(1.0), strata, .8 + .2 * steep);
     // Broad iron-oxide weathering rind: brown-orange reaches of the face.
     float rind = smoothstep(.5, .78, noise(vec2(along * .045, world.y * .06) + vec2(13.0, 2.0)));
     rock.albedo *= mix(vec3(1.0), vec3(1.30, 1.0, .72), rind * .7);
     rock.albedo *= mix(.52, 1.06, smoothstep(.06, .55, rock.h)) * (1.0 - .45 * joint * steep);
     // Rust streaks run straight down the face from iron-bearing seams.
     float rust = smoothstep(.62, .86, noise(vec2(along * .8, world.y * .012))) * smoothstep(.38, .7, noise(vec2(along * .05, world.y * .07) + vec2(4.0, 9.0))) * steep;
     rock.albedo = mix(rock.albedo, vec3(.30, .135, .055) * (.7 + .6 * rock.h), rust * .55);
     // Moss on shaded north-facing (+Z) rock above the flood line, in the hollows first.
     float moss = smoothstep(.05, .45, n0.z) * smoothstep(-.35, .3, n0.y) * flood
       * smoothstep(.42, .66, noise(vec2(along * .3, world.y * .42) + vec2(7.0, 3.0)) * .8 + rock.h * .2) * (1.0 - .7 * smoothstep(.5, .95, rock.h));
     rock.albedo = mix(rock.albedo, vec3(.055, .085, .024), moss * .85);
     rock.rough = mix(rock.rough, .95, moss);
     // Below the flood line the river has scoured lichen and stain off: paler, cleaner.
     rock.albedo = mix(rock.albedo, vec3(dot(rock.albedo, vec3(.2126, .7152, .0722))) * 1.12, (1.0 - flood) * .3);
     s = rock;
   }
   if (soil_m > .01 || duff_m > .01) {
     float k = noise(xz * .3) * 4.0; float ki = floor(k);
     float seam = smoothstep(.4, .6, fract(k));
     if (soil_m > .01) {
       Surf t = layer(soil_albedo, soil_normal, soil_orm, xz / SOIL_TILE, dwx / SOIL_TILE, dwy / SOIL_TILE, variant(ki), variant(ki + 1.0), seam, n0, want_n);
       s = soil_m >= .99 ? t : cover(s, t, soil_m, .1);
     }
     if (duff_m > .01) {
       Surf d = layer(duff_albedo, duff_normal, duff_orm, xz / DUFF_TILE, dwx / DUFF_TILE, dwy / DUFF_TILE, variant(ki + 7.0), variant(ki + 8.0), seam, n0, want_n);
       s = cover(s, d, duff_m, .1);
     }
   }
   s.albedo *= .9 + .2 * macro;
 } else {
   // Bar and river bed: cobble, sand in the swash band and hollows, red-brown soil
   // toward the wall foot, oak duff in the shade.
   float k = (noise(xz * .31) + .5 * noise(xz * .73 + vec2(5.2, 1.3))) * 3.0;
   float ki = floor(k);
   float seam = smoothstep(.4, .6, fract(k));
   vec4 va = variant(ki), vb = variant(ki + 1.0);
   // Low bar forms: swales a few centimetres deep and 6-15 m across. Their slope tilts the
   // shading normal, and they hold sand.
   vec2 hd = vec2(swale_dx, swale_dy);
   float det = dwx.x * dwy.y - dwx.y * dwy.x;
   vec2 slope2 = abs(det) > 1e-7 ? vec2(dwy.y * hd.x - dwx.y * hd.y, dwx.x * hd.y - dwy.x * hd.x) / det : vec2(0.0);
   n0 = normalize(n0 - vec3(slope2.x, 0.0, slope2.y) * .3 * smoothstep(.9, .97, n0.y));
   float wander = inland + (noise(xz * .35) - .5) * 3.6 + (lumpy - .5) * .85;
   float sand_m = smoothstep(.15, 1.7, wander) * (1.0 - smoothstep(2.4, 4.4, wander)) * .9;
   // Sand pockets in hollows of the lower bar, where falling floods drop their sand;
   // between them and up the bar a cobble armour layer.
   // (Not below the late-summer low water: the current keeps the channel cobble bare.)
   float bank = smoothstep(-.5, -.3, world.y + (lumpy - .5) * .2);
   sand_m = max(sand_m, smoothstep(.64, .75, fbm(xz * .16 + vec2(-6.3, 11.9))) * smoothstep(16.0, 9.0, inland) * .85 * bank);
   sand_m = max(sand_m, smoothstep(.22, .1, swale + (lumpy - .5) * .08) * .7 * bank);
   // Bar boulders: shade where each meets the ground, sand banked against the sides and
   // drawn out in a tapered drift on the lee (+X, downstream); the upstream face is
   // scoured to coarse cobble.
   float contact = 0.0;
   // (The boulders all stand within x -45..38: skip the loop on the far reaches.)
   for (int i = 0; i < (world.x > -45.0 && world.x < 38.0 ? 7 : 0); i++) {
     vec4 b = boulder_at[i];
     vec2 v = xz - b.xy;
     float d2 = dot(v, v);
     if (d2 < b.z * b.z * 9.0) {
       vec4 f = boulder_shape[i];
       float d = sqrt(d2);
       vec2 u = v / max(d, .001);
       float e = d - (b.z + f.x * u.x + f.y * u.y + f.z * (u.x * u.x - u.y * u.y) + f.w * 2.0 * u.x * u.y);
       contact = max(contact, 1.0 - smoothstep(-.1, .55 + .35 * lumpy, e));
       float skirt = (1.0 - smoothstep(.05, .55, e + (lumpy - .5) * .5)) * smoothstep(-.45, .2, u.x);
       float half_width = b.z * .8 * (1.0 - v.x / (2.8 * b.z));
       float lee = smoothstep(0.0, b.z * .5, v.x) * (1.0 - smoothstep(half_width - .6, half_width + .3, abs(v.y) + (lumpy - .5) * 1.2));
       sand_m = max(sand_m, max(skirt * .8, lee * .85));
     }
   }
   float width = 38.0 * max(0.0, 1.0 - pow(world.x / 42.0, 2.0)) + max(abs(world.x) - 42.0, 0.0) * .2;
   float soil_m = smoothstep(11.0, 3.0, width - inland + (noise(xz * .15) - .5) * 8.0)
     * smoothstep(.40, .75, world.y + (swale - .5) * .5);
   // Oak litter: under each canopy, thinning out over 2-8 m into islands caught between the
   // stones; warped and noise-broken so no edge follows a circle. (Only inland of 7 m.)
   float duff_m = 0.0;
   if (inland > 7.0 && abs(world.x) < 50.0) {
     vec2 warp = (vec2(noise(xz * .23 + vec2(4.0, 1.0)), noise(xz * .23 + vec2(-3.0, 9.0))) - .5) * 7.0
       + (vec2(lumpy, swale) - .5) * 2.0;
     float under_oak = 0.0;
     for (int i = 0; i < 10; i++) under_oak = max(under_oak, 1.0 - smoothstep(1.5, 8.0, distance(xz + warp, oak_canopies[i].xy)));
     float litter = under_oak * 1.3 - .3 + (fbm(xz * .45 + vec2(1.3, 7.7)) - .5) * 1.4 + (lumpy - .5) * .45;
     duff_m = smoothstep(9.5, 13.5, inland + (noise(xz * .17) - .5) * 5.0) * smoothstep(.3, .75, litter);
   }
   int start = duff_m >= .99 ? 3 : (soil_m >= .99 ? 2 : (sand_m >= .99 ? 1 : 0));
   vec3 fam = family(xz);
   if (start == 0) {
     s = layer(gravel_albedo, gravel_normal, gravel_orm, xz / GRAVEL_TILE, dwx / GRAVEL_TILE, dwy / GRAVEL_TILE, va, vb, seam, n0, want_n);
     // White and cream pebbles weather to grey-tan, hot orange ones to rust-brown.
     float gl = dot(s.albedo, vec3(.2126, .7152, .0722));
     float bright = smoothstep(.2, .48, gl);
     s.albedo = mix(s.albedo, vec3(gl) * vec3(1.04, 1.0, .92), bright * .55) * (1.0 - .4 * bright);
     // The sandy matrix between cobbles sits in their shade and holds moisture.
     s.albedo *= fam * mix(.46, 1.0, smoothstep(.12, .58, s.h));
     review_stone = step(.55, s.h);
   }
   if (start <= 1 && sand_m > .01) {
     Surf t = layer(sand_albedo, sand_normal, sand_orm, xz / SAND_TILE, dwx / SAND_TILE, dwy / SAND_TILE, variant(ki + 3.0), variant(ki + 4.0), seam, n0, want_n);
     t.albedo *= mix(vec3(1.0), fam, .35);
     float h0 = s.h;
     s = start == 1 ? t : cover(s, t, sand_m, .08);
     review_sand = start == 1 ? 1.0 : smoothstep(h0 - .08, h0 + .08, mix(-.16, 1.16, sand_m) + (t.h - .5) * .16);
     // Current ripples in the sand, about 12 cm apart, fading out before they shimmer.
     float phase = (dot(xz, vec2(.96, .28)) + (lumpy - .5) * .6) * 52.0;
     float fade = review_sand * (1.0 - smoothstep(.25, .8, (abs(dot(dwx, vec2(.96, .28))) + abs(dot(dwy, vec2(.96, .28)))) * 52.0 * .16));
     fade *= smoothstep(.3, .65, swale + (lumpy - .5) * .3);
     if (fade > .01) s.n = normalize(s.n + vec3(.96, 0.0, .28) * cos(phase) * .16 * fade * smoothstep(.85, .97, s.n.y));
   }
   if (start <= 2 && soil_m > .01) {
     Surf t = layer(soil_albedo, soil_normal, soil_orm, xz / SOIL_TILE, dwx / SOIL_TILE, dwy / SOIL_TILE, variant(ki + 5.0), variant(ki + 6.0), seam, n0, want_n);
     s = start == 2 ? t : cover(s, t, soil_m, .1);
   }
   if (duff_m > .01) {
     Surf t = layer(duff_albedo, duff_normal, duff_orm, xz / DUFF_TILE, dwx / DUFF_TILE, dwy / DUFF_TILE, variant(ki + 7.0), variant(ki + 8.0), seam, n0, want_n);
     s = start == 3 ? t : cover(s, t, duff_m, .1);
   }
   s.albedo *= mix(1.0, .5, contact * contact);
   s.ao *= mix(1.0, .55, contact);
   s.albedo *= .92 + .16 * macro;
 }
 // Damp margin (Wave C): soaked, dark and glossy for the first 0.3-0.6 m from the live
 // waterline, damp to a ragged capillary edge 1.2-2.6 m out (horizontal distance, from
 // the ground's slope), never above 0.5 m; underwater is soaked. It follows water_level
 // as the river falls. Rain (rain_wetness) darkens and glosses everything, hollows first.
 float slope = length(n0.xz) / max(n0.y, .15);
 float edge = (lumpy - .5) * .35 + (s.h - .5) * .2;
 float from_water = above / max(slope, .03) + edge;
 float reach = 1.2 + 1.4 * swale;
 float damp = kind < -.5 ? 0.0 : (1.0 - smoothstep(reach - .1, reach + .06, from_water)) * (1.0 - smoothstep(.35, .5, above));
 float soak = kind < -.5 ? 0.0 : 1.0 - smoothstep(.45, .85, from_water - (reach - 1.2) * .2);
 float rain = rain_wetness * smoothstep(.2, .6, n0.y) * mix(1.0, .7, smoothstep(.4, .8, s.h));
 float wet = max(max(damp * .75, soak), rain * .8);
 float lum = dot(s.albedo, vec3(.2126, .7152, .0722));
 // The soaked strip carries a skin of fine grey-brown silt that evens out the stones.
 // Under the water the river's own absorption does the darkening: a lighter hand there.
 float under = 1.0 - smoothstep(-.3, -.03, above);
 s.albedo = mix(s.albedo, vec3(lum) * vec3(1.0, .93, .82), soak * .4 * (1.0 - under));
 s.albedo = max(mix(vec3(lum), s.albedo, 1.0 + .3 * wet), 0.0) * mix(mix(1.0, .42, max(damp, rain * .8)) * mix(1.0, .8, soak), .62, under);
 // Damp ground is satin, not mirror-like (sky reflections washed the darkening out);
 // water stands only in the hollows between stones and on the soaked strip.
 s.rough = mix(s.rough, mix(.52, .2, max(soak * .7, smoothstep(.45, .1, s.h))), wet * .92);
 // Dry cliff rock is matte: the scan roughness let ledge faces mirror the moon as bright
 // streaks at night. Walls keep only the wet band and rain glossy.
 float wall = kind > 2.5 && kind < 3.5 ? 1.0 : 0.0;
 s.rough = max(s.rough, wall * (1.0 - max(soak, rain)) * mix(.62, .9, 1.0 - smoothstep(.55, .85, n0.y)));
 // Bank the falling river has uncovered since June: a faint pale silt film.
 float silt = kind < -.5 ? 0.0 : (1.0 - wet) * (1.0 - smoothstep(.05, .14, world.y)) * smoothstep(.3, .6, swale);
 s.albedo = mix(s.albedo, vec3(lum) * vec3(1.06, 1.05, 1.0), silt * .3);
 float snow = snow_amount * smoothstep(.45, .9, n0.y) * smoothstep(water_level + .12, water_level + .3, world.y);
 ALBEDO = mix(s.albedo, vec3(.78, .81, .83), snow);
 ROUGHNESS = clamp(mix(s.rough, .7, snow), 0.0, 1.0); AO = s.ao;
 SPECULAR = .5 - .22 * wall;
 // Normal maps cast no shadows; let the scans' cavity AO dim direct sun too, the
 // contact shading a sunlit cobble bar has between its stones.
 AO_LIGHT_AFFECT = 1.0;
 float strength = 1.0 - smoothstep(40.0, 70.0, dist);
 NORMAL = normalize((VIEW_MATRIX * vec4(normalize(mix(n0, s.n, strength * (1.0 - snow * .7))), 0)).xyz);
 if (review_mode == 1) {
   ALBEDO = vec3(0.0); EMISSION = vec3(review_sand, review_stone * (1.0 - review_sand), 1.0);
 }
}
