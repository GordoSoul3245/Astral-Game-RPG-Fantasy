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
	if data.has("image"):  # las zonas dibujan su propio suelo
		var tex: Texture2D = load(data["image"])
		var grass := _add_grass(tex)
		_add_ground(tex, grass)
		_add_water(tex)
		masks.erase(tex)  # la imagen grande del suelo solo hacía falta para construir
	for o: Dictionary in data["objects"]:
		var sp: Dictionary = data["sprites"][o["sprite"]]
		var tile := Vector2(o["tile"][0], o["tile"][1])
		var g: Vector2 = main.tile_to_ground(tile)
		var s := Sprite2D.new()
		s.texture = load(o.get("texture", sp["path"]))
		if o["sprite"] == "portal":
			var flame := ShaderMaterial.new()
			flame.shader = preload("res://shaders/portal_cripta.gdshader")
			s.material = flame
		s.centered = false
		var sz := float(o.get("size", 1.0))  # tamaño del objeto (árboles variados o un árbol hito)
		s.scale = Vector2.ONE * main.SCALE * sz
		s.position = (g - Vector2(sp["feet"][0], sp["feet"][1]) * sz) * main.SCALE
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
		if sp.has("anim"):  # sprite animado cuadro a cuadro (árbol de PixelLab): sin recorte, cada cuadro mueve sus hojas
			var frames: Array[Texture2D] = []
			for k in 9:
				frames.append(load(sp["anim"] % [o.get("dir", "south"), k]))
			s.texture = frames[0]
			s.set_meta("frames", frames)
			anim_sprites.append([s, randf() * 9.0])
		else:
			_trim(s)
		add_child(s)
		if o["sprite"].begins_with("tree_") and not sp.has("anim"):
			_living_tree(s, sp, tile)
		if not o["sprite"].begins_with("rock") and o["sprite"] != "pueblo_piedras":  # las rocas son bajas: no tapan
			occluders.append(s)
		if o["sprite"].begins_with("tree_") or o["sprite"].begins_with("rock_") or o["sprite"] == "pueblo_piedras":  # se pueden talar y picar
			_register_node("tree" if o["sprite"].begins_with("tree_") else "rock", tile, s, circles[-1] if o.has("circle") else null)

# Rendimiento: un sprite se recorta a su parte no transparente (region_rect) y se desplaza lo mismo (offset), así se dibuja
# igual pero la GPU no pinta los márgenes vacíos. El offset base queda en "base_off" (las sacudidas lo usan de referencia).
func _image(tex: Texture2D) -> Image:
	if not masks.has(tex):
		var im: Image = tex.get_image()
		if im.is_compressed():
			im.decompress()
		masks[tex] = im
	return masks[tex]

func _trim(s: Sprite2D) -> void:
	var r := _image(s.texture).get_used_rect()
	if r.size == Vector2i.ZERO or r.size == Vector2i(s.texture.get_size()):
		s.set_meta("base_off", s.offset)
		return
	s.region_enabled = true
	s.region_rect = Rect2(r)
	s.offset += Vector2(r.position)
	s.set_meta("base_off", s.offset)

# --- pasto por casilla (GrassTile) sobre las casillas verdes de la imagen del suelo; caminos, arena y agua quedan como estaban.
# Se agrupa en bloques de 10x10 casillas (un suelo y un MultiMesh por bloque) para no multiplicar las llamadas de dibujo.
const GRASS_BLOCK := 8

# Suelo del mapa (la imagen de data/map.json) como una malla de bloques de 32 px de la imagen: se omiten los bloques
# del todo transparentes y los que quedan enteros bajo casillas de pasto (su suelo opaco los tapa). Mismo dibujo, menos GPU.
const GROUND_BLOCK := 32

func _add_ground(tex: Texture2D, grass: Dictionary) -> void:
	var img := _image(tex)
	var size := Vector2(img.get_size())
	var verts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for by in ceili(size.y / GROUND_BLOCK):
		for bx in ceili(size.x / GROUND_BLOCK):
			var r := Rect2i(bx * GROUND_BLOCK, by * GROUND_BLOCK, mini(GROUND_BLOCK, img.get_width() - bx * GROUND_BLOCK), mini(GROUND_BLOCK, img.get_height() - by * GROUND_BLOCK))
			if img.get_region(r).is_invisible() or _under_grass(Rect2(r), grass):
				continue
			var k := verts.size()
			for c: Vector2i in [r.position, Vector2i(r.end.x, r.position.y), r.end, Vector2i(r.position.x, r.end.y)]:
				verts.append((Vector2(c) - main.map_origin) * main.SCALE)
				uvs.append(Vector2(c) / size)
			idx.append_array([k, k + 1, k + 2, k, k + 2, k + 3])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance2D.new()
	mi.mesh = mesh
	mi.texture = tex
	mi.z_index = -4000  # siempre por debajo de héroe, objetos y proyectiles
	add_child(mi)

