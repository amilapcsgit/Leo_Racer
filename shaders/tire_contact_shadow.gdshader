shader_type spatial;
render_mode unshaded, depth_draw_never, cull_disabled;
void fragment() {
	float radius=length((UV-vec2(.5))*2.0);
	ALBEDO=vec3(.025,.03,.025);
	ALPHA=(1.0-smoothstep(.15,1.0,radius))*.34;
}
