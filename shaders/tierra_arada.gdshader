shader_type canvas_item;

// La tierra pierde opacidad entre terrones para que asome el pasto de la casilla.
void fragment() {
	vec2 p = floor(UV / TEXTURE_PIXEL_SIZE);
	float grain = fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
	float edge = abs((p.x - 46.0) / 39.0) + abs((p.y - 21.5) / 17.5);
	float soil = 1.0 - smoothstep(0.78, 1.02, edge + grain * 0.08);
	COLOR.rgb *= mix(vec3(1.0), vec3(0.83, 0.81, 0.76), smoothstep(0.62, 0.94, edge));
	COLOR.a *= soil;
}
