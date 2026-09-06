shader_type sky;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void sky(){
 float h=max(EYEDIR.y,0.0);
 vec3 base=mix(vec3(.64,.69,.71),vec3(.24,.35,.43),pow(h,.55));
 vec2 uv=EYEDIR.xz/max(.13,EYEDIR.y+.12)*1.8;
 float n=noise(uv)*.55+noise(uv*2.1)*.27+noise(uv*4.4)*.13+noise(uv*9.)*.05;
 float cloud=smoothstep(.44,.72,n)*smoothstep(0.,.16,h);
 COLOR=mix(base,vec3(.76,.77,.75),cloud*.82);
}
