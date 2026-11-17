shader_type canvas_item;
render_mode world_vertex_coords;
// Suelo de una casilla de pasto: mismas manchas de color, nubes y toon híbrido que las briznas (coordenadas del mundo).
#include "res://shaders/grass_common.gdshaderinc"

varying vec2 wp;

void vertex() {
	wp = VERTEX;
}

void fragment() {
	float light = clamp(0.72 - cloud_at(wp, TIME) * cloud_strength, 0.0, 1.0);
	COLOR = vec4(grass_color(wp, 0.0) * 0.92 * hybrid_toon(light), 1.0);
}
