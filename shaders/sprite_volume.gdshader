shader_type canvas_item;

// Volumen ancho y suave, conservando el modelado pintado del sprite.
void fragment() {
	float x = clamp((UV.x - 0.5) * 2.8, -0.82, 0.82);
	NORMAL = normalize(vec3(x, 0.18, sqrt(1.0-x*x)));
}
