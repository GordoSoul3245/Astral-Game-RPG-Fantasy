extends "res://scripts/world_map.gd"
# Zona exterior escrita a mano (data/zones.json): un mapa finito con suelo de colores, charcas, caminos, árboles o rocas colocados
# uno a uno y recursos en sitios fijos. Reusa colisiones, rutas y recolección de world_map.gd; los objetos usan los mismos sprites
# del mapa principal. Los monstruos, el cofre y las puertas los pone main._enter_zone.

var cfg := {}
var water := {}        # Vector2i -> true: charcas, bloquean como el mar
const ARBOL1_DIRS := ["south", "south-west", "west", "north-west", "north", "north-east", "east", "south-east"]
var floor_mesh: ArrayMesh
var paths := {}        # Vector2i -> true: caminos de tierra del "layout"
var floor_node: Node2D

class _Floor extends Node2D:
	var zone: Node2D

	func _draw() -> void:
		zone.paint(self)

func setup(data: Dictionary) -> void:
	cfg = data
	var n := int(data["tiles"])
	var forest: Array = []
	if data.has("layout"):  # mapa dibujado como texto: T bosque, . pasto, = camino, ~ agua (fila = j, columna = i)
		var lay: Array = data["layout"]
		for j in lay.size():
			var row: String = lay[j]
			for i in row.length():
				match row[i]:
					"~": water[Vector2i(i, j)] = true
					"=": paths[Vector2i(i, j)] = true
					"T":
						# bosque ralo: adentro una red al tresbolillo (i-j múltiplo de 4, uno sí y uno no) y todos los del borde de los claros, así las orillas quedan llenas
						var inner := (i - j) % 4 == 0 and posmod((i + j) / 2 + floori((i - j) / 4.0), 2) == 0
						if (i + j) % 2 == 0 and (inner or _clearing_next(lay, i, j)):
							var h := float((i * 73 + j * 37) % 100) / 100.0
							var o := _object("tree_arbol1", i + 0.3 + h * 0.4, j + 0.3 + fmod(h * 7.0, 1.0) * 0.4)
							o["dir"] = ARBOL1_DIRS[(i * 5 + j * 3) % 8]  # cada árbol mira a un lado: el bosque no se ve clonado
							forest.append(o)
	for r: Array in data["water_rects"]:
		for i in range(int(r[0]), int(r[2])):
			for j in range(int(r[1]), int(r[3])):
				water[Vector2i(i, j)] = true
	var rows: Array = []
	for i in n:
		var row := ""
		for j in n:
			var edge := i < 1 or j < 1 or i >= n - 1 or j >= n - 1  # el borde es el límite del mapa, salvo en los claros que llevan a otra región
			row += "0" if ((edge and not _gate(i, j)) or water.has(Vector2i(i, j))) else "1"
		rows.append(row)
	var sprites: Dictionary = main._read_json("res://data/map.json")["sprites"]
	sprites["tree_arbol1"] = {"path": "res://art/arbol1/south/frame_000.png", "frame": [124, 124], "feet": [62.0, 114.0], "anim": "res://art/arbol1/%s/frame_%03d.png"}  # árbol de PixelLab con reposo (9 cuadros, 8 direcciones)
	var objs: Array = forest
	for t: Array in data["trees"]:
		objs.append(_object(str(t[2]), float(t[0]), float(t[1])))
	for l: Dictionary in data["tree_lines"]:
		var a := Vector2(l["line"][0], l["line"][1])
		var b := Vector2(l["line"][2], l["line"][3])
		var steps := maxi(1, roundi(a.distance_to(b) / float(l["step"])))
		for k in steps + 1:
			var p := a.lerp(b, float(k) / float(steps))
			if not _in_gate_gap(p):
				objs.append(_object(str(l["sprite"]), p.x, p.y))
	super.setup({"tiles": n, "walk": rows, "objects": objs, "sprites": sprites})
	floor_node = _Floor.new()
	floor_node.zone = self
	floor_node.z_index = -4000
	add_child(floor_node)
	if data.has("layout"):  # pasto, agua y fogata vivos (los mismos del valle)
		var cells: Array = []
		for i in n:
			for j in n:
				var c := Vector2i(i, j)
				if not water.has(c) and not paths.has(c):
					cells.append({"q": PackedVector2Array([_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)]), "id": c})
		for k in range(0, cells.size(), 100):  # bloques de 100 casillas: pocas llamadas de dibujo
			var g := GrassTile.new()
			g.z_index = -3990
			g.build(cells.slice(k, k + 100))
			add_child(g)
		add_child(GrassManager.new())
		if not water.is_empty():
			var w := WaterPatch.new()
			w.z_index = -3990
			w.build(water, _corner)
			add_child(w)
		if data.has("camp"):
			var camp := Node2D.new()
			camp.set_script(load("res://scripts/payador.gd"))
			camp.main = main
			camp.fire_tile = Vector2(data["camp"]["fire"][0], data["camp"]["fire"][1])
			camp.seat_tile = Vector2(data["camp"]["old_man"][0], data["camp"]["old_man"][1])
			add_child(camp)
	var specs: Dictionary = main.crafting.cfg["world_sprites"]
	var glow := {"crystal": Color(0.65, 0.45, 1.0), "mushroom": Color(0.35, 1.0, 0.8)}
	for nd: Dictionary in data["nodes"]:
		var kind: String = nd["kind"]
		var key: String = {"herb": "herb_bush", "berry": "berry_bush"}.get(kind, "node_" + kind)
		var spec: Dictionary = specs[key]
		add_resource(kind, Vector2(nd["t"][0], nd["t"][1]), spec["paths"][0], spec["feet"], 0.0 if kind in ["mushroom", "herb", "berry"] else 0.45, glow.get(kind, Color.TRANSPARENT))

