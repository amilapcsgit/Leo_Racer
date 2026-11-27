shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
void fragment(){
 float radius=length(local_position.xz);
 float fade=1.-smoothstep(3.0,7.0,radius);
 float seams=1.-smoothstep(.008,.025,min(abs(fract(local_position.x*.25+.5)-.5),abs(fract(local_position.z*.25+.5)-.5)));
 ALBEDO=mix(vec3(.045,.055,.065),vec3(.062,.074,.084),seams*.3);
 METALLIC=.28;ROUGHNESS=.38;SPECULAR=.35;ALPHA=fade;
}
