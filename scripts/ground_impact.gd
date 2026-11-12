extends Node2D
# Huella de un golpe fuerte en el suelo: anillo isométrico (2:1) que se abre y grietas cortas que se apagan.
# La posición va en coordenadas de main (pos * SCALE); `size` escala todo (1 = tajo pesado).
const LIFE := 0.45
var tint := Color("#f2e6c8")
var size := 1.0
var age := 0.0
var cracks: Array[Vector2] = []

func _ready() -> void:
	for i in 6:  # direcciones repartidas con algo de azar: que no parezca una estrella perfecta
		cracks.append(Vector2.from_angle(i * TAU / 6.0 + randf_range(-0.35, 0.35)) * randf_range(0.7, 1.0))

func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var t := age / LIFE
	var ease_out := 1.0 - pow(1.0 - t, 3.0)  # se abre rápido y frena: lee como onda de choque
	var r := lerpf(18.0, 75.0, ease_out) * size
	var c := tint
	c.a = (1.0 - t) * 0.8
	var ring := PackedVector2Array()
	for i in 25:
		ring.append(Vector2.from_angle(i * TAU / 24.0) * Vector2(r, r * 0.5))
	draw_polyline(ring, c, maxf(3.0, 12.0 * (1.0 - t) * size))
	c.a = (1.0 - t) * 0.9
	for d in cracks:
		var a := d * 15.0 * size
		var b := d * lerpf(30.0, 54.0, minf(t * 3.0, 1.0)) * size  # las grietas crecen en el primer tercio
		draw_line(a * Vector2(1, 0.5), b * Vector2(1, 0.5), c, 6.0)
