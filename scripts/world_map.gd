extends Node2D
# Mapa isométrico (data/map.json): suelo, objetos con su sprite y colisiones por casillas.
# Hitboxes en coordenadas de casilla (1 casilla = 1 m): cuadrícula transitable (agua y vacío bloquean),
# círculos (troncos de árbol, rocas) y rectángulos (casa, castillo).

var main: Node
var tiles := 20
var walk: Array = []         # fila i -> cadena de '1'/'0' por columna j
var circles: Array = []      # [centro (Vector2 en casillas), radio]
var rects: Array = []        # Rect2 en casillas
var grid := {}               # Vector2i (celda de 2x2 casillas) -> círculos cercanos: evita revisar los ~600 objetos en cada consulta

func setup(data: Dictionary) -> void:
	tiles = int(data["tiles"])
	walk = data["walk"]
	var ground := Sprite2D.new()
	ground.texture = load(data["image"])
	ground.centered = false
	ground.position = -main.map_origin * main.SCALE
	ground.scale = Vector2.ONE * main.SCALE
	ground.z_index = -4000  # siempre por debajo de héroe, objetos y proyectiles
	add_child(ground)
	for o: Dictionary in data["objects"]:
		var sp: Dictionary = data["sprites"][o["sprite"]]
		var tile := Vector2(o["tile"][0], o["tile"][1])
		var g: Vector2 = main.tile_to_ground(tile)
		var s := Sprite2D.new()
		s.texture = load(sp["path"])
		s.centered = false
		s.scale = Vector2.ONE * main.SCALE
		s.position = (g - Vector2(sp["feet"][0], sp["feet"][1])) * main.SCALE
		var sort_y := g.y
		if o.has("circle"):
			var circle := [tile, float(o["circle"])]
			circles.append(circle)
			var key := Vector2i(floori(tile.x / 2.0), floori(tile.y / 2.0))
			if not grid.has(key):
				grid[key] = []
			grid[key].append(circle)
		if o.has("rect"):
			var r: Array = o["rect"]
			var rc := Rect2(r[0], r[1], r[2] - r[0], r[3] - r[1])
			rects.append(rc)
			# el edificio se ordena por su esquina más baja en pantalla: el héroe delante lo tapa, detrás queda oculto
			for corner in [rc.position, rc.end, Vector2(rc.position.x, rc.end.y), Vector2(rc.end.x, rc.position.y)]:
				sort_y = maxf(sort_y, main.tile_to_ground(corner).y)
		s.z_index = int(sort_y)
		add_child(s)

func _cell_walkable(i: int, j: int) -> bool:
	return i >= 0 and i < tiles and j >= 0 and j < tiles and walk[i][j] == "1"

func hits_structure(t: Vector2, r: float) -> bool:  # árboles, rocas y edificios (t y r en casillas)
	var cell := Vector2i(floori(t.x / 2.0), floori(t.y / 2.0))
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for c in grid.get(cell + Vector2i(dx, dy), []):
				if t.distance_to(c[0]) < c[1] + r:
					return true
	for rc: Rect2 in rects:
		var closest := Vector2(clampf(t.x, rc.position.x, rc.end.x), clampf(t.y, rc.position.y, rc.end.y))
		if t.distance_to(closest) < r:
			return true
	return false

func blocked(t: Vector2, r: float) -> bool:
	for dx in [-r, r]:
		for dy in [-r, r]:
			if not _cell_walkable(floori(t.x + dx), floori(t.y + dy)):
				return true
	return hits_structure(t, r)

# mueve un cuerpo de radio r (casillas) de un punto de suelo a otro; si choca, desliza por un eje o se queda
func move_collide(from_g: Vector2, to_g: Vector2, r: float) -> Vector2:
	var a: Vector2 = main.ground_to_tile(from_g)
	var b: Vector2 = main.ground_to_tile(to_g)
	if not blocked(b, r):
		return to_g
	var slide_x := Vector2(b.x, a.y)
	if not blocked(slide_x, r):
		return main.tile_to_ground(slide_x)
	var slide_y := Vector2(a.x, b.y)
	if not blocked(slide_y, r):
		return main.tile_to_ground(slide_y)
	return from_g

# siguiente punto de suelo en el camino (BFS sobre casillas) hacia to_g; si no hay camino, devuelve to_g
func next_waypoint(from_g: Vector2, to_g: Vector2, r: float) -> Vector2:
	var start := Vector2i(main.ground_to_tile(from_g).floor())
	var goal := Vector2i(main.ground_to_tile(to_g).floor())
	if start == goal:
		return to_g
	var prev := {start: start}
	var queue := [start]
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		if c == goal:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]:
			var n: Vector2i = c + d
			if prev.has(n) or (n != goal and blocked(Vector2(n) + Vector2(0.5, 0.5), r)):
				continue
			prev[n] = c
			queue.append(n)
	if not prev.has(goal):
		return to_g
	var step: Vector2i = goal
	while prev[step] != start:  # retrocede hasta la casilla vecina del inicio
		step = prev[step]
	return main.tile_to_ground(Vector2(step) + Vector2(0.5, 0.5))

func hits_obstacle(p_ground: Vector2) -> bool:  # los proyectiles chocan con estructuras, no con el agua
	return hits_structure(main.ground_to_tile(p_ground), 0.12)
