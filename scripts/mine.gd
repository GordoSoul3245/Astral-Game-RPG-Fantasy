extends "res://scripts/world_map.gd"
# Mina: cueva de `tiles` x `tiles` casillas (data/crafting.json "mine") con paredes de roca irregulares, vetas de hierro, carbón y
# cristal arcano y hongos que brillan. Se genera con una semilla fija (autómata celular) y solo deja suelo conectado con la entrada.
# Reusa colisiones y búsqueda de camino de world_map.gd; la roca de las paredes es de bloques dibujados por código.

const WALL_PX := 40.0   # alto de los bloques de pared, en px de suelo
var cfg := {}
var rock := {}          # Vector2i -> true si es pared
var open_cells: Array[Vector2i] = []
var rng := RandomNumberGenerator.new()

func setup(data: Dictionary) -> void:
	cfg = data
	tiles = int(data["tiles"])
	rng.seed = 20261112
	z_index = -4000
	_carve()
	walk = []
	for i in tiles:
		var row := ""
		for j in tiles:
			row += "0" if rock.has(Vector2i(i, j)) else "1"
		walk.append(row)
	_place_resources()
	queue_redraw()

func _carve() -> void:  # autómata celular: relleno 40 %, 3 pasadas de suavizado, borde de roca y bolsillo libre en la entrada
	var n := tiles
	var mid := n / 2
	for i in n:
		for j in n:
			if i < 2 or j < 2 or i >= n - 2 or j >= n - 2 or rng.randf() < 0.4:
				rock[Vector2i(i, j)] = true
	for pass_no in 3:
		var next := {}
		for i in n:
			for j in n:
				var c := 0
				for dx in [-1, 0, 1]:
					for dy in [-1, 0, 1]:
						if (dx != 0 or dy != 0) and rock.has(Vector2i(i + dx, j + dy)):
							c += 1
				if i < 2 or j < 2 or i >= n - 2 or j >= n - 2 or c >= 5:
					next[Vector2i(i, j)] = true
		rock = next
	for i in range(mid - 2, mid + 3):  # entrada y primera sala despejadas
		for j in range(2, 7):
			rock.erase(Vector2i(i, j))
	# solo queda suelo conectado con la entrada (las bolsas aisladas se rellenan de roca)
	var seen := {Vector2i(mid, 3): true}
	var queue: Array[Vector2i] = [Vector2i(mid, 3)]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var q: Vector2i = c + d
			if not seen.has(q) and not rock.has(q) and q.x >= 0 and q.y >= 0 and q.x < n and q.y < n:
				seen[q] = true
				queue.append(q)
	for i in n:
		for j in n:
			var v := Vector2i(i, j)
			if not rock.has(v) and not seen.has(v):
				rock[v] = true
	open_cells.clear()
	for v: Vector2i in seen:
		open_cells.append(v)
	open_cells.sort()

func spawn_tile() -> Vector2:
	return Vector2(tiles / 2.0 + 0.5, 3.5)

func free_tile(taken: Array, min_from_spawn := 5.0) -> Vector2:  # casilla libre lejos de la entrada y de lo ya colocado
	for attempt in 200:
		var c: Vector2i = open_cells[rng.randi() % open_cells.size()]
		var t := Vector2(c.x + 0.5, c.y + 0.5)
		if t.distance_to(spawn_tile()) < min_from_spawn:
			continue
		var ok := true
		for o: Vector2 in taken:
			if t.distance_to(o) < 1.6:
				ok = false
				break
		# que no quede entre dos paredes tapando un pasillo: exige las 4 casillas vecinas libres
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if rock.has(c + d):
				ok = false
		if ok:
			return t
	return spawn_tile() + Vector2(0, 3)

func _place_resources() -> void:
	var taken: Array = []
	var specs: Dictionary = main.crafting.cfg["world_sprites"]
	var glow := {"crystal": Color(0.65, 0.45, 1.0), "mushroom": Color(0.35, 1.0, 0.8)}
	for kind: String in cfg["nodes"]:
		for i in int(cfg["nodes"][kind]):
			var t := free_tile(taken)
			taken.append(t)
			var spec: Dictionary = specs["node_" + kind]
			add_resource(kind, t, spec["paths"][0], spec["feet"], 0.45 if kind != "mushroom" else 0.0, glow.get(kind, Color.TRANSPARENT))

func _corner(i: float, j: float) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

func _draw() -> void:
	var h: float = WALL_PX * main.SCALE
	for i in tiles:
		for j in tiles:
			var v := Vector2i(i, j)
			if rock.has(v):
				continue
			var shade := float((i * 7 + j * 13) % 5) * 0.012
			var base := Color("#3a3128") if (i + j) % 2 == 0 else Color("#41372d")
			var quad := PackedVector2Array([_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)])
			draw_colored_polygon(quad, base.lightened(shade))
	# bloques de pared: cara superior y las dos caras que dan al suelo (se pintan de atrás hacia delante)
	for i in tiles:
		for j in tiles:
			var v := Vector2i(i, j)
			if not rock.has(v):
				continue
			var up := Vector2(0, -h)
			var a := _corner(i, j)
			var b := _corner(i + 1, j)
			var c := _corner(i + 1, j + 1)
			var d := _corner(i, j + 1)
			var shade := float((i * 5 + j * 3) % 4) * 0.015
			var top := PackedVector2Array([a + up, b + up, c + up, d + up])
			if not rock.has(Vector2i(i, j + 1)):  # cara que mira a +j (abajo-izquierda en pantalla)
				draw_colored_polygon(PackedVector2Array([d + up, c + up, c, d]), Color("#2b2620").lightened(shade))
			if not rock.has(Vector2i(i + 1, j)):  # cara que mira a +i
				draw_colored_polygon(PackedVector2Array([b + up, c + up, c, b]), Color("#221e1a").lightened(shade))
			draw_colored_polygon(top, Color("#4d4439").lightened(shade * 2.0))
			draw_polyline(top + PackedVector2Array([top[0]]), Color("#1a1612"), 2.0)