func _under_grass(r: Rect2, grass: Dictionary) -> bool:  # true si todas las casillas que toca el bloque son de pasto
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c: Vector2 in [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]:
		var t: Vector2 = main.ground_to_tile(c - main.map_origin)
		lo = lo.min(t)
		hi = hi.max(t)
	for i in range(floori(lo.x), floori(hi.x) + 1):
		for j in range(floori(lo.y), floori(hi.y) + 1):
			if not grass.has(Vector2i(i, j)):
				return false
	return true

# Agua viva (WaterPatch) sobre las casillas azules de la imagen del suelo (el lago del valle).
func _add_water(tex: Texture2D) -> void:
	var img := _image(tex)
	var water := {}
	for i in tiles:
		for j in tiles:
			var px: Vector2 = main.tile_to_ground(Vector2(i + 0.5, j + 0.5)) + main.map_origin
			if px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height():
				continue
			var c := img.get_pixelv(Vector2i(px))
			if c.a > 0.5 and c.b > c.r + 0.15 and c.b > c.g:
				water[Vector2i(i, j)] = true
	if water.is_empty():
		return
	var w := WaterPatch.new()
	w.z_index = -3990
	w.build(water, func(i: float, j: float) -> Vector2: return main.tile_to_ground(Vector2(i, j)) * main.SCALE)
	add_child(w)

func _add_grass(tex: Texture2D) -> Dictionary:  # devuelve las casillas con pasto
	var img := _image(tex)
	var cells := {}
	var blocks := {}
	for i in tiles:
		for j in tiles:
			if walk[i][j] != "1":
				continue
			var px: Vector2 = main.tile_to_ground(Vector2(i + 0.5, j + 0.5)) + main.map_origin
			if px.x < 0 or px.y < 0 or px.x >= img.get_width() or px.y >= img.get_height():
				continue
			var c := img.get_pixelv(Vector2i(px))
			if not (c.g > c.r + 0.08 and c.g > c.b + 0.08):  # solo casillas de pasto
				continue
			var key := Vector2i(i / GRASS_BLOCK, j / GRASS_BLOCK)
			if not blocks.has(key):
				blocks[key] = []
			var q := PackedVector2Array()
			for k: Vector2 in [Vector2(i, j), Vector2(i + 1, j), Vector2(i + 1, j + 1), Vector2(i, j + 1)]:
				q.append(main.tile_to_ground(k) * main.SCALE)
			blocks[key].append({"q": q, "id": Vector2i(i, j)})
			cells[Vector2i(i, j)] = true
	for key: Vector2i in blocks:
		var g := GrassTile.new()
		g.z_index = -3990  # sobre la imagen del suelo, bajo puentes, huerto y todo lo demás
		g.build(blocks[key])
		add_child(g)
	if not blocks.is_empty():
		add_child(GrassManager.new())
	return cells

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
		var p: Vector2 = ((main.pos - Vector2(0, h)) * main.SCALE - s.position) / s.scale.x
		if p.x >= 0 and p.y >= 0 and p.x < img.get_width() and p.y < img.get_height() and img.get_pixel(int(p.x), int(p.y)).a > 0.5:
			return true
	return false

# Rendimiento: los tapadores se reparten en celdas de pantalla y cada fotograma solo se miran los de la celda del héroe
# (pies y cabeza) más los que siguen translúcidos. Mismo resultado que revisarlos todos.
const BUCKET := 512.0
var buckets := {}            # Vector2i -> sprites cuyo rectángulo toca esa celda
var bucketed := -1           # cuántos tapadores había al repartirlos (si cambia, se reparte de nuevo)
var faded: Array = []        # tapadores que no están opacos del todo

func _bucket_occluders() -> void:
	buckets.clear()
	bucketed = occluders.size()
	for s: Sprite2D in occluders:
		var r := Rect2(s.position, s.texture.get_size() * s.scale.x)
		for bx in range(floori(r.position.x / BUCKET), floori(r.end.x / BUCKET) + 1):
			for by in range(floori(r.position.y / BUCKET), floori(r.end.y / BUCKET) + 1):
				var k := Vector2i(bx, by)
				if not buckets.has(k):
					buckets[k] = []
				buckets[k].append(s)

var anim_sprites: Array = []  # [sprite, desfase en cuadros]
var anim_t := 0.0

