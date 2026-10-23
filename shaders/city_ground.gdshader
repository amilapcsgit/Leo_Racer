shader_type spatial;
varying vec3 world;
uniform vec3 tint : source_color = vec3(.43,.44,.37);
uniform sampler2D ground_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D ground_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform bool landscaped = false;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float grain=noise(world.xz*2.)*.07+noise(world.xz*.06)*.10;
 float park=smoothstep(-843.,-838.,world.x)*(1.-smoothstep(-620.,-615.,world.x))*smoothstep(-520.,-513.,world.z)*(1.-smoothstep(563.,570.,world.z));
 float sand=1.-smoothstep(-865.,-849.,world.x);
 park=max(park,landscaped ? 1.0 : 0.0);
 vec3 paving=texture(ground_albedo,world.xz*.22).rgb*vec3(.24,.26,.21);
 vec3 lawn=mix(vec3(.045,.095,.016),vec3(.12,.19,.04),grain*3.5);
 ALBEDO=mix(mix(paving,lawn,park),vec3(.57,.50,.35)+grain*.3,sand);
 NORMAL_MAP=texture(ground_normal,world.xz*.22).rgb;NORMAL_MAP_DEPTH=.20*(1.-park);
 ROUGHNESS=.94;SPECULAR=.12;
}
