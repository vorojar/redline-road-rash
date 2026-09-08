shader_type spatial;
uniform vec4 tint : source_color = vec4(.35,.03,.02,1.0);
uniform bool has_maps = false;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic;
uniform int roughness_channel = 1;
uniform sampler2D roughness_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform bool tint_warm_colors = false;
uniform bool has_metallic_map = false;
uniform sampler2D metallic_map : hint_default_white, filter_linear_mipmap_anisotropic;
uniform int metallic_channel = 0;
uniform float metallic_factor = 1.0;
uniform float wear = 0.0;
varying vec3 local_position;
void vertex() {
 local_position = VERTEX;
 float dent = exp(-dot((VERTEX-vec3(.12,.82,-.12))*5.0,(VERTEX-vec3(.12,.82,-.12))*5.0));
 VERTEX -= NORMAL*dent*wear*.025;
}
void fragment() {
 float scuff = smoothstep(.55,.82,sin(local_position.y*183.0+sin(local_position.z*31.0)*2.0)*.5+.5);
 float patch = smoothstep(.1,.65,sin(local_position.x*17.0+local_position.z*21.0)*.5+.5);
 float scratch = scuff*patch*wear;
 vec3 paint_color = tint.rgb;
 float paint_rough = .28;
 float paint_metal = .65;
 if (has_maps) {
  vec4 surface = texture(color_map,UV);
  // The licensed street bike has orange paint in RGB, not our authored alpha
  // mask. Recolor only that paint; keep its black panels and decals intact.
  if (tint_warm_colors) {
   surface.a = step(surface.b*1.8,surface.g)*step(surface.g*1.05,surface.r)*smoothstep(.015,.06,surface.r-surface.b);
   surface.rgb = mix(surface.rgb,vec3(max(surface.r,max(surface.g,surface.b))),surface.a);
  }
  paint_color = mix(surface.rgb,surface.rgb*tint.rgb,surface.a);
  NORMAL_MAP = texture(normal_map,UV).rgb;
  paint_rough = texture(roughness_map,UV)[roughness_channel];
  if (has_metallic_map) paint_metal = texture(metallic_map,UV)[metallic_channel]*metallic_factor;
 }
 ALBEDO = mix(paint_color*(1.0-wear*.25),vec3(.25,.27,.28),scratch*.8);
 METALLIC = mix(paint_metal,.45,wear);
 ROUGHNESS = paint_rough+wear*.38;
}
