extends Node2D
# Estela del tajo: una cinta que se construye detrás del filo. Dos puntos de la hoja (cerca de la base y cerca de la punta,
# calibrados en data/blade_points.json con las poses reales de cada animación y dirección) se unen a lo largo del barrido.
# El tramo reciente es nítido; el anterior se estrecha, se apaga y deja unos fragmentos sobre la trayectoria.
# Cada tramo queda donde se emitió (coordenadas del mundo), aunque el héroe se mueva mientras ataca.
# Qué cambia entre ataques y espadas: la trayectoria sale de la animación (items.json: anim, trail_frame, trail_end);
# el color, el ancho, la persistencia y los fragmentos salen del ataque y de la espada (trail_color/trail_width/trail_time/trail_shards, trail_fx).
# Dibujo: la cinta lleva la textura art/trails/estela.png (de PixelLab, en grises: filo claro arriba, bandas, cola en punta a la derecha),
# teñida con el color de la espada; así cualquier espada nueva tiene su estela solo con poner su color "trail" en equipment.json.

static var table: Dictionary = {}

var main: Node               # el juego: héroe, escala y estado del ataque
var pts: Array = []          # muestras [bx, by, tx, ty] en píxeles de sprite; la muestra i * sub es el fotograma i
var sub := 4
var anim_key := ""           # animación del héroe que dibuja el filo (con llamas: fslash_*)
var first := 0               # fotogramas entre los que se emite: la parte rápida del barrido
var last := 0
var color := Color.WHITE
var width := 10.0            # ancho de la cinta recién emitida, en píxeles de sprite (nunca más que base-punta)
var life := 0.2              # persistencia: lo que tarda un tramo en apagarse (s)
var shards := 4              # fragmentos que quedan sobre la trayectoria
var frame_dur := 0.06        # duración de un fotograma de la animación (s)

var t := 0.0
var emitting := true
var fr := 0                  # último fotograma emitido
var tips := PackedVector2Array()
var bases := PackedVector2Array()
var born := PackedFloat32Array()
var bits: Array = []         # fragmentos: {p, size, t0} (solo en el dibujo procedural)
const TEX := preload("res://art/trails/estela.png")
const WIDE := 1.6            # la cinta es más ancha que el ancho base del ataque: se lee como el arco clásico del pixel art

func samples(anim: String, dir: String) -> Array:  # puntos calibrados de un tajo; vacío si la animación no los tiene
	if table.is_empty():
		table = JSON.parse_string(FileAccess.get_file_as_string("res://data/blade_points.json"))
	sub = int(table["_sub"])
	return table.get(anim, {}).get(dir, [])

func _ready() -> void:
	material = CanvasItemMaterial.new()
	material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD  # brillo aditivo
	fr = first
	_add(first * sub)

func _world(p: Vector2) -> Vector2:  # píxel del sprite del héroe -> mundo, con el héroe donde está ahora
	return main.hero.position + (p + main.hero.offset) * main.SCALE

func _add(i: int, stamp := 0.0) -> void:
	var s: Array = pts[mini(i, pts.size() - 1)]
	bases.append(_world(Vector2(s[0], s[1])))
	tips.append(_world(Vector2(s[2], s[3])))
	born.append(t - stamp)

func _process(delta: float) -> void:
	t += delta
	if emitting:
		var f: int = main.hero.frame
		if not main.attacking or main.hero.animation != anim_key or f < fr:
			_stop()  # ataque interrumpido o repetido
		else:
			while fr < mini(f, last):
				fr += 1
				for j in range(1, sub + 1):  # los tramos del intervalo se reparten en el tiempo del fotograma
					_add((fr - 1) * sub + j, float(sub - j) / sub * frame_dur)
			if f > last:
				_stop()  # terminó el recorrido
	if not emitting and t - born[born.size() - 1] > life and bits.all(func(b: Dictionary) -> bool: return t - b["t0"] > life * 1.8):
		queue_free()
	queue_redraw()

func _stop() -> void:
	emitting = false
	var n := tips.size()
	for k in mini(shards, n):  # fragmentos repartidos por todo el recorrido, no pegados a la cabeza
		var i := int((float(k) + randf()) / shards * (n - 1) * 0.9)
		bits.append({"p": tips[i] + (bases[i] - tips[i]).limit_length(width * float(main.SCALE) * randf()) + Vector2(randf_range(-6, 6), randf_range(-6, 6)) * main.SCALE * 0.4,
			"size": Vector2(2, 1) if randf() < 0.5 else Vector2(1, 2), "t0": t - randf() * life * 0.3})

func _age(i: int) -> float:
	return clampf((t - born[i]) / life, 0.0, 1.0)

func _col(i: int) -> Color:  # color del filo en la muestra i: se apaga con la edad
	var a := _age(i)
	var c := color.lerp(Color.WHITE, 0.4 * (1.0 - a))
	c.a = pow(1.0 - a, 1.5)
	return c

func _in(i: int) -> Vector2:  # borde interior: el tramo viejo se estrecha hacia el filo
	return tips[i] + (bases[i] - tips[i]).limit_length(width * WIDE * float(main.SCALE) * pow(1.0 - _age(i), 0.8))

func _draw() -> void:
	var snap := Vector2.ONE * float(main.SCALE)
	var n := tips.size()
	var edge := PackedVector2Array()
	var core := PackedColorArray()
	for i in n:
		edge.append(tips[i].snapped(snap))
		var c := Color.WHITE.lerp(color, _age(i) * 0.7)  # borde nítido: más tenue cuanto más viejo
		c.a = pow(1.0 - _age(i), 2.0)
		core.append(c)
		if i > 0 and (_col(i).a > 0.01 or _col(i - 1).a > 0.01):
			# u = edad (lo recién cortado es la parte ancha de la textura; al envejecer se corre hacia la punta); v = del filo al interior
			var u1 := _age(i - 1) * 0.98
			var u2 := _age(i) * 0.98
			draw_primitive(PackedVector2Array([edge[i - 1], edge[i], _in(i).snapped(snap), _in(i - 1).snapped(snap)]),
				PackedColorArray([_col(i - 1), _col(i), _col(i), _col(i - 1)]),
				PackedVector2Array([Vector2(u1, 0.0), Vector2(u2, 0.0), Vector2(u2, 1.0), Vector2(u1, 1.0)]), TEX)
	if n > 1:
		draw_polyline_colors(edge, core, 3.0)
	for b: Dictionary in bits:  # fragmentos pequeños, estilo píxel
		var q := clampf((t - b["t0"]) / (life * 1.8), 0.0, 1.0)
		var c := color.lerp(Color.WHITE, 0.4)
		c.a = clampf((t - b["t0"]) * 20.0, 0.0, 1.0) * (1.0 - q * q)
		var sz: Vector2 = b["size"] * float(main.SCALE)
		draw_rect(Rect2((b["p"] + Vector2(0, -q * 6.0 * main.SCALE)).snapped(snap) - sz / 2.0, sz), c)
	if n > 0 and _age(n - 1) < 1.0:  # destello en la punta de la hoja
		var flash := Color(1, 1, 1, pow(1.0 - _age(n - 1), 2.0))
		draw_rect(Rect2(tips[n - 1].snapped(snap) - snap, snap * 2.0), flash)
