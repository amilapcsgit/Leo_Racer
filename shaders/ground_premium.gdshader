shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
uniform bool landscaped=true;
uniform bool coastal=false;
uniform sampler2D ground_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D ground_normal : hint_normal,filter_linear_mipmap,repeat_enable;
float hash(vec2 cell){vec3 p=fract(vec3(cell.xyx)*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float patch=noise(world.xz*.035)*.6+noise(world.xz*.13)*.4;
 float canopy=smoothstep(12.,60.,world.y);
 vec3 grass=mix(vec3(.085,.14,.055),vec3(.20,.27,.105),patch);
 vec3 forest=mix(vec3(.06,.13,.075),vec3(.17,.245,.105),patch);
 float footprint=max(length(dFdx(world.xz)),length(dFdy(world.xz)));
 float detail=mix(.5,noise(world.xz*9.),1.-smoothstep(.05,.35,footprint));
 vec3 mineral=texture(ground_albedo,world.xz/2.4).rgb;
 vec3 soil=mix(vec3(.15,.12,.075),vec3(.29,.235,.15),patch);
 vec3 sand=mix(vec3(.34,.29,.20),vec3(.48,.42,.29),patch);
 vec3 vegetation=mix(grass,forest,canopy);
 vec3 surface=mix(soil,vegetation,landscaped ? .92 : .62);
 if(coastal)surface=mix(surface,sand,smoothstep(.43,.75,patch)*.70);
 ALBEDO=surface*(1.-noise(world.xz*.7)*.10)*mix(.94,1.04,detail)*mix(vec3(1.),mineral*1.5,.12);
 NORMAL_MAP=texture(ground_normal,world.xz/2.4).rgb;
 NORMAL_MAP_DEPTH=(landscaped ? .13 : .24)*(1.-smoothstep(.08,.65,footprint));
 ROUGHNESS=.96;SPECULAR=.10;
}
