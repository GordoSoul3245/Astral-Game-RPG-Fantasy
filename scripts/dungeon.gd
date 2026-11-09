extends "res://scripts/world_map.gd"
# Piso de dungeon: suelo de losas de `tiles` x `tiles` casillas, sin obstáculos.
# Reusa las colisiones y el pathfinding de world_map.gd (toda la cuadrícula es transitable).

func setup(data: Dictionary) -> void:
	tiles = int(data["tiles"])
	walk = []
	for i in tiles:
		walk.append("1".repeat(tiles))
	z_index = -4000  # siempre por debajo de héroe y entidades
	queue_redraw()

func _corner(i: int, j: int) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

func _draw() -> void:
	for i in tiles:
		for j in tiles:
			var v := float((i * 7 + j * 13) % 5) * 0.012  # variación leve entre losas
			var base := Color("#2b2f4a") if (i + j) % 2 == 0 else Color("#32375a")
			var quad := PackedVector2Array([_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)])
			draw_colored_polygon(quad, base.lightened(v))
			quad.append(quad[0])
			draw_polyline(quad, Color("#171a2c"), 2.0)  # juntas
	var rim := PackedVector2Array([_corner(0, 0), _corner(tiles, 0), _corner(tiles, tiles), _corner(0, tiles), _corner(0, 0)])
	draw_polyline(rim, Color("#0a0c18"), 8.0)
