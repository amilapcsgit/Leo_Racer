shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
uniform sampler2D sand_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_position.xz;
 float coast=1.0-smoothstep(-132.0,-112.0,p.x);
 float lagoon=pow((p.x-215.0)/85.0,2.0)+pow((p.y+80.0)/125.0,2.0);
 float bank=1.0-smoothstep(1.0,1.18,lagoon);
 float sandy=max(coast,bank);
 vec3 sand=texture(sand_map,p*.10).rgb*vec3(.83,.73,.56);
 float patch=sin(p.x*.07)*sin(p.y*.06)*.5+.5;
 vec3 grass=mix(vec3(.055,.16,.047),vec3(.16,.27,.065),patch);
 ALBEDO=mix(grass,sand,sandy);
 ROUGHNESS=.90;
 SPECULAR=.12;
}