func _process(delta: float) -> void:
	anim_t += delta * 6.0  # 6 cuadros por segundo: brisa tranquila
	for a: Array in anim_sprites:
		var s: Sprite2D = a[0]
		if is_instance_valid(s):
			var fr: Array = s.get_meta("frames")
			s.texture = fr[int(anim_t + a[1]) % fr.size()]
	_tick_respawns(delta)
	if not visible:
		return
	if bucketed != occluders.size():
		_bucket_occluders()
	var feet: Vector2 = main.pos * main.SCALE
	var head: Vector2 = (main.pos - Vector2(0, 70)) * main.SCALE
	var near: Array = buckets.get(Vector2i(floori(feet.x / BUCKET), floori(feet.y / BUCKET)), []).duplicate()
	for s: Sprite2D in buckets.get(Vector2i(floori(head.x / BUCKET), floori(head.y / BUCKET)), []):
		if not near.has(s):
			near.append(s)
	for s: Sprite2D in faded:
		if not near.has(s):
			near.append(s)
	faded.clear()
	for s: Sprite2D in near:
		var target := FADE_ALPHA if covers_hero(s) else 1.0
		if s.modulate.a != target:
			s.modulate.a = move_toward(s.modulate.a, target, delta * 4.0)
		if s.modulate.a != 1.0:
			faded.append(s)

func _cell_walkable(i: int, j: int) -> bool:
	if i < 0 or j < 0 or i >= tiles or j >= tiles:  # fuera de esta región: se pisa si la región vecina tiene suelo ahí (un solo mapa)
		return main.has_method("walkable_elsewhere") and main.walkable_elsewhere(self, i, j)
	return walk[i][j] == "1"

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
	_trim(s)
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

# Árbol vivo (LivingTree) en lugar del PNG: el Sprite2D se queda (talar, tapar al héroe y su forma para la transparencia),
# pero no se dibuja (self_modulate transparente); lo que se ve es el árbol hijo, del mismo tamaño que el dibujo original.
func _living_tree(s: Sprite2D, sp: Dictionary, tile: Vector2) -> void:
	var used := _image(s.texture).get_used_rect()
	var lt := LivingTree.new()
	lt.seed_value = int(tile.x * 131.0 + tile.y * 17.0)
	lt.crown = used.size.x * main.SCALE * 0.42
	lt.height = used.size.y * main.SCALE * 0.4
	lt.scale = Vector2.ONE / main.SCALE  # el sprite padre va a escala 3; el árbol se dibuja en px de pantalla
	lt.position = Vector2(sp["feet"][0], sp["feet"][1])
	s.self_modulate.a = 0.0
	s.region_enabled = true
	s.region_rect = Rect2()  # rendimiento: el sprite invisible no manda nada a dibujar (tapar y talar usan su textura, no su región)
	s.add_child(lt)
	s.set_meta("living", lt)

func hit_node(n: Dictionary, power: int) -> bool:  # true si este golpe lo agota
	n["hp"] -= power
	var s: Sprite2D = n["spr"]
	var tw := create_tween()  # sacudida del golpe
	var lt: Node2D = s.get_meta("living") if s.has_meta("living") else null
	if lt != null:  # el árbol vivo se sacude él (el sprite no se ve)
		var p0 := lt.position.x
		tw.tween_property(lt, "position:x", p0 + 5.0 / main.SCALE * 3.0, 0.04)
		tw.tween_property(lt, "position:x", p0 - 4.0 / main.SCALE * 3.0, 0.06)
		tw.tween_property(lt, "position:x", p0, 0.06)
	var bo: Vector2 = s.get_meta("base_off", Vector2.ZERO)
	tw.tween_property(s, "offset:x", bo.x + 5.0, 0.04)
	tw.tween_property(s, "offset:x", bo.x - 4.0, 0.06)
	tw.tween_property(s, "offset:x", bo.x, 0.06)
	if n["hp"] > 0:
		return false
	n["depleted"] = true
	n["t"] = float(main.crafting.cfg["gather"][n["kind"]]["respawn"])
	respawning.append(n)
	if n["circle"] != null:  # ya no estorba el paso
		n["circle"][1] = 0.0
		n["circle"][2] = 0.0
	var fall := create_tween()
	if lt != null:
		fall.tween_property(lt, "modulate:a", 0.0, 0.3)
	else:
		fall.tween_property(s, "self_modulate:a", 0.0, 0.3)
	fall.parallel().tween_property(s, "offset:y", float(s.get_meta("base_off", Vector2.ZERO).y) + 10.0, 0.3)
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
		s.offset = s.get_meta("base_off", Vector2.ZERO)
		s.visible = true
		var lt: Node2D = s.get_meta("living") if s.has_meta("living") else null
		if lt != null:  # vuelve a crecer el árbol vivo; el sprite sigue sin dibujarse
			lt.modulate.a = 0.0
			create_tween().tween_property(lt, "modulate:a", 1.0, 0.6)
			continue
		s.self_modulate.a = 0.0
		create_tween().tween_property(s, "self_modulate:a", 1.0, 0.6)
