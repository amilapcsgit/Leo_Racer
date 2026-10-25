shader_type spatial;
render_mode cull_disabled;
varying vec3 p;
varying vec3 n;
void vertex(){p=VERTEX;n=NORMAL;}
void fragment(){
 float grain=fract(sin(dot(floor(p.xz*3.0),vec2(12.9898,78.233)))*43758.54);
 float patch=sin(p.x*.035)*sin(p.z*.027)*.5+.5;
 vec3 grass=mix(vec3(.19,.28,.12),vec3(.38,.43,.22),patch);
 vec3 soil=vec3(.32,.27,.18);
 ALBEDO=mix(soil,grass,smoothstep(.55,.9,n.y))*(.88+grain*.2);
 ROUGHNESS=.97;
}
