shader_type canvas_item;
render_mode blend_add;
uniform float strength = 0.0;
void fragment() {
	vec2 p = UV-vec2(.5);
	float angle = atan(p.y,p.x);
	float radius = length(p*vec2(1.0,1.15));
	float edge = smoothstep(.34,.71,radius);
	float streak = pow(max(0.0,sin(angle*47.0+sin(angle*11.0)*3.0)),24.0);
	float flow = pow(max(0.0,sin(radius*52.0-TIME*15.0+angle*3.0)),10.0);
	float light = edge*(.045+streak*flow*.28)*strength;
	COLOR = vec4(.12,.61,1.0,light);
}
