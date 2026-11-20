shader_type spatial;
render_mode cull_disabled;
uniform int detail = 1;
uniform vec3 low_color : source_color = vec3(.19,.30,.10);
uniform vec3 high_color : source_color = vec3(.55,.62,.25);
varying float blade_height;
varying float variation;
void vertex() {
	vec2 anchor = MODEL_MATRIX[3].xz;
	blade_height = UV.y;
	variation = fract(sin(dot(floor(anchor*.72),vec2(17.23,43.71)))*8337.25);
	float wind = sin(dot(anchor,vec2(.2,.115))-TIME*1.7);
	if (detail > 0) wind += .32*sin(dot(anchor,vec2(.73,-.61))-TIME*3.8);
	VERTEX.xz += vec2(.21,.13)*wind*blade_height*blade_height;
}
void fragment() {
	ALBEDO = mix(low_color,high_color,blade_height*(.36+variation*.64));
	ROUGHNESS = .93;
	SPECULAR = .1;
}
