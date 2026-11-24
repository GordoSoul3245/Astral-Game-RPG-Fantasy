shader_type canvas_item;
render_mode unshaded;
void fragment(){
	vec2 uv = (UV-0.5)*0.945 + 0.5 + vec2(sin(TIME*0.085)*0.023,cos(TIME*0.067)*0.013);
	vec3 scene = texture(TEXTURE,uv).rgb;
	float shade = mix(0.44,1.0,smoothstep(0.03,0.67,UV.x));
	COLOR = vec4(scene*shade,1.0);
}
