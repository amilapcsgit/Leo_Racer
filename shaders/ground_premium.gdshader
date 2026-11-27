shader_type spatial;
render_mode cull_disabled;
varying vec3 world;
uniform bool landscaped=true;
uniform bool coastal=false;
uniform sampler2D grass_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D grass_normal : hint_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D grass_roughness : filter_linear_mipmap,repeat_enable;
uniform sampler2D grass_ao : filter_linear_mipmap,repeat_enable;
uniform sampler2D grass_height : filter_linear_mipmap,repeat_enable;
uniform bool grass_displacement = false;
uniform vec3 terrain_palette=vec3(1.);
uniform sampler2D ground_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D ground_normal : hint_normal,filter_linear_mipmap,repeat_enable;
float hash(vec2 cell){vec3 p=fract(vec3(cell.xyx)*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);}
void vertex(){
 world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 if (grass_displacement && landscaped) {
  float range_fade=1.-smoothstep(12.,45.,distance(world,CAMERA_POSITION_WORLD));
  float relief=(textureLod(grass_height,world.xz/4.,1.).r-.5)*.035;
  VERTEX+=inverse(mat3(MODEL_MATRIX))*vec3(0.,relief*range_fade,0.);
 }
}
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
 vec3 vegetation=mix(grass,forest,canopy)*terrain_palette;
 vec3 surface=mix(soil,vegetation,landscaped ? .92 : .62);
 if(coastal)surface=mix(surface,sand,smoothstep(.43,.75,patch)*.70);
 vec2 grass_uv=world.xz/4.;
 vec3 mapped_grass=texture(grass_albedo,grass_uv).rgb;
 float coverage=landscaped ? .82 : .48;
 if(coastal) coverage*=1.-smoothstep(.43,.75,patch)*.70;
 surface=mix(surface,mapped_grass*terrain_palette,coverage);
 AO=mix(1.,texture(grass_ao,grass_uv).r,coverage*.65);
 ALBEDO=surface*(1.-noise(world.xz*.7)*.10)*mix(.94,1.04,detail)*mix(vec3(1.),mineral*1.5,.26);
 NORMAL_MAP=mix(texture(ground_normal,world.xz/2.4).rgb,texture(grass_normal,grass_uv).rgb,coverage);
 NORMAL_MAP_DEPTH=(landscaped ? .13 : .24)*(1.-smoothstep(.08,.65,footprint));
 ROUGHNESS=mix(.96,texture(grass_roughness,grass_uv).r,coverage);SPECULAR=.10;
}
