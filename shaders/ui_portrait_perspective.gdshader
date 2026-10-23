shader_type canvas_item;
render_mode unshaded;
uniform float yaw = 0.0;
uniform float perspective = 2.2;
varying vec4 vertex_tint;
void vertex() { vertex_tint=COLOR; }
void fragment() {
 vec2 p = UV * 2.0 - 1.0;
 float den = max(0.2, cos(yaw) - p.x * sin(yaw) / perspective);
 vec2 uv = vec2(p.x / den, p.y * (1.0 + p.x * sin(yaw) / (perspective * den))) * 0.5 + 0.5;
 float mask = step(0.0,uv.x)*step(uv.x,1.0)*step(0.0,uv.y)*step(uv.y,1.0);
 COLOR = texture(TEXTURE,uv) * vertex_tint * mask;
}
