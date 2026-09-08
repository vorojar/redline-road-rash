shader_type spatial;
// Source shell contains authored double-sided panels.
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(.1,.2,.3,1.0);
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic;
uniform int pattern = 0;
void fragment(){
 vec3 original=texture(color_map,UV).rgb;
 float decal=1.0-smoothstep(.08,.25,original.r-max(original.g,original.b));
 // UV-space markings remain fixed to the shell during skeletal animation.
 float x=UV.x-.5;
 float y=UV.y;
 if(pattern==1) decal=1.0-smoothstep(.040,.048,abs(x));
 else if(pattern==2) decal=1.0-smoothstep(.020,.028,abs(abs(x)-.16));
 else if(pattern==3){
  float checker=mod(floor(UV.x*14.0)+floor(y*14.0),2.0);
  decal=checker*(1.0-smoothstep(.22,.23,abs(x)));
 }
 else if(pattern==4) decal=smoothstep(.65,.82,sin((x+y)*35.0));
 else if(pattern==5) decal=1.0-smoothstep(.022,.028,abs(y-.45));
 ALBEDO=mix(tint.rgb,vec3(.88,.87,.81),decal);
 METALLIC=.14;
 ROUGHNESS=.28;
}
