shader_type spatial;
uniform vec4 paint : source_color = vec4(.84,.82,.74,1.0);
varying vec3 wp;
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
 float grain=fract(sin(dot(floor(wp.xz*95.0),vec2(12.9898,78.233)))*43758.5453);
 float wear=smoothstep(.92,1.0,grain)*.18*(1.0-smoothstep(.1,.2,wp.y));
 ALBEDO=paint.rgb*(1.0-wear);ROUGHNESS=.36+grain*.07;
}
