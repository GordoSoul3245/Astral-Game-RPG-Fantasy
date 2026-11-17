shader_type canvas_item;
render_mode world_vertex_coords;
// Hojas de la copa (MultiMesh 2D): se mecen con el viento único del mundo (más arriba, más se mueven), aleteo que imita
// una rotación moviendo esquinas opuestas en sentidos contrarios, pocos fotogramas con fase por hoja, 3 bandas de luz
// precalculadas por hoja (sombra por objeto, no por píxel), borde de luz en el lado iluminado y sombra de nubes.
// INSTANCE_CUSTOM: r = semilla, g = luz 0..1, b = borde (0/1), a = altura en la copa 0..1. Atlas: 2 matas de 8x8.
#include "res://shaders/grass_common.gdshaderinc"

uniform vec4 leaf_dark : source_color = vec4(0.13, 0.33, 0.18, 1.0);
uniform vec4 leaf_mid : source_color = vec4(0.24, 0.50, 0.21, 1.0);
uniform vec4 leaf_light : source_color = vec4(0.43, 0.69, 0.28, 1.0);
uniform vec4 leaf_rim : source_color = vec4(0.72, 0.86, 0.42, 1.0);
uniform float bend = 9.0;        // px que se mueve la copa con la ráfaga (arriba del todo)
uniform float flutter = 2.4;     // px de aleteo de cada hoja
uniform float frame_rate = 6.0;

varying flat float v_light;
varying flat float v_rim;
varying flat float v_cloud;
varying flat float v_w;
varying flat float v_var;

void vertex() {
	vec2 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float seed = INSTANCE_CUSTOM.r;
	v_light = INSTANCE_CUSTOM.g;
	v_rim = INSTANCE_CUSTOM.b;
	v_var = step(0.5, seed);
	float fr = 1.0 / frame_rate;
	float tq = floor(TIME / fr + hash12(base)) * fr;
	float w = wind_at(base, tq);
	v_w = w;
	vec2 wd = normalize(wind_dir);
	float sway = (w - 0.5) * 2.0 * bend * INSTANCE_CUSTOM.a;
	vec2 uvr = UV * 2.0 - 1.0;
	float fl = sin(tq * 4.0 + seed * 6.2831) * flutter * (0.4 + w);
	VERTEX += vec2(sway * wd.x + uvr.y * fl, sway * wd.y * 0.3 - uvr.x * fl * 0.6);
	v_cloud = cloud_at(base, TIME);
}

void fragment() {
	vec4 t = texture(TEXTURE, vec2(UV.x * 0.5 + 0.5 * v_var, UV.y));
	float l = v_light - v_cloud * cloud_strength * 1.5 + (v_w - 0.5) * gust_light * 0.6;
	vec3 c = l < 0.36 ? leaf_dark.rgb : (l < 0.68 ? leaf_mid.rgb : leaf_light.rgb);
	c = mix(c, leaf_rim.rgb, v_rim * step(0.55, l) * step(0.9, t.r));  // borde de luz solo en el lado iluminado
	COLOR = vec4(c * (0.82 + 0.25 * t.r), t.a);
}
