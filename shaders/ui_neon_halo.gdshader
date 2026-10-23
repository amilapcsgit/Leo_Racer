shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 rect_size = vec2(240.0, 88.0);
uniform float radius = 16.0;
uniform float glow_strength = 1.0;
uniform vec4 tint : source_color = vec4(0.263, 0.906, 0.937, 1.0);
void fragment() {
 vec2 q = abs((UV - 0.5) * rect_size) - (rect_size * 0.5 - vec2(16.0 + radius));
 float d = length(max(q, vec2(0.0))) + min(max(q.x,q.y),0.0) - radius;
 float halo = exp(-abs(d) / 5.5) * 0.24 + exp(-abs(d) / 1.3) * 0.30;
 COLOR = vec4(tint.rgb, halo * glow_strength * tint.a);
}
