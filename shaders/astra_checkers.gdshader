shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float checker=mod(floor(UV.x)+floor(UV.y),2.0);
 float wear=sin(wp.x*38.0+sin(wp.z*9.0))*sin(wp.z*29.0)*.5+.5;
 vec3 paint=mix(vec3(.025),vec3(.77,.74,.66),checker);
 ALBEDO=paint*mix(.92,1.0,wear);
 ROUGHNESS=mix(.34,.43,wear);
 SPECULAR=.22;
}
