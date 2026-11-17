shader_type canvas_item;
render_mode world_vertex_coords;
// Agua por capas (docs/ARTE_VIVO.md, idea 14), plana y estilizada, en la rejilla de 3 px y cuantizada a la paleta:
//  1. color por profundidad (orilla clara -> centro oscuro; COLOR.r del vértice = distancia a tierra 0..1)
//  2. refracción falsa: el ruido del viento ondula los límites entre tonos, más en lo hondo
//  3. olas grandes y lentas: dos senos perpendiculares multiplicados (va y viene), con cresta clara
//  4. espuma de orilla de 1 px de arte, irregular a propósito
//  5. espuma suelta / destellos: ruido con umbral que se desplaza con el viento
//  6. sombra de nubes (la misma que el pasto)
#include "res://shaders/grass_common.gdshaderinc"

uniform vec4 water_shallow : source_color = vec4(0.38, 0.74, 0.80, 1.0);
uniform vec4 water_mid : source_color = vec4(0.22, 0.53, 0.74, 1.0);
uniform vec4 water_deep : source_color = vec4(0.13, 0.33, 0.60, 1.0);
uniform vec4 water_foam : source_color = vec4(0.90, 0.97, 1.0, 1.0);
uniform float wave_scale = 0.03;
uniform float foam_amount = 0.80;   // umbral de la espuma suelta (más alto = menos)

varying vec2 wp;
varying float depth;

void vertex() {
	wp = VERTEX;
	depth = COLOR.r;
}

void fragment() {
	vec2 p = snap3(wp);
	float t = floor(TIME * 8.0) / 8.0;   // pocos fotogramas, como el pasto
	vec2 wd = normalize(wind_dir);
	vec2 pd = vec2(-wd.y, wd.x);
	float wave = sin(dot(p, wd) * wave_scale - t * 1.6) * sin(dot(p, pd) * wave_scale * 0.8 + t * 1.1);
	float n = textureLod(wind_noise, p * 0.0025 + wd * t * 0.015, 0.0).r;
	float d = clamp(depth + (n - 0.5) * 0.35 * depth + wave * 0.05, 0.0, 1.0);
	vec3 c = d < 0.3 ? water_shallow.rgb : (d < 0.62 ? water_mid.rgb : water_deep.rgb);
	c = mix(c, c * 1.16, step(0.6, wave));                      // cresta de la ola
	float shore = step(depth + (n - 0.5) * 0.04, 0.022);         // espuma de orilla, irregular
	float sp = textureLod(cloud_noise, p * 0.0045 - wd * t * 0.03, 0.0).r;
	float spark = step(foam_amount, sp) * step(0.2, wave + 0.5);
	c = mix(c, water_foam.rgb, max(shore, spark * 0.75));
	c *= 1.0 - cloud_at(p, TIME) * cloud_strength;
	COLOR = vec4(c, 1.0);
}
