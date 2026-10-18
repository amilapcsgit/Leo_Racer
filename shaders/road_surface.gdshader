shader_type spatial;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap, repeat_enable;
varying vec3 wp;
uniform float base_roughness = .35;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float footprint = max(length(dFdx(wp.xz)),length(dFdy(wp.xz)));
	float grain = mix(.5,noise(wp.xz*22.0),1.0-smoothstep(.025,.12,footprint));
	float broad = noise(wp.xz*.6);
	vec2 uv=wp.xz/1.25;
	vec3 base=texture(color_map,uv).rgb;
	float wet=smoothstep(.36,.65,noise(wp.xz*.12));
	ALBEDO = base*vec3(.43)*mix(1.0,.76,wet)*(.95+grain*.10);
	ROUGHNESS = clamp(base_roughness+mix(.06,-.08,wet)+(texture(rough_map,uv).r-.5)*.06,.20,.55);
	NORMAL_MAP=texture(normal_map,uv).rgb;
	NORMAL_MAP_DEPTH=mix(.40,.12,wet);
	METALLIC=.025;
	SPECULAR=.22;
}
