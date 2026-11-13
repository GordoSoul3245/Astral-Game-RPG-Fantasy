extends RefCounted
# Generador de pisos de la dungeon: sala de entrada arriba, sala de salida abajo y, entre ambas, salas aleatorias unidas por
# pasillos de 2 casillas (o una arena con pilares en los pisos de jefe). Cuadrícula N x N; la casilla (i, j) es i = x, j = y.
# Lógica pura: floors.gd coloca monstruos, puertas y cofre; dungeon.gd lo dibuja y world_map.gd lo usa para colisiones y rutas.

const N := 25
const ENTRY := Rect2i(9, 0, 7, 5)    # contiene el punto de aparición (12.5, 2.4) y la puerta de salida (12.5, 0.25)
const EXIT := Rect2i(9, 20, 7, 5)    # contiene la puerta al siguiente piso (12.5, 24.75)
const ARENA := Rect2i(3, 7, 19, 12)
const PILLARS := [Vector2i(6, 10), Vector2i(17, 10), Vector2i(6, 15), Vector2i(17, 15)]

# Devuelve {walk: Array[String], rooms: Array[Rect2i], spots: Array[Vector2] (casillas aptas para monstruos),
# boss_spot: Vector2, chest_spot: Vector2, boss: bool}
static func generate(n: int, rng: RandomNumberGenerator, boss: bool, rooms_mode := true) -> Dictionary:
	if not rooms_mode:  # salón abierto como el original: suelo libre de lado a lado, sin muros ni pasillos
		var walk_open: Array = []
		for i in N:
			walk_open.append("1".repeat(N))
		var open_spots: Array[Vector2] = []
		for i in range(3, 22):
			for j in range(7, 22):
				open_spots.append(Vector2(i + 0.5, j + 0.5))
		return {"walk": walk_open, "rooms": [Rect2i(1, 6, 23, 17)], "spots": open_spots, "boss_spot": Vector2(12.5, 11.5), "chest_spot": Vector2(12.5, 12.5), "boss": boss}
	var g: Array = []
	for i in N:
		var col: Array = []
		col.resize(N)
		col.fill(false)
		g.append(col)
	_carve(g, ENTRY, true)
	_carve(g, EXIT, true)
	var rooms: Array[Rect2i] = []
	if boss:
		rooms.append(ARENA)
		_carve(g, ARENA, true)
		_carve(g, Rect2i(11, 5, 3, 2), true)
		_carve(g, Rect2i(11, 19, 3, 1), true)
		for p: Vector2i in PILLARS:
			_carve(g, Rect2i(p.x, p.y, 2, 2), false)
	else:
		var want := 4 + mini(n / 3, 2)
		for attempt in 120:
			if rooms.size() >= want:
				break
			var w := rng.randi_range(4, 8)
			var h := rng.randi_range(4, 6)
			var r := Rect2i(rng.randi_range(1, N - 1 - w), rng.randi_range(6, 19 - h), w, h)
			var ok := not r.grow(1).intersects(ENTRY) and not r.grow(1).intersects(EXIT)
			for o: Rect2i in rooms:
				if r.grow(1).intersects(o):
					ok = false
			if ok:
				rooms.append(r)
				_carve(g, r, true)
		rooms.sort_custom(func(a: Rect2i, b: Rect2i) -> bool: return a.get_center().y < b.get_center().y)
		var chain: Array[Rect2i] = [ENTRY]
		chain.append_array(rooms)
		chain.append(EXIT)
		for k in chain.size() - 1:
			_link(g, chain[k], chain[k + 1], rng)
		for extra in rng.randi_range(1, 2):  # algún pasillo de más: rutas alternativas
			if rooms.size() >= 2:
				var a := rng.randi_range(0, rooms.size() - 1)
				var b := rng.randi_range(0, rooms.size() - 1)
				if a != b:
					_link(g, rooms[a], rooms[b], rng)
	var walk: Array = []
	for i in N:
		var s := ""
		for j in N:
			s += "1" if g[i][j] else "0"
		walk.append(s)
	var spots: Array[Vector2] = []
	for r: Rect2i in rooms:
		for i in range(r.position.x + 1, r.end.x - 1):
			for j in range(r.position.y + 1, r.end.y - 1):
				if g[i][j]:
					spots.append(Vector2(i + 0.5, j + 0.5))
	var chest_spot := Vector2(12.5, 12.5)
	if not boss and not rooms.is_empty():  # el cofre va en el centro de la sala mayor
		var best: Rect2i = rooms[0]
		for r: Rect2i in rooms:
			if r.get_area() > best.get_area():
				best = r
		chest_spot = Vector2(best.get_center()) + Vector2(0.5, 0.5)
	return {"walk": walk, "rooms": rooms, "spots": spots, "boss_spot": Vector2(12.5, 11.5), "chest_spot": chest_spot, "boss": boss}

static func _carve(g: Array, r: Rect2i, value: bool) -> void:
	for i in range(maxi(r.position.x, 0), mini(r.end.x, N)):
		for j in range(maxi(r.position.y, 0), mini(r.end.y, N)):
			g[i][j] = value

static func _link(g: Array, a: Rect2i, b: Rect2i, rng: RandomNumberGenerator) -> void:  # pasillo en L de 2 casillas entre los centros
	var ca := a.get_center()
	var cb := b.get_center()
	if rng.randf() < 0.5:
		_carve(g, Rect2i(mini(ca.x, cb.x), ca.y, absi(cb.x - ca.x) + 2, 2), true)
		_carve(g, Rect2i(cb.x, mini(ca.y, cb.y), 2, absi(cb.y - ca.y) + 2), true)
	else:
		_carve(g, Rect2i(ca.x, mini(ca.y, cb.y), 2, absi(cb.y - ca.y) + 2), true)
		_carve(g, Rect2i(mini(ca.x, cb.x), cb.y, absi(cb.x - ca.x) + 2, 2), true)

# Casillas alcanzables desde una casilla (para probar que el piso es conexo)
static func reachable(walk: Array, start: Vector2i) -> Dictionary:
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q := c + d
			if q.x >= 0 and q.y >= 0 and q.x < N and q.y < N and not seen.has(q) and str(walk[q.x])[q.y] == "1":
				seen[q] = true
				queue.append(q)
	return seen
