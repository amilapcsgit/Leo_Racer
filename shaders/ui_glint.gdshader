shader_type canvas_item;
render_mode unshaded, blend_add;
uniform vec2 rect_size = vec2(240.0, 88.0);
uniform float radius = 16.0;
uniform float sweep_speed = 1.0;
uniform float line_width = 0.045;
uniform float brightness = 0.45;
uniform float phase = 0.0;
uniform float effect_time = 0.0;
uniform bool enabled = true;
void fragment() {
 float age = mod(effect_time * sweep_speed + phase, 3.0);
 float center = mix(-0.3, 1.3, clamp(age / 0.65, 0.0, 1.0));
 float line = 1.0 - smoothstep(line_width * 0.4, line_width, abs(UV.x + (UV.y-0.5)*0.25 - center));
 vec2 q = abs((UV-0.5)*rect_size) - (rect_size*0.5-vec2(radius));
 float d = length(max(q,vec2(0.0))) + min(max(q.x,q.y),0.0) - radius;
 float mask = 1.0 - smoothstep(-1.0, 0.5, d);
 COLOR = vec4(vec3(1.0), enabled && age < 0.65 ? line * mask * brightness : 0.0);
}
