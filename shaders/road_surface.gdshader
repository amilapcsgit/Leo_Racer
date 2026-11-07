shader_type spatial;
uniform sampler2D color_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_map : filter_linear_mipmap, repeat_enable;
varying vec3 wp;
uniform float base_roughness = .72;
uniform float base_albedo_gain = .43;
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform float detail_strength : hint_range(0.0, 1.0) = .28;
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
	vec2 uv=wp.xz/1.25;
	vec3 base=texture(color_map,uv).rgb;
	float patch=noise(wp.xz*.12);
	float weathering=noise(wp.xz*.037+vec2(19.0,7.0));
	float damp=wetness*smoothstep(.46,.72,patch);
	ALBEDO = base*vec3(base_albedo_gain)*mix(.92,1.06,weathering)*(.96+grain*.08)*mix(1.0,.73,damp);
	float dry_roughness=clamp(base_roughness+(patch-.5)*.07+(texture(rough_map,uv).r-.5)*.10,.64,.91);
	ROUGHNESS = mix(dry_roughness,.24,damp);
	NORMAL_MAP=texture(normal_map,uv).rgb;
	NORMAL_MAP_DEPTH=detail_strength*(1.0-smoothstep(.08,.65,footprint))*mix(1.0,.35,damp);
	METALLIC=0.0;
	SPECULAR=mix(.16,.32,damp);
}
