shader_type spatial;
render_mode cull_disabled;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool has_normal = false;
uniform float sway = .065;
void vertex(){
 vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float weight=clamp(VERTEX.y*.45,.05,1.0);
 VERTEX.x+=sin(TIME*1.35+wp.x*.24+wp.z*.18)*weight*sway;
 VERTEX.z+=cos(TIME*1.1+wp.z*.22)*weight*sway*.6;
}
void fragment(){
 vec4 c=texture(color_map,UV)*tint;
 if(c.a<.45)discard;
 ALBEDO=c.rgb;ROUGHNESS=.67;
 if(has_normal){NORMAL_MAP=texture(normal_map,UV).rgb;NORMAL_MAP_DEPTH=.45;}
 BACKLIGHT=vec3(.06,.09,.025);
}
