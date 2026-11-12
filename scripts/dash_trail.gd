extends Node2D
# Estela de suelo del dash: raya en píxeles que engorda y se aviva hacia la punta, con una flecha
# en el rumbo; al terminar el dash se desvanece. Los puntos van en coordenadas de main (pos * SCALE).
const FADE_TIME := 0.35
const MAX_WIDTH := 24.0  # unidades de main (SCALE = 3 por píxel de arte), con el zoom de cámara queda fina
var tint := Color("#b7a38a")
var points := PackedVector2Array()
var done := false  # main lo marca al acabar el dash: empieza a desvanecerse
var fade := 1.0

func add_point(p: Vector2) -> void:
	points.append(p.snapped(Vector2(3, 3)))
	queue_redraw()

func _process(delta: float) -> void:
	if not done:
		return
	fade -= delta / FADE_TIME
	if fade <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var n := points.size()
	if n < 2:
		return
	for i in range(1, n):
		var k := float(i) / (n - 1)  # 0 en la cola, 1 en la punta
		var c := tint
		c.a = (0.2 + 0.65 * k) * fade
		draw_line(points[i - 1], points[i], c, maxf(1.0, MAX_WIDTH * k))
	var dir := (points[n - 1] - points[maxi(0, n - 4)]).normalized()
	if dir == Vector2.ZERO:
		return
	var c := tint
	c.a = 0.9 * fade
	var tip := points[n - 1] + dir * 54.0  # por delante de los pies, para que el sprite no la tape
	for side in [1.0, -1.0]:  # flecha de dos trazos hacia donde va
		draw_line(tip, tip - dir * 30.0 + dir.orthogonal() * 24.0 * side, c, 9.0)
