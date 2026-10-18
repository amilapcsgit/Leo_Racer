shader_type spatial;
render_mode cull_disabled;
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 vec2 p=wp.xz;
 float lagoon=pow((p.x-215.0)/85.0,2.0)+pow((p.y+80.0)/125.0,2.0);
 float inland=step(-100.0,p.x);
 float shore=mix(smoothstep(-210.0,-139.0,p.x),smoothstep(.55,1.0,lagoon),inland);
 float wave=sin(p.x*.44+TIME*1.1+sin(p.y*.12))*sin(p.y*.38-TIME*.7);
 float tiny=sin(p.x*1.6+p.y*.87+TIME*2.0);
 vec3 deep=vec3(.009,.16,.24);
 vec3 shallow=vec3(.02,.40,.38);
 vec3 water=mix(deep,shallow,shore*.8+wave*.07);
 float foam=smoothstep(.90,.99,sin(p.x*.65+p.y*.19-TIME*.8))*pow(shore,6.0)*.55;
 ALBEDO=water+vec3(.52,.60,.55)*foam;
 EMISSION=water*.12+vec3(1.0,.7,.35)*pow(max(tiny,0.0),40.0)*.13;
 ROUGHNESS=.22;
 METALLIC=.0;
 SPECULAR=.4;
 NORMAL_MAP=vec3(.5+sin(p.x*.44+TIME)*.04,.5+cos(p.y*.38-TIME*.7)*.04,1.0);
 NORMAL_MAP_DEPTH=.65;
}
