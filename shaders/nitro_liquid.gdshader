shader_type canvas_item;
uniform float fuel = 1.0;
uniform float animation_time = 0.0;
uniform float motion = 1.0;
void fragment(){
 vec2 p=(UV-.5)*400.0;
 float radius=length(p);
 float angle=atan(p.y,p.x);
 float t=(2.408554-angle)/1.675516;
 float arc=step(0.0,t)*step(t,1.0);
 float tube=1.0-smoothstep(6.0,8.0,abs(radius-164.0));
 float filled=1.0-smoothstep(fuel-.008,fuel+.008,t);
 float flow=sin(t*45.0-animation_time*3.5*motion+sin(t*17.0+animation_time*motion)*1.2);
 float crack=pow(max(0.0,sin(t*127.0+animation_time*5.0*motion)),24.0)*(.3+.7*motion);
 vec3 color=mix(vec3(.08,.58,.18),vec3(0.0,.9,.92),t);
 color*=.83+.17*flow;
 color+=vec3(.45,1.0,.65)*crack*.4;
 color+=vec3(.7,1.0,.82)*(1.0-smoothstep(.5,2.0,abs(radius-161.0)))*.45;
 COLOR=vec4(color,arc*tube*filled);
}
