shader_type spatial;
render_mode cull_disabled;
uniform sampler2D artwork : source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform sampler2D scene_depth : filter_linear_mipmap,repeat_disable;
uniform float depth_scale=.009;
void fragment(){
 float d=texture(scene_depth,UV).r;
 vec3 v=vec3(dot(VIEW,TANGENT),dot(VIEW,BINORMAL),dot(VIEW,NORMAL));
 vec2 uv=clamp(UV+v.xy/max(abs(v.z),.4)*(d-.5)*depth_scale,vec2(.002),vec2(.998));
 vec3 color=texture(artwork,uv).rgb;
 ALBEDO=color;EMISSION=color*.065;ROUGHNESS=.68;SPECULAR=.15;
}
