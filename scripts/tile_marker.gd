extends Node2D
# Marcador de casillas: pinta un rectángulo de casillas del suelo (para apuntar la ultimate y avisar del impacto).

var main: Node
var rect := Rect2()          # en coordenadas de casilla (0..10)
var color := Color(1.0, 0.4, 0.1)

func _process(_delta: float) -> void:
	queue_redraw()

func _world(t: Vector2) -> Vector2:
	return main.tile_to_ground(t) * main.SCALE

func _draw() -> void:
	if rect.size == Vector2.ZERO:
		return
	var a := rect.position
	var b := rect.end
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 8.0)
	var corners := PackedVector2Array([_world(a), _world(Vector2(b.x, a.y)), _world(b), _world(Vector2(a.x, b.y))])
	draw_colored_polygon(corners, Color(color.r, color.g, color.b, 0.18 + 0.14 * pulse))
	var grid := Color(color.r, color.g, color.b, 0.45)
	for i in int(rect.size.x) + 1:
		draw_line(_world(Vector2(a.x + i, a.y)), _world(Vector2(a.x + i, b.y)), grid, 2.0)
	for j in int(rect.size.y) + 1:
		draw_line(_world(Vector2(a.x, a.y + j)), _world(Vector2(b.x, a.y + j)), grid, 2.0)
	draw_polyline(PackedVector2Array([corners[0], corners[1], corners[2], corners[3], corners[0]]),
		Color(color.r, color.g, color.b, 0.9), 4.0)
