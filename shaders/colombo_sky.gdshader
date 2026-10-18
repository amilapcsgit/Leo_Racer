shader_type sky;
uniform vec4 zenith : source_color = vec4(.118,.373,.455,1.0);
uniform vec4 horizon : source_color = vec4(.878,.478,.373,1.0);
uniform sampler2D clouds : filter_linear_mipmap, repeat_enable;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
void sky(){
 float elevation=max(EYEDIR.y,0.0);
 vec3 color=mix(horizon.rgb,zenith.rgb,smoothstep(0.0,.30,elevation));
 vec2 uv=SKY_COORDS;
 vec3 original=texture(clouds,uv).rgb;
 float cloud=smoothstep(.55,.89,dot(original,vec3(.299,.587,.114)));
 color=mix(color,vec3(.84,.74,.63),cloud*.5*smoothstep(.01,.14,elevation));
 float sun=max(dot(EYEDIR,LIGHT0_DIRECTION),0.0);
 color+=vec3(1.0,.56,.20)*pow(sun,30.0)*.24;
 color+=vec3(1.0,.79,.47)*smoothstep(.9995,.9999,sun)*2.8;
 COLOR=color;
}
