shader_type canvas_item;
render_mode world_vertex_coords;
// Suelo de una casilla de pasto: mismas manchas de color, nubes y toon híbrido que las briznas (coordenadas del mundo).
#include "res://shaders/grass_common.gdshaderinc"

varying vec2 wp;

void vertex() {
	wp = VERTEX;
}

void fragment() {
	vec2 p = snap3(wp);
	float gust = (wind_at(p, floor(TIME * 8.0) / 8.0) - 0.5) * gust_light * 0.5;  // la ola de luz también pasa por el suelo
	float light = clamp(0.72 + gust - cloud_at(p, TIME) * cloud_strength, 0.0, 1.0);
	COLOR = vec4(grass_color(p, 0.0) * 0.92 * hybrid_toon(light), 1.0);
}
