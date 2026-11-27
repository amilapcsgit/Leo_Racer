shader_type spatial;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap, repeat_enable;
varying vec3 world;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 uv=world.xz/1.5;
 ALBEDO=texture(color_map,uv).rgb*.58;
 ROUGHNESS=clamp(texture(rough_map,uv).r*.3+.45,.55,.80);
 NORMAL_MAP=texture(normal_map,uv).rgb;
 NORMAL_MAP_DEPTH=.25;
 SPECULAR=.30;
}
