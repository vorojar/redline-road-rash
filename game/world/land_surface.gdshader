shader_type spatial;
render_mode cull_disabled;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform int surface_kind = 0; // asphalt, gravel shoulder, terrain
varying vec3 world_position;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p); f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}
void vertex() { world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz; }
void fragment() {
 vec3 tex=texture(color_map,UV).rgb;
 float broad=noise(world_position.xz*.045);
 NORMAL_MAP=texture(normal_map,UV).rgb;
 NORMAL_MAP_DEPTH=.28;
 ROUGHNESS=.9;
 if (surface_kind==0) {
  float lateral=UV.x*4.0;
  float distance=UV.y*4.0;
  float lane=mod(lateral+6.24,3.12);
  float tracks=exp(-pow((lane-.82)*3.0,2.0))+exp(-pow((lane-2.30)*3.0,2.0));
  float edge=smoothstep(5.95,6.5,abs(lateral)+noise(vec2(distance*.7,lateral))*.16);
  float section=floor(distance/63.0);
  float patch_length=mod(distance,63.0);
  float patch=smoothstep(3.0,3.25,patch_length)*(1.0-smoothstep(9.0,9.3,patch_length));
  float patch_center=mix(-4.3,4.3,hash(vec2(section,7.0)));
  patch*=1.0-smoothstep(.85,1.0,abs(lateral-patch_center));
  ALBEDO=tex*(.60+broad*.16)*(1.0-tracks*.11);
  ALBEDO=mix(ALBEDO,ALBEDO*.72,patch*.7);
  ALBEDO=mix(ALBEDO,vec3(.17,.155,.12),edge*.55);
  ROUGHNESS=.88-tracks*.09+edge*.09;
 } else if (surface_kind==1) {
  ALBEDO=tex*mix(vec3(.40,.35,.26),vec3(.61,.55,.42),broad);
 } else {
  float meadow=noise(world_position.xz*.12);
  ALBEDO=tex*mix(vec3(.22,.30,.16),vec3(.39,.40,.25),broad);
  ALBEDO*=.88+meadow*.22;
 }
}
