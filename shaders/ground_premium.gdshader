shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
uniform bool landscaped=true;
uniform bool coastal=false;
uniform sampler2D ground_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D ground_normal : hint_normal,filter_linear_mipmap,repeat_enable;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float patch=noise(world.xz*.035)*.6+noise(world.xz*.13)*.4;
 float canopy=smoothstep(12.,60.,world.y);
 vec3 grass=mix(vec3(.075,.12,.055),vec3(.19,.23,.09),patch);
 vec3 forest=mix(vec3(.055,.12,.072),vec3(.17,.245,.105),patch);
 float footprint=max(length(dFdx(world.xz)),length(dFdy(world.xz)));
 float detail=mix(.5,noise(world.xz*9.),1.-smoothstep(.05,.35,footprint));
 vec3 mineral=texture(ground_albedo,world.xz/2.4).rgb;
 ALBEDO=mix(grass,forest,canopy)*(1.-noise(world.xz*.7)*.13)*mix(.91,1.05,detail)*mix(vec3(1.),mineral*1.5,.10);
 ROUGHNESS=.96;SPECULAR=.12;
}
