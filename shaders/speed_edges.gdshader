shader_type canvas_item;
render_mode blend_mix;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float strength = 0.0;
uniform float glitch = 0.0;
uniform float animation_time = 0.0;
void fragment() {
	vec2 p = UV-vec2(.5);
	float angle = atan(p.y,p.x);
	float radius = length(p*vec2(1.0,1.15));
	float edge = smoothstep(.34,.71,radius);
	float streak = pow(max(0.0,sin(angle*47.0+sin(angle*11.0)*3.0)),24.0);
	float flow = pow(max(0.0,sin(radius*52.0-animation_time*15.0+angle*3.0)),10.0);
	float light = edge*(.045+streak*flow*.28)*strength;
	float reset_band=step(.86,sin(UV.y*180.0+animation_time*120.0))*glitch*.27;
	vec2 warp=vec2(sin(floor(UV.y*38.0)+animation_time*150.0)*.025*glitch,0.0);
	vec3 reset=texture(screen_tex,SCREEN_UV+warp).rgb;
	reset.r=texture(screen_tex,SCREEN_UV+warp+vec2(.008*glitch,0)).r;
	COLOR = vec4(mix(vec3(.03,.82,1.0),reset,step(.001,glitch)),max(light,glitch*.85)+reset_band);
}
