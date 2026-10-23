shader_type spatial;
uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_enable;
void fragment(){
 vec3 c=texture(atlas,UV).rgb;
 float tile=smoothstep(.04,.16,c.b-max(c.r,c.g*.85));
 vec3 clay=vec3(.39,.22,.14)*(.65+dot(c,vec3(.21,.72,.07)));
 ALBEDO=mix(c,clay,tile)*COLOR.rgb;ROUGHNESS=.88;SPECULAR=.18;
}
