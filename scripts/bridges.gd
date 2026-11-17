extends Node2D
# Puentes de tablas del valle hacia las regiones vecinas (data/world.json): abren casillas de mar como transitables y se dibujan
# a ras de suelo con barandilla y un cartel. Más allá del borde del mapa se ve un adelanto de la región vecina (suelo y siluetas).
# Funciona en los cuatro lados: w/e (las filas son y) y n/s (las "filas" son x). Cruzar su extremo lleva a la región de al lado.

var main: Node
var cells: Array[Vector2i] = []
var links: Array = []    # {side, rows, cells, color, label}

func _ready() -> void:
	z_index = -3900

func _horiz(side: String) -> bool:
	return side in ["w", "e"]

func _tile(side: String, depth: float, along: float) -> Vector2:  # depth = distancia al borde de su lado; along = posición a lo largo del borde
	var n: float = float(main.world.tiles)
	match side:
		"w": return Vector2(depth, along)
		"e": return Vector2(n - 1.0 - depth, along)
		"n": return Vector2(along, depth)
	return Vector2(along, n - 1.0 - depth)

func add_link(side: String, rows: Array, color := Color("#35682a"), label := "") -> void:  # abre el mar entre la costa y el borde por las filas indicadas
	var n: int = main.world.tiles
	var mine: Array[Vector2i] = []
	for r in range(int(rows[0]), int(rows[1]) + 1):
		for k in n:  # desde el borde hacia dentro, hasta tocar tierra
			var t := _tile(side, float(k), float(r))
			var c := Vector2i(int(t.x), int(t.y))
			if str(main.world.walk[c.x])[c.y] == "1":
				break
			var row: String = main.world.walk[c.x]
			main.world.walk[c.x] = row.substr(0, c.y) + "1" + row.substr(c.y + 1)
			cells.append(c)
			mine.append(c)
	links.append({"side": side, "rows": rows, "cells": mine, "color": color, "label": label})
	queue_redraw()

func _corner(i: float, j: float) -> Vector2:
	return main.tile_to_ground(Vector2(i, j)) * main.SCALE

# Rendimiento: los cientos de rombos y siluetas se juntan en una sola malla y las líneas en pocas llamadas (mismo dibujo)
var _tv := PackedVector2Array()
var _tc := PackedColorArray()
var _lines := {}   # ancho -> [puntos, colores] para draw_multiline_colors
var _mesh: ArrayMesh

func _tri(a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	_tv.append_array([a, b, c])
	_tc.append_array([color, color, color])

func _quad(i: float, j: float, color: Color) -> void:
	var a := _corner(i, j)
	var b := _corner(i + 1, j)
	var c := _corner(i + 1, j + 1)
	var d := _corner(i, j + 1)
	_tri(a, b, c, color)
	_tri(a, c, d, color)

func _line(a: Vector2, b: Vector2, color: Color, width: float) -> void:
	if not _lines.has(width):
		_lines[width] = [PackedVector2Array(), PackedColorArray()]
	_lines[width][0].append_array([a, b])
	_lines[width][1].append(color)

func _draw() -> void:
	_tv.clear()
	_tc.clear()
	_lines.clear()
	var boards: Array = []
	_build(boards)
	if not _tv.is_empty():
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = _tv
		arrays[Mesh.ARRAY_COLOR] = _tc
		_mesh = ArrayMesh.new()  # se guarda: el dibujo la sigue usando después de _draw
		_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		draw_mesh(_mesh, null)
	for w: float in _lines:
		draw_multiline_colors(_lines[w][0], _lines[w][1], w)
	for b: Array in boards:  # carteles al final, encima de todo
		var sc: float = main.SCALE
		var board: Rect2 = b[0]
		draw_rect(board, Color("#a97a42"))
		draw_rect(board, Color("#3a2410"), false, 3.0)
		draw_string(ThemeDB.fallback_font, board.position + Vector2(10, 18) * sc * 0.9, b[1], HORIZONTAL_ALIGNMENT_LEFT, -1, int(15 * sc * 0.6), Color("#2a1608"))

func _build(boards: Array) -> void:
	var sc: float = main.SCALE
	for l: Dictionary in links:
		var side: String = l["side"]
		var rows: Array = l["rows"]
		var col: Color = l["color"]
		for k in range(1, 9):  # adelanto de la región vecina más allá del borde: suelo y siluetas
			for r in range(int(rows[0]) - 3, int(rows[1]) + 4):
				var t := _tile(side, -float(k), float(r))
				var h := (int(t.x) * 73 + int(t.y) * 31 + 1000) % 100
				_quad(t.x, t.y, col.lightened(float(h % 5) * 0.02) if (int(t.x) + int(t.y)) % 2 == 0 else col.darkened(0.06))
				if h < 11 and k > 1:
					var b := _corner(t.x + 0.5, t.y + 0.5)
					_tri(b + Vector2(-9, 0) * sc, b + Vector2(9, 0) * sc, b + Vector2(0, -34) * sc, col.darkened(0.45))
		for c: Vector2i in l["cells"]:
			_quad(c.x, c.y, Color("#8a6238") if (c.x + c.y) % 2 == 0 else Color("#7a5530"))
			var ring := [_corner(c.x, c.y), _corner(c.x + 1, c.y), _corner(c.x + 1, c.y + 1), _corner(c.x, c.y + 1), _corner(c.x, c.y)]
			for e in 4:
				_line(ring[e], ring[e + 1], Color("#3a2410"), 2.0)
		var nrows: int = int(rows[1]) - int(rows[0]) + 1
		var steps: int = l["cells"].size() / nrows  # largo del puente en casillas
		for er: float in [float(rows[0]), float(rows[1]) + 1.0]:  # barandillas en los dos bordes largos y un poste por casilla
			var a := _tile(side, 0.0, er)
			var b2 := _tile(side, float(steps), er)
			if side in ["e", "s"]:  # el origen de una casilla es su esquina superior: ajusta para que la barandilla toque el borde
				a += Vector2(1, 0) if side == "e" else Vector2(0, 1)
				b2 += Vector2(1, 0) if side == "e" else Vector2(0, 1)
			_line(_corner(a.x, a.y) - Vector2(0, 16) * sc, _corner(b2.x, b2.y) - Vector2(0, 16) * sc, Color("#4a2e14"), 3.0)
			for st in range(0, steps + 1):
				var q := _tile(side, float(st), er)
				if side in ["e", "s"]:
					q += Vector2(1, 0) if side == "e" else Vector2(0, 1)
				var px := _corner(q.x, q.y)
				_line(px, px - Vector2(0, 20) * sc, Color("#3a2410"), 4.0)
		if l["cells"].size() > 0 and l["label"] != "":  # cartel en el extremo de la costa
			var s0 := _tile(side, float(steps), float(rows[0]) - 0.4)
			var shore := _corner(s0.x, s0.y)
			_line(shore, shore - Vector2(0, 44) * sc, Color("#3a2410"), 5.0)
			boards.append([Rect2(shore + Vector2(-58, -70) * sc, Vector2(116, 24) * sc), str(l["label"])])
