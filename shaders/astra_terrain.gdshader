shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
uniform bool grass_displacement=true;
uniform sampler2D sand_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grass_albedo : source_color,filter_linear_mipmap,repeat_enable;
uniform sampler2D grass_normal : hint_normal,filter_linear_mipmap,repeat_enable;
uniform sampler2D grass_roughness : filter_linear_mipmap,repeat_enable;
uniform sampler2D grass_ao : filter_linear_mipmap,repeat_enable;
uniform sampler2D grass_height : filter_linear_mipmap,repeat_enable;
float terrain_hash(vec2 cell){vec3 p=fract(vec3(cell.xyx)*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float terrain_noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(terrain_hash(i),terrain_hash(i+vec2(1.,0.)),f.x),mix(terrain_hash(i+vec2(0.,1.)),terrain_hash(i+vec2(1.,1.)),f.x),f.y);}
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;
 vec2 p=world_position.xz;
 if (grass_displacement) {
  float coast=smoothstep(-132.,-112.,p.x);
  float lagoon=pow((p.x-215.)/85.,2.)+pow((p.y+80.)/125.,2.);
  float grass_mask=coast*smoothstep(1.,1.18,lagoon);
  float range_fade=1.-smoothstep(12.,45.,distance(world_position,CAMERA_POSITION_WORLD));
  VERTEX.y+=(textureLod(grass_height,p/4.,1.).r-.5)*.035*range_fade*grass_mask;
 }
}
void fragment(){
 vec2 p=world_position.xz;
 float coast=1.0-smoothstep(-132.0,-112.0,p.x);
 float lagoon=pow((p.x-215.0)/85.0,2.0)+pow((p.y+80.0)/125.0,2.0);
 float bank=1.0-smoothstep(1.0,1.18,lagoon);
 float sandy=max(coast,bank);
 vec3 sand=texture(sand_map,p*.10).rgb*vec3(.83,.73,.56);
 float patch=terrain_noise(p*.035)*.65+terrain_noise(p*.13+vec2(13.,7.))*.35;
 vec3 grass=mix(vec3(.065,.16,.055),vec3(.17,.28,.09),patch);
 float footprint=max(length(dFdx(p)),length(dFdy(p)));
 float detail=mix(.5,terrain_noise(p*4.),1.-smoothstep(.06,.35,footprint));
 vec2 grass_uv=p/4.;
 grass=mix(grass,texture(grass_albedo,grass_uv).rgb,.78);
 AO=mix(texture(grass_ao,grass_uv).r,1.,sandy);
 ALBEDO=mix(grass,sand,sandy)*mix(.94,1.04,detail);
 NORMAL_MAP=mix(texture(grass_normal,grass_uv).rgb,texture(sand_normal,p*.10).rgb,sandy);
 NORMAL_MAP_DEPTH=mix(.08,.25,sandy)*(1.-smoothstep(.08,.65,footprint));
 ROUGHNESS=mix(texture(grass_roughness,grass_uv).r,.90,sandy);
 SPECULAR=.10;
}
