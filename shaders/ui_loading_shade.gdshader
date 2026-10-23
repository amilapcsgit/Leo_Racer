shader_type canvas_item;
render_mode unshaded;
void fragment() {
 float shade=mix(0.82,0.15,smoothstep(0.25,0.95,UV.x));
 COLOR=vec4(0.02,0.035,0.06,shade);
}
