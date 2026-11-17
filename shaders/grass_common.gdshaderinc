// Parte común del pasto (briznas y suelo): manchas de color por ruido en coordenadas del mundo,
// sombra de nubes y sombreado toon híbrido. Réplica en 2D del método de Dylearn (grass_tile.gd lo explica).

uniform sampler2D patch_noise : repeat_enable, filter_linear;
uniform sampler2D cloud_noise : repeat_enable, filter_linear;
uniform vec4 col_a : source_color = vec4(0.43, 0.71, 0.31, 1.0);      // verde base
uniform vec4 col_b : source_color = vec4(0.50, 0.77, 0.34, 1.0);      // mancha clara
uniform vec4 col_c : source_color = vec4(0.37, 0.63, 0.30, 1.0);      // mancha oscura
uniform vec4 col_accent : source_color = vec4(0.95, 0.85, 0.25, 1.0); // brizna de acento
uniform float patch_scale = 0.0006;
uniform float patch_t1 = 0.56;
uniform float patch_t2 = 0.60;
uniform vec2 cloud_dir = vec2(1.0, 0.4);
uniform float cloud_speed = 0.00002;
uniform float cloud_scale = 0.0006;
uniform float cloud_strength = 0.2;
uniform float cuts = 3.0;        // bandas de luz del toon
uniform float cut_grad = 0.4;    // fracción de cada corte que se suaviza (toon híbrido)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

// color del pasto en un punto del mundo: dos ruidos con umbral (manchas) y, si toca, el acento
vec3 grass_color(vec2 wp, float accent) {
	float n1 = textureLod(patch_noise, wp * patch_scale, 0.0).r;
	float n2 = textureLod(patch_noise, wp * patch_scale * 1.7 + vec2(0.37, 0.11), 0.0).r;
	vec3 c = col_a.rgb;
	c = n1 > patch_t1 ? col_b.rgb : c;
	c = n2 > patch_t2 ? col_c.rgb : c;
	return mix(c, col_accent.rgb, accent);
}

// sombra de nubes: un ruido que se desplaza con el tiempo, muestreado en el mundo
float cloud_at(vec2 wp, float time) {
	float c = textureLod(cloud_noise, wp * cloud_scale - cloud_dir * time * cloud_speed * 1000.0, 0.0).r;
	return smoothstep(0.5, 0.68, c);
}

// toon híbrido: escalones de luz, pero alrededor de cada corte la transición es un smoothstep
float hybrid_toon(float l) {
	float band = 1.0 / cuts;
	float e = round(l * cuts) / cuts;           // corte más cercano
	float gw = band * cut_grad * 0.5;
	float d = l - e;
	float lvl = floor(l * cuts) / cuts;
	if (abs(d) < gw) {
		lvl = mix(e - band, e, smoothstep(-gw, gw, d));
	}
	return mix(0.62, 1.12, lvl);
}
