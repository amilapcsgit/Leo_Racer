shader_type sky;
uniform sampler2D visual_panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D lighting_panorama : source_color, filter_linear_mipmap, repeat_enable;
uniform float horizon_offset = .017;
uniform float rotation_turns = 0.0;
void sky(){
 // Explicit world bearings: +X inland skyline, -X open ocean; matches HDR bake.
 vec2 uv=vec2(fract(atan(EYEDIR.x,EYEDIR.z)/TAU+.5+rotation_turns),acos(clamp(EYEDIR.y,-1.0,1.0))/PI);
 if(AT_CUBEMAP_PASS){COLOR=textureLod(lighting_panorama,uv,0.0).rgb;}
 else{
  uv.y=clamp(uv.y+horizon_offset,0.0,1.0);
  // atan's wrap discontinuity must not select the coarsest mip as a vertical stripe.
  vec3 color=textureLod(visual_panorama,uv,0.0).rgb;
  // Narrow symmetric wrap blend prevents the generated matte's edge seam.
  float seam=1.0-smoothstep(0.0,.018,min(uv.x,1.0-uv.x));
  vec3 edge=(textureLod(visual_panorama,vec2(.001,uv.y),0.0).rgb+textureLod(visual_panorama,vec2(.999,uv.y),0.0).rgb)*.5;
  COLOR=mix(color,edge,seam);
 }
}
