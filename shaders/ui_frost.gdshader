shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
uniform float blur_lod : hint_range(0.0,4.0) = 2.5;
void fragment() {
 vec4 sample_color = textureLod(screen_texture,SCREEN_UV,blur_lod);
 COLOR=vec4(sample_color.rgb,1.0);
}
