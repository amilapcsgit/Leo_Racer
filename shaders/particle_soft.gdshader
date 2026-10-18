shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;
uniform vec4 tint:source_color=vec4(.58,.65,.67,.32);
void vertex(){MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);}
void fragment(){float r=length(UV-.5)*2.0;ALBEDO=tint.rgb*COLOR.rgb;ALPHA=pow(max(0.0,1.0-r*r),2.0)*tint.a*COLOR.a;}
