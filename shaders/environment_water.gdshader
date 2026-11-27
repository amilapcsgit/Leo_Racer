shader_type spatial;
render_mode cull_disabled;
uniform int detail = 1;
uniform int shore_mode = 0;
uniform bool ocean = false;
uniform vec2 lake_center = vec2(215.,-80.);
uniform vec2 lake_extent = vec2(85.,125.);
uniform float coast_x = -145.;
uniform sampler2D shore_distance: filter_linear, repeat_disable;
uniform vec2 shore_origin = vec2(0.);
uniform vec2 shore_extent = vec2(1.);
uniform vec3 deep_color : source_color = vec3(.08,.27,.32);
uniform vec3 shallow_color : source_color = vec3(.23,.46,.42);
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
uniform sampler2D scene_depth : hint_depth_texture, filter_nearest, repeat_disable;
#endif
varying vec3 world;
void vertex() { world = (MODEL_MATRIX * vec4(VERTEX,1.)).xyz; }
void fragment() {
	vec2 p = world.xz;
	float width = ocean ? 35. : 12.;
	float distance_to_bank = width;
	if (shore_mode == 1) {
		distance_to_bank = abs(p.x - (coast_x - 4.*sin(p.y*.003)));
	} else if (shore_mode == 2) {
		distance_to_bank = abs(length((p-lake_center)/lake_extent)-1.)*min(lake_extent.x,lake_extent.y);
	} else if (shore_mode == 3) {
		distance_to_bank = texture(shore_distance,(p-shore_origin)/max(shore_extent,vec2(.001))).r*72.;
	}
	float bank = 1.-smoothstep(.8,width,distance_to_bank);
#if CURRENT_RENDERER == RENDERER_FORWARD_PLUS
	if (detail >= 2) {
		float depth = texture(scene_depth,SCREEN_UV).r;
		vec4 below = INV_PROJECTION_MATRIX*vec4(SCREEN_UV*2.-1.,depth,1.);
		float gap = max(0.,-below.z/below.w+VERTEX.z);
		bank = max(bank,(1.-smoothstep(.15,2.4,gap))*.48);
	}
#endif
	float a = sin(dot(p,vec2(.47,.23))+TIME*1.25);
	float b = cos(dot(p,vec2(-.18,.68))-TIME*.91);
	float foam = smoothstep(.68,.94,sin(distance_to_bank*1.8-TIME*.8+b*1.6));
	foam *= pow(bank,5.)*(ocean ? .47 : .15);
	vec2 slope = vec2(a,b);
	if (detail > 0) slope += vec2(sin(dot(p,vec2(1.7,-.84))+TIME*2.),cos(dot(p,vec2(.87,2.1))-TIME))*.25;
	NORMAL_MAP = vec3(.5+slope*(ocean ? .066 : .034),1.);
	ALBEDO = mix(deep_color,shallow_color,bank*.86)*(1.+a*b*.055)+vec3(.52,.64,.57)*foam;
	ROUGHNESS = ocean ? .27 : .37;
	SPECULAR = .41;
	METALLIC = .05;
}
