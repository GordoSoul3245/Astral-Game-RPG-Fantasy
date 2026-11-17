shader_type canvas_item;
render_mode world_vertex_coords;
// Briznas de pasto (MultiMesh 2D): viento en coordenadas del mundo con dos ruidos, falsa perspectiva, movimiento a pocos
// fotogramas con fase propia por brizna, empuje de personajes (hasta 64), manchas de color, acentos y toon híbrido.
// Cada brizna: origen en la base (abajo al centro). INSTANCE_CUSTOM: r = semilla, g = acento (0/1).
#include "res://shaders/grass_common.gdshaderinc"

uniform sampler2D wind_noise : repeat_enable, filter_linear;
uniform vec2 wind_dir = vec2(1.0, 0.35);
uniform float wind_speed = 0.00005;     // desplazamiento del ruido por segundo (en unidades de mundo * wind_scale * 1000)
uniform float wind_scale = 0.0009;
uniform float wind_amount = 0.55;       // inclinación máxima, en alturas de brizna
uniform float divergence = 0.65;        // ángulo (rad) en que se separan las dos direcciones de ruido
uniform float wind_bright = 0.12;
uniform float view_sway = 0.05;         // balanceo ligero "en el espacio de la vista"
uniform float frame_rate = 8.0;         // fotogramas por segundo del viento
uniform float persp_wind = 0.7;         // falsa perspectiva por el viento
uniform float persp_push = 0.9;         // falsa perspectiva por los personajes
uniform vec2 view_dir = vec2(0.0, 1.0); // hacia dónde mira la cámara en pantalla (profundidad = eje y)
uniform float blade_px = 20.0;          // altura de una brizna a escala 1, en px de pantalla
uniform vec4 chars[64];                 // x, y = posición (mundo), z = radio; z = 0 -> sin efecto
uniform float char_exp = 2.0;
uniform float char_push = 1.1;

varying vec2 v_base;
varying float v_accent;
varying float v_k;

vec2 rot(vec2 v, float a) {
	float s = sin(a), c = cos(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// viento en un punto: dos ruidos, cada uno desplazado en una dirección distinta y con una escala irracional, multiplicados
float wind_at(vec2 p, float t) {
	vec2 wd = normalize(wind_dir);
	vec2 d1 = rot(wd, divergence);
	vec2 d2 = rot(wd, -divergence);
	float n1 = textureLod(wind_noise, p * wind_scale - d1 * t * wind_speed * 1000.0, 0.0).r;
	float n2 = textureLod(wind_noise, p * wind_scale * 3.14159265 * 0.5 - d2 * t * wind_speed * 1000.0 * 1.7, 0.0).r;
	return clamp(n1 * n2 * 3.2 + wind_bright, 0.0, 1.0);
}

void vertex() {
	vec2 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xy;
	float h = 1.0 - UV.y;                      // 0 en la base, 1 arriba
	float seed = INSTANCE_CUSTOM.r;
	v_accent = INSTANCE_CUSTOM.g;
	v_base = base;
	// tiempo cuantizado, desfasado por brizna: baja frecuencia sin que todas cambien en el mismo fotograma
	float fr = 1.0 / frame_rate;
	float tq = floor(TIME / fr + hash12(base)) * fr;
	float w = wind_at(base, tq);
	vec2 wd = normalize(wind_dir);
	float sway = (w - 0.5) * 2.0 * wind_amount;
	float shear = sway * wd.x + sin(tq * 2.5 + seed * 6.2831) * view_sway;
	// empuje de los personajes cercanos (se suman y se limitan a -1..1)
	vec2 push = vec2(0.0);
	for (int i = 0; i < 64; i++) {
		float r = chars[i].z;
		if (r > 0.0) {
			vec2 dv = base - chars[i].xy;
			float m = pow(clamp(1.0 - length(dv) / r, 0.0, 1.0), char_exp);
			push += normalize(dv + vec2(0.0001)) * m;
		}
	}
	push = clamp(push, vec2(-1.0), vec2(1.0));
	shear += push.x * char_push;
	float size = blade_px * length(MODEL_MATRIX[1].xy);
	VERTEX.x += shear * h * size;
	VERTEX.y += abs(shear) * h * size * 0.22;  // al inclinarse, la punta baja un poco
	v_k = sway * dot(wd, view_dir) * persp_wind + push.y * persp_push;
}

void fragment() {
	// falsa perspectiva: se estira o encoge la parte alta del sprite según se acerca o aleja de la cámara
	float s = max(0.25, 1.0 + (1.0 - UV.y) * v_k);
	float ux = clamp((UV.x - 0.5) / s + 0.5, 0.0, 1.0);
	vec4 t = texture(TEXTURE, vec2(ux * 0.5 + 0.5 * v_accent, UV.y));
	float cl = cloud_at(v_base, TIME);
	float light = clamp(0.62 + 0.38 * (1.0 - UV.y) - cl * cloud_strength, 0.0, 1.0);
	COLOR = vec4(t.rgb * grass_color(v_base, v_accent) * 1.08 * hybrid_toon(light), t.a);
}
