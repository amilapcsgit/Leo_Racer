shader_type canvas_item;
render_mode unshaded, blend_add;
uniform float effect_time = 0.0;
void fragment() {
 vec2 p=UV;
 float title=exp(-length((p-vec2(0.15,0.09))*vec2(5.0,16.0)))*0.13;
 float edge=exp(-abs(p.x-0.982)*160.0)*smoothstep(0.2,0.9,p.y)*0.20;
 float curve=0.93-0.06*sin(p.x*3.0);
 float floor_light=exp(-abs(p.y-curve)*220.0)*smoothstep(0.4,0.9,p.x)*0.12;
 float breathe=0.92+0.08*sin(effect_time*0.7);
 COLOR=vec4(vec3(0.263,0.906,0.937),(title+edge+floor_light)*breathe);
}
