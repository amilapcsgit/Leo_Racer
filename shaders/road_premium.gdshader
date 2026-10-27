shader_type spatial;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap, repeat_enable;
varying vec3 wp;
uniform float base_roughness = .35;
// Keep corner hashes bounded and independent of sine precision/constant folding.
// Explicit corner interpolation keeps the world-space puddle field continuous.
float road_hash(vec2 cell){
	vec3 p3=fract(vec3(cell.xyx)*.1031);
	p3+=dot(p3,p3.yzx+33.33);
	return fract((p3.x+p3.y)*p3.z);
}
float noise(vec2 p){
	vec2 cell=floor(p);
	vec2 blend=fract(p);
	blend=blend*blend*(3.0-2.0*blend);
	float a=road_hash(cell);
	float b=road_hash(cell+vec2(1.0,0.0));
	float c=road_hash(cell+vec2(0.0,1.0));
	float d=road_hash(cell+vec2(1.0,1.0));
	return mix(mix(a,b,blend.x),mix(c,d,blend.x),blend.y);
}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float footprint = max(length(dFdx(wp.xz)),length(dFdy(wp.xz)));
	float grain = mix(.5,noise(wp.xz*22.0),1.0-smoothstep(.025,.12,footprint));
	float broad = noise(wp.xz*.6);
	vec2 uv=wp.xz/1.25;
	vec3 base=texture(color_map,uv).rgb;
	float patch=noise(wp.xz*.12);
	ALBEDO = base*vec3(.43)*mix(.97,1.03,patch)*(.95+grain*.10);
	ROUGHNESS = clamp(base_roughness+(patch-.5)*.08+(texture(rough_map,uv).r-.5)*.10,.50,.88);
	NORMAL_MAP=texture(normal_map,uv).rgb;
	NORMAL_MAP_DEPTH=.22;
	METALLIC=.025;
	SPECULAR=.22;
}
