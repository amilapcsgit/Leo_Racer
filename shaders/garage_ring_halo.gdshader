shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;
uniform vec4 tint : source_color = vec4(0.263,0.906,0.937,1.0);
void fragment() {
 ALBEDO=tint.rgb;
 ALPHA=0.14*pow(max(0.0,1.0-abs(UV.y*2.0-1.0)),2.0);
}
