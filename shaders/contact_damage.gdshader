shader_type spatial;
render_mode depth_draw_never, cull_back;
uniform vec3 patch_center;
uniform float patch_radius = 0.6;
varying vec3 local_position;
void vertex() { local_position = VERTEX; }
void fragment() {
	float mask = 1.0-smoothstep(patch_radius*.45,patch_radius,length(local_position-patch_center));
	float scratch = pow(abs(sin(local_position.y*170.0+sin(local_position.z*41.0)*2.0)),22.0);
	ALBEDO = mix(vec3(.055,.045,.035),vec3(.48,.47,.43),scratch);
	ROUGHNESS = .86;
	METALLIC = scratch*.35;
	NORMAL_MAP = vec3(.5+.075*sin(local_position.x*25.0)*mask,.5+.06*cos(local_position.y*23.0)*mask,1.0);
	ALPHA = mask*(.18+scratch*.58);
}
