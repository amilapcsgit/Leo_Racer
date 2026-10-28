shader_type canvas_item;
uniform vec2 rect_size=vec2(1216.,488.);
void fragment(){
 vec4 color=texture(TEXTURE,UV)*COLOR;
 vec2 q=abs((UV-.5)*rect_size)-(rect_size*.5-vec2(14.));
 float edge=length(max(q,vec2(0.)))+min(max(q.x,q.y),0.)-14.;
 COLOR=vec4(color.rgb,color.a*(1.-smoothstep(-1.,1.,edge)));
}
