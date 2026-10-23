shader_type spatial;
render_mode cull_disabled;
uniform bool ocean = true;
uniform vec2 lake_center = vec2(300.0,25.0);
uniform float lake_radius = 125.0;
uniform float coast_x = -853.0;
uniform vec3 deep_color : source_color = vec3(.025,.20,.29);
uniform vec3 shallow_color : source_color = vec3(.06,.40,.39);
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=world_position.xz;
 float shore=ocean ? abs(p.x-(coast_x-4.0*sin(p.y*.003))) : abs(length(p-lake_center)-lake_radius);
 float near_shore=1.0-smoothstep(1.0,24.0,shore);
 float a=sin(p.x*.49+p.y*.18+TIME*1.4);
 float b=sin(p.y*.71-p.x*.11-TIME*.8);
 float scale=ocean ? 1.0 : .35;
 NORMAL_MAP=vec3(.5+cos(p.x*.49+p.y*.18+TIME*1.4)*.055*scale,.5+cos(p.y*.71-p.x*.11-TIME*.8)*.035*scale,1.0);
 NORMAL_MAP_DEPTH=.7;
 float foam=smoothstep(.73,.97,sin(shore*1.2-TIME*1.1+p.y*.04))*pow(near_shore,6.0)*.35*scale;
 ALBEDO=mix(deep_color,shallow_color,near_shore*.7)+vec3(.65,.73,.66)*foam+(a*b)*.008;
 ROUGHNESS=ocean ? .26 : .48; METALLIC=0.0; SPECULAR=ocean ? .45 : .18;
}
