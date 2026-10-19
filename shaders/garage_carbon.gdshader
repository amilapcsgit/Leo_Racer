shader_type canvas_item;
void fragment() {
	vec2 p = floor(FRAGCOORD.xy / 3.0);
	float weave = mod(p.x + p.y, 4.0) < 2.0 ? 1.0 : 0.0;
	vec3 fiber = mix(vec3(.043,.041,.038), vec3(.068,.064,.055), weave);
	COLOR = vec4(fiber, COLOR.a);
}
