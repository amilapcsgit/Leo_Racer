shader_type spatial;
uniform vec4 base_color : source_color = vec4(.15,.5,.5,1.);
uniform vec4 led_color : source_color = vec4(1.,.015,.42,1.);
uniform float phase = 0.;
uniform float night_gain = 1.;
uniform float pattern = 0.;
varying vec3 local_point;
varying vec3 local_normal;
void vertex(){local_point=VERTEX;local_normal=NORMAL;}
void fragment(){
 float angle=atan(local_point.z,local_point.x);
 float ribs=pow(abs(sin(angle*12.+local_point.y*.32)),18.);
 float edge=pow(1.-abs(dot(normalize(local_normal),normalize(VIEW))),3.);
 float mask=pattern>.5 ? max(ribs*.8,edge*.7) : .36;
 float sweep=.76+.24*sin(local_point.y*.15-phase*6.2831853);
 ALBEDO=base_color.rgb;ROUGHNESS=.42;METALLIC=.15;
 EMISSION=led_color.rgb*mask*sweep*night_gain*2.2;
}
