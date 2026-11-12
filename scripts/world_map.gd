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
			var circle := [tile, float(o["circle"]), float(o.get("pcircle", o["circle"]))]  # [centro, radio al caminar, radio para proyectiles (follaje)]
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
		if not o["sprite"].begins_with("rock"):  # las rocas son bajas: no tapan
			occluders.append(s)
		if o["sprite"].begins_with("tree_") or o["sprite"].begins_with("rock_"):  # se pueden talar y picar
			_register_node("tree" if o["sprite"].begins_with("tree_") else "rock", tile, s, circles[-1] if o.has("circle") else null)

# --- transparencia (estilo Project Zomboid): lo que tapa al héroe se vuelve translúcido
const FADE_ALPHA := 0.3
var occluders: Array = []    # Sprite2D de árboles y edificios
var masks := {}              # Texture2D -> Image, para mirar si el píxel que tapa al héroe es opaco

func covers_hero(s: Sprite2D) -> bool:
	if s.z_index <= int(main.pos.y):  # está detrás del héroe: no lo tapa
		return false
	if not masks.has(s.texture):
		var im: Image = s.texture.get_image()
		if im.is_compressed():
			im.decompress()
		masks[s.texture] = im
	var img: Image = masks[s.texture]
	for h in [12.0, 40.0, 70.0]:  # pies, pecho y cabeza, px de suelo sobre los pies
		var p: Vector2 = ((main.pos - Vector2(0, h)) * main.SCALE - s.position) / main.SCALE
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixel(int(p.x), int(p.y)).a > 0.5:
			return true
	return false

func _process(delta: float) -> void:
	_tick_respawns(delta)
	if not visible:
		return
	for s: Sprite2D in occluders:
		var target := FADE_ALPHA if covers_hero(s) else 1.0
		if s.modulate.a != target:
			s.modulate.a = move_toward(s.modulate.a, target, delta * 4.0)

func _cell_walkable(i: int, j: int) -> bool:
	return i >= 0 and i < tiles and j >= 0 and j < tiles and walk[i][j] == "1"

func is_water(t: Vector2) -> bool:  # casillas fuera de la isla: mar abierto (se puede pescar)
	return not _cell_walkable(floori(t.x), floori(t.y))

func hits_structure(t: Vector2, r: float, proj := false) -> bool:  # árboles, rocas y edificios (t y r en casillas)
	var cell := Vector2i(floori(t.x / 2.0), floori(t.y / 2.0))
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			for c in grid.get(cell + Vector2i(dx, dy), []):
				if t.distance_to(c[0]) < c[2 if proj else 1] + r:
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
	return hits_structure(main.ground_to_tile(p_ground), 0.12, true)

# --- recursos recolectables (data/crafting.json "gather"): árboles, rocas, minerales y plantas.
# Cada nodo guarda su sprite y su círculo de colisión (se pone a 0 mientras está agotado) y vuelve a crecer tras un tiempo.
var res_nodes: Array = []
var respawning: Array = []

func _register_node(kind: String, tile: Vector2, spr: Sprite2D, circle: Variant) -> Dictionary:
	var g: Dictionary = main.crafting.cfg["gather"][kind]
	var n := {"kind": kind, "tile": tile, "g": main.tile_to_ground(tile), "spr": spr, "circle": circle, "hp": int(g["hp"]),
		"r0": float(circle[1]) if circle != null else 0.0, "pr0": float(circle[2]) if circle != null else 0.0, "t": 0.0, "depleted": false}
	res_nodes.append(n)
	return n

# crea sprite y colisión de un recurso nuevo (minerales de la mina, plantas del valle)
func add_resource(kind: String, tile: Vector2, tex_path: String, feet: Array, radius: float, light_col := Color.TRANSPARENT) -> Dictionary:
	var g: Vector2 = main.tile_to_ground(tile)
	var s := Sprite2D.new()
	s.texture = load(tex_path)
	s.centered = false
	s.scale = Vector2.ONE * main.SCALE
	s.position = (g - Vector2(feet[0], feet[1])) * main.SCALE
	s.z_index = int(g.y)
	s.z_as_relative = false
	add_child(s)
	var circle: Variant = null
	if radius > 0.0:
		circle = [tile, radius, radius]
		circles.append(circle)
		var key := Vector2i(floori(tile.x / 2.0), floori(tile.y / 2.0))
		if not grid.has(key):
			grid[key] = []
		grid[key].append(circle)
	if light_col != Color.TRANSPARENT:
		var l: PointLight2D = main.combat.light(light_col, 0.5, 1.2)
		l.position = (g - Vector2(0, 14)) * main.SCALE
		add_child(l)
	return _register_node(kind, tile, s, circle)

func node_near(p_ground: Vector2, reach := 1.9) -> Dictionary:  # recurso en pie más cercano al héroe (distancia en casillas)
	var t: Vector2 = main.ground_to_tile(p_ground)
	var best := {}
	var best_d := reach
	for n: Dictionary in res_nodes:
		if n["depleted"] or absf(n["tile"].x - t.x) > reach or absf(n["tile"].y - t.y) > reach:
			continue
		var d: float = t.distance_to(n["tile"])
		if d < best_d:
			best_d = d
			best = n
	return best

func hit_node(n: Dictionary, power: int) -> bool:  # true si este golpe lo agota
	n["hp"] -= power
	var s: Sprite2D = n["spr"]
	var tw := create_tween()  # sacudida del golpe
	tw.tween_property(s, "offset:x", 5.0, 0.04)
	tw.tween_property(s, "offset:x", -4.0, 0.06)
	tw.tween_property(s, "offset:x", 0.0, 0.06)
	if n["hp"] > 0:
		return false
	n["depleted"] = true
	n["t"] = float(main.crafting.cfg["gather"][n["kind"]]["respawn"])
	respawning.append(n)
	if n["circle"] != null:  # ya no estorba el paso
		n["circle"][1] = 0.0
		n["circle"][2] = 0.0
	var fall := create_tween()
	fall.tween_property(s, "self_modulate:a", 0.0, 0.3)
	fall.parallel().tween_property(s, "offset:y", 10.0, 0.3)
	fall.tween_callback(func() -> void: s.visible = false)
	return true

func _tick_respawns(delta: float) -> void:
	for n: Dictionary in respawning.duplicate():
		n["t"] -= delta
		if n["t"] > 0.0:
			continue
		respawning.erase(n)
		n["depleted"] = false
		n["hp"] = int(main.crafting.cfg["gather"][n["kind"]]["hp"])
		if n["circle"] != null:
			n["circle"][1] = n["r0"]
			n["circle"][2] = n["pr0"]
		var s: Sprite2D = n["spr"]
		s.offset = Vector2.ZERO
		s.visible = true
		s.self_modulate.a = 0.0
		create_tween().tween_property(s, "self_modulate:a", 1.0, 0.6)
