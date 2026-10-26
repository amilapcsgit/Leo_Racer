shader_type spatial;
render_mode unshaded,cull_disabled;
uniform vec4 distance_tint : source_color=vec4(.3,.42,.36,1.);
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1.,0.)),f.x),mix(hash(i+vec2(0.,1.)),hash(i+vec2(1.,1.)),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){float canopy=noise(world.xz*.055)*.65+noise(world.xz*.19)*.35;ALBEDO=distance_tint.rgb*(.78+canopy*.30);}
