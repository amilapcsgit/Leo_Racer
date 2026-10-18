shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
}
void fragment() {
	vec2 p = world_position.xz;
	float shore = 1.0-smoothstep(0.0,90.0,abs(p.x+145.0));
	float w = sin(p.x*.38+TIME*1.7+sin(p.y*.08))*sin(p.y*.32-TIME*.9);
	float ripple = sin(p.x*1.9+p.y*.71+TIME*2.2)*.5+.5;
	float surf = sin(p.x*.57+sin(p.y*.035)*1.7-TIME*1.35);
	float foam = smoothstep(.89,.99,surf)*pow(shore,5.0)*.74;
	vec3 deep = vec3(.008,.18,.30);
	vec3 shallow = vec3(.018,.48,.48);
	ALBEDO = mix(deep,shallow,shore*.73+w*.09)+vec3(.55,.73,.68)*foam;
	float glitter = pow(ripple,32.0)*pow(max(0.0,sin(p.y*1.3+p.x*.43+TIME)),14.0);
	EMISSION = vec3(1.0,.8,.47)*glitter*.18+mix(deep,shallow,shore*.73)*.12;
	ROUGHNESS = .23;
	METALLIC = .0;
	NORMAL_MAP = vec3(.5+cos(p.x*.38+TIME*1.7)*.045,.5+sin(p.y*.32-TIME*.9)*.04,1.0);
	NORMAL_MAP_DEPTH = .7;
}
