class_name Wind
extends RefCounted
# Viento único del mundo (guía docs/ARTE_VIVO.md, idea 5): un ruido que se desplaza por coordenadas del mundo con una sola
# dirección, velocidad y escala. Pasto, hojas de los árboles y agua leen estos mismos valores, así una misma ráfaga recorre
# toda la escena. Cada material se registra con Wind.use(mat); cambiar algo aquí cambia todo a la vez (Wind.set_param).

const DIR := Vector2(1.0, 0.35)
const SPEED := 0.00005   # desplazamiento del ruido por segundo
const SCALE := 0.0009    # tamaño de las ráfagas en el mundo

static var _noise: ImageTexture
static var _mats: Array[ShaderMaterial] = []

static func noise() -> ImageTexture:
	if _noise == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = 5
		n.frequency = 0.02
		_noise = ImageTexture.create_from_image(n.get_seamless_image(256, 256))
	return _noise

static func use(m: ShaderMaterial) -> ShaderMaterial:
	m.set_shader_parameter("wind_noise", noise())
	m.set_shader_parameter("wind_dir", DIR)
	m.set_shader_parameter("wind_speed", SPEED)
	m.set_shader_parameter("wind_scale", SCALE)
	if not _mats.has(m):
		_mats.append(m)
	return m

static func set_param(param: String, value: Variant) -> void:  # p. ej. una tormenta: Wind.set_param("wind_speed", 0.00015)
	for m in _mats:
		m.set_shader_parameter(param, value)
