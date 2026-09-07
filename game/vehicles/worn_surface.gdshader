shader_type spatial;
render_mode cull_back;
uniform vec4 tint : source_color = vec4(.07,.065,.06,1.0);
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform int roughness_channel = 1;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float metal = 0.0;
void fragment(){
 vec4 surface = texture(color_map,UV);
 // Atlas alpha masks team-colored panels; white markings remain white and opaque.
 ALBEDO = mix(surface.rgb,surface.rgb*tint.rgb,surface.a);
 NORMAL_MAP = texture(normal_map,UV).rgb;
 NORMAL_MAP_DEPTH = .65;
 METALLIC = metal;
 ROUGHNESS = texture(roughness_map,UV)[roughness_channel];
}
