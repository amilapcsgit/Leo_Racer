shader_type spatial;
render_mode cull_disabled;
uniform vec4 leaf_color : source_color = vec4(.08,.28,.09,1.0);
uniform float strength = .09;
varying float shade;
void vertex(){
 vec3 wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;
 float weight=clamp((VERTEX.y-3.0)/5.0,0.0,1.0);
 VERTEX.x+=sin(TIME*1.5+wp.x*.28+wp.z*.2)*weight*strength;
 VERTEX.z+=cos(TIME*1.1+wp.z*.3)*weight*strength*.7;
 shade=.80+.20*sin(VERTEX.x*2.3+VERTEX.z*1.2);
}
void fragment(){ALBEDO=leaf_color.rgb*shade;ROUGHNESS=.66;BACKLIGHT=vec3(.12,.19,.035);}
