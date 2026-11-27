shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float glitch=0.;
uniform float animation_time=0.;
void fragment(){
 vec2 warp=vec2(sin(floor(UV.y*38.)+animation_time*150.)*.025*glitch,0.);
 vec3 reset=texture(screen_tex,SCREEN_UV+warp).rgb;
 reset.r=texture(screen_tex,SCREEN_UV+warp+vec2(.008*glitch,0.)).r;
 float band=step(.86,sin(UV.y*180.+animation_time*120.))*glitch*.27;
 COLOR=vec4(reset,glitch*.85+band);
}
