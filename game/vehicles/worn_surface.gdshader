shader_type spatial;
render_mode cull_back;
uniform vec4 tint : source_color = vec4(.07,.065,.06,1.0);
uniform float metal = 0.0;
uniform float rough = .78;
uniform float grain_scale = 180.0;
varying vec3 surface_position;
void vertex(){surface_position=VERTEX;}
float hash(vec3 p){return fract(sin(dot(p,vec3(17.17,127.1,31.7)))*43758.5453);}
void fragment(){
 float grain=hash(floor(surface_position*grain_scale));
 float wear=hash(floor(surface_position*18.0));
 float detail=1.0-clamp(length(fwidth(surface_position))*grain_scale,0.0,1.0);
 ALBEDO=tint.rgb*(.94+(grain-.5)*.06*detail+(wear-.5)*.04);
 METALLIC=metal;
 ROUGHNESS=clamp(rough+(grain-.5)*.10*detail,.08,1.0);
}
