shader_type spatial;
render_mode cull_back;
uniform vec4 tint : source_color = vec4(.07,.065,.06,1.0);
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform int roughness_channel = 1;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform float metal = 0.0;
uniform sampler2D sponsor_sheet : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D ehafo_patch : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform int sponsor_layout = 0;

vec4 badge(vec2 uv, vec4 target, vec4 source, bool primary) {
 vec2 point = (uv-target.xy)/target.zw;
 if (any(lessThan(point,vec2(0.0))) || any(greaterThan(point,vec2(1.0)))) return vec4(0.0);
 if (primary) return vec4(texture(ehafo_patch,point).rgb,1.0);
 return vec4(texture(sponsor_sheet,(source.xy+point*source.zw)/225.0).rgb,1.0);
}

void fragment(){
 vec4 surface = texture(color_map,UV);
 // Atlas alpha masks team-colored panels; white markings remain white and opaque.
 ALBEDO = mix(surface.rgb,surface.rgb*tint.rgb,surface.a);
 // Sponsor ink follows the existing skinned UVs and is not recolored by team tint.
 vec2 panel = vec2(fract(UV.x*2.0),UV.y);
 vec4 ink = vec4(0.0);
 if (sponsor_layout==1) {
  // Cover the old number panel before laying the primary sponsor over it.
  if (panel.x>.16 && panel.x<.84 && panel.y>.39 && panel.y<.78) ALBEDO=vec3(.008,.012,.010);
  ink = badge(panel,vec4(.18,.415,.64,.20),vec4(0.0),true);
  ALBEDO=mix(ALBEDO,ink.rgb,ink.a);
  ink = badge(panel,vec4(.23,.285,.54,.075),vec4(152.0,35.0,66.0,27.0),false);
  ALBEDO=mix(ALBEDO,ink.rgb,ink.a);
  ink = badge(panel,vec4(.19,.655,.29,.055),vec4(80.0,67.0,72.0,23.0),false);
  ALBEDO=mix(ALBEDO,ink.rgb,ink.a);
  ink = badge(panel,vec4(.52,.655,.29,.055),vec4(157.0,65.0,57.0,20.0),false);
  ALBEDO=mix(ALBEDO,ink.rgb,ink.a);
  ink = badge(panel,vec4(.19,.725,.29,.045),vec4(10.0,94.0,58.0,18.0),false);
  ALBEDO=mix(ALBEDO,ink.rgb,ink.a);
  ink = badge(panel,vec4(.52,.725,.29,.045),vec4(81.0,143.0,72.0,17.0),false);
  ALBEDO=mix(ALBEDO,ink.rgb,ink.a);
 } else if (sponsor_layout==2) {
  ink=badge(vec2(fract(UV.x),UV.y),vec4(.30,.325,.40,.085),vec4(80.0,67.0,72.0,23.0),false);
  ALBEDO=mix(ALBEDO,ink.rgb,ink.a);
  ink=badge(vec2(fract(UV.x),UV.y),vec4(.30,.43,.40,.085),vec4(10.0,94.0,58.0,18.0),false);
  ALBEDO=mix(ALBEDO,ink.rgb,ink.a);
 }
 NORMAL_MAP = texture(normal_map,UV).rgb;
 NORMAL_MAP_DEPTH = .65;
 METALLIC = metal;
 ROUGHNESS = texture(roughness_map,UV)[roughness_channel];
}