func _gate(i: int, j: int) -> bool:  # casilla del borde dentro de un claro que lleva a otra región
	var g: Dictionary = cfg.get("gates", {})
	var n := int(cfg["tiles"])
	for side: String in g:
		var r: Array = g[side]
		var along: int = j if side in ["w", "e"] else i
		var on_edge: bool = (side == "w" and i == 0) or (side == "e" and i == n - 1) or (side == "n" and j == 0) or (side == "s" and j == n - 1)
		if on_edge and along >= int(r[0]) and along <= int(r[1]):
			return true
	return false

func _in_gate_gap(p: Vector2) -> bool:  # los árboles del borde dejan libre el claro y un margen
	var g: Dictionary = cfg.get("gates", {})
	var n := float(cfg["tiles"])
	for side: String in g:
		var r: Array = g[side]
		var along: float = p.y if side in ["w", "e"] else p.x
		var depth: float = {"w": p.x, "e": n - p.x, "n": p.y, "s": n - p.y}[side]
		if depth < 3.0 and along >= float(r[0]) - 1.0 and along <= float(r[1]) + 2.0:
			return true
	return false

func _object(sprite: String, x: float, y: float) -> Dictionary:
	var r := 0.3 if sprite.begins_with("tree") else 0.5
	return {"sprite": sprite, "tile": [x, y], "circle": r, "pcircle": 0.55 if sprite.begins_with("tree") else r}

func _clearing_next(lay: Array, i: int, j: int) -> bool:  # la casilla toca pasto, camino o agua (no el borde del mapa)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var q := Vector2i(i, j) + d
		if q.y >= 0 and q.y < lay.size() and q.x >= 0 and q.x < String(lay[q.y]).length() and String(lay[q.y])[q.x] != "T":
			return true
	return false

func spawn_tile() -> Vector2:
	return Vector2(cfg["start"][0], cfg["start"][1])

func _corner(i: float, j: float) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

func _in_rects(i: int, j: int, key: String) -> bool:
	for r: Array in cfg[key]:
		if i >= int(r[0]) and i < int(r[2]) and j >= int(r[1]) and j < int(r[3]):
			return true
	return false

func paint(ci: CanvasItem) -> void:  # suelo de losas de colores: mullido, caminos y charcas que brillan
	_preview(ci)
	var g: Array = cfg["ground"]
	var t := Time.get_ticks_msec() * 0.001
	# Rendimiento: las losas y sus motas van en una sola malla (una llamada de dibujo en vez de ~4 por casilla)
	var verts := PackedVector2Array()
	var cols := PackedColorArray()
	var sc: float = main.SCALE
	var base := Color(str(g[0]))
	for i in tiles:
		for j in tiles:
			var quad := PackedVector2Array([_corner(i, j), _corner(i + 1, j), _corner(i + 1, j + 1), _corner(i, j + 1)])
			var col: Color
			if water.has(Vector2i(i, j)):
				col = Color(cfg["water"]).lerp(Color(cfg["water2"]), 0.5 + 0.5 * sin(t * 1.5 + i * 0.7 + j * 0.9))
			elif paths.has(Vector2i(i, j)) or _in_rects(i, j, "path_rects") or _gate_zone(i, j):
				col = Color(cfg["path"]).lightened(float((i * 7 + j * 13) % 5) * 0.012)
			else:
				col = Color(g[(i + j) % 2]).lightened(float((i * 5 + j * 3) % 4) * 0.012)
			verts.append_array([quad[0], quad[1], quad[2], quad[0], quad[2], quad[3]])
			for k in 6:
				cols.append(col)
			if not water.has(Vector2i(i, j)):  # textura: motas claras y oscuras repartidas por la casilla (hexágonos pequeños)
				var c: Vector2 = _corner(i + 0.5, j + 0.5)
				for k in 3:
					var hh := (i * 131 + j * 17 + k * 53) % 100
					var p := c + Vector2(float(hh % 21) - 10.0, float((hh * 7) % 9) - 4.0) * sc
					var r := (1.4 + float(hh % 3) * 0.5) * sc
					var mc := base.darkened(0.1) if hh % 2 == 0 else base.lightened(0.12)
					for e in 6:
						verts.append_array([p, p + Vector2.from_angle(e * TAU / 6.0) * r, p + Vector2.from_angle((e + 1) * TAU / 6.0) * r])
						cols.append_array([mc, mc, mc])
			_detail(ci, i, j, t)
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_COLOR] = cols
	floor_mesh = ArrayMesh.new()  # se guarda: el lienzo solo referencia la malla, si se libera no se dibuja
	floor_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	ci.draw_mesh(floor_mesh, null)

