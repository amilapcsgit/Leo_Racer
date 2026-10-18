shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float phase = 0.0;
void fragment(){
	float pulse = .85+.15*sin(TIME*5.5+phase);
	ALBEDO = vec3(.05,.66,.88);
	EMISSION = vec3(.05,.62,1.0)*2.5*pulse;
}
