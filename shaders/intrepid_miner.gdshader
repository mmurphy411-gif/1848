shader_type spatial;
render_mode cull_disabled;
uniform sampler2D albedo_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_atlas : hint_normal, filter_linear_mipmap_anisotropic;
uniform sampler2D surface_atlas : filter_linear_mipmap_anisotropic;
uniform bool wettable = false;
uniform float wet_line = 0.0;
uniform float feet_y = 0.0;
varying float height;
void vertex() { height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - feet_y; }
void fragment() {
    vec3 surface = texture(surface_atlas, UV).rgb;
    float wet = wettable ? (1.0 - smoothstep(max(0.0, wet_line - .10), wet_line + .10, height)) * smoothstep(0.0, .03, wet_line) : 0.0;
    ALBEDO = texture(albedo_atlas, UV).rgb * mix(1.0, .48, wet);
    NORMAL_MAP = texture(normal_atlas, UV).rgb;
    ROUGHNESS = mix(surface.g, .30, wet);
    METALLIC = surface.b;
}
