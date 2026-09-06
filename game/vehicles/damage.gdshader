shader_type spatial;
uniform vec4 tint : source_color = vec4(.35,.03,.02,1.0);
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
 ALBEDO = mix(tint.rgb*(1.0-wear*.25),vec3(.25,.27,.28),scratch*.8);
 METALLIC = mix(.65,.45,wear);
 ROUGHNESS = .28+wear*.38;
}
