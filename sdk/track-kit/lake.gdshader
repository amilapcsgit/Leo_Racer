shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float ripple=sin(world_position.x*.7+TIME*.65)*sin(world_position.z*.9-TIME*.4);
 ALBEDO=mix(vec3(.12,.28,.25),vec3(.27,.43,.37),ripple*.15+.35);
 ROUGHNESS=.23+ripple*.035;METALLIC=.16;NORMAL_MAP=vec3(.5+ripple*.035,.5+sin(world_position.x+TIME)*.025,1.);
}
