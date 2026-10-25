shader_type spatial;
render_mode cull_back;
uniform sampler2D source_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D local_atlas : source_color, filter_linear_mipmap_anisotropic;
uniform vec4 plaster_tint : source_color=vec4(1.);
varying vec3 local_position;
varying vec3 face_normal;
void vertex(){ local_position=VERTEX;face_normal=NORMAL; }
void fragment(){
 vec3 base=texture(source_atlas,UV).rgb;
 vec2 mapped=abs(face_normal.x)>.6?local_position.zy:local_position.xy;
 vec2 cell=fract(mapped*.3)*.48+.01;
 bool blue=base.b>base.r*1.15 && base.b>base.g*.98;
 bool roof=abs(face_normal.y)>.25;
 vec2 offset=roof?vec2(.5,.5):vec2(0.);
 vec3 plaster=texture(local_atlas,cell+offset).rgb*plaster_tint.rgb;
 ALBEDO=mix(base*.78,plaster,roof?.9:.65);
 ROUGHNESS=.86;
 if(blue&&!roof){ALBEDO=base*vec3(.55,.72,.7);ROUGHNESS=.24;METALLIC=.12;}
 if(max(base.r,max(base.g,base.b))<.18){ALBEDO=texture(local_atlas,cell+vec2(0.,.5)).rgb*.55;}
}