func _preview(ci: CanvasItem) -> void:  # adelanto de la región vecina al otro lado de cada claro
	var g: Dictionary = cfg.get("gates", {})
	var pv: Dictionary = cfg.get("preview", {})
	var n := int(cfg["tiles"])
	var sc: float = main.SCALE
	for side: String in g:
		var col := Color(str(pv.get(side, "#35682a")))
		var r: Array = g[side]
		for k in range(1, 8):
			for j in range(int(r[0]) - 3, int(r[1]) + 4):
				var i: int = j
				var j2: int = j
				if side in ["w", "e"]:
					i = -k if side == "w" else n - 1 + k
				else:
					j2 = -k if side == "n" else n - 1 + k
				var h := (absi(i) * 73 + absi(j2) * 31) % 100
				var q := PackedVector2Array([_corner(i, j2), _corner(i + 1, j2), _corner(i + 1, j2 + 1), _corner(i, j2 + 1)])
				ci.draw_colored_polygon(q, col.lightened(float(h % 5) * 0.02) if (i + j2) % 2 == 0 else col.darkened(0.06))
				if h < 11 and k > 1:
					var b := _corner(i + 0.5, j2 + 0.5)
					ci.draw_colored_polygon(PackedVector2Array([b + Vector2(-9, 0) * sc, b + Vector2(9, 0) * sc, b + Vector2(0, -34) * sc]), col.darkened(0.45))

func _gate_zone(i: int, j: int) -> bool:  # camino que sale del claro hacia dentro
	var g: Dictionary = cfg.get("gates", {})
	var n := int(cfg["tiles"])
	for side: String in g:
		var r: Array = g[side]
		var along: int = j if side in ["w", "e"] else i
		var depth: int = {"w": i, "e": n - 1 - i, "n": j, "s": n - 1 - j}[side]
		if depth <= 3 and along >= int(r[0]) and along <= int(r[1]):
			return true
	return false

func _detail(ci: CanvasItem, i: int, j: int, t: float) -> void:  # detalles de suelo repartidos por una función de las casillas (siempre iguales)
	var h := (i * 73856093 ^ j * 19349663) % 100
	var c: Vector2 = _corner(i + 0.5, j + 0.5)
	var sc: float = main.SCALE
	var kind: String = str(cfg.get("detail", ""))
	if kind == "snow":
		if water.has(Vector2i(i, j)):
			if h < 18:  # grietas del hielo
				ci.draw_line(c + Vector2(-12, -3) * sc, c + Vector2(10, 4) * sc, Color(1, 1, 1, 0.6), 1.5)
		elif h < 12:  # ventisqueros
			ci.draw_circle(c + Vector2(float(h % 5) - 2.0, 3.0) * sc, 7.0 * sc, Color(1, 1, 1, 0.55))
		elif h > 92:  # cristales de hielo
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-3, 0) * sc, c + Vector2(0, -12) * sc, c + Vector2(3, 0) * sc]), Color(0.65, 0.9, 1.0))
	if kind == "swamp":
		if water.has(Vector2i(i, j)):
			if h < 22:  # nenúfar
				ci.draw_circle(c + Vector2(float(h % 7) - 3.0, float(h % 5) - 2.0) * sc, 5.0 * sc, Color(0.2, 0.5, 0.25))
				ci.draw_circle(c + Vector2(float(h % 7) - 2.0, float(h % 5) - 3.0) * sc, 1.6 * sc, Color(0.95, 0.8, 0.9))
		elif h < 16 and not _in_rects(i, j, "path_rects"):  # juncos
			for k in 3:
				var b := c + Vector2(float(k - 1) * 5.0 + float(h % 3), 3.0) * sc
				ci.draw_line(b, b + Vector2(float(k - 1) * 2.0, -12.0 - float(h % 4)) * sc, Color(0.2, 0.34, 0.16), 2.0)
	elif kind == "desert":
		if h < 14 and not water.has(Vector2i(i, j)):  # rizos de arena
			ci.draw_line(c + Vector2(-14, 2) * sc, c + Vector2(14, -2) * sc, Color(0.8, 0.66, 0.38, 0.7), 2.0)
		elif h > 94 and not water.has(Vector2i(i, j)):  # guijarros
			ci.draw_circle(c + Vector2(float(h % 9) - 4.0, 2.0) * sc, 2.2 * sc, Color(0.55, 0.45, 0.32))

func _process(delta: float) -> void:
	super._process(delta)
	if floor_node and not water.is_empty() and not cfg.has("layout"):  # las charcas brillan; en las zonas con layout el agua viva (WaterPatch) ya se mueve sola
		floor_node.queue_redraw()
