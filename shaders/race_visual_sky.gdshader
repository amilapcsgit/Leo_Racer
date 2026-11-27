shader_type spatial;
render_mode unshaded, fog_disabled, cull_disabled, depth_draw_never, shadows_disabled;
uniform vec4 top_color : source_color;
uniform vec4 horizon_color : source_color;
varying vec2 clip_uv;
void vertex(){clip_uv=VERTEX.xy;POSITION=vec4(VERTEX.xy,CLIP_SPACE_FAR+(CLIP_SPACE_FAR>.5 ? -.000001 : .000001),1.);}
void fragment(){
 vec4 far_view=INV_PROJECTION_MATRIX*vec4(clip_uv,CLIP_SPACE_FAR+0.000001,1.);
 vec3 ray=normalize((INV_VIEW_MATRIX*vec4(normalize(far_view.xyz/far_view.w),0.)).xyz);
 float h=smoothstep(0.,.62,max(0.,ray.y));
 ALBEDO=mix(horizon_color.rgb,top_color.rgb,h);
}
