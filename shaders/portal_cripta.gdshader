shader_type canvas_item;

varying vec4 tint;
void vertex() {
	tint = COLOR;
}

void fragment() {
	vec2 pixel = floor(UV / TEXTURE_PIXEL_SIZE);
	vec4 stone = texture(TEXTURE, UV);
	// Silueta del arco interior y de cada peldaño, en píxeles del sprite.
	float side = abs(pixel.x - 79.5);
	float width = 25.0;
	if (pixel.y < 92.0) {
		float rise = (92.0 - pixel.y) / 25.5;
		width *= sqrt(max(0.0, 1.0 - rise * rise));
	} else if (pixel.y >= 152.0) {
		width = pixel.y < 166.0 ? 32.0 : 36.0;
	}
	// Segunda hilera: jambas rectas y una ojiva baja sobre el arco original.
	if (pixel.y < 152.0) {
		float lateral = min(side / 32.0, 1.0);
		float outer_top = 56.0 + 8.0 * lateral + 28.0 * (1.0 - sqrt(1.0 - lateral * lateral));
		if (side > 32.0 || pixel.y < outer_top) {
			discard;
		}
		if (side > width || pixel.y < 67.0) {
			vec2 sample_pixel = pixel;
			if (pixel.y < 92.0) {
				float angle = atan(side, 92.0 - pixel.y);
				float radius = 20.5 + clamp((pixel.y - outer_top) * cos(angle) + (32.0 - side) * sin(angle), 0.0, 6.0) * 0.55;
				sample_pixel = vec2(79.5, 92.0) + vec2(sign(pixel.x - 79.5) * sin(angle), -cos(angle)) * radius;
			} else {
				sample_pixel.x = 79.5 + sign(pixel.x - 79.5) * (18.5 + mod(side - 25.0, 7.0));
				sample_pixel.y = 96.0 + mod(pixel.y - 89.0, 48.0);
			}
			stone = texture(TEXTURE, (floor(sample_pixel) + 0.5) * TEXTURE_PIXEL_SIZE);
			stone.rgb *= 0.88;
		}
		width = 32.0;
	}
	float bottom = 182.0 - max(0.0, side - 18.0) * 0.34;
	if (pixel.y > bottom || side > width) {
		discard;
	}
	// Las juntas y el canto exterior toman la sombra cálida de la mampostería.
	if (side >= 18.0 || pixel.y < 74.0 || pixel.y >= 148.0) {
		stone.rgb = max(stone.rgb, vec3(0.205, 0.152, 0.183));
	}
	vec4 result = stone;
	float phase = floor(TIME * 10.0) * 0.1;
	if (pixel.x > 62.0 && pixel.x < 98.0 && pixel.y > 92.0 && pixel.y < 146.0) {
		float height = clamp((146.0 - pixel.y) / 48.0, 0.0, 1.0);
		vec2 drift = round(vec2(sin(pixel.y * 0.13 + phase * 5.0) * 3.5,
			sin(pixel.x * 0.22 - phase * 4.0) * 6.0) * height);
		vec4 fire = texture(TEXTURE, UV + drift * TEXTURE_PIXEL_SIZE);
		if (fire.b > fire.g * 1.18 && fire.r > fire.g * 1.18) {
			result = vec4(fire.rgb * (1.15 + 0.16 * sin(phase * 6.0)), fire.a);
		}
	}
	// La reja ocupa la sombra del vano y queda detrás de las piedras del arco.
	if (pixel.y >= 72.0 && pixel.y < 96.0 && pixel.x >= 62.0 && pixel.x <= 98.0 && stone.r < 0.14 && stone.g < 0.055 && stone.a > 0.9) {
		float bar = mod(pixel.x - 63.0, 8.0);
		float tip = 92.0 + mod(floor(pixel.x / 8.0), 2.0) * 2.0;
		if ((bar < 3.0 && pixel.y < tip - abs(bar - 1.0) * 2.0) || (pixel.y >= 81.0 && pixel.y <= 84.0)) {
			result.rgb = bar == 0.0 || pixel.y == 81.0 ? vec3(0.16, 0.16, 0.19) : vec3(0.055, 0.05, 0.065);
		}
	}
	COLOR = result * tint;
}
