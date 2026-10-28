shader_type canvas_item;
render_mode blend_mix;
uniform float strength = 0.0;
uniform float glitch = 0.0;
uniform float animation_time = 0.0;
void fragment() {
	vec2 p = UV-vec2(.5);
	float radius = length(p*vec2(1.0,1.15));
	float edge = smoothstep(.34,.71,radius);
	if(edge<.001 || strength<.001)discard;
	float angle = atan(p.y,p.x);
	float streak = pow(max(0.0,sin(angle*47.0+sin(angle*11.0)*3.0)),24.0);
	float flow = pow(max(0.0,sin(radius*52.0-animation_time*15.0+angle*3.0)),10.0);
	float light = edge*(.045+streak*flow*.28)*strength;
	float vignette=edge*strength*.075;
	COLOR = vec4(vec3(.03,.82,1.0)*(1.0-vignette),light+vignette);
}
