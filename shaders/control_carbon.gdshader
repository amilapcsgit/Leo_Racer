shader_type canvas_item;
void fragment(){
 vec2 p=UV*vec2(735.0,45.0);
 vec2 tile=floor(p/4.0);
 float weave=mod(tile.x+tile.y,2.0);
 float fiber=sin((p.x+p.y)*2.5)*.012;
 float glow=(1.0-smoothstep(0.0,5.0,p.y))*.14;
 vec3 c=mix(vec3(.016,.021,.027),vec3(.033,.043,.052),weave)+fiber;
 COLOR=vec4(c+vec3(0.0,.7,.8)*glow,.94);
}
