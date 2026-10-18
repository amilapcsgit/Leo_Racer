shader_type spatial;
render_mode cull_disabled;
uniform sampler2D flag_map : source_color, filter_linear_mipmap_anisotropic;
void vertex(){
 float pin=UV.x*UV.x;
 VERTEX.z+=sin(UV.x*7.0-TIME*2.4+MODEL_MATRIX[3].x)*pin*.12;
 VERTEX.y+=sin(UV.x*9.0-TIME*2.0)*pin*.035;
}
void fragment(){ALBEDO=texture(flag_map,UV).rgb;ROUGHNESS=.8;BACKLIGHT=ALBEDO*.12;}
