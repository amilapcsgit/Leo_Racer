shader_type canvas_item;
render_mode unshaded;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength : hint_range(0.0, 0.012) = 0.0;
void fragment() {
	vec2 direction=(SCREEN_UV-vec2(0.5))*strength;
	float edge=smoothstep(0.12,0.55,length(SCREEN_UV-vec2(0.5)));
	vec3 color=texture(screen_texture,SCREEN_UV).rgb*0.4;
	color+=texture(screen_texture,SCREEN_UV-direction*edge).rgb*0.3;
	color+=texture(screen_texture,SCREEN_UV-direction*edge*2.0).rgb*0.2;
	color+=texture(screen_texture,SCREEN_UV-direction*edge*3.0).rgb*0.1;
	COLOR=vec4(color,1.0);
}
