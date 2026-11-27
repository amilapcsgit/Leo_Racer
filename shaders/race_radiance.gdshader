shader_type sky;
uniform vec4 top_color : source_color;
uniform vec4 horizon_color : source_color;
void sky(){COLOR=mix(horizon_color.rgb,top_color.rgb,smoothstep(0.,.62,max(0.,EYEDIR.y)));}
