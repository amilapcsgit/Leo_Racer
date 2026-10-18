shader_type spatial;
uniform vec4 tint : source_color = vec4(.1,.4,.4,1.0);
uniform sampler2D concrete_color : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool glass = false;
varying vec3 world;
varying vec3 world_normal;
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;world_normal=MODEL_NORMAL_MATRIX*NORMAL;}
void fragment(){
 vec2 uv=abs(world_normal.y)>.7?world.xz*.6:(abs(world_normal.x)>.7?world.zy*.6:world.xy*.6);
 vec3 tex=texture(concrete_color,uv).rgb;
 float detail=mix(.80,1.14,dot(tex,vec3(.333)));
 ALBEDO=tint.rgb*COLOR.rgb*detail;
 ROUGHNESS=glass?.18:.72;
 METALLIC=glass?.68:.02;
 NORMAL_MAP=texture(concrete_normal,uv).rgb;
 NORMAL_MAP_DEPTH=glass?.025:.16;
 if(glass){
  float row=step(.83,fract(world.y*.27))*step(.78,fract(world.x*.21+world.z*.19));
  EMISSION=vec3(1.0,.46,.12)*row*.35;
 }
}
