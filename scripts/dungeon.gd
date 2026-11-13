extends "res://scripts/world_map.gd"
# Piso de dungeon generado (dungeon_gen.gd): suelo de losas en las casillas transitables y bloques de muro alrededor.
# Reusa las colisiones y el pathfinding de world_map.gd: lo que no es transitable ('0') bloquea al héroe y a los monstruos.

const WALL_H := 34.0  # px de suelo; bajo, para que no tape al héroe

func setup(data: Dictionary) -> void:
	tiles = int(data["tiles"])
	if data.has("walk"):
		walk = data["walk"]
	else:
		walk = []
		for i in tiles:
			walk.append("1".repeat(tiles))
	z_index = -4000  # siempre por debajo de héroe y entidades
	queue_redraw()

func _corner(i: int, j: int) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

func _floor(i: int, j: int) -> bool:
	return i >= 0 and j >= 0 and i < tiles and j < tiles and str(walk[i])[j] == "1"

func _near_floor(i: int, j: int) -> bool:  # muro visible: casilla bloqueada que toca el suelo
	for di in range(-1, 2):
		for dj in range(-1, 2):
			if _floor(i + di, j + dj):
				return true
	return false

func _draw() -> void:
	for i in tiles:
		for j in tiles:
			if not _floor(i, j):
				continue
			var v := float((i * 7 + j * 13) % 5) * 0.012  # variación leve entre losas
			var base := Color("#2b2f4a") if (i + j) % 2 == 0 else Color("#32375a")
			var quad := PackedVector2Array([_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)])
			draw_colored_polygon(quad, base.lightened(v))
			quad.append(quad[0])
			draw_polyline(quad, Color("#171a2c"), 2.0)  # juntas
	var up := Vector2(0, WALL_H * main.SCALE)
	for s in range(0, tiles * 2):  # de atrás hacia delante, para que cada bloque tape al de detrás
		for i in range(maxi(0, s - tiles + 1), mini(s, tiles - 1) + 1):
			var j := s - i
			if _floor(i, j) or not _near_floor(i, j):
				continue
			var a := _corner(i, j)
			var b := _corner(i + 1, j)
			var c := _corner(i + 1, j + 1)
			var d := _corner(i, j + 1)
			draw_colored_polygon(PackedVector2Array([a, d, d - up, a - up]), Color("#1d2038"))
			draw_colored_polygon(PackedVector2Array([d, c, c - up, d - up]), Color("#262a47"))
			draw_colored_polygon(PackedVector2Array([a - up, b - up, c - up, d - up]), Color("#3b4068"))
	var rim := PackedVector2Array([_corner(0, 0), _corner(tiles, 0), _corner(tiles, tiles), _corner(0, tiles), _corner(0, 0)])
	draw_polyline(rim, Color("#0a0c18"), 8.0)
