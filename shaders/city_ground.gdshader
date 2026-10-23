shader_type spatial;
varying vec3 world;
uniform vec3 tint : source_color = vec3(.43,.44,.37);
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 float grain=sin(world.x*.45)*sin(world.z*.63)*.012+sin(world.x*.08+world.z*.11)*.018;
 ALBEDO=tint+vec3(grain);ROUGHNESS=.94;SPECULAR=.08;
}
