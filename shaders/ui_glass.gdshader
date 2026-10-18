shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform vec4 panel_color : source_color = vec4(.025,.042,.052,.90);
uniform vec2 panel_size=vec2(400,300);
void fragment(){
 vec2 p=UV*panel_size;
 float cut=14.0;
 float mask=step(cut,p.x+p.y)*step(cut,panel_size.x+panel_size.y-p.x-p.y);
 float edge=min(min(p.x,p.y),min(panel_size.x-p.x,panel_size.y-p.y));
 float carbon=mod(floor(p.x/3.0)+floor(p.y/3.0),2.0)*.012;
 vec3 scene=textureLod(screen_tex,SCREEN_UV,2.4).rgb;
 vec3 base=mix(scene,panel_color.rgb,panel_color.a)+carbon;
 base+=vec3(0,.32,.36)*(1.0-smoothstep(0.0,1.4,edge))*.55;
 COLOR=vec4(base,mask*.98);
}
