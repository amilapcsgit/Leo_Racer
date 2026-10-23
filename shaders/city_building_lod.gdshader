shader_type spatial;
varying vec3 world_position;
void vertex(){world_position=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float horizontal=world_position.x+world_position.z;
 float window=smoothstep(.12,.20,fract(horizontal/2.3))*(1.-smoothstep(.58,.66,fract(horizontal/2.3)));
 window*=smoothstep(.22,.3,fract(world_position.y/3.2))*(1.-smoothstep(.66,.74,fract(world_position.y/3.2)));
 ALBEDO=mix(vec3(.72,.67,.55)*COLOR.rgb,vec3(.14,.23,.26),window*.65);ROUGHNESS=.9;
}
