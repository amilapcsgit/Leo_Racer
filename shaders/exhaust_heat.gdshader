shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float gain=0.0;
void fragment(){
 vec2 uv=UV*2.0-1.0;
 float edge=pow(max(0.0,1.0-dot(uv,uv)),2.0);
 vec2 warp=vec2(sin(UV.y*35.0-TIME*45.0),cos(UV.x*22.0+TIME*30.0))*.003*edge*gain;
 ALBEDO=texture(screen_tex,SCREEN_UV+warp).rgb;
 ALPHA=edge*.32*gain;
}
