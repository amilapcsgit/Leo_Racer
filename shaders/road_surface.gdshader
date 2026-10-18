shader_type spatial;
varying vec3 wp;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wp=(MODEL_MATRIX*vec4(VERTEX,1.0)).xyz;}
void fragment(){
	float footprint = max(length(dFdx(wp.xz)),length(dFdy(wp.xz)));
	float grain = mix(.5,noise(wp.xz*22.0),1.0-smoothstep(.025,.12,footprint));
	float broad = noise(wp.xz*.6);
	ALBEDO = vec3(.048,.061,.082)*(.88+grain*.24)+broad*.006;
	ROUGHNESS = .82;
}
