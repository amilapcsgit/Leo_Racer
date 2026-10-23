shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex(){
 world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 VERTEX.x+=sin(TIME*1.3+world_position.x*.3+world_position.z*.2)*.025*(1.0-UV.y);
}
void fragment(){
 float blade=1.0-abs(UV.x-.5)*2.0;
 if(blade<UV.y*.65)discard;
 ALBEDO=mix(vec3(.16,.25,.07),vec3(.36,.43,.16),UV.y);ROUGHNESS=.95;
}
